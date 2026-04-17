#!/usr/bin/env bash
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# ──────────────────────────────────────────────────────────────
#  git-push — streamlined commit & push for direct-to-main
#             and branch-PR workflows
#
#  Usage:  git-push [--amend] "commit message" [branch_name]
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

# ── Validate Environment ────────────────────────────────────
git rev-parse --is-inside-work-tree &>/dev/null \
    || fail "Not inside a git repository."

# ── Parse Arguments ──────────────────────────────────────────
AMEND=false
POSITIONAL=()

for arg in "$@"; do
    case "${arg}" in
        --amend) AMEND=true ;;
        *)       POSITIONAL+=("${arg}") ;;
    esac
done

[[ ${#POSITIONAL[@]} -lt 1 ]] && {
    echo -e "\n  ${BOLD}Usage:${RESET}  git-push ${DIM}[--amend]${RESET} ${C}\"commit message\"${RESET} ${DIM}[branch_name]${RESET}\n"
    exit 1
}

# Sanitise commit message: strip backticks, convert " → '
COMMIT_MSG="${POSITIONAL[0]}"
COMMIT_MSG="${COMMIT_MSG//\`/}"
COMMIT_MSG="${COMMIT_MSG//\"/\'}"
[[ -z "${COMMIT_MSG}" ]] && fail "Commit message cannot be empty after sanitisation."

BRANCH_NAME="${POSITIONAL[1]:-}"

# ── Summary Banner ───────────────────────────────────────────
echo ""
echo -e "  ${BOLD}${C}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${C}│${RESET}  ${BOLD}git-push${RESET}                               ${BOLD}${C}│${RESET}"
echo -e "  ${BOLD}${C}╰─────────────────────────────────────────╯${RESET}"
echo ""
info "${BOLD}Message:${RESET}  ${G}${COMMIT_MSG}${RESET}"
if ${AMEND}; then
    info "${BOLD}Mode:${RESET}     ${Y}amend${RESET}  ${DIM}(replaces last commit, force-pushes)${RESET}"
fi
if [[ -n "${BRANCH_NAME}" ]]; then
    info "${BOLD}Branch:${RESET}   ${M}${BRANCH_NAME}${RESET}  ${DIM}(branch → PR workflow)${RESET}"
else
    info "${BOLD}Branch:${RESET}   ${DIM}(current branch — direct push)${RESET}"
fi

# ── Step 1 · Show Recent Commit ─────────────────────────────
if ${AMEND}; then
    banner "Commit To Amend"
else
    banner "Last Commit"
fi
echo ""
git --no-pager log -1 --color=always \
    --format="  %C(dim)%h%C(reset)  %s  %C(dim)(%ar by %an)%C(reset)" 2>/dev/null \
    || warn "No commits yet in this repository."
if ${AMEND}; then
    echo ""
    warn "This commit will be ${Y}replaced${RESET} with your new message."
fi
echo ""

confirm "Does this look right? Continue"

# ── Step 2 · Branch Switch (if needed) ──────────────────────
CURRENT_BRANCH="$(git symbolic-ref --short HEAD)"

if [[ -n "${BRANCH_NAME}" && "${CURRENT_BRANCH}" != "${BRANCH_NAME}" ]]; then
    banner "Switch Branch"
    if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
        info "Local branch ${M}${BRANCH_NAME}${RESET} exists — switching."
        run_cmd git switch "${BRANCH_NAME}"
    else
        info "Creating new branch ${M}${BRANCH_NAME}${RESET}."
        run_cmd git switch -c "${BRANCH_NAME}"
    fi
    success "Now on ${M}${BRANCH_NAME}${RESET}"
    CURRENT_BRANCH="${BRANCH_NAME}"
else
    if [[ -n "${BRANCH_NAME}" ]]; then
        info "Already on ${M}${BRANCH_NAME}${RESET} — no switch needed."
    fi
    CURRENT_BRANCH="$(git symbolic-ref --short HEAD)"
fi

# ── Step 3 · Review Working Tree ────────────────────────────
banner "Working Tree"
echo ""
run_cmd git status --short
echo ""

confirm "Stage all changes"

# ── Step 4 · Stage ───────────────────────────────────────────
banner "Staging"
run_cmd git add -A
echo ""
run_cmd git status --short
echo ""

confirm "Commit these changes"

# ── Step 5 · Commit ──────────────────────────────────────────
banner "Commit"
if ${AMEND}; then
    if run_cmd git commit --amend -m "${COMMIT_MSG}"; then
        success "Amended."
    else
        fail "Amend failed."
    fi
else
    if run_cmd git commit -m "${COMMIT_MSG}"; then
        success "Committed."
    else
        fail "Commit failed (nothing to commit?)."
    fi
fi

# ── Step 5.5 · Post-Commit Dirty-Tree Check ─────────────────
DIRTY="$(git status --porcelain)"
if [[ -n "${DIRTY}" ]]; then
    echo ""
    warn "Working tree is ${Y}still dirty${RESET} after commit."
    info "Likely cause: a pre-commit hook reformatted files."
    echo ""
    echo -e "${DIM}${DIRTY}${RESET}"
    echo ""
    if ask_yn "Fold these changes into the commit via --amend?"; then
        run_cmd git add -A
        run_cmd git commit --amend --no-edit
        success "Folded into commit."
        # Force amend mode so the push step uses --force-with-lease
        AMEND=true
    else
        warn "Proceeding with current commit — dirty files will not be pushed."
    fi
fi

# ── Step 6 · Push ────────────────────────────────────────────
banner "Push"
info "Pushing ${M}${CURRENT_BRANCH}${RESET} → ${DIM}origin/${CURRENT_BRANCH}${RESET}"
echo ""

if ${AMEND}; then
    info "Amend mode → using ${DIM}--force-with-lease${RESET} automatically."
    echo ""
    if run_cmd git push --force-with-lease origin "${CURRENT_BRANCH}"; then
        success "Force-pushed successfully."
    else
        fail "Force-push failed — resolve manually."
    fi
else
    if run_cmd git push origin "${CURRENT_BRANCH}"; then
        success "Pushed successfully."
    else
        warn "Push was rejected."
        if ask_yn "Retry with --force-with-lease? (safe force push)"; then
            run_cmd git push --force-with-lease origin "${CURRENT_BRANCH}"
            success "Force-pushed successfully."
        else
            fail "Push failed — resolve manually."
        fi
    fi
fi

# ── Step 7 · Branch PR Workflow (cleanup) ────────────────────
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    divider
    echo ""
    info "${BOLD}Branch PR Workflow${RESET}"
    info "You're on ${M}${CURRENT_BRANCH}${RESET}, not ${M}main${RESET}."
    info "Next steps: open a PR on GitHub, wait for CI, merge."

    # Try to build the Actions URL
    REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
    ACTIONS_URL=""
    if [[ "${REMOTE_URL}" =~ github\.com[:/](.+)(\.git)?$ ]]; then
        REPO_PATH="${BASH_REMATCH[1]}"
        REPO_PATH="${REPO_PATH%.git}"
        ACTIONS_URL="https://github.com/${REPO_PATH}/actions"
    fi

    if ask_yn "Wait for GitHub Actions / CI to pass?"; then
        if [[ -n "${ACTIONS_URL}" ]]; then
            info "Actions: ${DIM}${ACTIONS_URL}${RESET}"
            # Attempt to open in browser (macOS / Linux)
            if command -v open &>/dev/null; then
                open "${ACTIONS_URL}" 2>/dev/null || true
            elif command -v xdg-open &>/dev/null; then
                xdg-open "${ACTIONS_URL}" 2>/dev/null || true
            fi
        fi
        echo ""
        echo -e "  ${DIM}Press Enter when ready to continue…${RESET}"
        read -r

        if ask_yn "Delete ${M}${CURRENT_BRANCH}${RESET} and pull latest main?"; then
            banner "Cleanup"
            run_cmd git switch main
            run_cmd git fetch --prune
            run_cmd git pull
            run_cmd git branch -D "${CURRENT_BRANCH}"
            echo ""
            success "Branch ${M}${CURRENT_BRANCH}${RESET} deleted. You're on ${M}main${RESET} with latest."
        fi
    fi
fi

# ── Done ─────────────────────────────────────────────────────
banner "Latest Commit"
echo ""
git --no-pager log -1 --color=always \
    --format="  %C(dim)%h%C(reset)  %s  %C(dim)(%ar by %an)%C(reset)" 2>/dev/null
echo ""
echo -e "  ${BOLD}${G}╭─────────────────────────────────────────╮${RESET}"
echo -e "  ${BOLD}${G}│${RESET}  ${CHECK} ${BOLD}All done.${RESET}                            ${BOLD}${G}│${RESET}"
echo -e "  ${BOLD}${G}╰─────────────────────────────────────────╯${RESET}"
echo ""
