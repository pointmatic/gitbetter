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

If the push is rejected, `git-push` offers three explicit recovery options:

1. **Retry with `--force-with-lease`** — safe force push; fixes divergence from earlier history rewrites.
2. **Roll back commit** — undoes the commit (`git reset --soft HEAD~1`) so your changes stay staged, ready to retry with a branch name.
3. **Abort** — leave everything as-is and resolve manually.

The default is **Roll back** when the remote rejects with a branch-protection error (e.g. `GH006`) or when you're pushing to `main` without a `branch_name`; otherwise the default is **Abort**. Amend mode (`--amend`) bypasses the menu and auto-uses `--force-with-lease`.

### git-tag

Validate a semver tag, show the latest tag for context, and push to origin.

```bash
git-tag v1.0.0              # validate, create, and push tag
git-tag v1.0.0 main         # push tag to specific branch
git-tag v2.1.1 --prefix npm # create and push npm-v2.1.1
git-tag v1.0.0 main --prefix ios
```

Tags are validated against `vX.Y.Z` format. The most recent tag is displayed (sorted numerically, not lexicographically) so you always know where you are. Before creating the tag, `git-tag` probes `origin` and refuses to proceed if the tag already exists remotely — no silent overwrites.

Use `--prefix NAME` in monorepos or multi-artifact projects to namespace tags by component (e.g., `npm-v2.1.1`, `ios-v1.0.0`, `backend-v3.2.0`). The separator is always `-`; the prefix value must match `[a-zA-Z0-9][a-zA-Z0-9._-]*`. When `--prefix` is set, the "Latest" display filters to the same prefix family so you see relevant version history only.

## Requirements

- Bash ≥ 4.0
- Git ≥ 2.30
- macOS or Linux

## Development

Run the test suite locally:

```bash
shellcheck gitbetter.sh git-push.sh git-tag.sh lib/ui.sh
bats tests/
```

BATS can be installed via Homebrew: `brew install bats-core`. Helper libraries `bats-support` and `bats-assert` are cloned into `tests/test_helper/` by the CI workflow; install them locally the same way if you want to run the full suite offline.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## For Maintainers

### Homebrew formula auto-bump

Pushing a tag matching `v*` triggers `.github/workflows/homebrew.yml`, which updates the `gitbetter` formula in `pointmatic/homebrew-tap` via [`dawidd6/action-homebrew-bump-formula`](https://github.com/dawidd6/action-homebrew-bump-formula).

**Required repository secret:** `HOMEBREW_TAP_TOKEN` — a GitHub personal access token (fine-grained or classic) with `contents: write` permission on `pointmatic/homebrew-tap`. Set it under **Settings → Secrets and variables → Actions**.

## License

[Apache-2.0](LICENSE) — Copyright (c) 2026 Pointmatic
