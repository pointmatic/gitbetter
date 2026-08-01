# stories.md -- gitbetter (python)

This document breaks the `gitbetter` project into an ordered sequence of small, independently completable stories grouped into phases. Each story has a checklist of concrete tasks. Stories are organized by phase and reference modules defined in `tech-spec.md`.

Put **`vX.Y.Z` in the story title only when that story ships the package version bump** for that release. Doc-only or polish stories **omit the version from the title** (they share the release with the preceding code story, or use your project’s doc-release policy). **One semver bump per owning story** — extra tasks on the *same* story share that bump; see `project-essentials.md`. Semantic versioning applies to the package. Stories are marked with `[Planned]` initially and changed to `[Done]` when completed.

For a high-level concept (why), see [`concept.md`](concept.md). For requirements and behavior (what), see [`features.md`](features.md). For implementation details (how), see [`tech-spec.md`](tech-spec.md). For project-specific must-know facts, see [`project-essentials.md`](project-essentials.md) (`plan_phase` appends new facts per phase). For the workflow steps tailored to the current mode (cycle steps, approval gates, conventions), see [`docs/project-guide/go.md`](../project-guide/go.md) — re-read it whenever the mode changes or after context compaction.

---

## Version Cadence

Standard semantic versioning, with these conventions:

- **Every story belongs to a phase.** Bugfix stories included. No orphan stories.
- **Per-story bumping** (when a story owns its own release):
  - Bugfix or trivial change → **patch** (`vX.Y.Z+1`)
  - Feature or improvement → **minor** (`vX.Y+1.0`)
  - Breaking change → **major** (`vX+1.0.0`). Post-1.0 only, and only via the `plan_production_phase` mode, which negotiates with the developer about whether the breakage is substantively user-facing or technically-but-trivially breaking (example: a log-format change is technically breaking, but if logs aren't a core consumer capability, the developer may judge it minor or even patch).
- **Phase-bundling option:** a phase can run unversioned during work and ship a single release/tag at end-of-phase. Stories within the phase carry no version in their title; the phase's last story owns the bump (magnitude determined by the highest-impact change in the bundle).
- **No out-of-order implementation.** Story order in this file is the order of execution. If work order needs to change, **reorganize/renumber here first** — don't skip ahead and create version-number gaps.
- **Pre-1.0:** standard semver applies; version starts at `v0.1.0` (Story A.a).
- **Post-1.0:** every phase must go through `plan_production_phase` (the lighter `plan_phase` is pre-1.0 only). Major bumps only happen through that mode's negotiation step.

This is the authoritative cadence rule. **Do not extrapolate the bump magnitude from `pyproject.toml`'s current version** — re-read this section whenever you're about to assign a version to a story.

---

## Phase F: General Improvements

---

### Story F.a: v1.7.0 Add a `git-commit` - identical to `git-push` but doesn't push [Done]

GitHub actions get burned up on the free tier, and even on the paid Pro tier when pushing on every single commit. We need to economize on GitHub actions usage, and the things that CI catches can often be caught locally, and when not, it is not catastrophic to be a cleanup step at the end of a release. 

This new command will have the same functionality/flag(s)/params/subcommand(s) as `git-push`. 

- [x] Add the new command
- [x] Add tests for the new command
- [x] Bump version 1.6.3 → 1.7.0: `GITBETTER_VERSION` in `lib/ui.sh` + `--version` assertions in all `tests/*.bats`
- [x] Update documentation — every doc that enumerates the command set (`git-push` / `git-tag`) needs `git-commit` added:
  - [x] `README.md` (tagline, commands overview, new `git-commit` section, dev shellcheck list)
  - [x] `CHANGELOG.md` (v1.7.0 entry)
  - [x] `docs/specs/features.md` (Core Requirements list, Inputs tables, FR-5b added, FR-9 command lists, Acceptance Criteria)
  - [x] `docs/specs/tech-spec.md` (repo layout, meta-flag section, new `git-commit.sh` section, command table, Shared Flags, test layout, Homebrew formula snippet)
  - [x] `docs/specs/concept.md` (solution statement + in-scope list)
  - [x] `docs/specs/project-essentials.md` (command-script lists in the `lib/ui.sh` and `.sh`-extension sections)
  - [x] `.github/workflows/ci.yml` (shellcheck file list — config, not a doc, but the same enumeration)
  - **Out of repo:** the Homebrew formula in `pointmatic/homebrew-tap` must add `git-commit.sh` + `bin/git-commit` wrapper at release time, or the new command won't be installed.

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

**Out of scope (Story D.f: v1.3.0):**

- **Auto-detect PR merge status via `gh pr view`**: when the GitHub CLI is available, call `gh pr view <branch> --json state -q .state`; if `MERGED`, default the cleanup prompt to **y**. Pure UX upgrade, doesn't change the flag or prompt shape. Added to Future section.
