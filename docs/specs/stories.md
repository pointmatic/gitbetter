# stories.md -- gitbetter (Bash 4.0+)

This document breaks the `gitbetter` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see `concept.md`. For requirements and behavior (what), see `features.md`. For implementation details (how), see `tech-spec.md`. For project-specific must-know facts, see `project-essentials.md` (`plan_phase` appends new facts per phase).

---

## Phase A: Foundation

### Story A.a: Project Scaffolding [Done]

Set up the repository skeleton: license, copyright headers, package manifest, README, and .gitignore.

- [x] Create `LICENSE` file (Apache-2.0, Copyright (c) 2026 Pointmatic)
- [x] Add copyright and SPDX header to `git-push.sh`
- [x] Create `README.md` with project overview, install instructions (`brew install pointmatic/tap/gitbetter`), usage examples for `git-push` and `git-tag`, and license section
- [x] Create `CHANGELOG.md` with initial `## [Unreleased]` section
- [x] Review `.gitignore` for completeness
- [x] Verify: repo has LICENSE, README.md, CHANGELOG.md, and `git-push.sh` has copyright header

### Story A.b: v0.1.0 Hello World — git-tag Minimal Skeleton [Done]

Create the smallest runnable `git-tag.sh` that proves the script structure, helpers, and UX pattern work.

- [x] Create `git-tag.sh` with copyright header, `set -euo pipefail`, and the full shared constants/helpers block (copied from `git-push.sh`)
- [x] Implement: parse first positional arg as TAG, print header box with "git-tag", print TAG, print footer box with "✔ All done.", and exit
- [x] No validation, no git operations yet — just argument parsing and the UX shell
- [x] Make `git-tag.sh` executable (`chmod +x`)
- [x] Bump version to v0.1.0
- [x] Update CHANGELOG.md
- [x] Verify: `./git-tag.sh v1.0.0` prints header box, tag, and footer box

### Story A.c: v0.2.0 Spike — End-to-End Tag Flow in a Temp Repo [Done]

Throwaway verification that the full tag-create-and-push flow works in an isolated environment before building production logic.

- [x] Create `scripts/spike-tag.sh` — a temporary script that:
  - Creates a temp directory with `git init`
  - Adds a dummy commit
  - Adds a bare remote (local bare repo)
  - Calls `git-tag.sh v0.0.1` and verifies the tag exists on the remote
- [x] Run the spike and confirm the tag appears on the remote
- [x] Bump version to v0.2.0
- [x] Update CHANGELOG.md
- [x] Verify: `./scripts/spike-tag.sh` completes without error and tag is on remote

## Phase B: Core — git-tag Implementation

### Story B.a: v0.3.0 Semver Validation [Done]

Add input validation so `git-tag.sh` rejects invalid tag formats before any git operations.

- [x] Implement semver regex validation: `^v[0-9]+\.[0-9]+\.[0-9]+$`
- [x] Fail with descriptive error and expected format if validation fails
- [x] Fail with usage message if no tag argument provided
- [x] Bump version to v0.3.0
- [x] Update CHANGELOG.md
- [x] Verify: `./git-tag.sh v1.0.0` passes; `./git-tag.sh 1.0.0`, `./git-tag.sh v1.0`, `./git-tag.sh vabc` all fail with clear errors

### Story B.b: v0.4.0 Duplicate Tag Detection and Latest Tag Display [Done]

Show the most recent tag for context and prevent creating duplicate tags.

- [x] Check `git tag -l "$TAG"` — fail if the tag already exists locally
- [x] Retrieve all `v*` tags, sort numerically by major.minor.patch (strip `v`, `sort -t. -k1,1n -k2,2n -k3,3n`), display the latest
- [x] Show "No tags found" if no tags exist
- [x] Display latest tag in the summary section after the header box
- [x] Bump version to v0.4.0
- [x] Update CHANGELOG.md
- [x] Verify: in a repo with tags `v1.9.0` and `v1.10.0`, latest shown is `v1.10.0`; creating a duplicate fails

### Story B.c: v0.5.0 Tag Creation and Push [Done]

Implement the core tag-and-push workflow with confirmation gates.

