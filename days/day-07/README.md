# Day 7 — Package an ML Project as an Installable Python Package

> **Want the full debugging session, the PEP refs, and the "why does it work that way" notes?** See [walkthrough.md](walkthrough.md). This README is the TL;DR.

## Task

Fix `/root/code/fraud-detection/pyproject.toml` so `python3 -m build` produces a compliant wheel.

**Acceptance criteria:**
- `[build-system]` declares `requires = ["setuptools>=61.0", "wheel"]` and `build-backend = "setuptools.build_meta"`.
- `[project]` sets `name = "fraud_detection"`, `version = "0.1.0"`, `requires-python = ">=3.10"`, `dependencies = ["scikit-learn", "pandas", "numpy"]`.
- `python3 -m build` produces `dist/fraud_detection-0.1.0-*.whl`.

## Why this matters

A `.py` file you copy around is not a deliverable; a wheel is. Once code is packaged:

- `pip install fraud_detection==0.1.0` installs the right code with the right deps — every dev, every CI runner, every Docker image.
- The model registry can record "trained with `fraud_detection==0.1.0`" and a rollback is a single version bump.
- The same wheel goes into a dev venv, a CI runner, a serving container — build once, install anywhere.

`pyproject.toml` is the modern single source of truth for both build config (PEP 517/518) and metadata (PEP 621). The old `setup.py` + `setup.cfg` + `requirements.txt` triad is gone.

## How to run

The lab `pyproject.toml` has five things wrong: missing `[build-system]`, wrong `name`, wrong `version`, wrong `requires-python`, empty `dependencies`. Fix all five, rebuild, verify.

The final shape:

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "fraud_detection"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = ["scikit-learn", "pandas", "numpy"]

[tool.setuptools.packages.find]
where = ["src"]
```

Then:

```bash
cd /root/code/fraud-detection
rm -rf build dist ./*.egg-info
python3 -m build
ls dist/   # expect: fraud_detection-0.1.0-py3-none-any.whl  +  .tar.gz
```

Verify the metadata in the wheel matches what you declared:

```bash
python3 -m zipfile -e dist/fraud_detection-0.1.0-py3-none-any.whl /tmp/wheel-inspect
grep -E "^(Name|Version|Requires-Python|Requires-Dist):" \
  /tmp/wheel-inspect/fraud_detection-0.1.0.dist-info/METADATA
```

A reference [`pyproject.toml`](pyproject.toml) and [`build.sh`](build.sh) are in this directory.

## Key gotchas

- **`name` must use an underscore** (`fraud_detection`) to match `src/fraud_detection/`. Hyphens are normalised in wheel filenames, so the filename alone can mask the bug — the `Name:` line in METADATA is the source of truth.
- **A successful build is not a correct build.** Without `[build-system]`, modern `build` falls back to `setuptools>=40.8.0` and *silently ignores* your `[project]` table. The wheel pops out anyway, with wrong metadata. Always declare `[build-system]`.
- **`python3`, not `python`** on the lab. The grader expects `python3`.
- **Don't commit `dist/`, `build/`, `*.egg-info/`** — they're generated.

The walkthrough has the deeper "why does it work that way" treatment of each of these.

## Resources

- [Python Packaging User Guide — Packaging Python Projects](https://packaging.python.org/en/latest/tutorials/packaging-projects/)
- [PEP 517](https://peps.python.org/pep-0517/) (build-system interface), [PEP 518](https://peps.python.org/pep-0518/) (`pyproject.toml` itself), [PEP 621](https://peps.python.org/pep-0621/) (`[project]` schema)
- [setuptools — Quickstart](https://setuptools.pypa.io/en/latest/userguide/quickstart.html) and [Package discovery](https://setuptools.pypa.io/en/latest/userguide/package_discovery.html)
- [pypa/build](https://github.com/pypa/build)
- [Calendar Versioning](https://calver.org/) — alternative to semver, popular in ML projects
