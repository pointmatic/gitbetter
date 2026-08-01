#!/usr/bin/env bash
# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# ──────────────────────────────────────────────────────────────
#  git-commit — streamlined stage & commit for direct-to-main
#               and branch workflows (identical to git-push,
#               but never pushes)
#
#  Usage:  git-commit [--amend] [--keep|-k] "commit message" [branch_name]
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Shared UI Library ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/ui.sh
source "${SCRIPT_DIR}/lib/ui.sh"

print_help() {
    cat <<EOF
git-commit — streamlined stage & commit (identical to git-push, but never pushes)

Usage:
  git-commit [--amend] [--keep|-k] "commit message" [branch_name]
  git-commit --help
  git-commit --version

Options:
  --amend       Replace the last commit with the new message
  --keep, -k    Interface parity with git-push; affirms keeping the branch
                (git-commit has no post-push cleanup prompt to skip)
  --help        Show this help and exit
  --version     Show version and exit

Examples:
  git-commit "fix: typo"
  git-commit "feat: new thing" feature-xyz
  git-commit --amend "updated message"
  git-commit "wip" feature-xyz --keep

Why commit-only:
  Pushing on every commit burns GitHub Actions minutes. Most of what CI
  catches can be caught locally; the rest is a cheap cleanup step at the
  end of a release. Commit early and often with git-commit, then push in
  batches with git-push when you're ready.

Differences from git-push:
  - No push step — the commit stays local. Push later with git-push.
  - The remote divergence check is advisory only ("Commit anyway?").
  - No push-rejection recovery menu (nothing is pushed).
  - No branch cleanup prompt (cleanup requires a pushed, merged branch).

Homepage: ${GITBETTER_HOMEPAGE}
EOF
}

# ── Meta Flags (handled before any git work) ─────────────────
case "${1:-}" in
    --help)    print_help;                 exit 0 ;;
    --version) print_version "git-commit"; exit 0 ;;
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
    echo -e "\n  ${BOLD}Usage:${RESET}  git-commit ${DIM}[--amend] [--keep|-k]${RESET} ${C}\"commit message\"${RESET} ${DIM}[branch_name]${RESET}\n"
    exit 1
}

# Sanitise commit message: strip backticks, convert " → '
COMMIT_MSG="${POSITIONAL[0]}"
COMMIT_MSG="${COMMIT_MSG//\`/}"
COMMIT_MSG="${COMMIT_MSG//\"/\'}"
[[ -z "${COMMIT_MSG}" ]] && fail "Commit message cannot be empty after sanitisation."

BRANCH_NAME="${POSITIONAL[1]:-}"

# ── Project-Guide Exclusion Detection ───────────────────────
# When .project-guide.yml exists at the repo root, treat
# docs/project-guide/ as operational/dev artifacts and exclude it
# from every `git add -A` in this script via a pathspec. The marker
# gates the behavior so unrelated repos with a docs/project-guide
# directory are unaffected.
REPO_ROOT_PATH="$(git rev-parse --show-toplevel 2>/dev/null || true)"
PROJECT_GUIDE=false
# Always seed with `--` so the array is non-empty under set -u on Bash
# 4.0–4.3 (empty-array expansion was made safe only in 4.4). `git add
# -A --` with no following pathspec is equivalent to bare `git add -A`.
GIT_ADD_PATHSPEC=(--)
if [[ -n "${REPO_ROOT_PATH}" && -f "${REPO_ROOT_PATH}/.project-guide.yml" ]]; then
    PROJECT_GUIDE=true
    GIT_ADD_PATHSPEC=(-- ':/' ':(exclude,top)docs/project-guide')
fi

# ── Cleanup-Tombstone Path ──────────────────────────────────
# Branches deleted by gitbetter's cleanup flow get an entry here so
# we can warn before re-creating a branch with the same name later.
TOMBSTONE_FILE=""
GIT_DIR_PATH="$(git rev-parse --git-dir 2>/dev/null || true)"
if [[ -n "${GIT_DIR_PATH}" ]]; then
    TOMBSTONE_FILE="${GIT_DIR_PATH}/gitbetter-deleted-branches"
fi

# Echo the most recent tombstone date for $1, or empty if not present.
# Format per line: "<branch>\t<YYYY-MM-DD>".
tombstone_lookup() {
    local branch="$1"
    [[ -z "${TOMBSTONE_FILE}" || ! -f "${TOMBSTONE_FILE}" ]] && return 0
    awk -F '\t' -v b="${branch}" '$1 == b { d = $2 } END { if (d) print d }' \
        "${TOMBSTONE_FILE}"
}

# Strip every entry for $1 from the tombstone (a successful re-create
# clears past entries; a future cleanup writes a fresh one).
tombstone_remove() {
    local branch="$1"
    [[ -z "${TOMBSTONE_FILE}" || ! -f "${TOMBSTONE_FILE}" ]] && return 0
    local tmp
    tmp="$(mktemp -t gitbetter-tomb.XXXXXX)"
    awk -F '\t' -v b="${branch}" '$1 != b' "${TOMBSTONE_FILE}" > "${tmp}"
    mv "${tmp}" "${TOMBSTONE_FILE}"
}

