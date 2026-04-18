# gitbetter

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Streamline repetitive git workflows — push, tag, and clean up — into single, interactive commands.

## Install

```bash
brew install pointmatic/tap/gitbetter
```

## Commands

Quick overview:

```bash
gitbetter            # list all commands
gitbetter --help     # same as above
gitbetter --version  # print version and homepage
```

Every command supports `--help` and `--version`:

```bash
git-push --help
git-tag --version
```

### git-push

Stage, commit, push, and optionally clean up a branch — all in one command.

```bash
git-push "commit message"                # stage, commit, push to current branch
git-push "commit message" feature-xyz    # switch to branch, push, offer PR cleanup
git-push --amend "updated message"       # amend last commit, force-push safely
git-push "wip" feature-xyz --keep        # push without prompting for branch cleanup
```

Every step is previewed and confirmed before execution. Pre-commit hook changes are detected and can be folded back in automatically.

Before staging, `git-push` does a read-only `git fetch` against the upstream and warns if the remote has new commits you haven't seen. It never auto-pulls — you decide whether to rebase or push anyway.

After pushing from a non-`main` branch, `git-push` shows the Actions and Compare URLs and asks a single question: *"Merge complete? Clean up (switch to main, pull, delete branch)?"*. The default is **no** (keep the branch). Pass `--keep` (or `-k`) to skip the prompt entirely — handy for multi-commit feature branches.

### git-tag

Validate a semver tag, show the latest tag for context, and push to origin.

```bash
git-tag v1.0.0              # validate, create, and push tag
git-tag v1.0.0 main         # push tag to specific branch
```

Tags are validated against `vX.Y.Z` format. The most recent tag is displayed (sorted numerically, not lexicographically) so you always know where you are. Before creating the tag, `git-tag` probes `origin` and refuses to proceed if the tag already exists remotely — no silent overwrites.

## Requirements

- Bash ≥ 4.0
- Git ≥ 2.30
- macOS or Linux

## For Maintainers

### Homebrew formula auto-bump

Pushing a tag matching `v*` triggers `.github/workflows/homebrew.yml`, which updates the `gitbetter` formula in `pointmatic/homebrew-tap` via [`dawidd6/action-homebrew-bump-formula`](https://github.com/dawidd6/action-homebrew-bump-formula).

**Required repository secret:** `HOMEBREW_TAP_TOKEN` — a GitHub personal access token (fine-grained or classic) with `contents: write` permission on `pointmatic/homebrew-tap`. Set it under **Settings → Secrets and variables → Actions**.

## License

[Apache-2.0](LICENSE) — Copyright (c) 2026 Pointmatic
