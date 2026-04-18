# tech-spec.md -- gitbetter (Bash 4.0+)

This document defines **how** the `gitbetter` project is built -- architecture, module layout, dependencies, data models, API signatures, and cross-cutting concerns.

For requirements and behavior, see `features.md`. For the implementation plan, see `stories.md`. For project-specific must-know facts (workflow rules, architecture quirks, hidden coupling), see `project-essentials.md` — `plan_tech_spec` populates it after this document is approved.

---

## Runtime & Tooling

| Tool | Version / Details |
|------|-------------------|
| **Language** | Bash ≥ 4.0 |
| **Shell mode** | `set -euo pipefail` in every script |
| **Linter** | [ShellCheck](https://www.shellcheck.net/) (latest, run in CI) |
| **Test framework** | [BATS-core](https://github.com/bats-core/bats-core) (Bash Automated Testing System) |
| **CI** | GitHub Actions (ubuntu-latest runner) |
| **Package manager** | Homebrew (distribution only; no build-time package manager) |

---

## Dependencies

### Runtime (system-level)

| Dependency | Minimum Version | Purpose |
|------------|----------------|---------|
| `bash` | 4.0 | Script interpreter — arrays, regex, `set -euo pipefail` |
| `git` | 2.30 | `git switch`, `--force-with-lease`, `--porcelain` |
| `coreutils` | — | `sort`, `head`, `read`, `echo` (standard on macOS and Linux) |

### Development

| Dependency | Purpose |
|------------|---------|
| `shellcheck` | Static analysis / linting |
| `bats-core` | Test runner for `.bats` test files |
| `bats-support` | BATS helper library (assertions) |
| `bats-assert` | BATS assertion functions (`assert_success`, `assert_output`, etc.) |

No runtime libraries, no Python, no Node, no compiled code.

---

## Package Structure

```
gitbetter/
├── gitbetter.sh                 # Umbrella info command (--help, --version)
├── git-push.sh                  # git-push command script
├── git-tag.sh                   # git-tag command script
├── lib/
│   └── ui.sh                    # Shared UI helpers + version/homepage constants
├── tests/
│   ├── test_helper/
│   │   └── common-setup.bash    # Shared BATS test setup (temp repo, helpers)
│   ├── gitbetter.bats           # BATS tests for gitbetter umbrella command
│   ├── git-push.bats            # BATS tests for git-push
│   └── git-tag.bats             # BATS tests for git-tag
├── .github/
│   └── workflows/
│       ├── ci.yml               # CI: shellcheck + BATS on push/PR
│       └── homebrew.yml         # Homebrew formula bump on v* tag push
├── docs/
│   └── specs/
│       ├── idea.md              # Project idea
│       ├── concept.md           # Problem/solution space
│       ├── features.md          # Requirements and behavior
│       ├── tech-spec.md         # This file
│       └── project-essentials.md # Must-know facts for LLMs
├── LICENSE                      # Apache-2.0
├── README.md                    # Project overview, install, usage
└── .gitignore                   # Ignore patterns
```

---

## Filename Conventions

| File Type | Convention | Examples |
|-----------|------------|----------|
| **Command scripts** | `git-<command>.sh` (hyphenated, `.sh` extension) | `git-push.sh`, `git-tag.sh` |
| **Library scripts** | `<name>.sh` in `lib/` (sourced by command scripts) | `lib/ui.sh` |
| **Test files** | `git-<command>.bats` (matches script name) | `git-push.bats`, `git-tag.bats` |
| **Test helpers** | `<name>.bash` (`.bash` extension for sourced files) | `common-setup.bash` |
| **GitHub workflows** | Hyphens, lowercase | `ci.yml`, `homebrew.yml` |
| **Documentation** | Hyphens, lowercase | `tech-spec.md`, `project-essentials.md` |

---

## Key Component Design

### Shared UI Library (`lib/ui.sh`)

All color constants, symbols, and helper functions live in a single sourced library, `lib/ui.sh`. Every command script sources it at the top:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/ui.sh
source "${SCRIPT_DIR}/lib/ui.sh"
```

`pwd -P` resolves symlinks so `lib/ui.sh` is found even if the command is invoked via a symlinked entry on `PATH`. Homebrew installation places both the command scripts and `lib/` into `libexec/` together; see [Homebrew Formula](#homebrew-formula) for details.

When a helper changes, update it only in `lib/ui.sh` — all commands pick it up automatically.

#### Shared Constants

```bash
GITBETTER_VERSION="1.1.0"
GITBETTER_HOMEPAGE="https://github.com/pointmatic/gitbetter"
```

Single source of truth for the version number and project homepage URL. Bumped whenever a story bumps the product version.

#### Color Constants

```bash
R=$'\033[0;31m'   G=$'\033[0;32m'   Y=$'\033[0;33m'
B=$'\033[0;34m'   C=$'\033[0;36m'   M=$'\033[0;35m'
DIM=$'\033[2m'    BOLD=$'\033[1m'   RESET=$'\033[0m'
CHECK="${G}✔${RESET}"   CROSS="${R}✘${RESET}"   ARROW="${C}▸${RESET}"
WARN="${Y}⚠${RESET}"
```

#### Helper Functions (provided by `lib/ui.sh`)

| Function | Signature | Behavior |
|----------|-----------|----------|
| `banner` | `banner "Title"` | Prints `\n── Title ──` in blue+bold |
| `info` | `info "message"` | Prints `  ▸ message` with cyan arrow |
| `success` | `success "message"` | Prints `  ✔ message` with green check |
| `warn` | `warn "message"` | Prints `  ⚠ message` with yellow warning |
| `fail` | `fail "message"` | Prints `  ✘ message` in red, exits 1 |
| `confirm` | `confirm "Prompt text"` | `[Y/n]` prompt, default yes; exits 0 on abort |
| `ask_yn` | `ask_yn "Prompt text"` | `[y/N]` prompt, default no; returns 0/1 |
| `divider` | `divider` | Prints a dimmed horizontal rule |
| `run_cmd` | `run_cmd git add -A` | Echoes `$ git add -A` dimmed, then executes |
| `header_box` | `header_box "git-push"` | Prints the cyan rounded-corner header box with the given title |
| `footer_box` | `footer_box` | Prints the green rounded-corner footer box with "✔ All done." |
| `print_version` | `print_version [subcommand]` | Prints `gitbetter[ <subcommand>] v<GITBETTER_VERSION>` followed by the homepage URL. Called by every command's `--version` handler. |

#### Header Box (rendered by `header_box "<command-name>"` inside `lib/ui.sh`)

```bash
echo -e "  ${BOLD}${C}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${C}│${RESET}  ${BOLD}<command-name>${RESET}                        ${BOLD}${C}│${RESET}"
echo -e "  ${BOLD}${C}╰─────────────────────────────────────────╯${RESET}"
```

#### Footer Box (rendered by `footer_box` inside `lib/ui.sh`)

```bash
echo -e "  ${BOLD}${G}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${G}│${RESET}  ${CHECK} ${BOLD}All done.${RESET}                            ${BOLD}${G}│${RESET}"
echo -e "  ${BOLD}${G}╰─────────────────────────────────────────╯${RESET}"
```

### gitbetter.sh (umbrella command)

Pure info command. Does not perform git operations or dispatch to subcommands. See `features.md` FR-9 for behavior.

| Aspect | Implementation |
|--------|---------------|
| **Argument parsing** | `case "${1:-}"` on first arg: empty or `--help` → `print_help`; `--version` → `print_version`; anything else → error to stderr, exit 1. |
| **Help text** | Local `print_help()` function in `gitbetter.sh` — lists all gitbetter commands (`git-push`, `git-tag`), points users at `git-push --help` / `git-tag --help`, ends with `Homepage: ${GITBETTER_HOMEPAGE}`. |
| **Version output** | `print_version` (from `lib/ui.sh`) called with no subcommand name. |
| **Exit code** | 0 for help/version; 1 for unknown flag. |

### Meta-flag handling in `git-push.sh` and `git-tag.sh`

Both scripts handle `--help` and `--version` **before** any git-repo validation or other arg parsing, so the flags work outside a git repository.

```bash
case "${1:-}" in
    --help)    print_help;    exit 0 ;;
    --version) print_version "git-push"; exit 0 ;;
