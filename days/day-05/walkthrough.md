# Day 5 — Walkthrough

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

The [README](README.md) covers the task, the acceptance criteria, and the diagnosis table. This file is the run-through: order of fixes, what each is supposed to fix, and how to confirm `make all` will pass. For the cross-cutting writeup on `make` (what `.PHONY` does, recipe-per-shell semantics, the offensive-security angle), see [`notes/makefile.md`](../../notes/makefile.md).

## Starting state

`/root/code/fraud-detection/Makefile` exists but `make all` doesn't complete. The plants the lab can use are listed in the README's diagnosis table — most common are:

- Recipes indented with spaces, not tabs (`*** missing separator. Stop.`).
- Targets missing from `.PHONY` (so `make test` silently no-ops because `tests/` exists).
- `all` lists prerequisites in the wrong order.
- `clean` removes the `models/` directory itself instead of clearing its contents.
- `clean`'s `__pycache__` removal isn't recursive.

## Step 1 — run `make all` and read the first error

```bash
cd /root/code/fraud-detection
make all
```

**Why first:** `make` is mostly self-diagnosing. The first error either points at a literal line (`Makefile:7: ***`) or is one of a small set of well-known failure modes.

Read the first line of the error and look up the row in the README's diagnosis table.

## Step 2 — the tab check

If the error was `*** missing separator. Stop.`:

```bash
cat -A Makefile | head -30
```

**What `cat -A` shows:** tabs render as `^I`, spaces as literal spaces. Every recipe line (the indented one under a target) must start with `^I`, not eight spaces.

**Fix:** in an editor that doesn't auto-convert, replace the leading whitespace with a real tab on each recipe line. Or use `sed -i 's/^    /\t/' Makefile` if the spaces-instead-of-tabs is exactly four spaces and consistent (don't trust this — eyeball the result).

**The trap:** most editors helpfully convert tabs to spaces. For a `Makefile`, that breaks the file. For repeat offenders, set `"[makefile]": { "editor.insertSpaces": false }` in VS Code or the equivalent for your editor.

## Step 3 — `.PHONY` for every target

The Makefile should start with:

```makefile
.PHONY: setup data train test clean all
```

**Why this matters here specifically:** the project has a `tests/` directory (Day 4 created it). Without `.PHONY: test`, `make test` looks at the target name, sees `tests/` exists, and decides "test is up to date" — silently no-ops. The grader fails because `pytest` never ran.

The same applies to any target whose name matches a real path. `clean` would no-op if a file called `clean` existed; `data` would no-op if `data/` is present (which it is). Mark every orchestration target. See [`notes/makefile.md`](../../notes/makefile.md#what-phony-actually-does) for the full mechanics.

## Step 4 — `all` in the right order

```makefile
all: setup data train test
```

**Why this order:** `make` runs prerequisites left to right (when not parallelised with `-j`). `setup` must run first because it creates the venv. `data` produces inputs `train` needs. `train` produces outputs `test` may exercise. The order is causal, not alphabetical.

## Step 5 — recipe correctness

The target bodies the grader expects:

```makefile
setup:
	python3 -m venv mlops-venv
	mlops-venv/bin/pip install -r requirements.txt

data:
	python src/data/process_data.py

train:
	python src/models/train.py

test:
	pytest tests/

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	rm -rf .pytest_cache
	rm -rf models/*
```

**Two `clean` traps worth highlighting:**

- `rm -rf __pycache__` only removes the top-level one. Use `find ... -exec rm -rf {} +` to clear them recursively across `src/`, `tests/`, etc.
- `rm -rf models/` removes the *directory itself*. The task says "clear `models/`" — keep the directory, drop its contents: `rm -rf models/*`.

**A `setup` note:** the recipe runs `python3 -m venv mlops-venv` then `mlops-venv/bin/pip install -r requirements.txt`. Calling `mlops-venv/bin/pip` directly avoids the `source venv/bin/activate` trap — `source` modifies the *current* shell, and `make` discards that shell between lines. See [`notes/makefile.md`](../../notes/makefile.md#source-venvbinactivate-is-almost-always-a-mistake).

## Step 6 — dry run, then real run

```bash
make -n all   # prints what would happen; no execution
make all      # exits 0 if everything passes
echo $?
```

**Why `make -n` first:** confirms recipe order and which commands will run without spending time. Catches "wait, `train` runs before `data`?" before you sit through ten minutes of failed execution.

**Expected behaviour of `make all`:**

- `setup` creates `mlops-venv/`, installs packages.
- `data` runs `process_data.py` — succeeds if the script exists and doesn't crash.
- `train` runs `train.py` — same.
- `test` runs `pytest tests/` — should report "no tests collected" or some passing count, depending on what's in `tests/`. The grader cares that pytest *ran*, not that there are real tests.

## Tab verification one-liner

```bash
grep -P '^\t' Makefile | head    # recipe lines should appear
grep -P '^ +' Makefile | head    # should be empty (no space-indented recipes)
```

If the second `grep` shows hits, the tab fix isn't complete.

## Gotchas worth remembering

- **Tabs, not spaces.** The single most famous papercut in `make`. `cat -A` is the diagnostic.
- **`.PHONY` for everything that doesn't produce a file with its own name.** Especially when a directory of that name exists in the repo.
- **`source venv/bin/activate` doesn't work in recipes.** Each line is a fresh shell. Call venv binaries directly.
- **`clean models/*`, not `clean models/`.** Keep the directory, drop the contents.
- **Order in `all` is causal.** `setup → data → train → test`.

## What this day proves for the rest of the course

`make` is the gateway drug to declarative pipelines. DVC's `dvc.yaml` (Days 14+), Argo's `Workflow` (Day 86+), Prefect flows (Days 88+) are all more sophisticated versions of the same idea: name targets, declare dependencies, run them in order. The mental model — "targets, prerequisites, recipes" — transfers.
