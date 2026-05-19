# Day 7 — Walkthrough

The actual debugging session, preserved. The [README](README.md) describes the steps abstractly; this file shows what the tools actually printed at each step and what each output proved.

## Starting state

`/root/code/fraud-detection/pyproject.toml`:

```toml
[project]
name = "fraud-detection"
version = "0.0.1"
description = "Fraud detection model for xFusionCorp Industries"
requires-python = ">=3.8"
dependencies = []

[tool.setuptools.packages.find]
where = ["src"]
```

Five things violate the acceptance criteria:

1. `[build-system]` missing.
2. `name = "fraud-detection"` (hyphen, must be underscore).
3. `version = "0.0.1"` (must be `0.1.0`).
4. `requires-python = ">=3.8"` (must be `>=3.10`).
5. `dependencies = []` (must be the three packages).

## Step 0 — baseline, no edits

```bash
rm -rf build dist ./*.egg-info
python3 -m build
```

Selected output:

```
* Installing packages in isolated environment:
  - setuptools >= 40.8.0
...
Successfully built fraud_detection-0.0.1.tar.gz and fraud_detection-0.0.1-py3-none-any.whl
```

**What this proved:**

- The build *succeeded* even without `[build-system]`. Modern `python -m build` falls back to `setuptools>=40.8.0` and uses its legacy entry points. This was unexpected — a missing `[build-system]` is a spec violation, but not a build failure. Useful to know: when inheriting a `pyproject.toml`, "the build works" is *not* proof the config is correct.
- The wheel filename was `fraud_detection-0.0.1-py3-none-any.whl` — note the **underscore**, even though `name = "fraud-detection"` (hyphen) in the file. That's [PEP 503](https://peps.python.org/pep-0503/) name normalisation: hyphens, underscores, and dots are all equivalent for distribution naming, and wheel filenames always use the underscore form. The filename alone can't tell you whether the source `name` is right — you have to read the metadata.
- One cosmetic warning to ignore: `sdist: standard file not found: should have one of README...`. The project has no README. Not part of the spec.

## Step 1 — add `[build-system]`

