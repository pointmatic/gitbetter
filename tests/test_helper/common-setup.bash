#!/usr/bin/env bash
# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0
#
# Shared BATS setup/teardown helpers for gitbetter tests.
#
# Each test gets an isolated temp directory with a fresh git repo.
# Optionally, `setup_bare_remote` creates a local bare repo and wires it
# up as `origin` for push-related tests.

# Resolve repo root (two levels up from this file: tests/test_helper/..)
_common_setup() {
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    GIT_TAG_SH="${REPO_ROOT}/git-tag.sh"
    GIT_PUSH_SH="${REPO_ROOT}/git-push.sh"
    GITBETTER_SH="${REPO_ROOT}/gitbetter.sh"
    export REPO_ROOT GIT_TAG_SH GIT_PUSH_SH GITBETTER_SH
}

# Create an isolated temp working repo and cd into it.
setup_temp_repo() {
    TMP_ROOT="$(mktemp -d)"
    export TMP_ROOT
    cd "${TMP_ROOT}"
    git init -q -b main 2>/dev/null || git init -q
    git config user.email "test@gitbetter.local"
    git config user.name "Test User"
    git config commit.gpgsign false
}

# Create a bare remote and wire it up as origin.
#
# The bare is initialized with `-b main` so its HEAD symbolic ref
# matches the local default branch. Without this, on hosts whose
# `init.defaultBranch` is still `master` (e.g. stock Ubuntu CI),
# sibling clones of this bare emit "remote HEAD refers to nonexistent
# ref" and fail to check out a working tree — breaking any helper that
# commits or tags from a clone. Falls back to plain `init --bare` on
# git < 2.28 (which doesn't support `-b` on init).
setup_bare_remote() {
    local bare="${TMP_ROOT}/remote.git"
    git init --bare -q -b main "${bare}" 2>/dev/null || git init --bare -q "${bare}"
    git remote add origin "${bare}"
    export BARE_REMOTE="${bare}"
}

# Add a dummy commit (needed before tagging or pushing).
add_dummy_commit() {
    echo "hello" > README.md
    git add -A
    git commit -q -m "initial commit"
}

# Remove the temp directory.
teardown_temp_repo() {
    if [[ -n "${TMP_ROOT:-}" && -d "${TMP_ROOT}" ]]; then
        rm -rf "${TMP_ROOT}"
    fi
}

# Make the bare remote one commit ahead of the current local branch by
# cloning, committing, and pushing from a sibling working copy. The
# current working directory (main test repo) is unchanged.
#
# Requires: setup_bare_remote to have been called and at least one
# commit pushed to origin already (so the clone is non-empty).
make_remote_ahead() {
    local extra="${TMP_ROOT}/extra_ahead"
    local here
    here="$(pwd)"
    git clone -q "${BARE_REMOTE}" "${extra}"
    (
        cd "${extra}"
        git config user.email "test@gitbetter.local"
        git config user.name "Test User"
        git config commit.gpgsign false
        echo "remote-only" > remote-only.txt
        git add -A
        git commit -q -m "commit only on remote"
        git push -q origin HEAD
    )
    cd "${here}"
}

# Push an arbitrary tag to the bare remote from a sibling clone without
# creating the tag locally in the main test repo.
#
# Requires: setup_bare_remote and at least one commit pushed to origin.
tag_on_remote() {
    local tag="$1"
    local extra="${TMP_ROOT}/extra_tag_${tag}"
    local here
    here="$(pwd)"
    git clone -q "${BARE_REMOTE}" "${extra}"
    (
        cd "${extra}"
        git config user.email "test@gitbetter.local"
        git config user.name "Test User"
        git config commit.gpgsign false
        git tag "${tag}"
        git push -q origin "${tag}"
    )
    cd "${here}"
}
