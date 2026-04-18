#!/usr/bin/env bash
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0
# ──────────────────────────────────────────────────────────────
#  gitbetter — umbrella info command for the gitbetter toolkit
#
#  Pure info command: does not perform git operations or
#  dispatch to subcommands. Users invoke `git-push` / `git-tag`
#  directly.
#
#  Usage:  gitbetter [--help | --version]
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Shared UI Library ────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/ui.sh
source "${SCRIPT_DIR}/lib/ui.sh"

print_help() {
    cat <<EOF
gitbetter — streamline repetitive git workflows into single, interactive commands

Usage:
  gitbetter --help
  gitbetter --version

Commands:
  git-push      Stage, commit, push, and optionally clean up a branch
  git-tag       Validate a semver tag, create it, and push to origin

Run \`git-push --help\` or \`git-tag --help\` for command-specific usage.

Homepage: ${GITBETTER_HOMEPAGE}
EOF
}

# ── Dispatch ─────────────────────────────────────────────────
case "${1:-}" in
    ""|--help)
        print_help
        exit 0
        ;;
    --version)
        print_version ""
        exit 0
        ;;
    *)
        echo "gitbetter: unknown argument: $1" >&2
        echo "Run 'gitbetter --help' for usage." >&2
        exit 1
        ;;
esac
