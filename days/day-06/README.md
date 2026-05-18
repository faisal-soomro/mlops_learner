# Day 6 — Set Up Code Quality Tools for ML Code

## Task

Make `/root/code/fraud-detection/` pass `ruff check src/` and `black --check src/`.

**Acceptance criteria:**
- Both tools configured with `line-length = 120`.
- Ruff lint rule selection includes `E`, `F`, `W`, `I`, declared under `[tool.ruff.lint]` (the ruff 0.1+ schema, not the old top-level `select`).
- `ruff check src/` exits 0.
- `black --check src/` exits 0.

## Why this matters

Two different tools doing two different jobs, both needed:

- **`black`** is a *formatter*. It rewrites code to a canonical style — line breaks, quotes, spacing, trailing commas. It has effectively zero knobs, by design. The whole pitch is "stop arguing about style; commit the diff." `black --check` exits non-zero if any file would change.
- **`ruff`** is a *linter* (and a fast one — Rust). It looks for actual bugs and lint smells: unused imports (`F401`), undefined names (`F821`), unused variables (`F841`), bad import ordering (`I001`), things that flake8 + isort + pylint would catch, but in one pass and roughly 100× faster. Ruff *can* also format, but on this project black is the formatter and ruff is the linter — same separation most teams use today.

Why have both in CI? Because they catch different classes of problem:

- A formatter cannot tell you `import os` is unused — that's a lint check.
- A linter does not standardise where line breaks fall in long function signatures — that's a formatter's job.

Running both on every PR gives you a stable, mechanical floor of code quality. Reviewers stop nitpicking whitespace and start reviewing logic. New contributors get one canonical style without reading a 40-page style guide.

For ML code specifically: notebooks-turned-scripts are *full* of unused imports (the leftovers from "let me just try this"), `import *`, and inconsistent indentation. `ruff` + `black` clean those up automatically before anyone reads the diff.

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

- **`[tool.ruff.lint]` is the ruff 0.1+ schema.** Pre-0.1 used `[tool.ruff]` with `select`. Ruff still reads the old form but warns. The lab grader expects the new form.
- **Don't enable every ruff rule.** `select = ["ALL"]` is a footgun — it includes mutually contradictory rules and stylistic choices most teams reject. Start with `E F W I` (the task's choice), add specific codes as the team agrees on them.
- **`per-file-ignores` for tests and notebooks.** Tests often want `assert` (ruff `S101`), long lines for parametrised fixtures, and unused fixtures (ruff `ARG`). Notebooks-as-scripts want `E402` (imports not at top). Configure via `[tool.ruff.lint.per-file-ignores]` rather than scattering `# noqa` comments.
- **Black version pinning.** Black is deliberately opinionated and occasionally changes formatting between versions. Pin the version in `requirements.txt` (or `pyproject.toml` dev deps) so CI and devs format identically. Same applies to ruff, though ruff is more disciplined about backward compatibility.
- **Black target-version warning.** If you see `Warning: Python 3.X cannot parse code formatted for Python 3.Y`, the run still succeeded — black just couldn't run its post-format AST safety check because the running interpreter is older than the (inferred) target version. Pin `target-version = ["py312"]` (or whatever you actually run) under `[tool.black]` to silence it and make the safety check run.
- **`# noqa` is a last resort.** If a real lint hit needs to be silenced, write `# noqa: F401` (specific code), not bare `# noqa`. The latter silences everything and never expires.
- **`ruff format` vs `black`.** Ruff now ships a formatter that is ~99% black-compatible. Many teams have migrated to ruff-only. The lab keeps both because that's what most teams *currently* run; expect this to consolidate over the next year or two.
- **Pre-commit hooks.** Day 8 will wire these tools to run automatically on `git commit`. For now, run them by hand or via `make lint`.

## Resources

- [ruff docs](https://docs.astral.sh/ruff/) — the [rules reference](https://docs.astral.sh/ruff/rules/) is the most useful page; it shows every code, its category, and an example.
- [ruff configuration](https://docs.astral.sh/ruff/configuration/) — full `pyproject.toml` schema; covers `[tool.ruff]` vs `[tool.ruff.lint]`.
- [Black — The Uncompromising Code Formatter](https://black.readthedocs.io/) — short, opinionated; the [What? Why? Should I?](https://black.readthedocs.io/en/stable/the_black_code_style/index.html) section is worth reading once.
- [Why I use Black](https://blog.encode.io/the-tale-of-the-black-formatter-2c3e4d3e7c7e) — short essay on the value of removing style debates.
- [Astral's "ruff format" announcement](https://astral.sh/blog/the-ruff-formatter) — context on the ruff-vs-black overlap and where things are heading.
- [PEP 8](https://peps.python.org/pep-0008/) — the style guide ruff `E`/`W` rules ultimately encode. Read once to know what the linter is enforcing and why.
