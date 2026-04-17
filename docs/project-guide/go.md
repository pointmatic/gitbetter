# Project-Guide — Calm the chaos of LLM-assisted coding

This document provides step-by-step instructions for an LLM to assist a human developer in a project. 

## How to Use Project-Guide

### For Developers
After installing project-guide (`pip install project-guide`) and running `project-guide init`, instruct your LLM as follows in the chat interface: 

```
Read `docs/project-guide/go.md`
```

After reading, the LLM will respond:
1. (optional) "I need more information..." followed by a list of questions or details needed. 
  - LLM will continue asking until all needed information is clear.
2. "The next step is ___."
3. "Say 'go' when you're ready." 

For efficiency, when you change modes, start a new LLM conversation. 

### For LLMs

**Modes**
This Project-Guide offers a human-in-the-loop workflow for you to follow that can be dynamically reconfigured based on the project `mode`. Each `mode` defines a focused cycle of steps to guide you (the LLM) to help generate artifacts for some facet in the project lifecycle. This document is customized for code_direct.

**Approval Gate**
When you have completed the steps, pause for the developer to review, correct, redirect, or ask questions about your work.  

**Rules**
- Work through each step methodically, presenting your work for approval before continuing a cycle. 
- When the developer says "go" (or equivalent like "continue", "next", "proceed"), continue with the next action. 
- If the next action is unclear, tell the developer you don't have a clear direction on what to do next, then suggest something. 
- Never auto-advance past an approval gate—always wait for explicit confirmation. 
- At approval gates, present the completed work and wait. Do **not** propose follow-up actions outside the current mode step — in particular, do not prompt for git operations (commits, pushes, PRs, branch creation), CI runs, or deploys unless the current step explicitly calls for them. The developer initiates these on their own schedule.
- After compacting memory, re-read this guide to refresh your context.
- Before recording a new memory, reflect: is this fact project-specific (belongs in `docs/specs/project-essentials.md`) or cross-project (belongs in LLM memory)? Could it belong in both? If project-specific, add it to `project-essentials.md` instead of or in addition to memory.
- When creating any new source file, add a copyright notice and license header using the comment syntax for that file type (`#` for Python/YAML/shell, `//` for JS/TS, `<!-- -->` for HTML/Svelte). Check this project's `project-essentials.md` for the specific copyright holder, license, and SPDX identifier to use.

---

## Project Essentials

<!--
This file captures must-know facts future LLMs need to avoid blunders when
working on this project. Anything a smart newcomer could miss on day one and
waste time on goes here.

This content gets injected verbatim under a `## Project Essentials` section
in every rendered `go.md`, so entries below should use `###` for subsections
(not `##`, which would collide with the wrapper heading). Do NOT include a
top-level `#` title — the wrapper provides it.
-->

### File header conventions

Every new source file must begin with a copyright notice and license
identifier. Use the comment syntax for the file type:

| File type | Comment syntax |
|-----------|---------------|
| Shell, YAML, Makefile | `#` |
| JavaScript, TypeScript, Go, Java, C/C++ | `//` or `/* */` |
| HTML, Svelte, XML | `<!-- -->` |
| CSS, SCSS | `/* */` |

**This project's header:**

- **Copyright**: `Copyright (c) 2025 Pointmatic`
- **SPDX identifier**: `SPDX-License-Identifier: Apache-2.0`

Shell example:
```bash
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0
```

YAML example:
```yaml
# Copyright (c) 2025 Pointmatic
# SPDX-License-Identifier: Apache-2.0
```

### Shared UI library — `lib/ui.sh`

Color constants, symbols, and helper functions (`banner`, `info`, `success`, `warn`, `fail`, `confirm`, `ask_yn`, `divider`, `run_cmd`, `header_box`, `footer_box`) live in `lib/ui.sh` and are sourced by every command script (`git-push.sh`, `git-tag.sh`). Update helpers in **`lib/ui.sh` only**, never duplicate them into individual command scripts.

