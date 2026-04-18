# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# shellcheck shell=bash
# Variables below are part of this library's public API — they
# are consumed by scripts that source this file, so shellcheck
# cannot see their usage when linting ui.sh on its own.
# shellcheck disable=SC2034
# ──────────────────────────────────────────────────────────────
#  lib/ui.sh — shared UI helpers, colors, and constants for
#              gitbetter command scripts.
#
#  Sourced, not executed. Do not add `set -euo pipefail` here —
#  the sourcing script sets its own shell options.
#
#  Usage (from a command script):
#      SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
#      # shellcheck source=lib/ui.sh
#      source "${SCRIPT_DIR}/lib/ui.sh"
# ──────────────────────────────────────────────────────────────

# ── Project Constants ────────────────────────────────────────
GITBETTER_VERSION="1.3.0"
GITBETTER_HOMEPAGE="https://github.com/pointmatic/gitbetter"

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

# ── Rounded-corner boxes ─────────────────────────────────────
# Internal box width is 41 visible chars (between │…│); content
# area after leading "  " is 39 chars, so pad with (39 - title_len) spaces.

header_box() {
    local title="$1"
    local pad_len=$(( 39 - ${#title} ))
    local pad
    printf -v pad '%*s' "${pad_len}" ""
    echo -e "  ${BOLD}${C}╭─────────────────────────────────────────╮${RESET}"
    echo -e "  ${BOLD}${C}│${RESET}  ${BOLD}${title}${RESET}${pad}${BOLD}${C}│${RESET}"
    echo -e "  ${BOLD}${C}╰─────────────────────────────────────────╯${RESET}"
}

footer_box() {
    echo -e "  ${BOLD}${G}╭─────────────────────────────────────────╮${RESET}"
    echo -e "  ${BOLD}${G}│${RESET}  ${CHECK} ${BOLD}All done.${RESET}                            ${BOLD}${G}│${RESET}"
    echo -e "  ${BOLD}${G}╰─────────────────────────────────────────╯${RESET}"
}

# ── Remote helpers ───────────────────────────────────────────
# Attempt a read-only `git fetch`. On failure (offline, auth,
# unreachable remote) warn and return non-zero so the caller can
# skip any divergence / staleness checks gracefully.
#
# Usage:
#   fetch_quiet_or_warn              # default fetch
#   fetch_quiet_or_warn --tags       # forward any args to git fetch
fetch_quiet_or_warn() {
    if git fetch --quiet "$@" 2>/dev/null; then
        return 0
    fi
    warn "Could not reach remote (offline?). Skipping divergence check."
    return 1
}

# ── Version printer ──────────────────────────────────────────
# Usage:
#   print_version               → "gitbetter v<VERSION>" + homepage
#   print_version "git-push"    → "gitbetter git-push v<VERSION>" + homepage
print_version() {
    local subcommand="${1:-}"
    if [[ -n "${subcommand}" ]]; then
        echo "gitbetter ${subcommand} v${GITBETTER_VERSION}"
    else
        echo "gitbetter v${GITBETTER_VERSION}"
    fi
    echo "${GITBETTER_HOMEPAGE}"
}