- [x] Add confirmation prompt: "Create and push tag `<tag>` to `origin`?"
- [x] Run `git tag "$TAG"` via `run_cmd`
- [x] Run `git push origin "$TAG"` via `run_cmd` (or `git push origin "$TAG" "$BRANCH_NAME"` if branch provided)
- [x] Display one-liner outcome proof (the new tag)
- [x] Print footer box with "✔ All done."
- [x] Bump version to v0.5.0
- [x] Update CHANGELOG.md
- [x] Verify: `./git-tag.sh v0.5.0` creates tag, pushes, and shows success footer

## Phase C: Testing

### Story C.a: v0.6.0 Test Infrastructure — BATS Setup [Done]

Set up the BATS test framework and shared test helpers.

- [x] Create `tests/test_helper/common-setup.bash` with:
  - `setup()` — create temp dir, `git init`, configure user.email/user.name
  - `teardown()` — `rm -rf` temp dir
  - Helper to create a bare remote in the temp dir for push tests
- [x] Create `tests/git-tag.bats` with a single smoke test that sources common-setup and runs `git-tag.sh --help` or a trivial invocation
- [x] Create `tests/git-push.bats` with a single smoke test
- [x] Confirm BATS runs locally: `bats tests/`
- [x] Bump version to v0.6.0
- [x] Update CHANGELOG.md
- [x] Verify: `bats tests/` passes with 2 smoke tests

### Story C.b: v0.7.0 git-tag Tests [Done]

Comprehensive BATS tests for `git-tag.sh`.

- [x] Test: missing tag argument → prints usage, exits 1
- [x] Test: valid semver tags accepted (`v0.0.1`, `v1.0.0`, `v10.20.30`)
- [x] Test: invalid tags rejected (`1.0.0`, `v1.0`, `v1.2.3.4`, `vabc`, `v1.2.3-beta`)
- [x] Test: duplicate tag detected → fails with "already exists"
- [x] Test: latest tag sorted numerically (`v1.10.0` after `v1.9.0`)
- [x] Test: tag created and pushed to remote successfully
- [x] Test: no tags exist → "No tags found" displayed, proceeds normally
- [x] Bump version to v0.7.0
- [x] Update CHANGELOG.md
- [x] Verify: `bats tests/git-tag.bats` — all tests pass

### Story C.c: v0.8.0 git-push Tests [Done]

BATS tests for `git-push.sh` argument parsing and validation.

- [x] Test: missing commit message → prints usage, exits 1
- [x] Test: commit message sanitization (backticks stripped, `"` → `'`)
- [x] Test: empty message after sanitization → fails with error
- [x] Test: `--amend` flag parsed correctly
- [x] Test: positional args (message, branch) parsed correctly
- [x] Bump version to v0.8.0
- [x] Update CHANGELOG.md
- [x] Verify: `bats tests/git-push.bats` — all tests pass

## Phase D: CI/CD & Distribution

### Story D.a: v0.9.0 CI Pipeline — ShellCheck + BATS [Done]

Set up GitHub Actions to lint and test on every push and PR.

- [x] Create `.github/workflows/ci.yml`:
  - Trigger on push to `main` and pull requests to `main`
  - Install shellcheck
  - Install bats-core, bats-support, bats-assert
  - Run `shellcheck git-push.sh git-tag.sh`
  - Run `bats tests/`
- [x] Fix any shellcheck warnings in `git-push.sh` and `git-tag.sh`
- [x] Bump version to v0.9.0
- [x] Update CHANGELOG.md
- [x] Verify: push to main triggers CI; all checks pass

### Story D.b: v1.0.0 Homebrew Formula Auto-Bump [Done]

Set up the GitHub Action to update the Homebrew formula on tag push.

- [x] Create `.github/workflows/homebrew.yml`:
  - Trigger on push of tags matching `v*`
  - Use `dawidd6/action-homebrew-bump-formula@v4`
  - Configure: `token: ${{ secrets.HOMEBREW_TAP_TOKEN }}`, `tap: pointmatic/tap`, `formula: gitbetter`, `tag: ${{ github.ref_name }}`
- [x] Document the `HOMEBREW_TAP_TOKEN` secret requirement in README.md (for maintainers)
- [x] Bump version to v1.0.0
- [x] Update CHANGELOG.md
- [x] Verify: push tag `v1.0.0` triggers the homebrew workflow

### Story D.c: v1.0.1 Refactor — Extract 'lib/ui.sh' [Done]

