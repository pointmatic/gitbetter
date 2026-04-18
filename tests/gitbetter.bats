#!/usr/bin/env bats
# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0

load 'test_helper/common-setup'

setup() {
    _common_setup
    # gitbetter is a pure info command — no git repo needed.
    TMP_ROOT="$(mktemp -d)"
    export TMP_ROOT
    cd "${TMP_ROOT}"
}

teardown() {
    teardown_temp_repo
}

# ── No args → help ──────────────────────────────────────────

@test "gitbetter: no args prints help and exits 0" {
    run "${GITBETTER_SH}"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"Commands:"* ]]
    [[ "${output}" == *"git-push"* ]]
    [[ "${output}" == *"git-tag"* ]]
    [[ "${output}" == *"Homepage:"* ]]
}

# ── --help ──────────────────────────────────────────────────

@test "gitbetter: --help prints help and exits 0" {
    run "${GITBETTER_SH}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"Commands:"* ]]
    [[ "${output}" == *"Homepage:"* ]]
}

# ── --version ───────────────────────────────────────────────

@test "gitbetter: --version prints version and homepage, exits 0" {
    run "${GITBETTER_SH}" --version
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"gitbetter v1.3.0"* ]]
    [[ "${output}" == *"https://github.com/pointmatic/gitbetter"* ]]
}

# ── Unknown flag ────────────────────────────────────────────

@test "gitbetter: unknown flag exits 1 with error on stderr" {
    run "${GITBETTER_SH}" --bogus
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"unknown argument"* ]]
}
