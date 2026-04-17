#!/usr/bin/env bats
# Copyright (c) 2025 Pointmatic
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
