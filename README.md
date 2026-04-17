# gitbetter

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Streamline repetitive git workflows — push, tag, and clean up — into single, interactive commands.

## Install

```bash
brew install pointmatic/tap/gitbetter
```

## Commands

### git-push

Stage, commit, push, and optionally clean up a branch — all in one command.

```bash
git-push "commit message"                # stage, commit, push to current branch
git-push "commit message" feature-xyz    # switch to branch, push, offer PR cleanup
git-push --amend "updated message"       # amend last commit, force-push safely
```

Every step is previewed and confirmed before execution. Pre-commit hook changes are detected and can be folded back in automatically.

### git-tag

Validate a semver tag, show the latest tag for context, and push to origin.

```bash
git-tag v1.0.0              # validate, create, and push tag
git-tag v1.0.0 main         # push tag to specific branch
```

Tags are validated against `vX.Y.Z` format. The most recent tag is displayed (sorted numerically, not lexicographically) so you always know where you are.

## Requirements

- Bash ≥ 4.0
- Git ≥ 2.30
- macOS or Linux

## License

[Apache-2.0](LICENSE) — Copyright (c) 2025 Pointmatic
