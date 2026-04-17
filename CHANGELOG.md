# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
