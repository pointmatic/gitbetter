#!/usr/bin/env bash
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# ──────────────────────────────────────────────────────────────
#  git-tag — validate a semver tag, create it, and push to origin
#
#  Usage:  git-tag "vX.Y.Z" [branch_name]
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors & Symbols ─────────────────────────────────────────
R=$'\033[0;31m'   G=$'\033[0;32m'   Y=$'\033[0;33m'
B=$'\033[0;34m'   C=$'\033[0;36m'   M=$'\033[0;35m'
DIM=$'\033[2m'    BOLD=$'\033[1m'   RESET=$'\033[0m'
CHECK="${G}✔${RESET}"   CROSS="${R}✘${RESET}"   ARROW="${C}▸${RESET}"
WARN="${Y}⚠${RESET}"

# ── Helpers ──────────────────────────────────────────────────
banner()  { echo -e "\n${B}${BOLD}── $1 ──${RESET}"; }
info()    { echo -e "  ${ARROW} $1"; }
success() { echo -e "  ${CHECK} $1"; }
warn()    { echo -e "  ${WARN} $1"; }
fail()    { echo -e "\n  ${CROSS} ${R}$1${RESET}\n"; exit 1; }

# Prompt with default Y. Returns 0 for yes, exits for no.
confirm() {
    local prompt="${1:-Continue}"
    echo ""
    read -rp $'  \033[0;33m'"${prompt}"$' [Y/n]\033[0m ' answer
    answer="${answer:-y}"
    if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
        echo -e "\n  ${DIM}Aborted.${RESET}\n"
        exit 0
    fi
}

# Prompt with default N. Returns 0 for yes, 1 for no.
ask_yn() {
    local prompt="${1:-Proceed}"
    echo ""
    read -rp $'  \033[0;33m'"${prompt}"$' [y/N]\033[0m ' answer
    answer="${answer:-n}"
    [[ "${answer}" =~ ^[Yy]$ ]]
}

divider() { echo -e "  ${DIM}─────────────────────────────────────────${RESET}"; }

run_cmd() {
    echo -e "  ${DIM}\$ $*${RESET}"
    "$@"
}

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

# ── Summary Banner ───────────────────────────────────────────
echo ""
echo -e "  ${BOLD}${C}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${C}│${RESET}  ${BOLD}git-tag${RESET}                                ${BOLD}${C}│${RESET}"
echo -e "  ${BOLD}${C}╰─────────────────────────────────────────╯${RESET}"
echo ""
info "${BOLD}Tag:${RESET}  ${G}${TAG}${RESET}"

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

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}${G}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${G}│${RESET}  ${CHECK} ${BOLD}All done.${RESET}                            ${BOLD}${G}│${RESET}"
echo -e "  ${BOLD}${G}╰─────────────────────────────────────────╯${RESET}"
echo ""
