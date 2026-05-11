# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.1] — 2026-05-11

Branch-resurrection guard. When the cleanup flow deletes a branch, `git-push` now records a tombstone entry in `${GIT_DIR}/gitbetter-deleted-branches`. If you later run `git-push "msg" feat/x` and `feat/x` is in that file, the script warns and asks for confirmation before creating a new branch with the same name from current HEAD — protecting against accidental reuse of a retired branch name.

### Added

- `git-push`: cleanup flow now appends `<branch>\t<YYYY-MM-DD>` to `${GIT_DIR}/gitbetter-deleted-branches` after `git branch -D` succeeds.
- `git-push`: pre-creation guard in the new-branch leg of the branch-switch step. When the requested branch is in the tombstone, prints a warning with the recorded date and prompts `ask_yn "Re-create <branch> from current HEAD?"` (default no → exit cleanly). Answering yes proceeds and removes every entry for that name from the tombstone, so subsequent intentional uses are silent.
- Five new BATS tests in `tests/git-push.bats` covering: tombstone written on cleanup, prompt fires + N aborts without creating the branch, prompt fires + Y creates the branch and clears the entry (unrelated entries preserved), no tombstone → silent, tombstone hit but local branch already exists → no prompt (switch path).

### Design notes

- **Why a tombstone file, not a reflog scan.** A reflog scan (`git reflog show HEAD | grep`) would catch all deletions including manual `git branch -D`, but has fuzzy semantics — 90-day expiry, no way to distinguish delete-after-merge from rename-away. The tombstone is written exactly when gitbetter retired the branch, so the warning is precise: "this script deleted this branch on this date." Manual deletes and GitHub auto-delete are deliberately not flagged (their intent is too ambiguous to warn cleanly).
- **Why local-only.** The tombstone lives in `${GIT_DIR}/` so it never enters the working tree, is never committed, and never syncs across clones. It's per-checkout bookkeeping. A new clone won't see another checkout's history and will skip the guard — that's an accepted tradeoff for keeping the mechanism purely local.
- **Self-clearing on confirm.** Removing the entry once the user explicitly re-creates the branch means subsequent pushes to the same name are silent. A future cleanup writes a fresh tombstone, restoring the guard.
- **`${GIT_DIR}` via `git rev-parse --git-dir`.** Works in plain repos, worktrees, and submodules where `.git` is a file rather than a directory.

## [1.6.0] — 2026-05-11

