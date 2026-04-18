#!/usr/bin/env bash
# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# ──────────────────────────────────────────────────────────────
#  git-push — streamlined commit & push for direct-to-main
#             and branch-PR workflows
#
#  Usage:  git-push [--amend] [--keep|-k] "commit message" [branch_name]
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Shared UI Library ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/ui.sh
source "${SCRIPT_DIR}/lib/ui.sh"

print_help() {
    cat <<EOF
git-push — streamlined commit & push for direct-to-main and branch-PR workflows

Usage:
  git-push [--amend] [--keep|-k] "commit message" [branch_name]
  git-push --help
  git-push --version

Options:
  --amend       Replace the last commit with the new message; force-pushes safely with --force-with-lease
  --keep, -k    Skip the post-push cleanup prompt and leave the branch intact
                (for multi-commit feature branches)
  --help        Show this help and exit
  --version     Show version and exit

Examples:
  git-push "fix: typo"
  git-push "feat: new thing" feature-xyz
  git-push --amend "updated message"
  git-push "wip" feature-xyz --keep

Homepage: ${GITBETTER_HOMEPAGE}
EOF
}

# ── Meta Flags (handled before any git work) ─────────────────
case "${1:-}" in
    --help)    print_help;                 exit 0 ;;
    --version) print_version "git-push";   exit 0 ;;
esac

# ── Validate Environment ────────────────────────────────────
git rev-parse --is-inside-work-tree &>/dev/null \
    || fail "Not inside a git repository."

# ── Parse Arguments ──────────────────────────────────────────
AMEND=false
KEEP=false
POSITIONAL=()

for arg in "$@"; do
    case "${arg}" in
        --amend)    AMEND=true ;;
        --keep|-k)  KEEP=true ;;
        *)          POSITIONAL+=("${arg}") ;;
    esac
done

[[ ${#POSITIONAL[@]} -lt 1 ]] && {
    echo -e "\n  ${BOLD}Usage:${RESET}  git-push ${DIM}[--amend] [--keep|-k]${RESET} ${C}\"commit message\"${RESET} ${DIM}[branch_name]${RESET}\n"
    exit 1
}

# Sanitise commit message: strip backticks, convert " → '
COMMIT_MSG="${POSITIONAL[0]}"
COMMIT_MSG="${COMMIT_MSG//\`/}"
COMMIT_MSG="${COMMIT_MSG//\"/\'}"
[[ -z "${COMMIT_MSG}" ]] && fail "Commit message cannot be empty after sanitisation."

BRANCH_NAME="${POSITIONAL[1]:-}"

# ── Summary Banner ─────────────────────────────────────
echo ""
header_box "git-push"
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

# ── Step 2.5 · Remote Divergence Check ──────────────────────
# Read-only fetch + ahead/behind detection. Never auto-pulls.
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -n "${UPSTREAM}" ]]; then
    banner "Remote Check"
    # shellcheck disable=SC2119  # intentional no-args call
    if fetch_quiet_or_warn; then
        # rev-list --count outputs "<ahead>\t<behind>"
        COUNTS="$(git rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null || echo "0	0")"
        AHEAD="$(echo "${COUNTS}" | cut -f1)"
        BEHIND="$(echo "${COUNTS}" | cut -f2)"
        if [[ "${BEHIND}" -gt 0 ]]; then
            echo ""
            if ${AMEND}; then
                warn "Amend + remote-ahead: ${M}${UPSTREAM}${RESET} has ${Y}${BEHIND}${RESET} new commit(s) you don't have locally."
                info "${DIM}--force-with-lease${RESET} will overwrite based on your local view, but you"
                info "haven't seen the remote's new commits. This is ${Y}almost certainly not${RESET}"
                info "what you want."
                info "Consider: ${DIM}git pull --rebase${RESET}  (then re-run git-push --amend)"
            else
                warn "Remote ${M}${UPSTREAM}${RESET} has ${Y}${BEHIND}${RESET} new commit(s) you don't have locally."
                info "Consider: ${DIM}git pull --rebase${RESET}  (then re-run git-push)"
            fi
            if ! ask_yn "Push anyway?"; then
                echo -e "\n  ${DIM}Aborted.${RESET}\n"
                exit 0
            fi
        else
            if [[ "${AHEAD}" -gt 0 ]]; then
                info "${AHEAD} commit(s) ahead of ${M}${UPSTREAM}${RESET} — ready to push."
            else
                info "Up to date with ${M}${UPSTREAM}${RESET}."
            fi
        fi
    fi
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

# ── Step 7 · Branch Workflow ─────────────────────────────────
# Only applies on non-main branches. Single ask_yn (default no = keep)
# replaces the old two-step wait-for-CI → delete-branch prompts.
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    divider
    banner "Branch Workflow"

    # Parse GitHub remote once; reuse for Actions + Compare URLs.
    REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
    ACTIONS_URL=""
    COMPARE_URL=""
    if [[ "${REMOTE_URL}" =~ github\.com[:/](.+)(\.git)?$ ]]; then
        REPO_PATH="${BASH_REMATCH[1]}"
        REPO_PATH="${REPO_PATH%.git}"
        ACTIONS_URL="https://github.com/${REPO_PATH}/actions"
        COMPARE_URL="https://github.com/${REPO_PATH}/compare/${CURRENT_BRANCH}"
    fi

    info "${BOLD}Branch:${RESET}   ${M}${CURRENT_BRANCH}${RESET}"
    if [[ -n "${ACTIONS_URL}" ]]; then
        info "${BOLD}Actions:${RESET}  ${DIM}${ACTIONS_URL}${RESET}"
        info "${BOLD}Compare:${RESET}  ${DIM}${COMPARE_URL}${RESET}"
    fi
    echo ""

    if ${KEEP}; then
        info "Keeping ${M}${CURRENT_BRANCH}${RESET}. Next push will continue on it."
    elif ask_yn "Merge complete? Clean up (switch to main, pull, delete branch)?"; then
        banner "Cleanup"
        run_cmd git switch main
        run_cmd git fetch --prune
        run_cmd git pull --ff-only
        run_cmd git branch -D "${CURRENT_BRANCH}"
        echo ""
        success "Branch ${M}${CURRENT_BRANCH}${RESET} deleted. You're on ${M}main${RESET} with latest."
    else
        info "Keeping ${M}${CURRENT_BRANCH}${RESET}. Next push will continue on it."
    fi
fi

# ── Done ─────────────────────────────────────────────────────
banner "Latest Commit"
echo ""
git --no-pager log -1 --color=always \
    --format="  %C(dim)%h%C(reset)  %s  %C(dim)(%ar by %an)%C(reset)" 2>/dev/null
echo ""
footer_box
echo ""
