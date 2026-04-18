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

- **Copyright**: `Copyright (c) 2026 Pointmatic`
- **SPDX identifier**: `SPDX-License-Identifier: Apache-2.0`

Shell example:
```bash
# Copyright (c) 2026 Pointmatic
# SPDX-License-Identifier: Apache-2.0
```

YAML example:
```yaml
# Copyright (c) 2026 Pointmatic
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