`project-guide` integration. When a `.project-guide.yml` marker file exists at the repo root, `git-push` now excludes `docs/project-guide/` from every `git add -A` via a Git pathspec, so the operational/dev artifacts managed by [`project-guide`](https://github.com/pointmatic/project-guide) don't accidentally land in source commits. Repos without the marker file are completely unaffected.

### Added

- `git-push`: marker-gated pathspec exclusion. Detects `${REPO_ROOT}/.project-guide.yml` via `git rev-parse --show-toplevel` (cwd-independent). When present, every `git add -A` becomes `git add -A -- :/ ':(exclude,top)docs/project-guide'`, and the **Staging** banner shows a one-line `info` naming the exclusion so it's never invisible.
- Both `git add -A` invocations in `git-push.sh` are covered — the main staging step and the post-commit dirty-tree amend fold-in — so a pre-commit hook reformatting a `docs/project-guide` file can't sneak it into the amended commit.
- Three new BATS tests in `tests/git-push.bats` covering: marker present → directory excluded with banner note; marker absent → directory committed normally (existing behavior); marker present + running from a subdirectory → exclusion still anchored to the repo root.

### Design notes

- **Why marker-gated and not unconditional.** A bare exclusion of `docs/project-guide` would surprise any unrelated repo that happens to use that path. The `.project-guide.yml` file is project-guide's own root-level config, so its presence is a precise signal that the repo opts into the convention.
- **Why a pathspec on `git add`, not `.gitignore`.** `.gitignore` would forbid the path across *all* git tooling, including the user's deliberate `git add docs/project-guide/something.md`. A pathspec on `git-push`'s own `git add -A` is local to this command and reversible — the user can still commit a file under that directory by running `git add` manually.
- **Why `:/` + `:(exclude,top)`.** Git requires at least one positive pathspec; an exclude-only pathspec matches nothing. `:/` anchors the positive match at the working-tree root, mirroring the cwd-independent semantics of bare `git add -A`. The `top` magic on the exclude is essential: without it, pathspecs are interpreted relative to cwd, so running `git-push` from a subdirectory would leave the real `docs/project-guide` un-excluded.
- **`git-tag` and `gitbetter` unchanged.** Neither invokes `git add`, so there's nothing to filter. The exclusion is `git-push`-local by design.

## [1.5.0] — 2026-05-04

`git-tag --prefix` release. Adds a `--prefix NAME` flag to `git-tag` for monorepos and multi-artifact projects where multiple independently-versioned components share a single repository. `git-tag v2.1.1 --prefix npm` creates and pushes `npm-v2.1.1`; all existing no-prefix behavior is unchanged.

### Added

- `git-tag`: `--prefix NAME` flag. `NAME` is prepended to the semver tag with a `-` separator (`npm` + `v2.1.1` → `npm-v2.1.1`). The flag may appear before or after the `vX.Y.Z` positional argument and before or after the optional `branch_name`.
- `git-tag`: prefix validation against `^[a-zA-Z0-9][a-zA-Z0-9._-]*$`. Fails with a clear error and allowed-character guidance if the value is invalid.
- `git-tag`: when `--prefix` is set, the **Latest** line in the summary banner queries only the `<prefix>-v*` tag family (e.g., `Latest (npm-v*): npm-v0.9.0`) so users see the version history for the right component.
- `git-tag --help`: updated usage line `[--prefix NAME] vX.Y.Z [branch_name]`, new `--prefix NAME` option, and two new examples (`--prefix npm`, `--prefix ios` with branch).
- Eight new BATS tests in `tests/git-tag.bats` covering: flag-after-semver, flag-before-semver, with-branch-arg, missing-value, invalid-chars, remote-duplicate-uses-full-tag, latest-display-scoped-to-family, and `--help` output.

### Changed

- `git-tag.sh` argument parsing refactored from a two-line positional assignment to a `while [[ $# -gt 0 ]]; do case` loop, enabling flag-before-or-after-positional ordering. Existing two-arg invocations (`git-tag v1.0.0` and `git-tag v1.0.0 main`) are fully backward-compatible.
- All internal references to the git tag name now use `FULL_TAG` (`<prefix>-<semver>` or just `<semver>` when no prefix is given): local duplicate check, `ls-remote` probe, `git tag`, `git push origin`, `git show` outcome proof, and user-facing messages.

### Design notes

- **Separator is always `-`.** Including the separator in the flag value (`--prefix npm-`) would produce double-dashes (`npm--v1.0.0`). Auto-inserting `-` matches the de facto convention for most package-manager and CI tagging schemes. Custom separators (e.g., `/` for `npm/v1.0.0`) are deferred.
- **User passes the `vX.Y.Z` part, not the full tag.** The prefix is an envelope around the version number. Semver validation (`^v[0-9]+\.[0-9]+\.[0-9]+$`) is applied to `TAG` before `FULL_TAG` is assembled, so invalid semver is caught independently of the prefix.
- **Latest tag scoped to prefix family.** Unscoped latest-tag display in a monorepo is meaningless — `v10.0.0` on the `ios` component tells you nothing about the `npm` component's history. Scoping to `<prefix>-v*` is both more useful and simpler to implement.
- **No regressions on no-prefix path.** The `else` branch of the prefix check reproduces the original `git tag -l 'v*'` query and `v`-strip/prepend sort. All pre-v1.5.0 tests continue to pass.

## [1.4.0] — 2026-04-25

Push-rejection recovery release. When `git push` is rejected, `git-push` now presents an explicit **3-option** menu (retry with `--force-with-lease` / roll back commit / abort) instead of a binary force-or-abort prompt. The new **roll back** option undoes the orphan commit with `git reset --soft HEAD~1` and prints a copy/paste retry hint so the user can immediately put the work on a feature branch — solving the most common branch-protection footgun without losing any work.

### Added

- `lib/ui.sh`: new `ask_choice <prompt> <default> <option1> <option2> [...]` helper. Prints a numbered menu, accepts digits only, treats Enter as the default, and re-prompts once on invalid input before falling back to the default. Sets `REPLY` to the 1-indexed selection.
- `git-push`: post-rejection `What now?` menu with three options:
  1. **Retry with `--force-with-lease`** (safe force push — fixes divergence, not branch protection).
  2. **Roll back commit** (`git reset --soft HEAD~1`; staged changes preserved; prints original commit message + retry hint).
  3. **Abort** (matches the previous abort behavior).
- `git-push`: stderr capture during `git push` (via `tee` to a `mktemp` tempfile, cleaned by `trap`) so we can detect branch-protection rejections by pattern (`protected branch`, `GH006`) and pick a sensible default.
- `git-push --help`: new "On rejection" section documenting the three recovery options.
- `tests/ui.bats`: 5 new unit tests for `ask_choice` covering Enter-default, valid-digit selection, single re-prompt on invalid, two-invalid → default fallback, and menu rendering.
- `tests/git-push.bats`: 5 new tests covering protected-rejection on main with explicit choice and Enter (default = roll back), generic rejection on a feature branch with Enter (default = abort) and explicit roll back, and amend-mode rejection (no menu, no roll-back option).
- `tests/test_helper/common-setup.bash`: new `block_pushes_to_remote <reason>` helper that installs a `pre-receive` hook on the bare remote rejecting every push with a configurable stderr message.

### Changed

- `git-push` non-amend rejection path replaces the old `ask_yn "Retry with --force-with-lease? (y/N)"` with the new 3-option menu. Default selection is context-aware:
  - Branch protection detected → **Roll back**.
  - On `main` with no `branch_name` argument → **Roll back**.
  - Otherwise (e.g. feature branch with non-FF) → **Abort**.
- `git-push` now displays the verbatim `git push` stderr above the menu so the user always sees git's own rejection message before choosing.

### Unchanged

- `git-push --amend` continues to auto-use `--force-with-lease` with no recovery prompt; on failure it `fail`s with "Force-push failed — resolve manually." Rolling back an amend is semantically muddy and intentionally not offered.

### Design notes

- **Why `--soft` reset.** `git reset --soft HEAD~1` keeps the working tree and index untouched, so the user's changes remain exactly where they were after `git add -A` — ready to be re-committed onto a feature branch with a single `git-push "msg" feature-xyz` retry. `--mixed` would force a re-stage; `--hard` would lose work.
- **Why detect only branch protection.** Stderr parsing across git versions and hosting providers is brittle. Branch protection has the most stable, recognizable pattern (`protected branch` / `GH006`) and is the *only* case where rolling back is unambiguously correct (force-with-lease cannot bypass server-side protection rules). Other rejection causes (signed-commit policy, file-size hooks, generic pre-receive declines) are presented neutrally with abort as the default.
- **Why Enter defaults to abort on feature branches.** On a feature branch, force-with-lease is the most common right answer but also the only destructive option, and rollback is rarely desired. Defaulting to abort keeps Enter-spam safe; users explicitly type `1` when they mean to force-push.
- **No letter shortcuts (`f`/`r`/`a`).** Numbers + Enter keep the helper simple and consistent with the existing `ask_yn` idiom. Letter shortcuts noted as a future enhancement.
- **Auto `git pull --rebase` on non-FF still deferred.** Same rationale as v1.2.0 (no-auto-pull): pulling is a mutation that can fail in ways gitbetter shouldn't paper over. The user runs `git pull --rebase` themselves when ready.

## [1.3.1] — 2026-04-17

Docs-only patch release (Story E.a). No behavior changes.

### Added

- README `Development` section with local `shellcheck` + `bats tests/` commands and BATS install guidance.
- README `Changelog` section linking to `CHANGELOG.md`.

### Removed

- `scripts/spike-tag.sh` — throwaway end-to-end spike from Phase A.c. Its coverage is fully subsumed by the `git-tag.bats` suite, and the `scripts/` directory is now gone.

## [1.3.0] — 2025-04-17

Branch-workflow simplification. The post-push branch cleanup flow now uses a single explicit prompt and a new `--keep` / `-k` flag, replacing the older two-step "wait for CI, then delete branch" interaction.

### Added

- `git-push`: `--keep` / `-k` flag. When pushing from a non-`main` branch, suppresses the cleanup prompt entirely and leaves the branch intact. Intended for multi-commit feature branches where cleanup happens later, manually, after PR merge.
- `git-push`: on non-`main` branches after a successful push, shows the branch name plus the GitHub **Actions** and **Compare** URLs (when the origin is a GitHub remote) so users can jump straight to CI or PR creation.
- Three new BATS tests in `tests/git-push.bats` covering: `--keep` skips the cleanup prompt, answering N keeps the branch, answering y runs the full cleanup (switch to main, fetch --prune, pull --ff-only, delete branch).

### Changed

- `git-push`: replaced the old two-step prompt ("Wait for GitHub Actions / CI to pass?" → press Enter → "Delete branch and pull latest main?") with a single `ask_yn "Merge complete? Clean up (switch to main, pull, delete branch)?"`. Default is **no** (keep branch) — the safe choice when in doubt.
- `git-push`: cleanup now uses `git pull --ff-only` instead of plain `git pull` to avoid surprising merge commits on `main` if upstream has diverged.
- `git-push --help` lists the new `--keep` / `-k` flag and example.

### Removed

- "Press Enter when ready to continue…" blocking wait step. Browser-opening of the Actions URL is also gone; the URL is still printed for copy/paste.

### Design notes

- **Single prompt, default no.** The previous flow tried to shepherd users through "wait, then delete"; in practice the two steps happen at wildly different times (CI can take many minutes) and the "press Enter" pause is a poor proxy for "PR is merged." The new prompt asks the one question that actually matters — *"is the merge done?"* — and defaults to "no" so hitting Enter leaves the branch untouched.
- **`--keep` shortcut.** Multi-commit feature branches shouldn't have to answer "no" every push. The short `-k` form keeps day-to-day pushes frictionless.
- **Automated PR-merge detection deferred.** `gh pr view --json state` could answer the "is it merged?" question definitively, but adds a `gh` dependency and an auth path. Noted for a future enhancement.

## [1.2.0] — 2025-04-17

Remote-awareness release. Both commands now perform cheap, read-only checks against `origin` before mutating anything locally, catching the two most common footguns: pushing on top of a diverged history, and creating a tag that already exists on the remote. **No automatic pulling, merging, or rebasing** — only fetching (for `git-push`) and `ls-remote` probing (for `git-tag`).

### Added

- `fetch_quiet_or_warn` helper in `lib/ui.sh` — wraps `git fetch --quiet` with a warn-on-failure pattern so callers can gracefully degrade when offline.
- `git-push`: after branch switch and before staging, runs `git fetch` and compares `HEAD` against `@{u}`. If the remote has new commits you don't have locally, prints a warning with the exact count and upstream name, suggests `git pull --rebase`, and prompts before proceeding (default: no). Amend mode gets a stronger, amend-specific warning because `--force-with-lease` + unseen remote commits is almost never intentional.
- `git-push`: when on an up-to-date or ahead branch, shows a brief "Up to date with <upstream>." or "N commit(s) ahead of <upstream> — ready to push." line for context.
- `git-tag`: before creating the tag, probes `origin` via `git ls-remote --tags` (read-only — no local refs created) and **hard-fails** if the tag already exists on the remote. No force-path is offered; this is a safety rail against accidental tag reuse.
- `tests/test_helper/common-setup.bash`: new helpers `make_remote_ahead` and `tag_on_remote` for constructing these scenarios in temp repos.
- Six new BATS tests covering: no-upstream skip, remote-ahead warn+abort, amend + remote-ahead stronger warning, up-to-date info line, remote-existing tag rejected, remote reachable + novel tag proceeds.

### Design notes

- **No timeout on fetch.** `timeout(1)` isn't portable (BSD/macOS doesn't ship it), and `git fetch` will surface its own errors quickly in normal cases. If a remote hangs, Ctrl-C is the user's escape hatch. A pluggable timeout is a future consideration.
- **`ls-remote` instead of `fetch --tags`** for the tag-existence check. `fetch --tags` would create local refs for every remote tag as a side effect, polluting the local tag namespace. `ls-remote` is a pure query.
- **No auto-pull.** Pulling is a mutation that can fail mid-script (conflicts, auth prompts, surprising merge commits), conflicts with `--amend` semantics, and defeats `--force-with-lease`. Users pull themselves when they're ready.

