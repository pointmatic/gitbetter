# features.md -- gitbetter (Bash 4.0+)

This document defines **what** the `gitbetter` project does -- requirements, inputs, outputs, behavior -- without specifying **how** it is implemented. This is the source of truth for scope.

For a high-level concept (why), see `concept.md`. For implementation details (how), see `tech-spec.md`. For a breakdown of the implementation plan (step-by-step tasks), see `stories.md`. For project-specific must-know facts that future LLMs need to avoid blunders, see `project-essentials.md`.

---

## Project Goal

Provide a set of Homebrew-installable Bash scripts that streamline repetitive git workflows — stage, commit, push, tag, and branch cleanup — into single, interactive commands with confirmation gates, colorful output, and smart defaults. Each command follows a consistent UX pattern so developers always know what to expect.

### Core Requirements

- `gitbetter` — umbrella info command that lists all gitbetter commands, with `--help` (default) and `--version` flags
- `git-push` — interactive stage → commit → push with amend support, pre-commit hook recovery, and branch-PR cleanup
- `git-tag` — semver-validated tagging with latest-tag display and push to origin
- Every command supports `--help` (full usage + examples) and `--version` (unified gitbetter version + homepage URL)
- Homebrew tap distribution via `pointmatic/tap`
- CI/CD via GitHub Actions (tests on push/PR, formula auto-bump on tag)

### Operational Requirements

- Strict error handling via `set -euo pipefail`
- Clean, descriptive error messages on failure (colored red with ✘ prefix)
- Every git command echoed to the terminal before execution (dimmed `$ git ...` format)
- Colored terminal output using ANSI escape codes (no external dependency on `tput` or `ncurses`)

### Quality Requirements

- No external dependencies beyond git and coreutils
- Works on macOS and Linux
- Consistent UX across all commands: same color palette, prompt style, banner format, and confirmation conventions. All commands must share a single set of color and symbol definitions:
  - **Colors**: Red (errors), Green (success), Yellow (warnings/prompts), Blue (banners), Cyan (info arrows, header/footer boxes), Magenta (branch/tag names), Dim (command echo, secondary text), Bold (emphasis)
  - **Symbols**: ✔ (success, green), ✘ (failure, red), ▸ (info arrow, cyan), ⚠ (warning, yellow)
  - **Prompts**: `[Y/n]` (yellow, default yes) for expected actions; `[y/N]` (yellow, default no) for optional/destructive actions
  - **Banners**: `── Title ──` format in blue+bold
  - **Header/footer boxes**: Rounded-corner box (`╭╰╮╯│`) in cyan+bold (header) or green+bold (footer)
- Scripts pass `shellcheck` with no warnings

### Usability Requirements

