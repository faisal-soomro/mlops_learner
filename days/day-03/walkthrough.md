# Day 3 — Walkthrough

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

The [README](README.md) covers the broken file and the diagnosis table. This file is the run-through: what each fix is supposed to fix, what `uv pip compile` should do, and how to read the lockfile it produces. For the wider concepts (PEPs, pinning vs ranges vs lockfiles, frontends vs backends), see [`notes/python-packaging.md`](../../notes/python-packaging.md).

## Starting state

The lab's `requirements.in` is:

```
# requirements.in
# Fraud detection project dependencies
sklearn
mlflow>=100.0
numpy
```

Four problems:

1. `sklearn` is the wrong PyPI name (and a stub that errors on install).
2. `mlflow>=100.0` is unsatisfiable — mlflow is at ~2.x.
3. `numpy` has no version constraint (the task requires one).
4. `pandas` is missing entirely.

## Step 1 — fix the four issues

Rewrite `requirements.in` to something like:

```
scikit-learn>=1.4,<2
mlflow>=2.10,<3
pandas>=2.0,<3
numpy>=1.26,<3
```

**Why each constraint shape:**

- `>=1.4,<2` — accepts patch and minor bumps but not the next major. Standard "tolerate compatible releases" pattern for libraries that follow semver loosely.
- The exact lower bounds are judgement calls. `scikit-learn>=1.4` means "we depend on at least 1.4's API"; if the team is on 1.5 already, bump it. The lab grader only cares that the constraint exists and resolves.

**Why `scikit-learn`, not `sklearn`.** The *import name* in Python is `sklearn`. The *PyPI package* that provides that import is `scikit-learn`. `sklearn` exists as a separate PyPI project — historically a redirect, but since 2023 it raises a deliberate `InstallationError` to stop the confusion from spreading. If `sklearn` appears in a real-world `requirements.in` or `pyproject.toml`, treat it as a bug. See [`notes/python-packaging.md`](../../notes/python-packaging.md) "PEP 503 name normalisation" for the related case of `-` vs `_` in distribution names.

## Step 2 — compile

```bash
cd /root/code/fraud-detection
uv pip compile requirements.in -o requirements.txt
```

**What `uv pip compile` does:**

1. Parses `requirements.in` as a spec.
2. Resolves against PyPI: picks the highest version of each top-level that satisfies its constraint *and* is compatible with the others' transitive requirements.
3. Writes `requirements.txt` containing every package — top-level *and* transitive — pinned with `==`.

**Expected behaviour:**

- Should complete in seconds, not minutes. `uv` is Rust and uses a smarter resolver than pip-tools.
- The output file is significantly longer than the input — maybe 40-80 lines for these four packages, mostly transitive deps (scipy, joblib, threadpoolctl, cloudpickle, gitpython, sqlalchemy, alembic, ...).
- Each line in `requirements.txt` should look like `package==X.Y.Z` plus a comment showing which top-level package pulled it in.

## Step 3 — verify the lockfile

```bash
# every top-level package pinned with ==
grep -E '^(scikit-learn|mlflow|pandas|numpy)==' requirements.txt

# transitive deps are present
wc -l requirements.txt   # expect >> 4
```

**What to confirm:**

- All four top-level packages appear with `==` pins.
- The file is long enough that transitives are clearly included.
- No line still says `>=` or `<` — the lockfile is pins-only.

## Step 4 (optional) — install to prove the lockfile resolves cleanly

```bash
uv venv .venv
uv pip sync --python .venv/bin/python requirements.txt
```

**Why `sync` and not `install`:**

- `uv pip sync` makes the target environment match the lockfile *exactly* — installs anything missing, removes anything extra. Idempotent.
- `uv pip install` only adds; it never removes. Re-running it after editing the lockfile leaves stale packages.

For CI and Docker images, `sync` is the right verb. For "let me try this experimentally in my dev venv", `install` is fine.

## Gotchas worth remembering

- **`sklearn` vs `scikit-learn`.** Import name ≠ PyPI name. The stub package raises on install.
- **Don't hand-edit `requirements.txt`.** It's generated output. Edit `requirements.in`, recompile.
- **Lockfiles are platform-specific by default.** A lockfile compiled on macOS may pick different wheels than one compiled on Linux because of `manylinux` availability. Compile on the platform you deploy on (usually Linux), or use `uv pip compile --universal` for cross-platform.
- **Hashes for production.** `uv pip compile --generate-hashes` adds SHA hashes; `pip install` then refuses if any wheel doesn't hash-match. Worth turning on for prod images.
- **Two `uv` worlds.** `uv pip compile` is the pip-tools-compatible flow (this lab). `uv lock` is the modern `pyproject.toml` + `uv.lock` flow that Day 7 onwards will use. Same idea, different file formats.

## What this day proves for the rest of the course

Every later environment — CI, Docker images, training reproduction — installs from a lockfile, not from a hand-edited list. The spec/lockfile split (and the `sync` discipline that goes with it) is what makes "reproducible Python environment" actually true instead of aspirational. The same pattern shows up in `npm`/`package-lock.json`, `cargo`/`Cargo.lock`, `go.sum` — it's the universal answer to "how do I get the same install everywhere."
