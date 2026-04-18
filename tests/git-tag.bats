#!/usr/bin/env bats
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0

load 'test_helper/common-setup'

setup() {
    _common_setup
    setup_temp_repo
    setup_bare_remote
    add_dummy_commit
}

teardown() {
    teardown_temp_repo
}

# ── Argument parsing ────────────────────────────────────────

@test "git-tag: missing tag argument prints usage and exits 1" {
    run "${GIT_TAG_SH}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"git-tag"* ]]
}

# ── Meta flags ──────────────────────────────────────────────

@test "git-tag: --help prints full help and exits 0" {
    run "${GIT_TAG_SH}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    [[ "${output}" == *"Examples:"* ]]
    [[ "${output}" == *"Homepage:"* ]]
}

@test "git-tag: --version prints version and homepage, exits 0" {
    run "${GIT_TAG_SH}" --version
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"gitbetter git-tag v1.1.0"* ]]
    [[ "${output}" == *"https://github.com/pointmatic/gitbetter"* ]]
}

@test "git-tag: --help works outside a git repo" {
    TMP_OUTSIDE="$(mktemp -d)"
    cd "${TMP_OUTSIDE}"
    run "${GIT_TAG_SH}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Usage:"* ]]
    rm -rf "${TMP_OUTSIDE}"
}

# ── Valid semver tags ───────────────────────────────────────

@test "git-tag: valid semver v0.0.1 accepted (proceeds past validation)" {
    run bash -c "echo n | '${GIT_TAG_SH}' v0.0.1"
    # confirm "n" path exits 0 with "Aborted." — validation passed
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Aborted."* ]]
    [[ "${output}" != *"Invalid tag format"* ]]
}

@test "git-tag: valid semver v1.0.0 accepted" {
    run bash -c "echo n | '${GIT_TAG_SH}' v1.0.0"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Aborted."* ]]
    [[ "${output}" != *"Invalid tag format"* ]]
}

@test "git-tag: valid semver v10.20.30 accepted" {
    run bash -c "echo n | '${GIT_TAG_SH}' v10.20.30"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Aborted."* ]]
    [[ "${output}" != *"Invalid tag format"* ]]
}

# ── Invalid semver tags ─────────────────────────────────────

@test "git-tag: invalid tag 1.0.0 (no v prefix) rejected" {
    run "${GIT_TAG_SH}" 1.0.0
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Invalid tag format"* ]]
}

@test "git-tag: invalid tag v1.0 (missing patch) rejected" {
    run "${GIT_TAG_SH}" v1.0
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Invalid tag format"* ]]
}

@test "git-tag: invalid tag v1.2.3.4 (too many parts) rejected" {
    run "${GIT_TAG_SH}" v1.2.3.4
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Invalid tag format"* ]]
}

@test "git-tag: invalid tag vabc (non-numeric) rejected" {
    run "${GIT_TAG_SH}" vabc
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Invalid tag format"* ]]
}

@test "git-tag: invalid tag v1.2.3-beta (pre-release suffix) rejected" {
    run "${GIT_TAG_SH}" v1.2.3-beta
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Invalid tag format"* ]]
}

# ── Duplicate tag detection ─────────────────────────────────

@test "git-tag: duplicate tag fails with 'already exists'" {
    git tag v1.0.0
    run "${GIT_TAG_SH}" v1.0.0
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"already exists"* ]]
}

# ── Latest tag display & numeric sort ───────────────────────

@test "git-tag: latest tag sorted numerically — v1.10.0 > v1.9.0" {
    git tag v1.0.0
    git tag v1.9.0
    git tag v1.10.0
    run bash -c "echo n | '${GIT_TAG_SH}' v2.0.0"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"v1.10.0"* ]]
    # v1.9.0 must not be shown as the "Latest:" value — assert v1.10.0
    # is the one rendered after "Latest:" (basic substring check is enough
    # given only v1.10.0 appears in output).
}

@test "git-tag: no tags exist — '(no tags found)' displayed, proceeds" {
    run bash -c "echo n | '${GIT_TAG_SH}' v0.1.0"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no tags found"* ]]
    [[ "${output}" == *"Aborted."* ]]
}

# ── End-to-end: create and push ─────────────────────────────

@test "git-tag: tag created and pushed to remote successfully" {
    run bash -c "echo y | '${GIT_TAG_SH}' v0.0.1"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"All done."* ]]
    # Verify tag exists locally
    run git tag -l v0.0.1
    [ "${output}" = "v0.0.1" ]
    # Verify tag exists on the bare remote
    run git ls-remote --tags origin
    [[ "${output}" == *"refs/tags/v0.0.1"* ]]
}
