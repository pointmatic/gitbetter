#!/usr/bin/env bats
# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0

load 'test_helper/common-setup'

setup() {
    _common_setup
    setup_temp_repo
    add_dummy_commit
}

teardown() {
    teardown_temp_repo
}

# ── Argument parsing ────────────────────────────────────────

@test "git-commit: missing commit message prints usage and exits 1" {
    run "${GIT_COMMIT_SH}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"git-commit"* ]]
}

# ── Meta flags ──────────────────────────────────────────────

@test "git-commit: --help prints full help and exits 0" {
    run "${GIT_COMMIT_SH}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"Examples:"* ]]
    [[ "${output}" == *"--amend"* ]]
    [[ "${output}" == *"--keep"* ]]
    [[ "${output}" == *"-k"* ]]
    [[ "${output}" == *"never pushes"* ]]
    [[ "${output}" == *"Homepage:"* ]]
}

@test "git-commit: --version prints version and homepage, exits 0" {
    run "${GIT_COMMIT_SH}" --version
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"gitbetter git-commit v1.7.0"* ]]
    [[ "${output}" == *"https://github.com/pointmatic/gitbetter"* ]]
}

@test "git-commit: --help works outside a git repo" {
    TMP_OUTSIDE="$(mktemp -d)"
    cd "${TMP_OUTSIDE}"
    run "${GIT_COMMIT_SH}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    rm -rf "${TMP_OUTSIDE}"
}

# ── Core commit flow (no push) ──────────────────────────────

@test "git-commit: full flow commits locally and never pushes" {
    setup_bare_remote
    echo "remote.git/" > .gitignore && git add -A && git commit -q -m "ignore bare"
    git push -q -u origin main
    PRE_REMOTE="$(git rev-parse origin/main)"
    echo "work" > work.txt
    # 3 prompts: last-commit (y), stage (y), commit (y)
    run bash -c "printf 'y\ny\ny\n' | '${GIT_COMMIT_SH}' 'feat: thing'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Committed."* ]]
    [[ "${output}" == *"No Push"* ]]
    [[ "${output}" == *"nothing pushed"* ]]
    [[ "${output}" != *"git push"* ]]
    # Local HEAD advanced, remote untouched
    run git log -1 --format=%s
    [ "${output}" = "feat: thing" ]
    [ "$(git rev-parse origin/main)" = "${PRE_REMOTE}" ]
}

@test "git-commit: on feature branch, commits there and shows keep note" {
    setup_bare_remote
    echo "remote.git/" > .gitignore && git add -A && git commit -q -m "ignore bare"
    git push -q -u origin main
    echo "work" > work.txt
    run bash -c "printf 'y\ny\ny\n' | '${GIT_COMMIT_SH}' --keep 'wip' feat/x"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Now on"* ]]
    [[ "${output}" == *"Keeping"* ]]
    [[ "${output}" != *"Merge complete?"* ]]
    [[ "${output}" != *"Cleanup"* ]]
    run git symbolic-ref --short HEAD
    [ "${output}" = "feat/x" ]
    run git log -1 --format=%s
    [ "${output}" = "wip" ]
    # Nothing on the remote under that branch name
    run git ls-remote origin feat/x
    [ -z "${output}" ]
}

# ── Remote-awareness (advisory) ─────────────────────────────

@test "git-commit: no upstream → no remote check, no prompt mentioned" {
    run bash -c "echo n | '${GIT_COMMIT_SH}' 'msg'"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Remote Check"* ]]
    [[ "${output}" != *"Commit anyway?"* ]]
}

@test "git-commit: remote ahead → warn + advisory prompt; answering no aborts" {
    # Note: bash's `read -rp` only prints the prompt to a TTY, not to a
    # piped stdin — so we match the warning text and the abort message
    # rather than the literal "Commit anyway?" prompt.
    setup_bare_remote
    git push -q -u origin main
    make_remote_ahead
    # y at "Does this look right?", n at "Commit anyway?"
    run bash -c "printf 'y\nn\n' | '${GIT_COMMIT_SH}' 'local change'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Remote Check"* ]]
    [[ "${output}" == *"new commit"* ]]
    [[ "${output}" == *"Aborted."* ]]
}

@test "git-commit --amend: remote ahead → amend-specific warning appears" {
    setup_bare_remote
    git push -q -u origin main
    make_remote_ahead
    # Make a local change so there's something to amend
    echo "tweak" > tweak.txt
    git add -A
    git commit -q --amend --no-edit
    # y at "Does this look right?", n at "Commit anyway?"
    run bash -c "printf 'y\nn\n' | '${GIT_COMMIT_SH}' --amend 'amended msg'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Amend + remote-ahead"* ]]
    [[ "${output}" == *"Aborted."* ]]
}

