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

@test "git-push: missing commit message prints usage and exits 1" {
    run "${GIT_PUSH_SH}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"git-push"* ]]
}

# ── Meta flags ──────────────────────────────────────────────

@test "git-push: --help prints full help and exits 0" {
    run "${GIT_PUSH_SH}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"Examples:"* ]]
    [[ "${output}" == *"--amend"* ]]
    [[ "${output}" == *"--keep"* ]]
    [[ "${output}" == *"-k"* ]]
    [[ "${output}" == *"Homepage:"* ]]
}

@test "git-push: --version prints version and homepage, exits 0" {
    run "${GIT_PUSH_SH}" --version
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"gitbetter git-push v1.3.1"* ]]
    [[ "${output}" == *"https://github.com/pointmatic/gitbetter"* ]]
}

@test "git-push: --help works outside a git repo" {
    TMP_OUTSIDE="$(mktemp -d)"
    cd "${TMP_OUTSIDE}"
    run "${GIT_PUSH_SH}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    rm -rf "${TMP_OUTSIDE}"
}

# ── Remote-awareness (D.e) ──────────────────────────────────

@test "git-push: no upstream → no remote check, no prompt mentioned" {
    # Fresh repo with no remote at all — existing behavior preserved.
    run bash -c "echo n | '${GIT_PUSH_SH}' 'msg'"
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Remote Check"* ]]
    [[ "${output}" != *"Push anyway?"* ]]
}

@test "git-push: remote ahead → warn + divergence prompt; answering no aborts" {
    # Note: bash's `read -rp` only prints the prompt to a TTY, not to a
    # piped stdin — so we match the warning text and the abort message
    # rather than the literal "Push anyway?" prompt.
    setup_bare_remote
    git push -q -u origin main
    make_remote_ahead
    # y at "Does this look right?", n at "Push anyway?"
    run bash -c "printf 'y\nn\n' | '${GIT_PUSH_SH}' 'local change'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Remote Check"* ]]
    [[ "${output}" == *"new commit"* ]]
    [[ "${output}" == *"Aborted."* ]]
}

@test "git-push --amend: remote ahead → amend-specific warning appears" {
    setup_bare_remote
    git push -q -u origin main
    make_remote_ahead
    # Make a local change so there's something to amend
    echo "tweak" > tweak.txt
    git add -A
    git commit -q --amend --no-edit
    # y at "Does this look right?", n at "Push anyway?"
    run bash -c "printf 'y\nn\n' | '${GIT_PUSH_SH}' --amend 'amended msg'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Amend + remote-ahead"* ]]
    [[ "${output}" == *"Aborted."* ]]
}

@test "git-push: remote up to date → 'Up to date' or 'ready to push' message, no prompt" {
    setup_bare_remote
    git push -q -u origin main
    # Abort at the stage-confirm prompt (first confirm AFTER the remote check)
    # Inputs: y (last commit), n (stage all changes)
    run bash -c "printf 'y\nn\n' | '${GIT_PUSH_SH}' 'msg'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Remote Check"* ]]
    [[ "${output}" != *"Push anyway?"* ]]
    [[ "${output}" == *"Up to date with"* || "${output}" == *"ready to push"* ]]
}

# ── Commit message sanitization ─────────────────────────────

@test "git-push: commit message — backticks stripped" {
    # Abort at the first confirm prompt so no commit is made.
    run bash -c "echo n | '${GIT_PUSH_SH}' 'hello \`evil\` world'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"hello evil world"* ]]
    [[ "${output}" != *'`evil`'* ]]
}

@test "git-push: commit message — double quotes converted to single" {
    run bash -c "echo n | '${GIT_PUSH_SH}' 'say \"hi\" there'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"say 'hi' there"* ]]
}

@test "git-push: empty message after sanitization fails with error" {
    # A message of only backticks becomes empty after sanitization.
    run "${GIT_PUSH_SH}" '```'
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"empty"* ]]
}

