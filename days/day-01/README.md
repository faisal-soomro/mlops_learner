# Day 1 — Create a Python Virtual Environment for ML

> **Step-by-step run-through with what each step proves and the gotchas hit along the way:** see [walkthrough.md](walkthrough.md). This README is the TL;DR.

## Task

Set up a standardised Python environment for an ML project on the `controlplane` host.

**Acceptance criteria:**

- A venv named `ml-env` exists at `/root/code/ml-env`, created with `python3 -m venv`.
- `numpy`, `pandas`, `scikit-learn`, and `matplotlib` are installed inside it.
- `/root/code/requirements.txt` exists, produced by `pip freeze` from the activated venv.

## Why this matters

Without a venv, every `pip install` writes to system Python — dependency collisions ("project A needs `numpy 1.24`, project B needs `numpy 2.0`") and unreproducible runs ("works on my machine") follow within weeks. A venv gives each project an isolated `site-packages`; `requirements.txt` is the contract that lets anyone reproduce the environment.

This is the floor of MLOps. Everything later — DVC, MLflow, Docker, CI — assumes you can pin and reproduce a Python environment.

## How to run

```bash
bash setup.sh
```

Or by hand:

```bash
mkdir -p /root/code && cd /root/code
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

A reference [`requirements.txt`](requirements.txt) is in this directory; your exact versions will differ.

## Key gotchas

- **`source`, not `./`** — activation must modify the current shell. A subprocess activates a child shell that exits immediately.
- **Don't commit the venv directory.** Only `requirements.txt` goes in git.
- **`pip freeze` captures the full transitive tree** — right for a lockfile, wrong for a library's `install_requires`. Day 3 fixes this with `requirements.in` → `requirements.txt`.
- **Import name ≠ PyPI name.** `import sklearn`, but `pip install scikit-learn`. See Day 3.

## Resources

- [Python docs — venv](https://docs.python.org/3/library/venv.html)
- [PEP 405 — Python Virtual Environments](https://peps.python.org/pep-0405/)
- [pip user guide — Requirements files](https://pip.pypa.io/en/stable/user_guide/#requirements-files)
- [Real Python — Primer on Virtual Environments](https://realpython.com/python-virtual-environments-a-primer/)
