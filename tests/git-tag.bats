#!/usr/bin/env bats
# Copyright (c) 2026 Pointmatic
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
    [[ "${output}" == *"gitbetter git-tag v1.5.0"* ]]
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

# ── Remote-awareness (D.e) ──────────────────────────────────

@test "git-tag: remote-existing tag is rejected before any prompt" {
    git push -q -u origin main
    tag_on_remote v9.9.9
    run "${GIT_TAG_SH}" v9.9.9
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"already exists on remote"* ]]
    # Tag must not be created locally either
    run git tag -l v9.9.9
    [ -z "${output}" ]
}

@test "git-tag: remote reachable, tag novel → existing behavior (proceeds to prompt)" {
    git push -q -u origin main
    run bash -c "echo n | '${GIT_TAG_SH}' v0.0.1"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Aborted."* ]]
    [[ "${output}" != *"already exists on remote"* ]]
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

# ── --prefix flag (E.c) ─────────────────────────────────────

@test "git-tag --prefix: creates and pushes prefixed tag (flag after semver)" {
    run bash -c "echo y | '${GIT_TAG_SH}' v1.0.0 --prefix npm"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"npm-v1.0.0"* ]]
    [[ "${output}" == *"All done."* ]]
    run git tag -l 'npm-v1.0.0'
    [ "${output}" = "npm-v1.0.0" ]
    run git tag -l 'v1.0.0'
    [ "${output}" = "" ]
    run git ls-remote --tags origin
    [[ "${output}" == *"refs/tags/npm-v1.0.0"* ]]
}

@test "git-tag --prefix: flag before semver produces same result" {
    run bash -c "echo y | '${GIT_TAG_SH}' --prefix ios v1.0.0"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"ios-v1.0.0"* ]]
    run git tag -l 'ios-v1.0.0'
    [ "${output}" = "ios-v1.0.0" ]
}

@test "git-tag --prefix: with branch arg, push includes branch" {
    run bash -c "echo y | '${GIT_TAG_SH}' v1.0.0 main --prefix backend"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"backend-v1.0.0"* ]]
    run git tag -l 'backend-v1.0.0'
    [ "${output}" = "backend-v1.0.0" ]
}

@test "git-tag --prefix: missing value exits 1 with error" {
    run bash -c "'${GIT_TAG_SH}' v1.0.0 --prefix"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"--prefix requires a value"* ]]
}

@test "git-tag --prefix: invalid characters exit 1 with error" {
    run bash -c "'${GIT_TAG_SH}' v1.0.0 --prefix 'bad name'"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Invalid prefix"* ]]
}

@test "git-tag --prefix: remote duplicate check uses full prefixed tag" {
    git push -q -u origin main
    tag_on_remote "npm-v1.0.0"
    run bash -c "'${GIT_TAG_SH}' v1.0.0 --prefix npm"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"npm-v1.0.0"* ]]
    [[ "${output}" == *"already exists on remote"* ]]
}

@test "git-tag --prefix: latest-tag display scoped to prefix family" {
    git tag npm-v0.9.0
    git tag v2.0.0
    run bash -c "echo n | '${GIT_TAG_SH}' v1.0.0 --prefix npm"
    [[ "${output}" == *"Latest (npm-v*):"* ]]
    [[ "${output}" == *"npm-v0.9.0"* ]]
    [[ "${output}" != *"v2.0.0"* ]]
}

@test "git-tag --help: output contains --prefix and updated usage" {
    run bash -c "'${GIT_TAG_SH}' --help"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"--prefix"* ]]
    [[ "${output}" == *"NAME-"* ]]
    [[ "${output}" == *"[--prefix NAME]"* ]]
}
