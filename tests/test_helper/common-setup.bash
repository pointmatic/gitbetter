#!/usr/bin/env bash
# Copyright (c) 2025 Pointmatic
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
setup_bare_remote() {
    local bare="${TMP_ROOT}/remote.git"
    git init --bare -q "${bare}"
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
