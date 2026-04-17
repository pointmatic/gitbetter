#!/usr/bin/env bash
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# ──────────────────────────────────────────────────────────────
#  spike-tag.sh — throwaway end-to-end test for git-tag.sh
#
#  Creates a temp repo with a bare remote, runs git-tag.sh,
#  and verifies the tag exists on the remote.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_TAG="${SCRIPT_DIR}/git-tag.sh"

BOLD=$'\033[1m'
DIM=$'\033[2m'
G=$'\033[0;32m'
R=$'\033[0;31m'
RESET=$'\033[0m'

pass() { echo -e "  ${G}✔${RESET} $1"; }
fail() { echo -e "\n  ${R}✘${RESET} ${R}$1${RESET}\n"; exit 1; }

echo ""
echo -e "  ${BOLD}spike-tag.sh${RESET} — end-to-end tag flow"
echo -e "  ${DIM}─────────────────────────────────────────${RESET}"

# ── Set up temp directory ────────────────────────────────────
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMPDIR_ROOT}"' EXIT

BARE_REPO="${TMPDIR_ROOT}/remote.git"
WORK_REPO="${TMPDIR_ROOT}/work"

# ── Create bare remote ──────────────────────────────────────
echo ""
echo -e "  ${DIM}Creating bare remote...${RESET}"
git init --bare "${BARE_REPO}" >/dev/null 2>&1
pass "Bare remote created at ${DIM}${BARE_REPO}${RESET}"

# ── Create working repo ─────────────────────────────────────
echo -e "  ${DIM}Creating working repo...${RESET}"
git init "${WORK_REPO}" >/dev/null 2>&1
cd "${WORK_REPO}"
git config user.email "spike@test.local"
git config user.name "Spike Test"
git remote add origin "${BARE_REPO}"
pass "Working repo created at ${DIM}${WORK_REPO}${RESET}"

# ── Add a dummy commit ──────────────────────────────────────
echo -e "  ${DIM}Adding dummy commit...${RESET}"
echo "hello" > README.md
git add -A
git commit -m "initial commit" >/dev/null 2>&1
git push origin main >/dev/null 2>&1
pass "Dummy commit pushed to remote"

# ── Run git-tag.sh ───────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Running:${RESET} ${DIM}${GIT_TAG} v0.0.1${RESET}"
echo -e "  ${DIM}(auto-confirming with 'y')${RESET}"
echo ""

echo "y" | "${GIT_TAG}" v0.0.1

# ── Verify tag on remote ────────────────────────────────────
echo ""
echo -e "  ${DIM}Verifying tag on remote...${RESET}"
REMOTE_TAGS="$(git ls-remote --tags origin 2>/dev/null)"

if echo "${REMOTE_TAGS}" | grep -q "refs/tags/v0.0.1"; then
    pass "Tag ${G}v0.0.1${RESET} exists on remote"
else
    fail "Tag v0.0.1 NOT found on remote. Remote tags: ${REMOTE_TAGS}"
fi

echo ""
echo -e "  ${G}${BOLD}Spike passed!${RESET} End-to-end tag flow works."
echo ""
