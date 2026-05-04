#!/usr/bin/env bash
# Copyright (c) 2026 Pointmatic
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

print_help() {
    cat <<EOF
git-tag — validate a semver tag, create it, and push to origin

Usage:
  git-tag [--prefix NAME] vX.Y.Z [branch_name]
  git-tag --help
  git-tag --version

Options:
  --prefix NAME Prepend NAME- to the tag (e.g., --prefix npm → npm-v1.0.0).
                NAME must match [a-zA-Z0-9][a-zA-Z0-9._-]*
  --help        Show this help and exit
  --version     Show version and exit

Examples:
  git-tag v1.0.0
  git-tag v1.2.3 main
  git-tag v2.1.1 --prefix npm
  git-tag v1.0.0 main --prefix ios

Homepage: ${GITBETTER_HOMEPAGE}
EOF
}

# ── Meta Flags (handled before any git work) ─────────────────
case "${1:-}" in
    --help)    print_help;                exit 0 ;;
    --version) print_version "git-tag";   exit 0 ;;
esac

# ── Parse Arguments ──────────────────────────────────────────
PREFIX=""
TAG=""
BRANCH_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)
            [[ -z "${2:-}" || "${2:-}" == --* ]] \
                && { echo -e "\n  ${CROSS} ${R}--prefix requires a value.${RESET}\n"; exit 1; }
            PREFIX="$2"
            shift 2
            ;;
        --*)
            echo -e "\n  ${CROSS} ${R}Unknown flag: $1${RESET}\n"
            exit 1
            ;;
        *)
            if [[ -z "${TAG}" ]]; then
                TAG="$1"
            elif [[ -z "${BRANCH_NAME}" ]]; then
                BRANCH_NAME="$1"
            else
                echo -e "\n  ${CROSS} ${R}Unexpected argument: $1${RESET}\n"
                exit 1
            fi
            shift
            ;;
    esac
done

[[ -z "${TAG}" ]] && {
    echo -e "\n  ${BOLD}Usage:${RESET}  git-tag ${C}[--prefix NAME] \"vX.Y.Z\"${RESET} ${DIM}[branch_name]${RESET}\n"
    exit 1
}

# ── Validate Prefix (if given) ──────────────────────────────
if [[ -n "${PREFIX}" ]]; then
    PREFIX_RE='^[a-zA-Z0-9][a-zA-Z0-9._-]*$'
    if [[ ! "${PREFIX}" =~ ${PREFIX_RE} ]]; then
        echo -e "\n  ${CROSS} ${R}Invalid prefix '${PREFIX}'.${RESET}"
        echo -e "  ${DIM}Allowed: alphanumeric start, then [a-zA-Z0-9._-] (e.g., npm, ios, my-app)${RESET}\n"
        exit 1
    fi
fi

# ── Validate Tag Format ─────────────────────────────────────
SEMVER_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'
if [[ ! "${TAG}" =~ ${SEMVER_RE} ]]; then
    echo -e "\n  ${CROSS} ${R}Invalid tag format:${RESET} ${BOLD}${TAG}${RESET}"
    echo -e "  ${DIM}Expected format: ${RESET}${C}vX.Y.Z${RESET} ${DIM}(e.g., v1.0.0, v0.2.3, v10.20.30)${RESET}\n"
    exit 1
fi

# ── Derive Full Tag Name ─────────────────────────────────────
if [[ -n "${PREFIX}" ]]; then
    FULL_TAG="${PREFIX}-${TAG}"
else
    FULL_TAG="${TAG}"
fi

# ── Validate Environment ────────────────────────────────────
git rev-parse --is-inside-work-tree &>/dev/null \
    || fail "Not inside a git repository."

# ── Duplicate Tag Check ─────────────────────────────────────
if [[ -n "$(git tag -l "${FULL_TAG}")" ]]; then
    fail "Tag ${BOLD}${FULL_TAG}${RESET}${R} already exists locally."
fi

# ── Remote Tag Check ─────────────────────────────────────────
# Read-only probe: `ls-remote` queries the remote without mutating
# any local refs (unlike `fetch --tags`, which would create local
# copies of every remote tag). If origin is unreachable, ls-remote
# fails silently and we proceed — offline is not fatal here.
if git remote get-url origin &>/dev/null; then
    if git ls-remote --tags origin "refs/tags/${FULL_TAG}" 2>/dev/null | grep -q .; then
        fail "Tag ${BOLD}${FULL_TAG}${RESET}${R} already exists on remote ${BOLD}origin${RESET}${R}. Refusing to overwrite."
    fi
fi

# ── Find Latest Tag (numeric sort, scoped to prefix family) ─
# Strip prefix and leading 'v', sort numerically, re-prepend.
LATEST_TAG=""
if [[ -n "${PREFIX}" ]]; then
    ALL_TAGS="$(git tag -l "${PREFIX}-v*" 2>/dev/null || true)"
    if [[ -n "${ALL_TAGS}" ]]; then
        LATEST_TAG="$(echo "${ALL_TAGS}" \
            | sed "s/^${PREFIX}-v//" \
            | sort -t. -k1,1n -k2,2n -k3,3n \
            | tail -n 1 \
            | sed "s/^/${PREFIX}-v/")"
    fi
else
    ALL_TAGS="$(git tag -l 'v*' 2>/dev/null || true)"
    if [[ -n "${ALL_TAGS}" ]]; then
        LATEST_TAG="$(echo "${ALL_TAGS}" \
            | sed 's/^v//' \
            | sort -t. -k1,1n -k2,2n -k3,3n \
            | tail -n 1 \
            | sed 's/^/v/')"
    fi
fi

# ── Summary Banner ─────────────────────────────────────
echo ""
header_box "git-tag"
echo ""
info "${BOLD}New tag:${RESET}  ${G}${FULL_TAG}${RESET}"
if [[ -n "${LATEST_TAG}" ]]; then
    if [[ -n "${PREFIX}" ]]; then
        info "${BOLD}Latest (${PREFIX}-v*):${RESET}  ${M}${LATEST_TAG}${RESET}"
    else
        info "${BOLD}Latest:${RESET}   ${M}${LATEST_TAG}${RESET}"
    fi
else
    info "${BOLD}Latest:${RESET}   ${DIM}(no tags found)${RESET}"
fi

# ── Create & Push Tag ────────────────────────────────────────
confirm "Create and push tag ${FULL_TAG} to origin?"

banner "Tag"
run_cmd git tag "${FULL_TAG}"
success "Tag ${G}${FULL_TAG}${RESET} created."

banner "Push"
if [[ -n "${BRANCH_NAME}" ]]; then
    run_cmd git push origin "${FULL_TAG}" "${BRANCH_NAME}"
else
    run_cmd git push origin "${FULL_TAG}"
fi
success "Tag ${G}${FULL_TAG}${RESET} pushed to origin."

# ── Outcome Proof ───────────────────────────────────────────
banner "New Tag"
echo ""
git --no-pager show --no-patch --color=always \
    --format="  %C(dim)%h%C(reset)  %C(green)%D%C(reset)  %s  %C(dim)(%ar by %an)%C(reset)" \
    "${FULL_TAG}" 2>/dev/null || info "${G}${FULL_TAG}${RESET}"
echo ""

# ── Done ─────────────────────────────────────────────────────
echo ""
footer_box
echo ""
