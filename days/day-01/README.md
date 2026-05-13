# Day 1 — Create a Python Virtual Environment for ML

## Task

Set up a standardised Python environment for an ML project on the `controlplane` host.

**Acceptance criteria:**
- A venv named `ml-env` exists at `/root/code/ml-env`, created with `python3 -m venv`.
- `numpy`, `pandas`, `scikit-learn`, and `matplotlib` are installed inside it.
- `/root/code/requirements.txt` exists, produced by `pip freeze` from the activated venv.

## Why this matters

Without a virtual environment, every `pip install` writes to the system Python. Two consequences bite quickly:

- **Dependency collisions.** Project A needs `numpy==1.24`, project B needs `numpy==2.0`. Only one wins, and the other silently breaks.
- **Unreproducible runs.** "Works on my machine" because your laptop has whatever versions accumulated over a year. A teammate clones the repo and gets different results — sometimes silently wrong ones (different `scikit-learn` defaults, different RNG behaviour).

A venv gives each project an isolated `site-packages`. `requirements.txt` (from `pip freeze`) is the contract that lets anyone — a teammate, a CI runner, a Docker build — recreate that exact environment.

This is the floor of MLOps. Everything else (DVC, MLflow, Docker images, CI pipelines) assumes you can pin and reproduce a Python environment.

## Use case

A data science team at xFusionCorp is starting a new churn-prediction project. Three people will work on it, plus a nightly training job on a build server. Day 1 of the project: agree on the environment.

- Each engineer activates `ml-env` locally, installs from `requirements.txt`, and gets the same library versions.
- The CI job in week 2 will `pip install -r requirements.txt` to reproduce training.
- When someone adds `xgboost` later, they re-freeze and commit the updated `requirements.txt` — the change is visible in git diff.

Without this, week 4 will involve someone debugging why their model scores 0.82 AUC locally and 0.79 in CI.

## How to run

On the lab `controlplane` host:

```bash
bash setup.sh
```

Or step by step (what `setup.sh` does):

```bash
mkdir -p /root/code
cd /root/code
python3 -m venv ml-env
source ml-env/bin/activate
pip install --upgrade pip
pip install numpy pandas scikit-learn matplotlib
pip freeze > /root/code/requirements.txt
```

Verify:

```bash
source /root/code/ml-env/bin/activate
python -c "import numpy, pandas, sklearn, matplotlib; print('ok')"
cat /root/code/requirements.txt
```

A reference `requirements.txt` is included in this directory — your exact versions will differ depending on the lab's Python and PyPI state at the time you run it.

## Notes & gotchas

- **`source`, not `./`** — activating a venv must run in your current shell (`source ml-env/bin/activate`). Running it as a subprocess does nothing to your shell.
- **`python3 -m venv` vs `virtualenv`** — `venv` ships with Python 3.3+. `virtualenv` is the older third-party tool; functionally similar, no reason to reach for it on a fresh project.
- **`pip freeze` captures the full transitive tree**, including pinned versions of dependencies-of-dependencies. That's what you want for reproducibility, not what you want for a library's `install_requires`. (Later days will introduce `uv` and `pyproject.toml`, which separate these concerns more cleanly.)
- **Don't commit the venv directory itself.** Only `requirements.txt` goes in git.

## Resources

- [Python docs — venv](https://docs.python.org/3/library/venv.html) — official, short, worth reading once.
- [PEP 405 — Python Virtual Environments](https://peps.python.org/pep-0405/) — the design rationale behind `venv`.
- [pip user guide — Requirements files](https://pip.pypa.io/en/stable/user_guide/#requirements-files) — what `pip freeze` produces and how `pip install -r` consumes it.
- [Real Python — Primer on Virtual Environments](https://realpython.com/python-virtual-environments-a-primer/) — readable long-form intro.
- [Hitchhiker's Guide — Pipenv & Virtual Environments](https://docs.python-guide.org/dev/virtualenvs/) — the wider ecosystem (venv, virtualenv, pipenv, uv) at a glance.
