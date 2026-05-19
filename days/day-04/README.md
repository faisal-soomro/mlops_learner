# Day 4 — Create a Standard ML Project Structure

> **Step-by-step run-through:** see [walkthrough.md](walkthrough.md). For the wider concepts (raw/processed split, `__init__.py` vs PEP 420, src/ vs flat), see [`notes/ml-project-layout.md`](../../notes/ml-project-layout.md). This README is the TL;DR.

## Task

The fraud-detection project at `/root/code/fraud-detection/` doesn't match the team's standard layout. Bring it in line.

**Acceptance criteria:**
- Directory tree matches the target exactly (see below).
- Every subdirectory under `src/` contains an `__init__.py`.
- `requirements.txt` lists `scikit-learn`, `pandas`, `numpy`, `mlflow` — one per line, using the canonical PyPI name `scikit-learn` (not `sklearn`).
- `README.md` begins with `# fraud-detection`.

Target layout:

```
fraud-detection/
├── data/
│   ├── raw/
│   └── processed/
├── models/
├── notebooks/
├── src/
│   ├── data/
│   ├── features/
│   ├── models/
│   └── utils/
├── tests/
├── configs/
├── requirements.txt
└── README.md
```

## Why this matters

A consistent layout is the cheapest piece of MLOps infrastructure you can buy: a new joiner finds things in minutes, and every later tool (DVC, MLflow, Docker, CI) assumes the standard shape.

For the cross-cutting writeup — what each directory is for, `raw/` vs `processed/` reproducibility, `__init__.py` vs namespace packages, `src/` vs flat layout — see [`notes/ml-project-layout.md`](../../notes/ml-project-layout.md). The sections below focus on this lab.

## Use case

A new analyst joins the team Monday. Without a standard layout, day one is "where does data go? where do I put a notebook? how do I import a function I just wrote?". With one, they clone the repo and know within five minutes. Same when you `cd` into a teammate's project six months later, or when CI needs to find the training entrypoint.

This isn't a hypothetical — Cookiecutter Data Science (Day 9) exists exactly because every team kept reinventing roughly this layout. The structure here is a minimal version of it.

## How to run

Run the fix script against the broken project:

```bash
PROJECT_DIR=/root/code/fraud-detection bash fix.sh
```

Or do it by hand:

```bash
cd /root/code/fraud-detection

# 1. Create any missing directories
mkdir -p data/raw data/processed models notebooks \
         src/data src/features src/models src/utils \
         tests configs

# 2. __init__.py in every src/ subdir
touch src/__init__.py \
      src/data/__init__.py \
      src/features/__init__.py \
      src/models/__init__.py \
      src/utils/__init__.py

# 3. requirements.txt (overwrite — task specifies the four lines)
cat > requirements.txt <<'EOF'
scikit-learn
pandas
numpy
mlflow
EOF

# 4. README.md must start with the right heading
[ -f README.md ] || echo "# fraud-detection" > README.md
head -1 README.md   # confirm it starts with "# fraud-detection"
```

Verify:

```bash
tree -L 2 /root/code/fraud-detection
find /root/code/fraud-detection/src -name __init__.py
head -1 /root/code/fraud-detection/README.md
cat /root/code/fraud-detection/requirements.txt
```

A reference skeleton matching the target layout is in [`fraud-detection/`](fraud-detection/) in this directory.

### The actual broken state from the lab

```
fraud-detection/
├── data/                # empty — missing raw/ and processed/
├── models/
├── notebooks/
├── src/
│   ├── data/__init__.py
│   ├── feature/__init__.py   # ✗ singular, must be `features`
│   ├── models/__init__.py
│   └── util/__init__.py      # ✗ singular, must be `utils`
├── README.md
└── requirements.txt
```

Diagnosis:

| Issue | Fix |
|---|---|
| `data/` missing `raw/` and `processed/` | `mkdir -p data/raw data/processed` |
| `src/feature/` — wrong name | **rename** to `src/features/` (do *not* create alongside) |
| `src/util/` — wrong name | **rename** to `src/utils/` |
| Missing `tests/` and `configs/` | `mkdir -p tests configs` |
| `requirements.txt` — wrong contents | overwrite with the four required lines |
| `README.md` — wrong heading | first line must be `# fraud-detection` |

The rename trap: `mkdir -p src/features` does **not** delete `src/feature`. Running it on the broken state leaves both directories side by side, and the lab grader (rightly) fails the check. Use `mv src/feature src/features` to rename, not `mkdir`.

```bash
cd /root/code/fraud-detection
mv src/feature src/features
mv src/util    src/utils
mkdir -p data/raw data/processed tests configs
touch src/__init__.py   # top-level marker; harmless if already there
cat > requirements.txt <<'EOF'
scikit-learn
pandas
numpy
mlflow
EOF
head -1 README.md   # must print: # fraud-detection
```

`fix.sh` does all of this idempotently, and handles the edge case where both `src/feature/` and `src/features/` already exist (merges and removes the singular one).

## Notes & gotchas

Lab-specific:

- **The rename trap.** `mkdir -p src/features` does *not* delete `src/feature`. Use `mv src/feature src/features` to rename.
- **`requirements.txt` here is a spec, not a lockfile.** The task asks for unpinned names; that's fine for the layout exercise. Day 3 covered the pinned lockfile via `uv pip compile`.
- **The four required deps are exactly `scikit-learn`, `pandas`, `numpy`, `mlflow`** — one per line, canonical PyPI name `scikit-learn` (not `sklearn`).
- **README first line must be `# fraud-detection`** — the grader checks `head -1`.

Cross-cutting context — `raw/` vs `processed/`, `__init__.py` vs PEP 420 namespace packages, `src/` vs flat layout — lives in [`notes/ml-project-layout.md`](../../notes/ml-project-layout.md).

## Resources

- [Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/) — the de facto standard ML project layout. The structure in this task is a close subset.
- [Hypermodern Python — Project structure](https://cjolowicz.github.io/posts/hypermodern-python-01-setup/) — readable take on `src/` layout, packaging, and tooling for modern Python.
- [PEP 328 — Imports](https://peps.python.org/pep-0328/) — relative vs absolute imports; matters once `src/` has cross-module imports.
- [PEP 420 — Namespace packages](https://peps.python.org/pep-0420/) — what happens without `__init__.py`, and why explicit files are still the safer default.
- [`setuptools` — src layout](https://setuptools.pypa.io/en/latest/userguide/package_discovery.html#src-layout) — the packaging-side rationale for keeping code in `src/`.
