# idea

`gitbetter` is a collection of git tools that 

`git-push` is a single-file bash script that wraps the repetitive multi-step git workflows — stage, commit, push, and optionally clean up — into one interactive command. It handles two common scenarios: pushing directly to the current branch, and the branch-PR workflow where you create a feature branch, push it, wait for CI, then merge and clean up locally. An `--amend` flag supports replacing the last commit with a `--force-with-lease` push. The script also detects when pre-commit hooks leave the working tree dirty after a commit and offers to fold those changes back in automatically, avoiding a separate follow-up amend. Each step shows what's about to happen, asks for confirmation, and can be aborted — the goal is to reduce typo-prone command sequences without hiding what git is actually doing.
