# stories.md -- gitbetter (Bash 4.0+)

This document breaks the `gitbetter` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Stories with code changes include a version number (e.g., v0.1.0). Stories with only documentation or polish changes omit the version number. The version follows semantic versioning and is bumped per story. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see `concept.md`. For requirements and behavior (what), see `features.md`. For implementation details (how), see `tech-spec.md`. For project-specific must-know facts, see `project-essentials.md` (`plan_phase` appends new facts per phase).

---

## Phase A: Foundation

### Story A.a: Project Scaffolding [Done]

Set up the repository skeleton: license, copyright headers, package manifest, README, and .gitignore.

- [x] Create `LICENSE` file (Apache-2.0, Copyright (c) 2025 Pointmatic)
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

### Story B.c: v0.5.0 Tag Creation and Push [Planned]

Implement the core tag-and-push workflow with confirmation gates.

- [ ] Add confirmation prompt: "Create and push tag `<tag>` to `origin`?"
- [ ] Run `git tag "$TAG"` via `run_cmd`
- [ ] Run `git push origin "$TAG"` via `run_cmd` (or `git push origin "$TAG" "$BRANCH_NAME"` if branch provided)
- [ ] Display one-liner outcome proof (the new tag)
- [ ] Print footer box with "✔ All done."
- [ ] Bump version to v0.5.0
- [ ] Update CHANGELOG.md
- [ ] Verify: `./git-tag.sh v0.5.0` creates tag, pushes, and shows success footer

## Phase C: Testing

### Story C.a: v0.6.0 Test Infrastructure — BATS Setup [Planned]

Set up the BATS test framework and shared test helpers.

- [ ] Create `tests/test_helper/common-setup.bash` with:
  - `setup()` — create temp dir, `git init`, configure user.email/user.name
  - `teardown()` — `rm -rf` temp dir
  - Helper to create a bare remote in the temp dir for push tests
- [ ] Create `tests/git-tag.bats` with a single smoke test that sources common-setup and runs `git-tag.sh --help` or a trivial invocation
- [ ] Create `tests/git-push.bats` with a single smoke test
- [ ] Confirm BATS runs locally: `bats tests/`
- [ ] Bump version to v0.6.0
- [ ] Update CHANGELOG.md
- [ ] Verify: `bats tests/` passes with 2 smoke tests

### Story C.b: v0.7.0 git-tag Tests [Planned]

Comprehensive BATS tests for `git-tag.sh`.

- [ ] Test: missing tag argument → prints usage, exits 1
- [ ] Test: valid semver tags accepted (`v0.0.1`, `v1.0.0`, `v10.20.30`)
- [ ] Test: invalid tags rejected (`1.0.0`, `v1.0`, `v1.2.3.4`, `vabc`, `v1.2.3-beta`)
- [ ] Test: duplicate tag detected → fails with "already exists"
- [ ] Test: latest tag sorted numerically (`v1.10.0` after `v1.9.0`)
- [ ] Test: tag created and pushed to remote successfully
- [ ] Test: no tags exist → "No tags found" displayed, proceeds normally
- [ ] Bump version to v0.7.0
- [ ] Update CHANGELOG.md
- [ ] Verify: `bats tests/git-tag.bats` — all tests pass

### Story C.c: v0.8.0 git-push Tests [Planned]

BATS tests for `git-push.sh` argument parsing and validation.

- [ ] Test: missing commit message → prints usage, exits 1
- [ ] Test: commit message sanitization (backticks stripped, `"` → `'`)
- [ ] Test: empty message after sanitization → fails with error
- [ ] Test: `--amend` flag parsed correctly
- [ ] Test: positional args (message, branch) parsed correctly
- [ ] Bump version to v0.8.0
- [ ] Update CHANGELOG.md
- [ ] Verify: `bats tests/git-push.bats` — all tests pass

## Phase D: CI/CD & Distribution

### Story D.a: v0.9.0 CI Pipeline — ShellCheck + BATS [Planned]

Set up GitHub Actions to lint and test on every push and PR.

- [ ] Create `.github/workflows/ci.yml`:
  - Trigger on push to `main` and pull requests to `main`
  - Install shellcheck
  - Install bats-core, bats-support, bats-assert
  - Run `shellcheck git-push.sh git-tag.sh`
  - Run `bats tests/`
- [ ] Fix any shellcheck warnings in `git-push.sh` and `git-tag.sh`
- [ ] Bump version to v0.9.0
- [ ] Update CHANGELOG.md
- [ ] Verify: push to main triggers CI; all checks pass

### Story D.b: v1.0.0 Homebrew Formula Auto-Bump [Planned]

Set up the GitHub Action to update the Homebrew formula on tag push.

- [ ] Create `.github/workflows/homebrew.yml`:
  - Trigger on push of tags matching `v*`
  - Use `dawidd6/action-homebrew-bump-formula@v4`
  - Configure: `token: ${{ secrets.HOMEBREW_TAP_TOKEN }}`, `tap: pointmatic/tap`, `formula: gitbetter`, `tag: ${{ github.ref_name }}`
- [ ] Document the `HOMEBREW_TAP_TOKEN` secret requirement in README.md (for maintainers)
- [ ] Bump version to v1.0.0
- [ ] Update CHANGELOG.md
- [ ] Verify: push tag `v1.0.0` triggers the homebrew workflow

## Phase E: Documentation & Release

### Story E.a: Final README and Docs Polish [Planned]

Finalize all documentation for the v1.0.0 release.

- [ ] Review and finalize README.md: project description, install, usage examples for both commands, contributing section, license
- [ ] Review CHANGELOG.md: ensure all versions are documented
- [ ] Remove `scripts/spike-tag.sh` (throwaway from A.c)
- [ ] Verify: README renders correctly on GitHub, all links work

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