## [1.1.0] — 2025-04-17

### Added

- `gitbetter` — new umbrella info command. `gitbetter` (no args) or `gitbetter --help` prints an overview of all commands and points users at `git-push --help` / `git-tag --help`. `gitbetter --version` prints the project version and homepage URL. Does not perform git operations and does not dispatch to subcommands.
- `--help` and `--version` flags on `git-push` and `git-tag`. Both flags short-circuit before any git or argument validation, so they work outside a git repository and regardless of other arguments.
- `print_version [subcommand]` helper in `lib/ui.sh` provides a unified version-output format (`gitbetter[ <subcommand>] v<VERSION>` + homepage) used by all three commands.
- `tests/gitbetter.bats` — 4 new BATS tests covering help, version, no-args, and unknown-flag handling.
- `tests/git-push.bats` and `tests/git-tag.bats` — each gains 3 new tests covering `--help`, `--version`, and `--help` outside a git repo.

### Changed

- CI (`.github/workflows/ci.yml`) now lints `gitbetter.sh` alongside the existing scripts.
- `tests/test_helper/common-setup.bash` exposes a `GITBETTER_SH` path variable to tests.

## [1.0.1] — 2025-04-17

Refactor-only release. Behavior-preserving extraction of shared UI helpers.

### Added

- `lib/ui.sh` — single sourced library containing color constants, symbols, helper functions (`banner`, `info`, `success`, `warn`, `fail`, `confirm`, `ask_yn`, `divider`, `run_cmd`), new rounded-box helpers (`header_box`, `footer_box`), and project constants (`GITBETTER_VERSION`, `GITBETTER_HOMEPAGE`)