Command scripts source the library using the script's own directory:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/ui.sh
source "${SCRIPT_DIR}/lib/ui.sh"
```

`pwd -P` resolves symlinks so the lib is found even when the script is reached via a PATH symlink.

**Homebrew install shape:** the formula installs both the scripts and `lib/` into `libexec/`, then writes thin `bin/git-push` and `bin/git-tag` wrappers that `exec` the real scripts. This keeps `$BASH_SOURCE[0]` pointing at `<libexec>/git-<cmd>.sh`, so `lib/ui.sh` resolves correctly at runtime. See `tech-spec.md` for the full formula snippet.

### `.sh` extension in repo, dropped on install

Source files in the repository use the `.sh` extension (`git-push.sh`, `git-tag.sh`). Homebrew installs them without the extension (`git-push`, `git-tag`) so git discovers them as subcommands. Always edit the `.sh` files in the repo — never edit installed copies.

### `confirm()` vs `ask_yn()` — different control flow

These two prompt functions have **different** control flow and must not be confused:

- **`confirm()`** — `[Y/n]`, default yes. On "n", **exits the script with code 0** (clean abort). Use for gates where aborting means stopping everything.
- **`ask_yn()`** — `[y/N]`, default no. On "n", **returns 1** (false). The caller decides what to do. Use for optional actions where "no" means skip and continue.

Mixing them up causes scripts to exit when they should continue, or continue when they should abort.

### Numeric tag sorting, not lexicographic

Tags must be sorted **numerically** by major.minor.patch — `v1.10.0` comes after `v1.9.0`. Never use plain `sort` or `sort -V` (which is not available on all platforms). Use:

```bash
sort -t. -k1,1n -k2,2n -k3,3n
```

(after stripping the `v` prefix for sorting purposes).

### Never `--force`, only `--force-with-lease`

This is a **hard rule**. No script in this project may ever use `git push --force`. The only permitted force-push variant is `--force-with-lease`, which refuses to overwrite remote commits that you haven't seen locally. This applies to amend mode, pre-commit hook fold-in, and any push retry flow.


---

# code_direct mode (cycle)

> Generate code directly, test after


Implement stories rapidly with direct commits to main. Focus on feature completion and iteration speed over process overhead.

**Next Action**
Restart the cycle of steps. 

---


## Cycle Steps

For each story:

1. **Read** the story's checklist from `docs/specs/stories.md`
2. **Implement** all tasks in the checklist
3. **Add copyright/license headers** to every new source file
4. **Run tests** -- `pyve run pytest` (fix failures before continuing)
5. **Run linting** -- fix any issues immediately
6. **Mark tasks** as `[x]` in `stories.md` and change story suffix to `[Done]`
7. **Bump version** in package manifest and source (if the story has a version)
8. **Update CHANGELOG.md** with the version entry
9. **Present** the completed story concisely: what changed (files + line refs), verification results (test counts, lint status), and the suggested next story. Do not propose commits, pushes, or bundling options. Do not offer "want me to also…?" follow-ups.
10. **Wait** for the developer to say "go" before starting the next story

## Velocity Practices

**LLM's role in each cycle:**

- **Version bump per story** -- v0.1.0, v0.2.0, v0.3.0, etc. — bump in package manifest and source
- **Minimal process overhead** -- focus on making it work, not making it perfect
- **Tests run after every story** -- not after every file, but before presenting to developer
- **Fix linting immediately** -- small incremental fixes, not batch cleanup
- **Update CHANGELOG.md** with the version entry before presenting

**Developer's role (do NOT prompt for, offer, or initiate):**

- **Direct commits to main** -- no branches, no PRs, no code review (velocity convention)
- **Commit messages** reference story IDs: `"Story A.a: v0.1.0 Hello World"`
- **Decides when to commit** -- the LLM presents, the developer commits. Multiple stories may be bundled into one commit at the developer's discretion — that is not the LLM's call to make or suggest.

## Story Ordering

- Start with Story A.a (Hello World) if not yet implemented
- If unclear which story is next, ask: "Which story should I work on next?"
- Never skip ahead -- complete stories in order within each phase

## File Header Reminder

Every new source file must include the copyright and license header as the very first content (before code, docstrings, or imports).

## When to Switch Modes

Switch to **code_test_first** when:
- Working on a story with complex logic that benefits from TDD
- The developer requests test-first approach

Switch to **debug** when:
- A bug is discovered during implementation
- Tests are failing unexpectedly

Switch to **production mode** when:
- CI/CD phase is complete and branch protection is enabled
- The project is ready for public users