Edited the file to prepend:

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"
```

Then:

```bash
rm -rf build dist ./*.egg-info
python3 -m build
```

Selected output:

```
* Installing packages in isolated environment:
  - setuptools>=61.0
  - wheel
...
Successfully built fraud_detection-0.0.1.tar.gz and fraud_detection-0.0.1-py3-none-any.whl
```

**What this proved:**

- The isolated build env now installs `setuptools>=61.0` (and `wheel`) — the exact versions declared in `[build-system].requires`. Compare to step 0's `setuptools >= 40.8.0`. **That diff is the only proof your `[build-system]` is being read.** If the line had stayed `40.8.0`, the new section was ignored.
- The wheel filename is still `0.0.1`. That's expected — `[build-system]` controls *how* the build runs, not *what* it produces. We haven't touched `name` or `version` yet.

## Step 2 — fix `name` and `version`

Edited `[project]`:

```toml
name = "fraud_detection"      # was: "fraud-detection"
version = "0.1.0"             # was: "0.0.1"
```

Then:

```bash
grep -E '^(name|version)' pyproject.toml   # confirm the edit landed
rm -rf build dist ./*.egg-info
python3 -m build 2>&1 | tail -3
ls dist/
```

Output:

```
adding 'fraud_detection-0.1.0.dist-info/RECORD'
removing build/bdist.linux-x86_64/wheel
Successfully built fraud_detection-0.1.0.tar.gz and fraud_detection-0.1.0-py3-none-any.whl

fraud_detection-0.1.0-py3-none-any.whl
fraud_detection-0.1.0.tar.gz
```

**What this proved:**

- The wheel filename now matches the grader's expectation: `fraud_detection-0.1.0-*.whl`.
- A small lesson: I rebuilt before editing the first time, got `0.0.1` again, and was puzzled. The cause was simple — the file hadn't actually been edited yet. **Always `grep` the file to confirm an edit landed before rebuilding.** "The build still produces the wrong thing" is sometimes "your editor didn't save."

## Step 3 — fix `requires-python` and `dependencies`

Edited `[project]`:

```toml
requires-python = ">=3.10"
dependencies = ["scikit-learn", "pandas", "numpy"]
```

Then:

```bash
rm -rf build dist ./*.egg-info /tmp/wheel-inspect
python3 -m build > /dev/null 2>&1
python3 -m zipfile -e dist/fraud_detection-0.1.0-py3-none-any.whl /tmp/wheel-inspect
grep -E "^(Name|Version|Requires-Python|Requires-Dist):" /tmp/wheel-inspect/fraud_detection-0.1.0.dist-info/METADATA
```

Output:

```
Name: fraud_detection
Version: 0.1.0
Requires-Python: >=3.10
Requires-Dist: scikit-learn
Requires-Dist: pandas
Requires-Dist: numpy
```

**What this proved:**

- A wheel is just a zip. `python -m zipfile -e <wheel> <dir>` unpacks it. Inside, `<dist-info>/METADATA` is the source of truth for `Name`, `Version`, `Requires-Python`, and `Requires-Dist`.
- Steps 0–2's builds were *succeeding*, but the wheel they produced **lied to consumers**. It claimed to require Python 3.8+ (it actually needs 3.10+) and to depend on nothing (it actually needs scikit-learn, pandas, numpy). These are runtime promises the wheel makes to `pip install`. The build can't catch them being wrong — only inspecting the metadata can.
- **A build succeeding is not the same as the build being right.** That lesson recurs throughout MLOps: a Docker image building, an MLflow run logging, a DVC stage completing — none of those mean the artifact is *correct*. Inspect the artifact.

## Step 4 — smoke-test the install

```bash
python3 -m venv /tmp/install-check
/tmp/install-check/bin/pip install dist/fraud_detection-0.1.0-py3-none-any.whl 2>&1 | tail -5
/tmp/install-check/bin/python -c "import fraud_detection; print(fraud_detection.__file__)"
```

Output (abridged):

```
Installing collected packages: threadpoolctl, six, numpy, joblib, scipy, python-dateutil,
                                scikit-learn, pandas, fraud-detection
Successfully installed fraud-detection-0.1.0 joblib-1.5.3 numpy-2.4.6 pandas-3.0.3 ...
/tmp/install-check/lib/python3.12/site-packages/fraud_detection/__init__.py
```

**What this proved:**

- The wheel installed into a clean venv. The transitive dep tree (`numpy`, `scipy`, `joblib`, `scikit-learn`, `pandas`, `python-dateutil`, `six`, `threadpoolctl`) was driven *entirely* by the three `Requires-Dist:` lines in METADATA. Declare three, get nine. That's what step 3 was actually about.
- The `import fraud_detection` resolved, and the printed path is inside the new venv's `site-packages` — so setuptools' src-layout discovery worked even without `[tool.setuptools.packages.find]` being explicitly declared. Auto-detection handles a single-package src layout fine; explicit is still recommended for older CI environments and clarity.
- One cosmetic detail: pip's "Successfully installed" line shows `fraud-detection-0.1.0` (hyphen), even though the wheel filename and `Name:` field use underscores. pip normalises distribution names *back* to hyphens for display. Confusing but harmless — distribution names are case- and separator-insensitive per PEP 503.

## Cross-cutting learnings (extracted)

After the lab, we pulled on:

- What a PEP is, and the cluster (517 / 518 / 621 / 503 / 440) that governs modern Python packaging.
- The difference between `setup.py`, `setuptools`, and `pyproject.toml` — easy to conflate.
- The `setuptools>=40.8.0` PEP 517 fallback and its silent-failure trap.
- PEP 503 distribution name normalisation — why `fraud-detection`, `fraud_detection`, and `Fraud_Detection` are all the same package, and why import names aren't.

These are *not* Day 7-specific — they apply to any Python packaging work going forward. Moved to **[notes/python-packaging.md](../../notes/python-packaging.md)**.

## What I'd want to remember six months from now

- `python -m build` falls back to `setuptools>=40.8.0` when `[build-system]` is missing. "It builds" doesn't mean the config is right.
- Wheel filenames always normalise hyphens to underscores. Read METADATA, not the filename, to verify the source `name`.
- `python -m zipfile -e wheel.whl dir` unpacks a wheel. METADATA inside `.dist-info/` is plain text and worth `grep`ing.
- `pip install` follows `Requires-Dist:` transitively — that's the *only* mechanism for "this package needs scikit-learn". Empty `dependencies = []` produces a wheel that installs no transitive deps, silently.
- The cycle is: change one thing → rebuild → inspect the *artifact* (filename, METADATA, install) → next change. Not "fix the whole file and hope."