### Changed

- `git-push.sh` and `git-tag.sh` now source `lib/ui.sh` via `SCRIPT_DIR`-relative resolution (with `pwd -P` to follow symlinks) instead of duplicating the full UI helper block in each script
- Inline header/footer rounded-corner boxes in both scripts replaced with `header_box "<command>"` and `footer_box` calls
- CI (`.github/workflows/ci.yml`) now lints `lib/ui.sh` in addition to the command scripts

## [1.0.0] — 2025-04-17

First stable release.

### Added

- `.github/workflows/homebrew.yml` — auto-bumps the `pointmatic/tap` Homebrew formula when a `v*` tag is pushed, using `dawidd6/action-homebrew-bump-formula@v4`
- README "For Maintainers" section documenting the required `HOMEBREW_TAP_TOKEN` repository secret

## [0.9.0] — 2025-04-16

### Added

- GitHub Actions CI workflow (`.github/workflows/ci.yml`) — runs ShellCheck on `git-push.sh` and `git-tag.sh`, installs BATS via `bats-core/bats-action`, and runs the full `bats tests/` suite on every push to `main` and pull request to `main`
- `.gitignore` entries for BATS helper lib clones (`tests/test_helper/bats-support/`, `tests/test_helper/bats-assert/`)

### Fixed

