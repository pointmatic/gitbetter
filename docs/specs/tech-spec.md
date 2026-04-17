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
├── git-push.sh                  # git-push command script (exists)
├── git-tag.sh                   # git-tag command script (to write)
├── tests/
│   ├── test_helper/
│   │   └── common-setup.bash    # Shared BATS test setup (temp repo, helpers)
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
| **Test files** | `git-<command>.bats` (matches script name) | `git-push.bats`, `git-tag.bats` |
| **Test helpers** | `<name>.bash` (`.bash` extension for sourced files) | `common-setup.bash` |
| **GitHub workflows** | Hyphens, lowercase | `ci.yml`, `homebrew.yml` |
| **Documentation** | Hyphens, lowercase | `tech-spec.md`, `project-essentials.md` |

---

## Key Component Design

### Shared Constants & Helpers

Both `git-push.sh` and `git-tag.sh` must define an identical block of color constants, symbols, and helper functions at the top of the script. These are **duplicated** (not sourced from a shared file) to keep each script fully standalone with zero file dependencies.

#### Color Constants

```bash
R=$'\033[0;31m'   G=$'\033[0;32m'   Y=$'\033[0;33m'
B=$'\033[0;34m'   C=$'\033[0;36m'   M=$'\033[0;35m'
DIM=$'\033[2m'    BOLD=$'\033[1m'   RESET=$'\033[0m'
CHECK="${G}✔${RESET}"   CROSS="${R}✘${RESET}"   ARROW="${C}▸${RESET}"
WARN="${Y}⚠${RESET}"
```

#### Helper Functions

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

#### Header Box

```bash
echo -e "  ${BOLD}${C}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${C}│${RESET}  ${BOLD}<command-name>${RESET}                        ${BOLD}${C}│${RESET}"
echo -e "  ${BOLD}${C}╰─────────────────────────────────────────╯${RESET}"
```

#### Footer Box

```bash
echo -e "  ${BOLD}${G}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${G}│${RESET}  ${CHECK} ${BOLD}All done.${RESET}                            ${BOLD}${G}│${RESET}"
echo -e "  ${BOLD}${G}╰─────────────────────────────────────────╯${RESET}"
```

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
| `git-push` | `git-push [--amend] "message" [branch]` | Stage, commit, push, and optionally clean up |
| `git-tag` | `git-tag <vX.Y.Z> [branch]` | Validate semver, create tag, push to origin |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success (including user-initiated abort via "n" at a prompt) |
| `1` | Error (validation failure, git command failure, missing arguments) |

### Shared Flags

None. Each command has its own argument set. No global flags or shared option parsing.

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

**git-push.bats:**
- Missing commit message → prints usage, exits 1
- Empty message after sanitization → fails with error
- Backtick and quote sanitization produces correct message
- `--amend` flag is parsed correctly
- Positional args (message, branch) are parsed correctly

**git-tag.bats:**
- Missing tag argument → prints usage, exits 1
- Valid semver tags accepted: `v0.0.1`, `v1.0.0`, `v10.20.30`
- Invalid tags rejected: `1.0.0`, `v1.0`, `v1.2.3.4`, `vabc`, `v1.2.3-beta`
- Duplicate tag detection → fails with "already exists"
- Latest tag sorted numerically: `v1.9.0` < `v1.10.0`
- Tag creation and push execute correct git commands

### CI Integration

ShellCheck and BATS run on every push and pull request via `.github/workflows/ci.yml`.

---

## Packaging and Distribution

### Homebrew Formula

- **Tap**: `pointmatic/tap` (hosted on GitHub as `pointmatic/homebrew-tap`)
- **Formula name**: `gitbetter`
- **Install method**: `brew install pointmatic/tap/gitbetter`
- **What it installs**: `git-push.sh` and `git-tag.sh` into the Homebrew prefix bin directory, renamed to `git-push` and `git-tag` (dropping the `.sh` extension) so git discovers them as subcommands.

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
        run: shellcheck git-push.sh git-tag.sh
      - name: Install BATS
        run: |
          git clone https://github.com/bats-core/bats-core.git /tmp/bats
          /tmp/bats/install.sh /usr/local
          git clone https://github.com/bats-core/bats-support.git /tmp/bats-support
          git clone https://github.com/bats-core/bats-assert.git /tmp/bats-assert
      - name: Test
        run: bats tests/
```
