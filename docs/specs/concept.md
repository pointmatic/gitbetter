# concept.md — gitbetter

This document defines why the `gitbetter` project exists. 
- **Problem space**: problem statement, why, pain points, target users, value criteria
- **Solution space**: solution statement, goals, scope, constraints
- **Value mapping**: Pain point to solution mapping

For requirements and behavior (what), see `features.md`. For implementation details (how), see `tech-spec.md`. For a breakdown of the implementation plan (step-by-step tasks), see `stories.md`. For project-specific must-know facts (workflow rules, hidden coupling, tool-wrapper conventions that the LLM would otherwise random-walk on), see `project-essentials.md`.

## Problem Space
 
### Problem Statement
Developers routinely execute multi-step git command sequences — stage, commit, push, tag, clean up branches — that are repetitive, error-prone, and context-dependent. A single typo or forgotten flag (e.g., `--force-with-lease` vs `--force`) can rewrite history dangerously or silently skip steps. These sequences also vary by workflow (direct-push vs. branch-PR, amend vs. new commit, semver tagging), requiring the developer to recall and adapt the correct recipe each time.

**Why this problem exists:**
Git is deliberately low-level and composable; it provides primitives, not workflows. This means every team and solo developer ends up mentally (or manually) scripting the same 3–8 command sequences over and over. There are no built-in "opinionated workflow" commands, and existing wrapper tools (e.g., git-flow, Husky) either impose rigid branching models or focus on hooks rather than the push/tag/cleanup lifecycle.

### Pain Points
- **Repetitive multi-step sequences**: Staging, committing, pushing, and optionally cleaning up a branch requires 3–6+ commands executed in the right order every time.
- **Error-prone manual typing**: Mistyping a branch name, forgetting `--force-with-lease`, or running `git push -f` instead can cause data loss or history corruption.
- **Pre-commit hook fallout**: Pre-commit hooks that reformat files leave the tree dirty after commit, requiring a manual follow-up amend that's easy to forget.
- **Branch-PR cleanup friction**: After merging a PR, switching back to main, pruning, pulling, and deleting the local branch is tedious and often deferred, cluttering the local repo.
- **Semver tag mistakes**: Manually typing `git tag vX.Y.Z` risks typos, duplicate tags, or non-semver formats that break downstream automation (Homebrew formula bumps, CI triggers).
- **No confirmation or visibility**: Raw git commands execute silently; there's no preview of what's about to happen and no easy abort point, increasing anxiety on destructive operations.

### Target Users
Solo developers and small-team contributors who use git from the terminal daily, value understanding what git is doing under the hood, but want to eliminate the friction and risk of repetitive command sequences. These users typically maintain open-source projects published via Homebrew or similar package managers and rely on CI/CD pipelines triggered by tags.

### Value Criteria
- **Time saved per push/tag cycle** — fewer commands typed, fewer context switches.
- **Error reduction** — typos, wrong flags, and forgotten steps eliminated by guided flows.
- **Confidence** — every destructive or irreversible action previewed and confirmed before execution.
- **Workflow completeness** — full coverage from commit through push, tag, and cleanup, without leaving loose ends.

## Solution Space
`gitbetter` is a Bash project to streamline repetitive git workflows — push, tag, and clean up — into single, interactive commands. 

### Solution Statement
gitbetter provides a set of Homebrew-installable Bash scripts (`git-push`, `git-tag`) that wrap multi-step git workflows into single commands with built-in confirmation gates, colorful status output, and smart defaults. Each command previews every action before executing, supports abort at any step, and handles edge cases (pre-commit hook dirty trees, force-push safety, semver validation) so the developer stays in control without memorizing recipes.

### Goals
- **Reduce push cycle to one command** — `git-push` covers stage → commit → push → branch cleanup in a single interactive flow, matching the "time saved" value criterion.
- **Eliminate tag format errors** — `git-tag` validates semver, shows the latest tag for context, and pushes with confirmation, matching the "error reduction" criterion.
- **Preview before every destructive action** — confirmation prompts at each step give the developer full visibility and an abort escape hatch, matching the "confidence" criterion.
- **Cover the full lifecycle** — from commit through push, tagging, CI trigger, and local branch cleanup, nothing is left as a manual afterthought, matching the "workflow completeness" criterion.

### Scope

**In scope:**
- `git-push` — interactive stage/commit/push with amend support, pre-commit hook recovery, and branch-PR cleanup
- `git-tag` — semver-validated tagging with latest-tag display and push to origin
- Homebrew tap distribution (`pointmatic/tap`) with formula auto-bump on tag push
- CI/CD via GitHub Actions (tests on push/PR, formula update on tag)

**Out of scope:**
- Git branching model enforcement (no git-flow or trunk-based policy)
- GUI or TUI beyond terminal ANSI colors
- Merge conflict resolution
- Support for non-Bash shells (zsh/fish wrappers, etc.)
- Repository hosting operations (PR creation, issue management)

### Constraints
- **Bash ≥ 4.0** — scripts use `set -euo pipefail`, arrays, and regex matching
- **Git ≥ 2.30** — relies on `git switch`, `--force-with-lease`
- **macOS + Linux** — primary targets; no Windows/native support
- **Homebrew distribution** — must conform to Homebrew formula conventions (tap at `pointmatic/tap`)
- **No external dependencies** — scripts use only git and coreutils; no Python, Node, etc.

## Value Mapping

**Repetitive multi-step sequences**:
  - `git-push` collapses stage → commit → push → cleanup into a single command with one commit message argument
  - `git-tag` collapses validate → tag → push-tag into a single command with one version argument

**Error-prone manual typing**:
  - Branch names are auto-detected or validated on input; no manual retyping at each step
  - `git-push --amend` automatically applies `--force-with-lease` (never `--force`)
  - `git-tag` enforces strict `vX.Y.Z` semver format before any git operation runs

**Pre-commit hook fallout**:
  - `git-push` detects a dirty tree after commit, offers to fold changes back via `--amend --no-edit`, and automatically switches to force-with-lease push mode

**Branch-PR cleanup friction**:
  - `git-push` offers an integrated post-push flow: wait for CI, then switch to main, fetch/prune, pull, and delete the feature branch — all confirmed step by step

**Semver tag mistakes**:
  - `git-tag` validates the tag format upfront, displays the most recent tag (sorted numerically, not lexicographically), and asks for confirmation before pushing — preventing duplicates, typos, and misordered versions

**No confirmation or visibility**:
  - Every script uses colored banners, step labels, and `[Y/n]` / `[y/N]` prompts before each action
  - The actual git command is echoed (`$ git add -A`, etc.) before execution so the developer always sees what's happening
  - Any step can be aborted cleanly with "n"
