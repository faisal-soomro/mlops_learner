# Day 14 — Walkthrough

First pipeline lab. Three plants in `dvc.yaml`, fixed iteratively by running the broken state and letting `dvc repro` name each one. The pattern that emerged here (run broken, capture errors, fix one plant, repeat) is the right Phase 2 default — see [memory: run-broken-state-first].

## Starting state

```yaml
stages:
  process_data:
    cmd: python src/data/process.py           # plant #1: wrong filename
    deps:
      - data/raw/transactions.csv
      - src/data/process_data.py
    outs:
      - data/processed/clean.csv              # plant #2: wrong filename

  split_data:
    cmd: python src/data/split_data.py
    deps:
      - src/data/split_data.py                # plant #3: missing upstream dep
    outs:
      - data/processed/train.csv
      - data/processed/test.csv
```

The scripts (read-only per the task):
- `process_data.py` reads `data/raw/transactions.csv`, writes `data/processed/clean_transactions.csv`
- `split_data.py` reads `data/processed/clean_transactions.csv`, writes `train.csv` + `test.csv`

So the YAML is wrong against the scripts on three counts.

## Step 1 — run the broken state (plant #1 surfaces)

```bash
$ dvc repro
Running stage 'process_data':
> python src/data/process.py
python: can't open file '/root/code/fraud-detection/src/data/process.py': [Errno 2] No such file or directory
ERROR: failed to reproduce 'process_data': failed to run: python src/data/process.py, exited with 2
```

DVC literally ran `python src/data/process.py`. Python can't open the file because it doesn't exist (real filename is `process_data.py`). DVC bubbled Python's exit code up.

**Fix:** `cmd: python src/data/process_data.py`.

## Step 2 — re-run, plant #2 surfaces

```bash
$ dvc repro
Running stage 'process_data':
> python src/data/process_data.py
Processed 15 rows
ERROR: failed to reproduce 'process_data': output 'data/processed/clean.csv' does not exist
```

This is the more interesting failure mode. The script ran successfully — `Processed 15 rows` is its own stdout, and exit code 0. DVC then checked: did the stage produce the `outs` it declared? It looked for `data/processed/clean.csv` (the YAML's claim) and didn't find one — because the script actually wrote `clean_transactions.csv`.

DVC doesn't introspect Python scripts. It only checks named output files exist after the command finishes. Mismatch → error, regardless of whether the script succeeded.

**Fix:** `outs: data/processed/clean_transactions.csv`.

## Step 3 — re-run, plant #3 hides

```bash
$ dvc repro
Running stage 'process_data':
> python src/data/process_data.py
Processed 15 rows
Generating lock file 'dvc.lock'
Updating lock file 'dvc.lock'

Running stage 'split_data':
> python src/data/split_data.py
Train: 12 rows, Test: 3 rows
Updating lock file 'dvc.lock'
```

Pipeline ran end to end. Both stages succeeded. `dvc.lock` generated. Looks done.

**It isn't** — plant #3 is still in there. `split_data` is missing the `data/processed/clean_transactions.csv` dep, but that didn't cause a runtime failure because:

1. First-run `dvc repro` has no `dvc.lock` to compare against, so every stage is stale and runs
2. DVC executes stages in YAML-declaration order, which happened to be the right order
3. `split_data` reads `clean_transactions.csv` directly (the script does — DVC doesn't care)
4. Both `outs` get produced; DVC moves on

The breakage is silent — only visible on a **future** `dvc repro` after `transactions.csv` changes: `process_data` would re-run (its dep changed), but `split_data` would *not* re-run (DVC sees no edge between them).

Surfaced via:

```bash
$ dvc dag
+--------------+
| process_data |
+--------------+
+------------+
| split_data |
+------------+
```

Two disconnected boxes. No edge. That's the bug.

**Fix:** add `data/processed/clean_transactions.csv` to `split_data.deps`.

## Step 4 — re-run with plant #3 fixed

```bash
$ dvc repro
Stage 'process_data' didn't change, skipping
Running stage 'split_data':
> python src/data/split_data.py
Train: 12 rows, Test: 3 rows
Updating lock file 'dvc.lock'

$ dvc dag
+--------------+
| process_data |
+--------------+
        *
        *
        *
 +------------+
 | split_data |
 +------------+

$ dvc status
Data and pipelines are up to date.
```

Two things to note in that `dvc repro` output:

1. **`Stage 'process_data' didn't change, skipping`** — DVC checked `process_data`'s deps against `dvc.lock`, hashes matched, skipped. Hash-based staleness in action.
2. **Only `split_data` re-ran** — its `deps` changed (`dvc.yaml` was edited), so it's stale relative to `dvc.lock`. Per-stage staleness, not whole-pipeline.

The asterisks in `dvc dag` are DVC's ASCII edge representation. `process_data → split_data` is now the real DAG.

## Why plant #3 was the most important one

Plants #1 and #2 are loud failures — `dvc repro` errors immediately. Annoying but easy: the tool tells you exactly what's broken. Fix the filename, move on.

Plant #3 is silent. The pipeline produces correct outputs on first run; you commit, push, and feel done. Two days later your teammate updates `transactions.csv`, runs `dvc repro`, sees only `process_data` re-run, and trains a model on stale split data. Nobody knows for weeks.

The lesson: **always `dvc dag` after editing `dvc.yaml`**. Visualise the graph, confirm the edges you expect are there. Don't trust that "first run worked" means the pipeline is correctly wired.

## Process lesson — capture errors, don't predict them

This was the first lab where Phase 2 ran the broken command first instead of fixing everything blind. Hugely better:

- The three error messages were specific enough to self-diagnose each plant
- The walkthrough captured *real* output, not guessed-at-error-text-from-the-README
- The cascade of failures (plant #1 → #2 → #3 surfacing differently) told the actual story

Days 12 and 13 didn't do this — added them to [BACKLOG.md](../../BACKLOG.md) for retroactive capture.

## Connections

- New pipeline material in [notes/dvc.md § Pipelines](../../notes/dvc.md#pipelines--dvcyaml-and-dvclock) — `dvc.yaml` shape, DAG construction, `dvc.lock` staleness model, failure modes
- The "run broken state first" pattern is now memory: `run-broken-state-first`
