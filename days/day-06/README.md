# Day 6 — Set Up Code Quality Tools for ML Code

> **Step-by-step run-through:** see [walkthrough.md](walkthrough.md). For the wider concepts (formatter vs linter, ruff schema migration, `per-file-ignores`, etc.), see [`notes/code-quality.md`](../../notes/code-quality.md). This README is the TL;DR.

## Task

Make `/root/code/fraud-detection/` pass `ruff check src/` and `black --check src/`.

**Acceptance criteria:**
- Both tools configured with `line-length = 120`.
- Ruff lint rule selection includes `E`, `F`, `W`, `I`, declared under `[tool.ruff.lint]` (the ruff 0.1+ schema, not the old top-level `select`).
- `ruff check src/` exits 0.
- `black --check src/` exits 0.

## Why this matters

`black` formats; `ruff` lints. Both belong in CI because they catch different classes of problem — a formatter can't tell you `import os` is unused, and a linter doesn't standardise where line breaks fall. For ML code (notebooks-turned-scripts, full of unused imports and inconsistent indentation), the auto-fix is especially valuable.

For the cross-cutting writeup — formatter vs linter, the ruff 0.1+ schema migration, per-file-ignores, `# noqa` specificity, `target-version` warning, ruff/black overlap — see [`notes/code-quality.md`](../../notes/code-quality.md). The sections below focus on this lab.

## Use case

The fraud-detection team requires PRs to pass `ruff check` and `black --check` before merge. CI runs them in seconds. A new joiner clones the repo, runs `make lint` (or whatever the team calls it), and gets the same verdict CI will give — no surprises in the PR.

When someone refactors and accidentally leaves three unused imports behind, ruff catches it. When someone formats a long line by hand "the way they like it," black reformats it on the next push. Reviewers see only the actual change.

## How to diagnose the broken setup

Two surfaces to check: the config (`pyproject.toml`) and the source files (`src/`).

### `pyproject.toml`

| Symptom | Cause | Fix |
|---|---|---|
| `ruff` enforces line length 88 (its default) instead of 120 | `line-length` missing from `[tool.ruff]` | add `line-length = 120` |
| `black` reformats long lines that ruff thinks are fine | `line-length` missing from `[tool.black]` | add `line-length = 120` |
| Ruff warning: `The top-level linter settings are deprecated in favour of their counterparts in the lint section` | `select = [...]` declared under `[tool.ruff]` directly | move it to a new `[tool.ruff.lint]` table |
| Ruff lints with fewer rules than expected | `select` missing or shorter than `["E", "F", "W", "I"]` | declare exactly those four codes |
| `[tool.black]` / `[tool.ruff]` typo'd as `[black]` / `[ruff]` | wrong table name | TOML tools only look at the namespaced tables |

### `src/*.py`

`ruff check src/` will print every offending line. Typical lab plants:

| Code | Meaning | Common cause |
|---|---|---|
| `F401` | imported but unused | `import os` left over from an earlier draft |
| `F811` | redefinition of unused name | function or import defined twice |
| `F821` | undefined name | typo'd variable, or use-before-define |
| `F841` | local variable assigned but never used | `result = ...` that's never read |
| `E501` | line too long | only fires if line > `line-length`; the 120 vs 88 mismatch lights this up |
| `E711` | comparison to None | `x == None` instead of `x is None` |
| `I001` | import block unsorted/unformatted | stdlib mixed with third-party, no blank lines |
| `W291` / `W293` | trailing whitespace | self-explanatory |

Fix order that works in practice:

```bash
cd /root/code/fraud-detection

# 1. Auto-fix anything ruff can fix on its own (unused imports, sorted imports, ...)
ruff check --fix src/

# 2. Let black reformat everything else
black src/

# 3. Re-run the checks
ruff check src/         # must exit 0
black --check src/      # must exit 0
```

If `ruff check --fix` removes an `import` that *should* have been used somewhere, the corresponding code is missing — re-add it manually, don't fight ruff.

A reference [`pyproject.toml`](pyproject.toml) is in this directory.

## How to run

```bash
cd /root/code/fraud-detection
ruff check src/
black --check src/
echo "exit: $?"
```

If both exit 0, you're done. CI will agree.

## Notes & gotchas

Lab-specific:

- **`[tool.ruff.lint]` is the ruff 0.1+ schema** — the grader expects the new form, not the deprecated top-level `select`.
- **`select = ["E", "F", "W", "I"]`** — exactly those four codes. Don't expand to `["ALL"]`.
- **Day 8 will wire these to pre-commit hooks.** For now, run by hand or via `make lint`.

Cross-cutting context — formatter vs linter, the ruff schema migration, `per-file-ignores`, `# noqa` specificity, the `target-version` warning, pinning, and the ruff/black trajectory — lives in [`notes/code-quality.md`](../../notes/code-quality.md).

## Resources

- [ruff docs](https://docs.astral.sh/ruff/) — the [rules reference](https://docs.astral.sh/ruff/rules/) is the most useful page; it shows every code, its category, and an example.
- [ruff configuration](https://docs.astral.sh/ruff/configuration/) — full `pyproject.toml` schema; covers `[tool.ruff]` vs `[tool.ruff.lint]`.
- [Black — The Uncompromising Code Formatter](https://black.readthedocs.io/) — short, opinionated; the [What? Why? Should I?](https://black.readthedocs.io/en/stable/the_black_code_style/index.html) section is worth reading once.
- [Why I use Black](https://blog.encode.io/the-tale-of-the-black-formatter-2c3e4d3e7c7e) — short essay on the value of removing style debates.
- [Astral's "ruff format" announcement](https://astral.sh/blog/the-ruff-formatter) — context on the ruff-vs-black overlap and where things are heading.
- [PEP 8](https://peps.python.org/pep-0008/) — the style guide ruff `E`/`W` rules ultimately encode. Read once to know what the linter is enforcing and why.