# ── Summary Banner ─────────────────────────────────────
echo ""
header_box "git-commit"
echo ""
info "${BOLD}Message:${RESET}  ${G}${COMMIT_MSG}${RESET}"
if ${AMEND}; then
    info "${BOLD}Mode:${RESET}     ${Y}amend${RESET}  ${DIM}(replaces last commit)${RESET}"
fi
if [[ -n "${BRANCH_NAME}" ]]; then
    info "${BOLD}Branch:${RESET}   ${M}${BRANCH_NAME}${RESET}  ${DIM}(branch workflow)${RESET}"
else
    info "${BOLD}Branch:${RESET}   ${DIM}(current branch)${RESET}"
fi
info "${BOLD}Push:${RESET}     ${DIM}no — commit stays local (push later with git-push)${RESET}"

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
        TOMB_DATE="$(tombstone_lookup "${BRANCH_NAME}")"
        if [[ -n "${TOMB_DATE}" ]]; then
            echo ""
            warn "Branch ${M}${BRANCH_NAME}${RESET} was cleaned up by gitbetter on ${Y}${TOMB_DATE}${RESET}."
            info "Re-creating it from current HEAD produces a new branch reusing a retired name."
            info "If you meant to start fresh work, consider a different name."
            if ! ask_yn "Re-create ${BRANCH_NAME} from current HEAD?"; then
                echo -e "\n  ${DIM}Aborted.${RESET}\n"
                exit 0
            fi
            tombstone_remove "${BRANCH_NAME}"
        fi
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

# ── Step 2.5 · Remote Divergence Check (advisory) ───────────
# Read-only fetch + ahead/behind detection. Never auto-pulls.
# Unlike git-push, this is advisory: nothing is pushed, so a
# remote-ahead state only means you may want to rebase before
# piling on more local commits.
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
                info "Amending on top of a stale view makes the later rebase messier."
                info "Consider: ${DIM}git pull --rebase${RESET}  (then re-run git-commit --amend)"
            else
                warn "Remote ${M}${UPSTREAM}${RESET} has ${Y}${BEHIND}${RESET} new commit(s) you don't have locally."
                info "Consider: ${DIM}git pull --rebase${RESET}  (then re-run git-commit)"
            fi
            if ! ask_yn "Commit anyway?"; then
                echo -e "\n  ${DIM}Aborted.${RESET}\n"
                exit 0
            fi
        else
            if [[ "${AHEAD}" -gt 0 ]]; then
                info "${AHEAD} commit(s) ahead of ${M}${UPSTREAM}${RESET} — will push later with git-push."
            else
                info "Up to date with ${M}${UPSTREAM}${RESET}."
            fi
        fi
    fi
fi

# ── Step 3 · Review Working Tree ────────────────────────────
banner "Working Tree"
if ${PROJECT_GUIDE}; then
    info "Excluding ${M}docs/project-guide${RESET} ${DIM}(project-guide artifacts; .project-guide.yml detected)${RESET}"
fi
echo ""
run_cmd git status --short "${GIT_ADD_PATHSPEC[@]}"
echo ""

confirm "Stage all changes"

# ── Step 4 · Stage ───────────────────────────────────────────
banner "Staging"
run_cmd git add -A "${GIT_ADD_PATHSPEC[@]}"
echo ""
run_cmd git status --short "${GIT_ADD_PATHSPEC[@]}"
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
# Reuse the staging pathspec so docs/project-guide isn't reported as
# dirty when the marker file is present — it was deliberately excluded
# from `git add`, so seeing it here is expected, not a hook reformat.
DIRTY="$(git status --porcelain "${GIT_ADD_PATHSPEC[@]}")"
if [[ -n "${DIRTY}" ]]; then
    echo ""
    warn "Working tree is ${Y}still dirty${RESET} after commit."
    info "Likely cause: a pre-commit hook reformatted files."
    echo ""
    echo -e "${DIM}${DIRTY}${RESET}"
    echo ""
    if ask_yn "Fold these changes into the commit via --amend?"; then
        run_cmd git add -A "${GIT_ADD_PATHSPEC[@]}"
        run_cmd git commit --amend --no-edit
        success "Folded into commit."
    else
        warn "Proceeding with current commit — dirty files left uncommitted."
    fi
fi

# ── Step 6 · No Push ─────────────────────────────────────────
banner "No Push"
info "Commit stays local — nothing pushed, ${G}no CI minutes burned${RESET}."
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    if ${KEEP}; then
        info "Keeping ${M}${CURRENT_BRANCH}${RESET} ${DIM}(--keep)${RESET} — no cleanup prompt (branch is unpushed)."
    else
        info "Staying on ${M}${CURRENT_BRANCH}${RESET} — no cleanup prompt (branch is unpushed)."
    fi
fi
info "Push in batches later with: ${DIM}git-push \"message\" ${CURRENT_BRANCH}${RESET}"

# ── Done ─────────────────────────────────────────────────────
banner "Latest Commit"
echo ""
git --no-pager log -1 --color=always \
    --format="  %C(dim)%h%C(reset)  %s  %C(dim)(%ar by %an)%C(reset)" 2>/dev/null
echo ""
footer_box
echo ""
