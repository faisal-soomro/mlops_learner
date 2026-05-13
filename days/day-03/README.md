# Day 3 — Fix a Broken `uv` Lockfile Specification

## Task

Fix a broken `requirements.in` for the fraud-detection project, then compile it into a pinned lockfile with `uv`.

**Acceptance criteria:**
- `/root/code/fraud-detection/requirements.in` lists exactly four top-level packages: `scikit-learn`, `mlflow`, `pandas`, `numpy`.
- Each one carries a version constraint that `uv` can actually resolve against PyPI.
- `uv pip compile requirements.in -o requirements.txt` succeeds.
- The resulting `requirements.txt` pins every top-level package with `==`, and includes the transitive dependencies `uv` resolved.

## Why this matters

Day 1 used `pip freeze` to produce a `requirements.txt`. That works, but it has a quiet problem: `pip freeze` captures whatever happens to be installed right now — including packages you installed by accident, packages from a previous experiment, and transitive deps tangled together with your real top-level dependencies. There's no record of which ones *you* actually asked for.

The `requirements.in` → `requirements.txt` split fixes this:

- **`requirements.in`** — the *spec*. Hand-edited. Lists only what you directly depend on, with loose version constraints (`pandas>=2.0,<3`). Small, readable, the source of truth for intent.
- **`requirements.txt`** — the *lockfile*. Machine-generated. Pins every package — including transitive — to an exact version with `==`. Big, ugly, the source of truth for reproducibility.

`uv pip compile` reads the spec, resolves the full dependency tree against PyPI, and writes the lockfile. `uv pip sync requirements.txt` then installs exactly that set into a venv — nothing more, nothing less. (Note: `sync` removes anything not in the lockfile, which is the whole point.)

Why `uv` and not `pip-tools`? Same workflow, same file formats, but `uv` is ~10–100× faster because it's written in Rust and uses a smarter resolver. Cold installs that took minutes with pip take seconds.

This is the floor for everything reproducible: CI installs from the lockfile, Docker images install from the lockfile, your teammate installs from the lockfile. Spec gets reviewed in PRs; lockfile is regenerated when you change the spec.

## Use case

The fraud-detection team is starting a new model. They pin `scikit-learn>=1.4,<2` in `requirements.in` because they want a recent version but don't want to break when 2.0 lands. They compile, commit both files, and the CI pipeline installs from `requirements.txt`.

Three months later, someone wants to try `scikit-learn` 1.5's new pipeline features. They bump the constraint in `requirements.in`, run `uv pip compile`, and the diff in `requirements.txt` is visible in the PR — including any transitive dep that changed. Reviewers can see whether `scipy` jumped a major version on the side, and decide whether to test more carefully.

Without the split, you either pin everything by hand (tedious, drifts) or pin nothing (un-reproducible). With it, intent and result are both versioned.

## How to diagnose the broken `requirements.in`

Read the file and check each line against the criteria. Common problems planted in lab versions:

| Symptom | Example | Fix |
|---|---|---|
| Typo in package name | `scikitlearn`, `scikit_learn` | `scikit-learn` |
| Wrong package | `pandas-extras`, `mlflow-skinny` (when `mlflow` is asked for) | `mlflow` |
| Impossible version | `numpy==999.0` | a real released version, e.g. `numpy>=1.26,<3` |
| Bad operator / typo | `pandas=2.0` (single `=`), `pandas~2.0` | `pandas==2.0` or `pandas>=2.0,<3` |
| Extra top-level packages | `tensorflow`, `xgboost`, etc. that aren't in the four | delete |
| Missing one of the four | only three packages listed | add the missing one |
| No constraint at all | bare `pandas` | task requires a constraint — add one |

A reference [`requirements.in`](requirements.in) is in this directory.

### The actual broken file from the lab

```
# requirements.in
# Fraud detection project dependencies
sklearn
mlflow>=100.0
numpy
```

Four things wrong:

| Line | Problem | Fix |
|---|---|---|
| `sklearn` | Wrong PyPI name. `sklearn` is a deprecated stub package that now errors on install — the *import* is `sklearn` but the *PyPI package* is `scikit-learn`. Also no version constraint. | `scikit-learn>=1.4,<2` |
| `mlflow>=100.0` | Unsatisfiable — mlflow is at ~2.x, there is no 100.0. | `mlflow>=2.10,<3` |
| `numpy` | No version constraint (task requires one). | `numpy>=1.26,<3` |
| *(missing)* | `pandas` not listed at all. | add `pandas>=2.0,<3` |

The `sklearn`-vs-`scikit-learn` trap is worth remembering: the *import name* and the *PyPI package name* are different. If you ever see `sklearn` in a `requirements.in` or a `pyproject.toml` in real code, treat it as a bug — the stub was published years ago to redirect users, and in 2023 the maintainers made it raise an error on install to stop the confusion from propagating.

## How to run

On the lab box:

```bash
cd /root/code/fraud-detection

# 1. Fix requirements.in (see diagnosis table above)

# 2. Compile to a pinned lockfile
uv pip compile requirements.in -o requirements.txt

# 3. Verify: every top-level package pinned with ==, plus transitives
grep -E '^(scikit-learn|mlflow|pandas|numpy)==' requirements.txt
wc -l requirements.txt   # should be >> 4 (transitive deps are listed too)
```

Optional — install into a venv to prove the lockfile resolves cleanly:

```bash
uv venv .venv
uv pip sync --python .venv/bin/python requirements.txt
```

## Notes & gotchas

- **`uv pip compile` is deterministic given the spec, the Python version, and the platform.** That's a *feature* — same inputs, same lockfile. But it also means a lockfile generated on macOS may differ from one generated on Linux (different `manylinux` wheels available). For team workflows, compile on the same platform you deploy on (usually Linux), or use `uv pip compile --universal` for a cross-platform lockfile.
- **Hashes.** `uv pip compile --generate-hashes` adds SHA hashes for every wheel. Standard for production; pip refuses to install a lockfile with hashes if anything in it doesn't hash-match. Worth turning on for any image that ships to prod.
- **`uv pip compile` vs `uv lock`.** Two different worlds:
  - `uv pip compile` — pip-tools-style, works with `requirements.in`/`requirements.txt`. What this task uses.
  - `uv lock` — the modern `pyproject.toml` + `uv.lock` workflow. More features (workspaces, dev dependency groups, scripts), but assumes a `pyproject.toml`. Later days will use this.
- **Don't hand-edit `requirements.txt`.** Edit `requirements.in`, recompile. The lockfile is generated output.

## Resources

- [`uv` docs — pip interface](https://docs.astral.sh/uv/pip/) — drop-in commands (`uv pip compile`, `uv pip sync`).
- [`uv` docs — Locking and syncing](https://docs.astral.sh/uv/concepts/projects/sync/) — modern `uv lock` workflow (you'll use this later).
- [pip-tools README](https://github.com/jazzband/pip-tools) — the original spec→lockfile tool `uv` is compatible with. Useful background.
- [PEP 440 — Version specifiers](https://peps.python.org/pep-0440/) — what `>=`, `<`, `~=`, `==` actually mean.
- [Astral blog — Introducing `uv`](https://astral.sh/blog/uv) — context on why `uv` exists and what it replaces.