- CLI tool for terminal-savvy developers
- Each command is a Bash script invoked as `git-push` or `git-tag` (leveraging git's subcommand discovery via PATH)
- Command scripts source shared UI helpers (colors, symbols, prompts, banners) from `lib/ui.sh` so every command has identical look-and-feel
- Interactive prompts use `[Y/n]` (default yes) for expected actions and `[y/N]` (default no) for optional/destructive actions
- Any step can be aborted cleanly by answering "n"

### Non-goals

- No branching model enforcement (no git-flow or trunk-based policy)
- No GUI or TUI beyond terminal ANSI colors
- No merge conflict resolution
- No support for non-Bash shells (zsh/fish native wrappers)
- No PR creation, issue management, or other hosting-platform operations

---

## Inputs

### `git-push`

| Argument | Required | Description |
|---|---|---|
| `"commit message"` | Yes | The commit message (first positional arg). Backticks are stripped; double quotes are converted to single quotes. |
| `[branch_name]` | No | Target branch (second positional arg). If omitted, pushes to the current branch. If provided and different from HEAD, switches or creates the branch. |
| `--amend` | No | Flag. Replaces the last commit with the new message and force-pushes with `--force-with-lease`. |

### `git-tag`

| Argument | Required | Description |
|---|---|---|
| `tag` | Yes | A semver tag in `vX.Y.Z` format (first positional arg). X, Y, and Z must be non-negative integers. |
| `[branch_name]` | No | Branch to push the tag to on origin (second positional arg). Defaults to the current branch. |
| `--help` | No | Flag. Print full usage (description, usage lines, options, examples, homepage) and exit 0. Takes precedence over all other args. |
| `--version` | No | Flag. Print `gitbetter git-tag v<VERSION>` and the homepage URL; exit 0. Takes precedence over all other args. |

### `git-push` — additional meta flags

| Argument | Required | Description |
|---|---|---|
| `--help` | No | Flag. Print full usage (description, usage lines, options, examples, homepage) and exit 0. Takes precedence over all other args. |
| `--version` | No | Flag. Print `gitbetter git-push v<VERSION>` and the homepage URL; exit 0. Takes precedence over all other args. |

### `gitbetter`

| Argument | Required | Description |
|---|---|---|
| `--help` | No | Flag. Print umbrella help (description, list of commands, pointer to per-command help, homepage). Exit 0. Also the default behavior when no arguments are passed. |
| `--version` | No | Flag. Print `gitbetter v<VERSION>` and the homepage URL; exit 0. |

`gitbetter` takes no positional arguments and does **not** dispatch to subcommands. Users invoke `git-push` / `git-tag` directly; `gitbetter` exists solely for discoverability, help, and version reporting.

---

## Outputs

All output is to the terminal via colored ANSI text. No files are written. The output structure for every command follows a consistent pattern:

1. **Rounded-box header** — command title displayed in a bordered box
2. **Context line** — the most recent related item (last commit for `git-push`, latest tag for `git-tag`)
3. **Step banners** — each phase of the workflow is introduced with a labeled banner
4. **Command echo** — every git command shown as dimmed `$ git ...` before execution
5. **Confirmation prompts** — `[Y/n]` or `[y/N]` prompts before each action
6. **Outcome proof** — a summarized one-liner showing the result (new commit hash + message, or new tag)
7. **Rounded-box footer** — "✔ All done." in a bordered box on success

On failure, a red `✘` error message is printed and the script exits with a non-zero status. No footer is shown on failure.

---

## Functional Requirements

### FR-1: Consistent Command UX Pattern

All gitbetter commands must follow a shared interactive flow pattern.

**Behavior:**
1. Print a rounded-box header containing the command name (e.g., `git-push`, `git-tag`).
2. Display the most recent related context (last commit for push, latest tag for tag).
3. Validate all input parameters before performing any git operations. Exit with a clear error if validation fails.
4. Execute the workflow steps, each preceded by a labeled banner and confirmation prompt.
5. Echo every git command (`$ git ...`) in dimmed text before running it.
6. After success, print a one-liner proof of the outcome (e.g., abbreviated commit hash + message, or the new tag).
7. Print a rounded-box footer with "✔ All done."

**Edge Cases:**
- No commits exist yet in the repo → show a warning instead of last commit, continue normally.
- No tags exist yet → show "No tags found" instead of latest tag, continue normally.
- Terminal does not support ANSI colors → colors degrade gracefully (escape codes are harmless in non-color terminals).

### FR-2: git-push — Direct Push Flow

Stage all changes, commit, and push to the current branch in one interactive command.

**Behavior:**
1. Verify the working directory is inside a git repository.
2. Parse arguments: commit message (required), optional `--amend` flag, optional branch name.
3. Sanitize the commit message (strip backticks, convert `"` to `'`). Fail if empty after sanitization.
4. Display the summary banner: message, mode (amend or normal), target branch.
5. Show the last commit for context.
6. Confirm with the user before proceeding.
7. Show `git status --short` and confirm staging.
8. Run `git add -A`, show updated status, and confirm commit.
9. Run `git commit -m "message"` and report success.
10. Push to `origin/<current_branch>` and report success.

**Edge Cases:**
- No arguments provided → print usage and exit 1.
- Empty commit message after sanitization → fail with descriptive error.
- Nothing to commit (clean tree) → commit fails; report "nothing to commit" and exit.
- Push rejected by remote → offer `--force-with-lease` retry (see FR-4).

### FR-3: git-push — Amend Mode

Replace the last commit and force-push safely.

**Behavior:**
1. When `--amend` is passed, label the mode as "amend" in the summary banner.
2. Show the commit that will be replaced and warn the user.
3. Run `git commit --amend -m "message"` instead of a normal commit.
4. Automatically push with `--force-with-lease` (never `--force`).

**Edge Cases:**
- Amend on a repo with no commits → `git commit --amend` fails; report error and exit.
- Amend with nothing staged → amend still rewrites the message; this is valid.

### FR-4: git-push — Pre-commit Hook Recovery

Detect and offer to fold in changes left by pre-commit hooks.

**Behavior:**
1. After a successful commit, check `git status --porcelain`.
2. If the working tree is dirty, warn the user that pre-commit hooks likely reformatted files.
3. Show the dirty files.
4. Offer (default no) to fold the changes into the commit via `git add -A && git commit --amend --no-edit`.
5. If the user accepts, switch to force-push mode (`--force-with-lease`) for the push step.
6. If the user declines, proceed with the push as normal; dirty files remain uncommitted.

**Edge Cases:**
- Dirty tree is from unrelated files, not hooks → user declines the fold; no harm done.
- Multiple rounds of hook reformatting → only one fold pass is offered.

### FR-5: git-push — Branch-PR Workflow and Cleanup

Support creating/switching branches and cleaning up after merge.

**Behavior:**
1. If a branch name is provided and differs from HEAD, switch to it (or create it if it doesn't exist).
2. After pushing, if the current branch is not `main`, enter the branch-PR flow.
3. Inform the user to open a PR and wait for CI.
4. Attempt to build the GitHub Actions URL from the remote and offer to open it in the browser.
5. Wait for the user to press Enter when CI is done.
6. Offer (default no) to delete the feature branch and pull latest main: `git switch main && git fetch --prune && git pull && git branch -D <branch>`.

**Edge Cases:**
- Branch already exists locally → switch to it instead of creating.
- Remote URL is not GitHub → skip Actions URL; still offer cleanup.
- User declines cleanup → script ends; branch is left as-is.
- Push rejected → offer `--force-with-lease` retry before entering the branch-PR flow.

### FR-6: git-tag — Semver Tag Validation and Push

Validate a semver tag, show context, and push it to origin.

**Behavior:**
1. Verify the working directory is inside a git repository.
2. Parse arguments: tag (required), optional branch name.
3. Validate the tag matches `vX.Y.Z` where X, Y, Z are non-negative integers. Fail immediately if invalid.
4. Check existing local tags for duplicates. Fail if the tag already exists.
5. Display the most recent existing tag, sorted numerically by major.minor.patch (not lexicographically). Show "No tags found" if none exist.
6. Confirm with the user: "Create and push tag `<tag>` to `origin/<branch>`?"
7. Run `git tag <tag>`.
8. Run `git push origin <tag>`.
9. Display the new tag as a one-liner proof of outcome.

**Edge Cases:**
- Tag format invalid (e.g., `1.2.3` without `v`, `v1.2`, `v1.2.3.4`, `vabc`) → fail with format error showing expected pattern.
- Tag already exists locally → fail with "tag already exists" and show the existing tag.
- Tag exists on remote but not locally → push fails; report the conflict.
- No tags exist yet → skip "most recent tag" display, proceed normally.
- Branch name omitted → push tag without specifying a branch (just `git push origin <tag>`).

### FR-7: CI/CD — GitHub Actions Pipeline

Automated testing on push/PR and Homebrew formula update on tag.

**Behavior:**
1. On every push and pull request to `main`, run CI tests (shellcheck, script tests).
2. On push of a tag matching `v*`, trigger the Homebrew formula update workflow.
3. The formula update uses `dawidd6/action-homebrew-bump-formula@v4` to bump the `gitbetter` formula in the `pointmatic/tap` tap.
4. The tap token is stored as the `HOMEBREW_TAP_TOKEN` GitHub secret.

**Edge Cases:**
- CI fails on a PR → PR cannot merge (branch protection assumed but not enforced by gitbetter).
- Tag push does not match `v*` → formula update workflow does not trigger.
- Tap token is missing or expired → formula update fails; GitHub Actions reports the error.

### FR-8: Homebrew Distribution

Install gitbetter commands via Homebrew.

**Behavior:**
1. Users install with `brew install pointmatic/tap/gitbetter`.
2. Installation places `gitbetter`, `git-push`, and `git-tag` command wrappers on the user's PATH and installs the command scripts plus `lib/ui.sh` into Homebrew's `libexec` (internal) location. Command wrappers exec the real scripts so `lib/ui.sh` resolves relative to the script's install directory.
3. Git automatically discovers `git-push` and `git-tag` as subcommands (e.g., `git push` vs `git-push` — the hyphenated versions are separate commands, not overrides). `gitbetter` is invoked directly, not as a git subcommand.

**Edge Cases:**
- User has a conflicting `git-push` on PATH → Homebrew-installed version takes precedence based on PATH ordering; user is responsible for resolving conflicts.
- Uninstall via `brew uninstall gitbetter` cleanly removes the scripts.

### FR-9: `--help` and `--version` Meta Flags

Every gitbetter command (`gitbetter`, `git-push`, `git-tag`) supports `--help` and `--version` flags with consistent behavior.

**Behavior:**
1. `--help` and `--version` are checked **before** any git-repository validation, semver validation, or message sanitization — they work outside a git repo and with invalid arguments.
2. Either flag short-circuits all other processing: print the output and exit 0.
3. `--version` output format is unified across all commands:
   - `gitbetter v<VERSION>` (for `gitbetter`)
   - `gitbetter <command-name> v<VERSION>` (for `git-push`, `git-tag`)
   - Followed on the next line by the homepage URL: `https://github.com/pointmatic/gitbetter`
4. `--help` output is per-command and includes: short description, usage lines (including the `--help` and `--version` invocations), options table, examples, and a `Homepage:` footer line.
5. The version number is defined once (in `lib/ui.sh` as `GITBETTER_VERSION`) and is shared by all three commands.
6. For `gitbetter` only, running with no arguments is equivalent to `--help` (exit 0). For `git-push` and `git-tag`, running with no arguments still prints a terse usage message and exits 1 (unchanged).

**Edge Cases:**
- Both `--help` and `--version` passed together → whichever appears first wins.
- `--help` or `--version` passed alongside other arguments → the meta flag still short-circuits; other arguments are ignored.
- Unknown flags (e.g., `-h`, `-v`, `--version=1`) → not supported; scripts treat them as positional args or fail with the existing usage message.

---

## Configuration

No configuration files. All behavior is driven by CLI arguments and interactive prompts at runtime. There is no config file, no environment variables, and no dotfile.

---

## Testing Requirements

- All scripts pass `shellcheck` with zero warnings.
- CI runs on every push and pull request via GitHub Actions.
- Script-level tests cover:
  - Argument parsing (missing args, `--amend` flag, extra args)
  - Commit message sanitization (backticks, quotes, empty after sanitization)
  - Semver validation (valid tags, invalid formats, duplicate detection)
  - Error paths (not in a git repo, nothing to commit, push rejected)
- Tests execute in isolated temporary git repositories to avoid side effects.

---

## Security and Compliance Notes

- Never uses `git push --force`; only `--force-with-lease` is permitted for safe force-push.
- No secrets are stored in scripts or committed to the repository.
- The Homebrew tap token (`HOMEBREW_TAP_TOKEN`) is stored exclusively as a GitHub Actions secret.
- Scripts do not make network requests beyond standard git push/fetch operations.

---

## Performance Expectations

N/A — interactive terminal scripts with negligible overhead beyond the underlying git commands themselves. No batch processing, no long-running operations.

---

## Acceptance Criteria

- [ ] `git-push "message"` completes the full stage → commit → push flow on macOS and Linux.
- [ ] `git-push --amend "message"` amends and force-pushes with `--force-with-lease`.
- [ ] `git-push "message" branch_name` switches/creates the branch and offers PR cleanup.
- [ ] Pre-commit hook dirty-tree detection works and fold-in amend is functional.
- [ ] `git-tag v1.0.0` validates semver, shows latest tag, creates and pushes the tag.
- [ ] `git-tag` rejects invalid formats (`1.0.0`, `v1.0`, `vabc`, duplicate tags).
- [ ] Both commands follow the shared UX pattern (header box, context, validation, proof, footer box).
- [ ] `gitbetter`, `gitbetter --help`, `git-push --help`, `git-tag --help` all print usage and exit 0.
- [ ] `gitbetter --version`, `git-push --version`, `git-tag --version` all print a unified `v<VERSION>` plus the homepage URL and exit 0, working outside a git repo.
- [ ] All scripts pass `shellcheck` with no warnings.
- [ ] CI runs on push/PR and formula update triggers on `v*` tag push.
- [ ] `brew install pointmatic/tap/gitbetter` installs all three commands (`gitbetter`, `git-push`, `git-tag`) and they are discoverable on PATH.