esac
```

The `print_help()` function is defined locally in each script (since help text is per-command), while `print_version` is shared from `lib/ui.sh`.

### git-push.sh

Already implemented. See `features.md` FR-2 through FR-5 for behavior. Key implementation details from the existing code:

| Aspect | Implementation |
|--------|---------------|
| **Argument parsing** | Loop over `$@`, `--amend` flag extracted, positionals collected into array |
| **Message sanitization** | Bash parameter expansion: strip backticks (`${COMMIT_MSG//\`/}`), convert `"` to `'` |
| **Branch detection** | `git symbolic-ref --short HEAD` |
| **Branch switch** | `git show-ref --verify` to check existence, then `git switch` or `git switch -c` |
| **Pre-commit recovery** | `git status --porcelain` post-commit; `ask_yn` to fold via `--amend --no-edit` |
| **Push retry** | On push failure, `ask_yn` to retry with `--force-with-lease` |
| **GitHub Actions URL** | Regex on `git remote get-url origin` to extract `github.com/<owner>/<repo>` |
| **Browser open** | `open` (macOS) or `xdg-open` (Linux) with fallback |

### git-tag.sh

To be written. Must follow the same structure as `git-push.sh`.

| Aspect | Implementation |
|--------|---------------|
| **Argument parsing** | `TAG="${1:-}"`, `BRANCH_NAME="${2:-}"`. Fail if TAG is empty. |
| **Semver validation** | Regex: `^v[0-9]+\.[0-9]+\.[0-9]+$`. Fail with format error if no match. |
| **Duplicate check** | `git tag -l "$TAG"` — if non-empty, fail with "tag already exists". |
| **Latest tag display** | `git tag -l 'v*'`, pipe through `sort -t. -k1,1n -k2,2n -k3,3n` (strip `v` prefix for sort, re-add), take last. |
| **Tag creation** | `run_cmd git tag "$TAG"` |
| **Tag push** | `run_cmd git push origin "$TAG"` |
| **Outcome proof** | `git tag -l "$TAG"` displayed as one-liner confirmation |

---

## Data Models

N/A — Bash scripts with no persistent data structures. All state is local variables within a single script execution.

---

## Configuration

No configuration files, no environment variables, no dotfiles. All behavior is driven by CLI arguments and interactive prompts.

---

## CLI Design

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `gitbetter` | `gitbetter [--help \| --version]` | Umbrella info command — lists subcommands, prints version |
| `git-push` | `git-push [--amend] "message" [branch]` | Stage, commit, push, and optionally clean up |
| `git-tag` | `git-tag <vX.Y.Z> [branch]` | Validate semver, create tag, push to origin |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success (including user-initiated abort via "n" at a prompt) |
| `1` | Error (validation failure, git command failure, missing arguments) |

### Shared Flags

All three commands (`gitbetter`, `git-push`, `git-tag`) support:

| Flag | Behavior |
|------|----------|
| `--help` | Print per-command help (usage, options, examples, homepage) and exit 0. Checked before any other processing. |
| `--version` | Print `gitbetter[ <subcommand>] v<GITBETTER_VERSION>` followed by the homepage URL and exit 0. Checked before any other processing. |

Only long-form flags; no `-h` / `-v` aliases (reserved for potential future use).

---

## Cross-Cutting Concerns

### Error Handling

- `set -euo pipefail` at the top of every script — any unhandled error exits immediately.
- Git commands that may fail are wrapped in `if run_cmd git ...; then ... else ... fi` to provide controlled error messages.
- `fail()` prints a red error and calls `exit 1`.

### User Abort

- `confirm()` exits with code 0 (clean abort) if the user answers "n".
- `ask_yn()` returns 1 (false) on "n" — caller decides whether to abort or skip.

### Terminal Output

- All output is indented 2 spaces for visual consistency.
- ANSI escape codes are hardcoded (no `tput`). They degrade harmlessly in terminals without color support.
- No output to stderr — all output goes to stdout.

---

## Performance Implementation

N/A — interactive scripts with negligible overhead. No concurrency, no batching, no caching.

---

## Testing Strategy

### Test Runner

BATS-core with `bats-support` and `bats-assert` helper libraries.

### Test Structure

```
tests/
├── test_helper/
│   └── common-setup.bash    # Shared setup: create temp git repo, source helpers
├── git-push.bats            # Tests for git-push
└── git-tag.bats             # Tests for git-tag
```

### common-setup.bash

Each test gets an isolated temporary git repository:

```bash
setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}
```

### Test Coverage

**gitbetter.bats:**
- No args → prints help, exits 0
- `--help` → prints help (contains Usage, Commands, Homepage), exits 0
- `--version` → prints `gitbetter v<VERSION>` and homepage URL, exits 0
- Unknown flag → exits 1

**git-push.bats:**
- Missing commit message → prints usage, exits 1
- Empty message after sanitization → fails with error
- Backtick and quote sanitization produces correct message
- `--amend` flag is parsed correctly
- Positional args (message, branch) are parsed correctly
- `--help` → exits 0 with full help text (Usage, Examples, Homepage)
- `--version` → exits 0 with `gitbetter git-push v<VERSION>` and homepage URL

**git-tag.bats:**
- Missing tag argument → prints usage, exits 1
- Valid semver tags accepted: `v0.0.1`, `v1.0.0`, `v10.20.30`
- Invalid tags rejected: `1.0.0`, `v1.0`, `v1.2.3.4`, `vabc`, `v1.2.3-beta`
- Duplicate tag detection → fails with "already exists"
- Latest tag sorted numerically: `v1.9.0` < `v1.10.0`
- Tag creation and push execute correct git commands
- `--help` → exits 0 with full help text (Usage, Examples, Homepage)
- `--version` → exits 0 with `gitbetter git-tag v<VERSION>` and homepage URL

### CI Integration

ShellCheck and BATS run on every push and pull request via `.github/workflows/ci.yml`.

---

## Packaging and Distribution

### Homebrew Formula

- **Tap**: `pointmatic/tap` (hosted on GitHub as `pointmatic/homebrew-tap`)
- **Formula name**: `gitbetter`
- **Install method**: `brew install pointmatic/tap/gitbetter`
- **What it installs**:
  - Command scripts (`gitbetter.sh`, `git-push.sh`, `git-tag.sh`) and the `lib/` directory are installed into the formula's `libexec` path.
  - Thin wrapper scripts are written to `bin/` as `gitbetter`, `git-push`, and `git-tag` (no `.sh` extension) so git discovers the hyphenated pair as subcommands. Each wrapper `exec`s its real script in `libexec`, preserving `$BASH_SOURCE[0]` resolution so `lib/ui.sh` is found at `<libexec>/lib/ui.sh`.

  The formula lives in the `pointmatic/homebrew-tap` repository (not in this repo). The `url` and `sha256` fields are updated automatically by `dawidd6/action-homebrew-bump-formula` on every `v*` tag push (see [GitHub Actions — Formula Auto-Bump](#github-actions--formula-auto-bump)); all other fields are maintained manually.

  ```ruby
  class Gitbetter < Formula
    desc "Streamline repetitive git workflows (push, tag) into single interactive commands"
    homepage "https://github.com/pointmatic/gitbetter"
    url "https://github.com/pointmatic/gitbetter/archive/refs/tags/vX.Y.Z.tar.gz"
    sha256 "<updated-by-action-on-each-release>"
    license "Apache-2.0"

    def install
      libexec.install "lib", "gitbetter.sh", "git-push.sh", "git-tag.sh"
      (bin/"gitbetter").write <<~SH
        #!/usr/bin/env bash
        exec "#{libexec}/gitbetter.sh" "$@"
      SH
      (bin/"git-push").write <<~SH
        #!/usr/bin/env bash
        exec "#{libexec}/git-push.sh" "$@"
      SH
      (bin/"git-tag").write <<~SH
        #!/usr/bin/env bash
        exec "#{libexec}/git-tag.sh" "$@"
      SH
      chmod 0555, [bin/"gitbetter", bin/"git-push", bin/"git-tag"]
    end

    test do
      assert_match "v#{version}", shell_output("#{bin}/gitbetter --version")
      assert_match "v#{version}", shell_output("#{bin}/git-push --version")
      assert_match "v#{version}", shell_output("#{bin}/git-tag --version")
    end
  end
  ```

  The `test do` block is required by `brew audit --strict` and exercised by `brew test gitbetter` and the tap's CI. It relies on the `--version` flag added in Story D.d.

### GitHub Actions — Formula Auto-Bump

`.github/workflows/homebrew.yml` triggers on `v*` tag push:

```yaml
name: Update Homebrew Formula
on:
  push:
    tags: ['v*']
jobs:
  update-formula:
    runs-on: ubuntu-latest
    steps:
      - name: Update Homebrew formula
        uses: dawidd6/action-homebrew-bump-formula@v4
        with:
          token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
          tap: pointmatic/tap
          formula: gitbetter
          tag: ${{ github.ref_name }}
```

### GitHub Actions — CI

`.github/workflows/ci.yml` triggers on push and PR to `main`:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install ShellCheck
        run: sudo apt-get install -y shellcheck
      - name: Lint
        run: shellcheck gitbetter.sh git-push.sh git-tag.sh lib/ui.sh
      - name: Install BATS
        run: |
          git clone https://github.com/bats-core/bats-core.git /tmp/bats
          /tmp/bats/install.sh /usr/local
          git clone https://github.com/bats-core/bats-support.git /tmp/bats-support
          git clone https://github.com/bats-core/bats-assert.git /tmp/bats-assert
      - name: Test
        run: bats tests/
```
