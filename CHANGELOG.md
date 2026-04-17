# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
