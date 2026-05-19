# Day 4 — Walkthrough

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

The [README](README.md) covers the target layout and the diagnosis table. This file is the run-through: order of operations, the rename trap, and how to confirm the grader will pass. For the cross-cutting writeup on the layout itself (raw/processed split, `__init__.py` mechanics, src/ vs flat), see [`notes/ml-project-layout.md`](../../notes/ml-project-layout.md).

## Starting state

The fraud-detection project at `/root/code/fraud-detection/` looks like this:

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

Five distinct things are wrong; one of them (the singular `feature`/`util` dirs) is a trap if you reach for `mkdir`.

## Step 1 — rename the singular directories, don't `mkdir` alongside

```bash
cd /root/code/fraud-detection
mv src/feature src/features
mv src/util    src/utils
```

**The trap:** `mkdir -p src/features` does *not* delete `src/feature`. If you reach for `mkdir`, the result is *both* directories side by side, and the grader (rightly) fails the layout check because there's a stray `src/feature/`.

**What `mv` does instead:** moves the directory *and* its `__init__.py` to the new name in one operation. After this, `src/feature` no longer exists.

**Sanity check:**

```bash
ls src/
# expect: data  features  models  utils
```

No singular forms left.

## Step 2 — create the missing directories

```bash
mkdir -p data/raw data/processed tests configs
```

**What this fixes:**

- `data/raw/` and `data/processed/` — the immutable-input vs derived-output split. See [`notes/ml-project-layout.md`](../../notes/ml-project-layout.md#dataraw-vs-dataprocessed).
- `tests/` — the place pytest will look.
- `configs/` — YAML/JSON configs separated from code (Day 32 will use this).

`mkdir -p` is idempotent — if a directory already exists, it's a no-op, not an error.

## Step 3 — `__init__.py` everywhere under `src/`

```bash
touch src/__init__.py \
      src/data/__init__.py \
      src/features/__init__.py \
      src/models/__init__.py \
      src/utils/__init__.py
```

**Why `touch` (and why even an empty file matters):** `__init__.py` marks the directory as a Python *package*. Without it, Python 3.3+ treats the directory as a namespace package — which mostly works but breaks linters, test runners, and editable installs in subtle ways. Empty is fine; presence is what matters.

The renames in Step 1 should have brought `__init__.py` over with their directories. `touch` here is the safety net — if any are missing, this creates them; if all are present, it's a no-op (updates mtime, harmless).

## Step 4 — `requirements.txt` with the four exact lines

```bash
cat > requirements.txt <<'EOF'
scikit-learn
pandas
numpy
mlflow
EOF
```

**Grader requirements:**

- Exactly these four packages, one per line.
- Canonical PyPI name `scikit-learn` — *not* `sklearn` (that's the deprecated stub; see Day 3).
- No version constraints (this lab is a layout exercise, not a pinning one).

**The `cat > ... <<'EOF'` form** overwrites whatever was there before — useful because the broken state likely has the wrong contents, not just a missing file.

## Step 5 — README first line

```bash
head -1 README.md
# must print: # fraud-detection
```

If it doesn't:

```bash
echo "# fraud-detection" > README.md   # overwrites; only if README is wrong
```

Be careful with the overwrite — if the existing README has substantive content, prepend rather than replace.

## Step 6 — verify

```bash
tree -L 2 /root/code/fraud-detection
find /root/code/fraud-detection/src -name __init__.py
cat /root/code/fraud-detection/requirements.txt
head -1 /root/code/fraud-detection/README.md
```

Compare against the target layout in the README. Everything that should be there, is. Nothing that shouldn't (`src/feature`, `src/util`) is.

## Or: `fix.sh`

The [`fix.sh`](fix.sh) in this directory wraps all of the above idempotently. It also handles the edge case where both `src/feature/` *and* `src/features/` already exist (merges and removes the singular one).

```bash
PROJECT_DIR=/root/code/fraud-detection bash fix.sh
```

## Gotchas worth remembering

- **`mkdir` does not rename.** Use `mv` for the singular→plural fix. `mkdir` leaves both directories.
- **`scikit-learn`, not `sklearn`.** Same as Day 3. The stub raises on install.
- **`__init__.py` even when empty.** Namespace packages "mostly work" — until they don't.
- **Don't commit `data/raw/` or `data/processed/`.** Both should be gitignored. DVC (Days 10+) handles real data versioning.

## What this day proves for the rest of the course

Every later tool assumes the standard layout:

- DVC (Days 10–19) tracks `data/raw/` and `data/processed/`.
- MLflow (Days 20–30) writes artifacts under a convention that maps to `models/`.
- Docker images (Days 50–56) `COPY src/ /app/src/`.
- CI workflows run `pytest tests/`.
- Training entrypoints live at `src/models/train.py` by convention.

Get the skeleton right once; every later day inherits it.
