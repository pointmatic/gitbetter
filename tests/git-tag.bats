#!/usr/bin/env bats
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0

load 'test_helper/common-setup'

setup() {
    _common_setup
    setup_temp_repo
}

teardown() {
    teardown_temp_repo
}

@test "git-tag: smoke — missing argument prints usage and exits 1" {
    run "${GIT_TAG_SH}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"git-tag"* ]]
}