- Verified `git-push.sh`, `git-tag.sh`, and `scripts/spike-tag.sh` pass ShellCheck with no warnings

## [0.8.0] — 2025-04-16

### Added

- Comprehensive `git-push.sh` BATS tests (8 cases): missing message, backtick stripping, double-quote-to-single conversion, empty-after-sanitization failure, `--amend` flag parsing, and positional arg (message + branch) parsing

## [0.7.0] — 2025-04-16

### Added

- Comprehensive `git-tag.sh` BATS tests (13 cases): missing arg, valid semver acceptance, invalid format rejection, duplicate detection, numeric tag sort, no-tags display, and end-to-end create+push verification against a bare remote

## [0.6.0] — 2025-04-16

### Added

- BATS test infrastructure: `tests/test_helper/common-setup.bash` with isolated temp-repo setup/teardown and bare-remote helper
- `tests/git-tag.bats` smoke test (missing-argument usage/exit)
- `tests/git-push.bats` smoke test (missing-argument usage/exit)

## [0.5.0] — 2025-04-16

### Added

- `git-tag.sh` outcome proof: after push, displays the new tag's commit SHA, refs, subject, and author via `git show --no-patch`

### Changed

- `git-tag.sh` tag creation and push workflow promoted from spike-support to first-class (confirmation prompt, `git tag`, `git push origin <TAG>` or `git push origin <TAG> <BRANCH>`)

## [0.4.0] — 2025-04-16

### Added

- `git-tag.sh` duplicate tag detection: fails with clear error if tag already exists locally
- `git-tag.sh` latest tag display in summary banner, sorted numerically by major.minor.patch (so `v1.10.0` > `v1.9.0`)
- "(no tags found)" shown when no `v*` tags exist

## [0.3.0] — 2025-04-16

### Added

- `git-tag.sh` semver validation: rejects tags not matching `^v[0-9]+\.[0-9]+\.[0-9]+$` with descriptive error message

## [0.2.0] — 2025-04-16

### Added

- `scripts/spike-tag.sh` — throwaway end-to-end test proving tag-create-and-push flow works in an isolated temp repo
- `git-tag.sh` now creates and pushes tags (minimal implementation for spike validation)

## [0.1.0] — 2025-04-16

### Added

- `git-tag.sh` minimal skeleton — argument parsing, header/footer UX boxes, shared color constants and helper functions
