# idea

`gitbetter` is a Homebrew tap that simplifies common git flows into single, intuitive commands with dynamic behavior.

`git-push` is a bash script that wraps the repetitive multi-step git workflows — stage, commit, push, and optionally clean up — into one interactive command. It handles two common scenarios: pushing directly to the current branch, and the branch-PR workflow where you create a feature branch, push it, wait for CI, then merge and clean up locally. An `--amend` flag supports replacing the last commit with a `--force-with-lease` push. The script also detects when pre-commit hooks leave the working tree dirty after a commit and offers to fold those changes back in automatically, avoiding a separate follow-up amend. Each step shows what's about to happen, asks for confirmation, and can be aborted — the goal is to reduce typo-prone command sequences without hiding what git is actually doing.

`git-tag` is a bash script that takes a tag as a parameter (required) and a branch_name as a second positional param (optional). It validates for semver formatting "vX.Y.Z" where X, Y, and Z are integers, checks existing local tags, outputs the most recent tag (sorted numerically by its parts, not lexicographically; e.g., v1.10.0 comes after v1.9.0), gets user confirmation on intent, then pushes the tag to origin <branch_name>. 

`git-push` is already written and tested. `git-tag` has not been written, but should follow the same look-and-feel and code pattern in bash. 

I want CI/CD testing, and automatically run the update homebrew formula action when I push a tag to origin. The repo should publish to my Homebrew tap on GitHub, similar to how I do this in another project (example GitHub actions config below). Obviously, the formula should be `gitbetter` instead of `pyve`

```yaml
name: Update Homebrew Formula

on:
  push:
    tags: ['v*']

jobs:
  update-formula:
    runs-on: ubuntu-latest
    steps:
      - name: Update Homebrew formula
        uses: dawidd6/action-homebrew-bump-formula@v4
        with:
          token: ${{ secrets.HOMEBREW_TAP_TOKEN }}
          tap: pointmatic/tap
          formula: pyve
          tag: ${{ github.ref_name }}
```

