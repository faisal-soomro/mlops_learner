# Day 6 — Walkthrough

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

The [README](README.md) covers the task and the two diagnosis tables (`pyproject.toml` config vs `src/*.py` lint hits). This file is the run-through: order to fix things in, what each tool reports, and how to confirm both checks exit 0. For the cross-cutting writeup on formatters vs linters, the ruff schema migration, `per-file-ignores`, etc., see [`notes/code-quality.md`](../../notes/code-quality.md).

## Starting state

`/root/code/fraud-detection/pyproject.toml` exists but doesn't satisfy the criteria, and one or more files under `src/` have lint or format violations. Two independent surfaces are broken: the config and the code.

## Step 1 — fix the config first

```bash
cat /root/code/fraud-detection/pyproject.toml
```

Read it against the README's "pyproject.toml" diagnosis table. Most common plants:

- `line-length` missing from `[tool.ruff]` or `[tool.black]` (ruff defaults to 88; criteria says 120).
- `select` declared under `[tool.ruff]` directly instead of `[tool.ruff.lint]` (the 0.1+ schema, see [`notes/code-quality.md`](../../notes/code-quality.md#ruff-config--the-01-schema-migration)).
- `select` missing or with the wrong codes.
- Table names typo'd as `[ruff]` / `[black]` instead of `[tool.ruff]` / `[tool.black]`.

The end state should look something like:

```toml
[tool.ruff]
line-length = 120

[tool.ruff.lint]
select = ["E", "F", "W", "I"]

[tool.black]
line-length = 120
```

**Why fix the config first:** running ruff/black before the config is right just produces wrong-shape errors. With `line-length = 88` (default), every long line lights up as `E501`; with `line-length = 120` set, only genuinely too-long lines remain. Save yourself the noise.

## Step 2 — let ruff auto-fix what it can

```bash
cd /root/code/fraud-detection
ruff check --fix src/
```

**What `--fix` handles automatically:**

- `F401` — removes unused imports.
- `I001` — sorts the import block.
- `W291`/`W293` — strips trailing whitespace.

**What `--fix` does *not* handle automatically:**

- `F821` (undefined name) — fixing it requires deciding what the right name *is*.
- `F841` (unused local variable) — could mean delete the variable, or could mean "this was meant to be used but isn't yet."
- `E711` (`x == None`) — ruff has a fixer but it's behind `--unsafe-fixes` because the rewrite isn't always semantically identical.

**Expected behaviour:** ruff prints a count of fixed and remaining issues. The remaining ones need manual fixes.

**If `--fix` removes an import you needed:** the corresponding *use* is missing from the source. Re-add the import manually and find the missing call site — don't fight ruff.

## Step 3 — manually fix what ruff couldn't

For each remaining ruff hit:

- `F821` / undefined name → fix the typo or add the missing import.
- `F841` / unused local → either use it or delete it. ML scripts often have `result = model.predict(...)` followed by no read — usually the intent was to log or return `result`.
- `E711` / comparison to `None` → change `x == None` to `x is None`. (And `x != None` to `x is not None`.)

The full table of codes is at <https://docs.astral.sh/ruff/rules/> — but in practice you just read what ruff prints; the code and message are right there.

## Step 4 — let black reformat

```bash
black src/
```

**What black does:** rewrites every `.py` file under `src/` to its canonical style — line breaks, quote style, trailing commas, spacing around operators. Effectively zero knobs by design.

**Expected behaviour:** prints `X files reformatted, Y files left unchanged`. No errors.

**The `target-version` warning** — if you see `Warning: Python 3.X cannot parse code formatted for Python 3.Y`, the run still succeeded; black just couldn't run its post-format AST safety check. Pin `target-version = ["py312"]` (or whatever you actually run) under `[tool.black]` to silence it. See [`notes/code-quality.md`](../../notes/code-quality.md#black-target-version-warning).

## Step 5 — re-run both checks

```bash
ruff check src/         # must exit 0
black --check src/      # must exit 0
echo "exit: $?"
```

**Why `black --check` and not `black src/` again:** `--check` exits non-zero if any file *would* change. That's what CI uses to gate merges. If you've already run `black src/`, `--check` should be a no-op.

If either exits non-zero, read the output, fix, and re-run. Don't `# noqa` your way to green — the lab grader will fail you, and so will any reviewer.

## Reading ruff output

Each hit looks like:

```
src/models/train.py:5:1: F401 [*] `os` imported but unused
```

- `src/models/train.py:5:1` — file, line, column.
- `F401` — the rule code.
- `[*]` — ruff can auto-fix this with `--fix`.
- `` `os` imported but unused`` — human description.

Hits without `[*]` need manual attention.

## Gotchas worth remembering

- **`[tool.ruff.lint]` is the 0.1+ schema.** The grader expects the new form. Pre-0.1 used `[tool.ruff]` with `select` directly; ruff still parses it but warns.
- **`select = ["E", "F", "W", "I"]` exactly.** Don't expand to `["ALL"]` — that's a footgun including mutually contradictory rules.
- **Config first, then `--fix`, then black, then `--check`.** Doing it in the wrong order produces phantom errors.
- **`# noqa` is a last resort,** and when used, write the specific code (`# noqa: F401`), never bare `# noqa`.

## What this day proves for the rest of the course

CI from Day 8 onwards will run `ruff` and `black --check` on every push. The same tools also feed pre-commit hooks (Day 8) and the GitHub Actions workflows from Day 76+. Get the config right once, here, and every later day inherits it.