@test "git-commit: remote up to date → 'Up to date' or 'ahead' message, no prompt" {
    setup_bare_remote
    git push -q -u origin main
    # Abort at the stage-confirm prompt (first confirm AFTER the remote check)
    # Inputs: y (last commit), n (stage all changes)
    run bash -c "printf 'y\nn\n' | '${GIT_COMMIT_SH}' 'msg'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Remote Check"* ]]
    [[ "${output}" != *"Commit anyway?"* ]]
    [[ "${output}" == *"Up to date with"* || "${output}" == *"ahead of"* ]]
}

# ── Commit message sanitization ─────────────────────────────

@test "git-commit: commit message — backticks stripped" {
    # Abort at the first confirm prompt so no commit is made.
    run bash -c "echo n | '${GIT_COMMIT_SH}' 'hello \`evil\` world'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"hello evil world"* ]]
    [[ "${output}" != *'`evil`'* ]]
}

@test "git-commit: commit message — double quotes converted to single" {
    run bash -c "echo n | '${GIT_COMMIT_SH}' 'say \"hi\" there'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"say 'hi' there"* ]]
}

@test "git-commit: empty message after sanitization fails with error" {
    # A message of only backticks becomes empty after sanitization.
    run "${GIT_COMMIT_SH}" '```'
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"empty"* ]]
}

# ── --amend flag ────────────────────────────────────────────

@test "git-commit: --amend flag parsed correctly (Mode: amend shown)" {
    run bash -c "echo n | '${GIT_COMMIT_SH}' --amend 'amended message'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"amend"* ]]
    [[ "${output}" == *"amended message"* ]]
}

@test "git-commit: without --amend, Mode: amend NOT shown" {
    run bash -c "echo n | '${GIT_COMMIT_SH}' 'regular message'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"regular message"* ]]
    # "Mode:" line only appears when amend is on
    [[ "${output}" != *"Mode:"* ]]
}

@test "git-commit --amend: full flow replaces last commit, no force-push" {
    setup_bare_remote
    echo "remote.git/" > .gitignore && git add -A && git commit -q -m "ignore bare"
    git push -q -u origin main
    PRE_COUNT="$(git rev-list --count HEAD)"
    echo "tweak" > tweak.txt
    # 3 prompts: commit-to-amend (y), stage (y), commit (y)
    run bash -c "printf 'y\ny\ny\n' | '${GIT_COMMIT_SH}' --amend 'amended msg'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Amended."* ]]
    [[ "${output}" != *"force"* ]]
    POST_COUNT="$(git rev-list --count HEAD)"
    [ "${PRE_COUNT}" = "${POST_COUNT}" ]
    run git log -1 --format=%s
    [ "${output}" = "amended msg" ]
}

# ── Positional args (message, branch) ───────────────────────

@test "git-commit: positional args — message and branch parsed correctly" {
    run bash -c "echo n | '${GIT_COMMIT_SH}' 'feat: add thing' feature-xyz"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"feat: add thing"* ]]
    [[ "${output}" == *"feature-xyz"* ]]
    [[ "${output}" == *"Branch:"* ]]
}

@test "git-commit: --amend with message and branch — all three parsed" {
    run bash -c "echo n | '${GIT_COMMIT_SH}' --amend 'fix: patch' bugfix"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"fix: patch"* ]]
    [[ "${output}" == *"bugfix"* ]]
    [[ "${output}" == *"amend"* ]]
}

# ── Project-Guide pathspec exclusion ────────────────────────

@test "git-commit: .project-guide.yml present → docs/project-guide excluded from commit" {
    # Marker + a file under the excluded dir + an unrelated change.
    : > .project-guide.yml
    mkdir -p docs/project-guide
    echo "internal artifact" > docs/project-guide/foo.md
    echo "keep me" > keep.txt
    # 3 prompts: last-commit (y), stage (y), commit (y). No remote, so
    # the flow goes straight to the No Push summary.
    run bash -c "printf 'y\ny\ny\n' | '${GIT_COMMIT_SH}' 'feat: thing'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Excluding"* ]]
    [[ "${output}" == *"docs/project-guide"* ]]
    [[ "${output}" == *".project-guide.yml detected"* ]]
    # Committed tree contains keep.txt + .project-guide.yml, NOT docs/project-guide/foo.md.
    run git ls-tree -r --name-only HEAD
    [[ "${output}" == *"keep.txt"* ]]
    [[ "${output}" == *".project-guide.yml"* ]]
    [[ "${output}" != *"docs/project-guide/foo.md"* ]]
    # File is still on disk, just not staged/committed.
    [ -f docs/project-guide/foo.md ]
}

# ── Tombstone guard ─────────────────────────────────────────

@test "git-commit: tombstoned branch name → warn + N aborts without creating branch" {
    TOMB="$(git rev-parse --git-dir)/gitbetter-deleted-branches"
    printf 'feat/old\t2026-01-01\n' > "${TOMB}"
    # y at last-commit confirm, n at re-create prompt
    run bash -c "printf 'y\nn\n' | '${GIT_COMMIT_SH}' 'msg' feat/old"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"cleaned up by gitbetter"* ]]
    [[ "${output}" == *"Aborted."* ]]
    run git branch --list feat/old
    [ -z "${output}" ]
}
