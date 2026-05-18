# Day 4 — Create a Standard ML Project Structure

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

A consistent layout is the cheapest piece of MLOps infrastructure you can buy. It pays off every time someone new opens the repo — and it makes the rest of the course easier, because every later tool (DVC, MLflow, Docker, CI) expects to find things in predictable places.

The structure encodes three separations that matter:

- **Raw vs processed data.** `data/raw/` is *immutable input* — never edit, never overwrite. `data/processed/` is *derived output* — regenerable from `raw/` + code. This split is the precondition for reproducibility: if `processed/` is lost, you can rebuild it; if `raw/` is lost, you have a real problem. Later, DVC will track both and assume this split.
- **Code vs notebooks.** `src/` is the library — importable, testable, version-controlled, reviewed. `notebooks/` is exploration — messy, throwaway, useful for plots and one-off analysis. Logic that matters migrates from `notebooks/` to `src/` when it stops being exploratory.
- **Code by lifecycle stage.** `src/data/` (loading, cleaning), `src/features/` (feature engineering), `src/models/` (training, evaluation), `src/utils/` (cross-cutting helpers). Not the only way to slice it, but matches the stages of an ML pipeline so people can find things by intent.

`__init__.py` (even empty) marks a directory as a Python *package* — meaning `from src.models.train import train_model` works. Without it, modern Python will treat the directory as a "namespace package", which often works but breaks in subtle ways (tooling that walks packages, editable installs, some test runners). Always include the file.

`configs/` separates *what to run* from *how to run it*. Hyperparameters, data paths, model names — all in YAML/JSON, not hardcoded. Day 32 will lean on this when we wire training to a YAML config.

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

- **Don't delete `data/raw/` casually.** Even if it looks empty in the lab, the convention is that raw data is sacred. If the lab grader checks the layout but the project later receives real data, an empty `raw/` directory is fine; a missing one breaks scripts that `open("data/raw/...")`.
- **`__init__.py` vs namespace packages.** Python 3.3+ allows packages without `__init__.py` (PEP 420). They mostly work, but explicit `__init__.py` files are still the safer default — every linter, test runner, and packaging tool understands them; not all understand namespace packages.
- **`src/` layout vs flat layout.** Some Python projects put package code directly at the repo root (flat layout). The `src/` layout (used here) prevents accidental imports from a half-installed package and forces you to install the project before importing it. For an ML project this is overkill for now but standard once you start packaging (Day 7).
- **`requirements.txt` here is a *spec*, not a lockfile.** Day 3 produced a pinned lockfile via `uv pip compile`. Day 4's requirements.txt is the loose, hand-edited spec — same role as `requirements.in`. The task asks for unpinned names, which is fine for the layout exercise; in a real project you'd still compile this to a lockfile.
- **Don't put data in git.** `data/raw/` and `data/processed/` should be gitignored. DVC (Days 10–19) handles the actual data versioning.

## Resources

- [Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/) — the de facto standard ML project layout. The structure in this task is a close subset.
- [Hypermodern Python — Project structure](https://cjolowicz.github.io/posts/hypermodern-python-01-setup/) — readable take on `src/` layout, packaging, and tooling for modern Python.
- [PEP 328 — Imports](https://peps.python.org/pep-0328/) — relative vs absolute imports; matters once `src/` has cross-module imports.
- [PEP 420 — Namespace packages](https://peps.python.org/pep-0420/) — what happens without `__init__.py`, and why explicit files are still the safer default.
- [`setuptools` — src layout](https://setuptools.pypa.io/en/latest/userguide/package_discovery.html#src-layout) — the packaging-side rationale for keeping code in `src/`.
