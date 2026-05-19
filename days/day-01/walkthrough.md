# Day 1 — Walkthrough

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

The [README](README.md) covers the task abstractly. This file is the step-by-step run: what you actually do, what each step is supposed to prove, and the small things that bite if you're new to venvs.

## Starting state

The lab's `controlplane` host has system Python 3.x available as `python3`. `/root/code/` may or may not exist yet. No venv. Whatever PyPI packages happen to be installed system-wide are irrelevant — they shouldn't be used.

## Step 1 — create the venv

```bash
mkdir -p /root/code
cd /root/code
python3 -m venv ml-env
```

**What this is supposed to do:** create `/root/code/ml-env/` with its own `bin/`, `lib/`, and `pyvenv.cfg`. After this step, `ml-env/bin/python` is an interpreter that imports from `ml-env/lib/python3.X/site-packages/` — a directory with no third-party packages yet.

**What confirms it worked:**

- `ls ml-env/bin/python` exists.
- `ml-env/bin/python -c "import sys; print(sys.prefix)"` prints `/root/code/ml-env`, not `/usr/...`.

## Step 2 — activate

```bash
source ml-env/bin/activate
```

**What this changes:** prepends `ml-env/bin/` to `PATH` and sets `VIRTUAL_ENV=/root/code/ml-env`. From now on, `python` and `pip` resolve to the venv's binaries.

**Why `source` and not `./`:** activation modifies the current shell. Running the script as a subprocess (`./activate`, `bash activate`) sets the variables in a child shell that exits immediately, leaving your shell unchanged.

Check `which python` — should now show `/root/code/ml-env/bin/python`, not `/usr/bin/python3`.

## Step 3 — upgrade pip, install the four packages

```bash
pip install --upgrade pip
pip install numpy pandas scikit-learn matplotlib
```

**What this is supposed to do:** download wheels for the four top-level packages plus their transitive dependencies (scipy, joblib, threadpoolctl, python-dateutil, pytz, tzdata, pillow, ...) into `ml-env/lib/.../site-packages/`.

**Expected behaviour:**

- Each `Successfully installed ...` line lists multiple packages — most of them are transitive.
- The whole thing should take well under a minute on a reasonable network. Slow installs almost always mean wheels weren't available and pip is compiling from source — on the lab box, wheels should be available for all four.

## Step 4 — freeze

```bash
pip freeze > /root/code/requirements.txt
```

**What `pip freeze` produces:** every installed package with `==<exact-version>`, one per line, alphabetical. This includes the four packages *and* all of their transitive deps — pip can't distinguish "what you asked for" from "what was pulled in."

**Why that's both a feature and a bug:**

- Feature: anyone running `pip install -r requirements.txt` gets the *exact* same versions everywhere — full reproducibility.
- Bug: there's no record of which packages were direct requests. Six months later, when `scipy` and `joblib` show up in the file, you can't tell whether you depended on them directly or whether they're transitives from scikit-learn.

Day 3 fixes this with the `requirements.in` (spec) → `requirements.txt` (lockfile) split.

## Step 5 — verify

```bash
source /root/code/ml-env/bin/activate   # re-source if you opened a new shell
python -c "import numpy, pandas, sklearn, matplotlib; print('ok')"
cat /root/code/requirements.txt
```

**What this proves:**

- All four packages import — confirms install actually wrote files where Python looks.
- The `requirements.txt` is non-empty and contains pinned versions like `numpy==1.26.4`. Exact versions depend on what PyPI was serving on the lab day.

The `import sklearn` part is the trap-spotter: `scikit-learn` is the *package name on PyPI*, `sklearn` is the *import name in Python*. They are deliberately different. (`sklearn` exists as a redirect package on PyPI but should not be used — see Day 3.)

## Gotchas worth remembering

- **`source`, not `./`.** Subprocess activation does nothing to your shell.
- **The venv directory is huge and machine-specific.** It contains compiled `.so` files for the host's architecture. Never commit it. Only commit `requirements.txt`.
- **`pip install` writes to whichever Python is on `PATH`.** Activate first, then install. Installing without activating writes to system Python and gets you nowhere.
- **`pip freeze` captures the transitive tree.** Right for a lockfile, wrong for a library's `install_requires`. Day 3 separates these concerns.

## What this day proves for the rest of the course

Every later tool — DVC, MLflow, Docker images, CI runs — assumes the project has *a* reproducible Python environment. This is the floor. The pattern (create venv, install deps, freeze) is something you'll do hundreds of times; the variations (uv, conda, Docker layers) are all riffs on it.
