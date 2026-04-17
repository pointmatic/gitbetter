#!/usr/bin/env bash
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# ──────────────────────────────────────────────────────────────
#  git-tag — validate a semver tag, create it, and push to origin
#
#  Usage:  git-tag "vX.Y.Z" [branch_name]
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Shared UI Library ────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/ui.sh
source "${SCRIPT_DIR}/lib/ui.sh"

# ── Parse Arguments ──────────────────────────────────────────
TAG="${1:-}"
BRANCH_NAME="${2:-}"

[[ -z "${TAG}" ]] && {
    echo -e "\n  ${BOLD}Usage:${RESET}  git-tag ${C}\"vX.Y.Z\"${RESET} ${DIM}[branch_name]${RESET}\n"
    exit 1
}

# ── Validate Tag Format ─────────────────────────────────────
SEMVER_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
if [[ ! "${TAG}" =~ ${SEMVER_RE} ]]; then
    echo -e "\n  ${CROSS} ${R}Invalid tag format:${RESET} ${BOLD}${TAG}${RESET}"
    echo -e "  ${DIM}Expected format: ${RESET}${C}vX.Y.Z${RESET} ${DIM}(e.g., v1.0.0, v0.2.3, v10.20.30)${RESET}\n"
    exit 1
fi

# ── Validate Environment ────────────────────────────────────
git rev-parse --is-inside-work-tree &>/dev/null \
    || fail "Not inside a git repository."

# ── Duplicate Tag Check ─────────────────────────────────────
if [[ -n "$(git tag -l "${TAG}")" ]]; then
    fail "Tag ${BOLD}${TAG}${RESET}${R} already exists locally."
fi

# ── Find Latest Tag (numeric sort) ──────────────────────────
# Strip leading 'v', sort numerically by major.minor.patch, re-prepend 'v'
LATEST_TAG=""
ALL_TAGS="$(git tag -l 'v*' 2>/dev/null || true)"
if [[ -n "${ALL_TAGS}" ]]; then
    LATEST_TAG="$(echo "${ALL_TAGS}" \
        | sed 's/^v//' \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -n 1 \
        | sed 's/^/v/')"
fi

# ── Summary Banner ─────────────────────────────────────
echo ""
header_box "git-tag"
echo ""
info "${BOLD}New tag:${RESET}  ${G}${TAG}${RESET}"
if [[ -n "${LATEST_TAG}" ]]; then
    info "${BOLD}Latest:${RESET}   ${M}${LATEST_TAG}${RESET}"
else
    info "${BOLD}Latest:${RESET}   ${DIM}(no tags found)${RESET}"
fi

# ── Create & Push Tag ────────────────────────────────────────
confirm "Create and push tag ${TAG} to origin?"

banner "Tag"
run_cmd git tag "${TAG}"
success "Tag ${G}${TAG}${RESET} created."

banner "Push"
if [[ -n "${BRANCH_NAME}" ]]; then
    run_cmd git push origin "${TAG}" "${BRANCH_NAME}"
else
    run_cmd git push origin "${TAG}"
fi
success "Tag ${G}${TAG}${RESET} pushed to origin."

# ── Outcome Proof ───────────────────────────────────────────
banner "New Tag"
echo ""
git --no-pager show --no-patch --color=always \
    --format="  %C(dim)%h%C(reset)  %C(green)%D%C(reset)  %s  %C(dim)(%ar by %an)%C(reset)" \
    "${TAG}" 2>/dev/null || info "${G}${TAG}${RESET}"
echo ""

# ── Done ─────────────────────────────────────────────────────
echo ""
footer_box
echo ""