# ── --amend flag ────────────────────────────────────────────

@test "git-push: --amend flag parsed correctly (Mode: amend shown)" {
    run bash -c "echo n | '${GIT_PUSH_SH}' --amend 'amended message'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"amend"* ]]
    [[ "${output}" == *"amended message"* ]]
}

@test "git-push: without --amend, Mode: amend NOT shown" {
    run bash -c "echo n | '${GIT_PUSH_SH}' 'regular message'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"regular message"* ]]
    # "Mode:" line only appears when amend is on
    [[ "${output}" != *"Mode:"* ]]
}

# ── Positional args (message, branch) ───────────────────────

@test "git-push: positional args — message and branch parsed correctly" {
    run bash -c "echo n | '${GIT_PUSH_SH}' 'feat: add thing' feature-xyz"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"feat: add thing"* ]]
    [[ "${output}" == *"feature-xyz"* ]]
    [[ "${output}" == *"Branch:"* ]]
}

@test "git-push: --amend with message and branch — all three parsed" {
    run bash -c "echo n | '${GIT_PUSH_SH}' --amend 'fix: patch' bugfix"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"fix: patch"* ]]
    [[ "${output}" == *"bugfix"* ]]
    [[ "${output}" == *"amend"* ]]
}

# ── Branch Workflow (D.f) ───────────────────────────────────

@test "git-push --keep: on non-main branch, no cleanup prompt; branch kept" {
    # Full push flow on a feature branch with --keep.
    # Inputs: y (last commit confirm), y (stage confirm), y (commit confirm)
    setup_bare_remote
    echo "remote.git/" > .gitignore && git add -A && git commit -q -m "ignore bare"
    git push -q -u origin main
    echo "work" > work.txt
    run bash -c "printf 'y\ny\ny\n' | '${GIT_PUSH_SH}' --keep 'wip' feat/x"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Branch Workflow"* ]]
    [[ "${output}" == *"Keeping"* ]]
    [[ "${output}" == *"Next push will continue"* ]]
    [[ "${output}" != *"Merge complete?"* ]]
    [[ "${output}" != *"Cleanup"* ]]
    # Branch still exists, HEAD still on it
    run git symbolic-ref --short HEAD
    [ "${output}" = "feat/x" ]
    run git branch --list feat/x
    [[ "${output}" == *"feat/x"* ]]
}

@test "git-push: on non-main branch, answer N at cleanup prompt → branch kept" {
    setup_bare_remote
    echo "remote.git/" > .gitignore && git add -A && git commit -q -m "ignore bare"
    git push -q -u origin main
    echo "work" > work.txt
    # 4 prompts: last-commit (y), stage (y), commit (y), cleanup (N via Enter)
    run bash -c "printf 'y\ny\ny\n\n' | '${GIT_PUSH_SH}' 'wip' feat/y"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Branch Workflow"* ]]
    [[ "${output}" == *"Keeping"* ]]
    [[ "${output}" != *"Cleanup"* ]]
    run git symbolic-ref --short HEAD
    [ "${output}" = "feat/y" ]
    run git branch --list feat/y
    [[ "${output}" == *"feat/y"* ]]
}

@test "git-push: on non-main branch, answer y at cleanup → switch main, delete branch" {
    setup_bare_remote
    echo "remote.git/" > .gitignore && git add -A && git commit -q -m "ignore bare"
    git push -q -u origin main
    echo "work" > work.txt
    # 4 prompts: last-commit (y), stage (y), commit (y), cleanup (y)
    run bash -c "printf 'y\ny\ny\ny\n' | '${GIT_PUSH_SH}' 'wip' feat/z"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Cleanup"* ]]
    [[ "${output}" == *"deleted"* ]]
    # Back on main
    run git symbolic-ref --short HEAD
    [ "${output}" = "main" ]
    # Branch gone
    run git branch --list feat/z
    [ -z "${output}" ]
}