Refactor the duplicated UI helper block out of `git-push.sh` and `git-tag.sh` into a single sourced library. Behavior-preserving — all existing tests must still pass unchanged.

- [x] Create `lib/ui.sh` with copyright header and `set` guards safe for sourcing (no `set -euo pipefail` at the top of `ui.sh`)
- [x] Move into `lib/ui.sh`: color constants (`R`, `G`, `Y`, `B`, `C`, `M`, `DIM`, `BOLD`, `RESET`, `CHECK`, `CROSS`, `ARROW`, `WARN`) and helper functions (`banner`, `info`, `success`, `warn`, `fail`, `confirm`, `ask_yn`, `divider`, `run_cmd`)
- [x] Add new helpers in `lib/ui.sh`: `header_box "<title>"` and `footer_box` (extract existing inline echo blocks from `git-push.sh` / `git-tag.sh`)
- [x] Add constants in `lib/ui.sh`: `GITBETTER_VERSION="1.0.1"` and `GITBETTER_HOMEPAGE="https://github.com/pointmatic/gitbetter"`
- [x] In `git-push.sh` and `git-tag.sh`: replace the duplicated block with:
  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  # shellcheck source=lib/ui.sh
  source "${SCRIPT_DIR}/lib/ui.sh"
  ```
- [x] Replace inline header/footer echo blocks in both scripts with `header_box "<cmd>"` / `footer_box` calls
- [x] `tests/test_helper/common-setup.bash` — no change needed; tests run the scripts, which find `lib/ui.sh` relative to their own directory
- [x] `scripts/spike-tag.sh` — no changes needed; passes `shellcheck`
- [x] Update `.github/workflows/ci.yml`: `shellcheck` command now includes `lib/ui.sh`
- [x] Bump version to v1.0.1 (set in `lib/ui.sh` as `GITBETTER_VERSION`)
- [x] Update CHANGELOG.md
- [x] Verify: `shellcheck git-push.sh git-tag.sh lib/ui.sh scripts/spike-tag.sh` clean; `bats tests/` passes (21/21)
- [ ] **Before tagging v1.0.1**: update `pointmatic/homebrew-tap/Formula/gitbetter.rb` install method from `bin.install "git-push.sh" => "git-push"` (v1.0.0 shape) to the libexec+wrapper shape (see `tech-spec.md` Homebrew Formula section). Without this, `brew install` will break at v1.0.1 because scripts now source `lib/ui.sh` relative to their own directory.

### Story D.d: v1.1.0 'gitbetter' umbrella + '--help' and '--version' flags [Done]

Add a new `gitbetter` umbrella command plus `--help` and `--version` flags on all three commands. Version and homepage constants are unified via `lib/ui.sh` (requires D.c).

- [x] In `lib/ui.sh`: bump `GITBETTER_VERSION` to `1.1.0`
- [x] In `lib/ui.sh`: add `print_version [subcommand]` helper that prints `gitbetter[ <subcommand>] v<GITBETTER_VERSION>` followed by `<GITBETTER_HOMEPAGE>`
- [x] Create `gitbetter.sh` with copyright header, sources `lib/ui.sh`, defines local `print_help()` (description + Commands list pointing to `git-push`/`git-tag` + pointer to per-command `--help` + `Homepage:` line)
- [x] In `gitbetter.sh`: dispatch on first arg — empty/`--help` → `print_help`, exit 0; `--version` → `print_version`, exit 0; unknown → error to stderr, exit 1
- [x] Make `gitbetter.sh` executable (`chmod +x`)
- [x] In `git-push.sh`: add a local `print_help()` with Usage, Options (`--amend`, `--help`, `--version`), Examples, and `Homepage:` line
- [x] In `git-push.sh`: before any git validation or arg parsing, handle `--help` (exit 0) and `--version` via `print_version "git-push"` (exit 0)
- [x] In `git-tag.sh`: add a local `print_help()` with Usage, Options (`--help`, `--version`), Examples, and `Homepage:` line
- [x] In `git-tag.sh`: before any git validation or semver validation, handle `--help` and `--version` (same pattern as `git-push.sh`)
- [x] Create `tests/gitbetter.bats` with cases: no args → help+exit 0; `--help` → contains Usage/Commands/Homepage, exit 0; `--version` → contains `v1.1.0` and URL, exit 0; unknown flag → exit 1
- [x] Extend `tests/git-push.bats`: `--help` exits 0 with Usage/Examples/Homepage; `--version` exits 0 with `gitbetter git-push v1.1.0` and URL; `--help` works outside a git repo
- [x] Extend `tests/git-tag.bats`: same three cases with `gitbetter git-tag v1.1.0`
- [x] Extend `tests/test_helper/common-setup.bash` to export `GITBETTER_SH` path
- [x] Update `.github/workflows/ci.yml`: include `gitbetter.sh` in the `shellcheck` command
- [x] Update `README.md`: add `gitbetter` entry point and `--help` / `--version` examples
- [x] Homebrew formula install snippet in `tech-spec.md` already reflects three wrappers — verified
- [x] Bump version to v1.1.0 in `lib/ui.sh`
- [x] Update CHANGELOG.md
- [x] Verify: `./gitbetter.sh`, `./gitbetter.sh --help`, `./gitbetter.sh --version`, `./git-push.sh --help`, `./git-push.sh --version`, `./git-tag.sh --help`, `./git-tag.sh --version` all print expected output and exit 0; `--help` works outside a git repo (covered by BATS); `shellcheck` clean; `bats tests/` passes (31/31)
- [ ] **Before tagging v1.1.0**: update `pointmatic/homebrew-tap/Formula/gitbetter.rb` to also install `gitbetter.sh` and write a `bin/gitbetter` wrapper; add a `test do` block asserting `--version` on all three commands. See `tech-spec.md` Homebrew Formula section for the full template.

### Story D.e: v1.2.0 Remote-awareness — fetch and warn before push/tag [Done]

Add cheap, read-only remote-awareness to `git-push` and `git-tag` so users don't unknowingly push on top of diverged history or create tags that already exist on the remote. Deliberately **does not** `git pull` — pulling is a mutation that can fail mid-script, surprise the user, conflict with `--amend`, and defeat the `--force-with-lease` safety net. Instead, `fetch` silently, detect divergence, and prompt or fail with clear guidance.

**Design principles:**
- Never mutate working tree or index automatically — only `git fetch`, which is read-only.
- Never silently merge or rebase — if action is needed, the user performs it after exiting.
- Respect existing prompt conventions: `confirm()` for abort-gates, `ask_yn()` for optional continue-prompts.
- Skip divergence checks gracefully when no upstream is configured (new branch) or when offline (fetch failure should warn, not abort).

**`git-push.sh`:**

- [x] After branch-switch step and before staging, run `git fetch --quiet` via `fetch_quiet_or_warn`; on failure the helper warns "Could not reach remote (offline?). Skipping divergence check." and the caller continues.
- [x] Detect upstream via `git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null`. If empty, skip the divergence check entirely.
- [x] Compute ahead/behind via `git rev-list --left-right --count 'HEAD...@{u}'` and parse into `AHEAD` / `BEHIND`.
- [x] If `BEHIND > 0` **and not** `--amend` mode: `warn` + `info "Consider: git pull --rebase  (then re-run git-push)"` + `ask_yn "Push anyway?"` (default no → exit 0 cleanly with `Aborted.`).
- [x] If `BEHIND > 0` **and** `--amend` mode: stronger multi-line warning explaining why `--force-with-lease` + unseen remote commits is almost certainly unintended; then the same `ask_yn "Push anyway?"` default-no abort. (Flipped from `confirm` to `ask_yn` for safety, as the story suggested.)
- [x] If `BEHIND == 0`: emit a single `info` line — either "Up to date with <upstream>." or "N commit(s) ahead of <upstream> — ready to push."
- [x] No change to the existing `--force-with-lease` push flow.

**`git-tag.sh`:**

- [x] After the local duplicate-tag check, probe `origin` via `git ls-remote --tags origin "refs/tags/${TAG}"` (read-only) and `fail` hard if the tag already exists on the remote. **Important change from the original plan:** we deliberately do NOT use `git fetch --tags` here because `fetch --tags` creates local refs for every remote tag as a side effect, polluting the local tag namespace. `ls-remote` is a pure query with no local mutation.
- [x] If origin is unreachable, `ls-remote` silently fails (stderr suppressed) and we proceed — offline is not fatal for the tag flow.
- [ ] Optional behind-warning — **deferred**. Low-value in practice (most repos tag on main after PRs have merged; the interesting signal is the remote tag collision, which is covered). Can be revisited if feedback calls for it.

**`lib/ui.sh`:**

- [x] Extracted `fetch_quiet_or_warn()` in `lib/ui.sh`. Drops the `timeout 10` wrapper for portability (BSD `timeout` isn't ubiquitous on macOS; `git fetch` surfaces its own errors quickly for normal failures). Used by `git-push.sh`; `git-tag.sh` intentionally uses `ls-remote` directly instead (see above).

**Tests (`tests/git-push.bats`, `tests/git-tag.bats`):**

- [x] `git-push`: remote-ahead + answer no → exits 0 with `Aborted.` message. (Note: bash's `read -rp` prompt text is only shown to a TTY, not to a piped stdin, so assertions match the warning + abort text rather than the literal `Push anyway?` string.)
- [x] `git-push --amend`: remote-ahead triggers the `Amend + remote-ahead` warning.
- [x] `git-push`: no upstream → no `Remote Check` banner appears (existing tests already hit this path; new test asserts it explicitly).
- [x] `git-push`: up-to-date → `Remote Check` banner appears with `Up to date with` or `ready to push`, no divergence prompt.
- [ ] `git-push`: explicit remote-ahead + answer yes → push proceeds. **Deferred** — would require either a second bare remote to push into (to avoid actually pushing the diverged history) or additional scaffolding; the abort path exercises the exact same code path that matters for the safety check.
- [ ] `git-push`: fetch-failure simulation (unreachable remote URL) → warn + continue. **Deferred** — simulating a reachable-but-broken origin in BATS is flakey. The code path is exercised by manual smoke testing and is a simple one-branch fall-through.
- [x] `git-tag`: tag exists on remote → exit 1 with clear error; tag NOT created locally (asserted).
- [x] `git-tag`: reachable origin + novel tag → behavior unchanged (proceeds to confirm prompt).

**Docs:**

- [x] Updated `README.md` — one-line fetch-and-warn note under `git-push`, one-line remote-probe note under `git-tag`.
- [ ] `docs/specs/features.md`: acceptance criteria for remote-awareness. **Deferred to Story E.a (Docs polish)** — keeping all features.md edits in one doc-polish pass.
- [ ] `docs/specs/tech-spec.md`: formal writeup of the fetch-and-warn flow. **Deferred to Story E.a** for the same reason. Design rationale is captured in the CHANGELOG v1.2.0 "Design notes" subsection in the meantime.
- [x] Updated `CHANGELOG.md` under v1.2.0 with full Added + Design-notes sections.

**Verify:**

- [x] `shellcheck gitbetter.sh git-push.sh git-tag.sh lib/ui.sh scripts/spike-tag.sh` clean.
- [x] `bats tests/` passes, 37/37 (was 31; +6 new D.e tests).
- [x] Manual smoke: behind-by-one (warning + abort verified via BATS + manual reproduction), remote-existing-tag (manually reproduced in `/tmp` before BATS fix), `--version` on all three commands prints `v1.2.0`.
- [ ] **Before tagging v1.2.0**: tap formula only needs the new `url` / `sha256` bump (no structural change this release). The Homebrew bump action handles this automatically on tag push.

## Phase E: Documentation & Release

### Story E.a: Final README and Docs Polish [Planned]

Finalize all documentation for the v1.2.1 release.

- [ ] Review and finalize README.md: project description, install, usage examples for all three commands (`gitbetter`, `git-push`, `git-tag`), `--help` / `--version` mentions, contributing section, license
- [ ] Review CHANGELOG.md: ensure all versions are documented
- [ ] Remove `scripts/spike-tag.sh` (throwaway from A.c)
- [ ] Verify: README renders correctly on GitHub, all links work
- [ ] Bump version to v1.2.1 in source

---

## Future

<!--
This section captures items intentionally deferred from the active phases above:
- Stories not yet planned in detail
- Phases beyond the current scope
- Project-level out-of-scope items
The `archive_stories` mode preserves this section verbatim when archiving stories.md.
-->

- Additional gitbetter commands (e.g., `git-sync`, `git-cleanup`)
- Homebrew formula creation (initial formula in `pointmatic/homebrew-tap` repo)
- Shell completion scripts (bash-completion, zsh)
- `man` pages for each command
