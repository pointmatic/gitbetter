#!/usr/bin/env bats
# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0
#
# Unit tests for helpers in lib/ui.sh.

load 'test_helper/common-setup'

setup() {
    _common_setup
}

# ── ask_choice ──────────────────────────────────────────────

@test "ask_choice: Enter selects the configured default index" {
    run bash -c "source '${REPO_ROOT}/lib/ui.sh' && printf '\n' | { ask_choice 'q?' 2 'a' 'b' 'c'; echo \"REPLY=\${REPLY}\"; }"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"REPLY=2"* ]]
}

@test "ask_choice: a valid digit selects that index" {
    run bash -c "source '${REPO_ROOT}/lib/ui.sh' && printf '3\n' | { ask_choice 'q?' 1 'a' 'b' 'c'; echo \"REPLY=\${REPLY}\"; }"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"REPLY=3"* ]]
}

@test "ask_choice: out-of-range digit re-prompts once, then valid digit wins" {
    run bash -c "source '${REPO_ROOT}/lib/ui.sh' && printf '9\n2\n' | { ask_choice 'q?' 1 'a' 'b' 'c'; echo \"REPLY=\${REPLY}\"; }"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Invalid choice"* ]]
    [[ "${output}" == *"REPLY=2"* ]]
}

@test "ask_choice: two invalid inputs fall back to default with warning" {
    run bash -c "source '${REPO_ROOT}/lib/ui.sh' && printf 'x\nyz\n' | { ask_choice 'q?' 3 'a' 'b' 'c'; echo \"REPLY=\${REPLY}\"; }"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Invalid input"* ]]
    [[ "${output}" == *"REPLY=3"* ]]
}

@test "ask_choice: prompt and numbered options are rendered" {
    run bash -c "source '${REPO_ROOT}/lib/ui.sh' && printf '1\n' | ask_choice 'Pick one' 1 'first' 'second'"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Pick one"* ]]
    [[ "${output}" == *"1)"* ]]
    [[ "${output}" == *"first"* ]]
    [[ "${output}" == *"2)"* ]]
    [[ "${output}" == *"second"* ]]
}
