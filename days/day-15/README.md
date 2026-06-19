# Day 15 — Parameterize a DVC Pipeline

**TL;DR:** Single plant — `params.yaml` has `n_estimator` (singular), but `dvc.yaml` and `train.py` both reference `n_estimators` (plural). Fix the key, run the pipeline, then change the value and watch only the `train` stage re-run.

## Task

A three-stage pipeline (`process_data`, `split_data`, `train`) already exists. The `train` stage's `params` block references `n_estimators`, but `dvc repro` fails. Fix `params.yaml`, run the pipeline, then demonstrate parameter-driven staleness by changing `n_estimators` and re-running.

### Acceptance criteria

- `params.yaml` has key `n_estimators` (matching what `dvc.yaml` and `train.py` reference)
- `dvc repro` runs all three stages end to end
- After bumping `n_estimators` to a new value (e.g. `200`), `dvc repro` re-runs **only** the `train` stage
- `dvc.lock` records the new parameter value
- `models/model.pkl` is regenerated

## Starting state (the plant)

```yaml
# params.yaml
n_estimator: 100      # ← singular; dvc.yaml + train.py both want plural "n_estimators"
```

The script (`src/models/train.py`, read-only) reads `params["n_estimators"]`. The pipeline (`dvc.yaml`) declares `params: - n_estimators`. So the truth is "plural" in two places; `params.yaml` is the odd one out.

## How `params` works in `dvc.yaml`

Adding a `params:` block to a stage tells DVC: "these named keys, looked up in `params.yaml` (default), are dependencies for this stage." DVC reads the values, includes them in the stage's hash, and writes them into `dvc.lock`. Change the value → hash changes → stage is stale → re-runs.

```yaml
train:
  cmd: python src/models/train.py
  deps:
    - data/processed/train.csv
    - src/models/train.py
  params:
    - n_estimators            # ← must resolve to a key in params.yaml
  outs:
    - models/model.pkl
```

Two important things:

1. **DVC doesn't pass parameters to the script.** The script reads `params.yaml` itself (via `yaml.safe_load(...)`). The `params:` block in `dvc.yaml` is purely for DVC's dependency tracking — so DVC knows when to re-run.
2. **Every name in `params:` must resolve to a key in `params.yaml`.** Missing keys are an error. That's the plant here.

## Diagnosis table

| Symptom (running `dvc repro`) | Probable cause | Fix |
|---|---|---|
| `Missing params: ['n_estimators']` or similar | Key in `params.yaml` doesn't match what `dvc.yaml` declares | Rename `n_estimator` → `n_estimators` in `params.yaml` |
| `KeyError: 'n_estimators'` from inside Python | Same root cause — the script also reads `n_estimators` | Same fix |

## Expected final `params.yaml`

See [`params.yaml`](params.yaml) in this directory:

```yaml
n_estimators: 100
```

## How to run

```bash
cd /root/code/fraud-detection

# Fix the plant (one-letter edit)
# n_estimator: 100  →  n_estimators: 100

# Run the full pipeline
dvc repro

# Demonstrate parameter-driven re-run
# Bump n_estimators to 200 in params.yaml
dvc repro

# Inspect what's in dvc.lock for the train stage
grep -A5 "params:" dvc.lock | head -20

# Inspect the regenerated model
ls -la models/model.pkl
```

## Gotchas

- **`params.yaml` is the default param file**, but you can point at others: `params: - other_file.yaml: - learning_rate` (rarely needed early on).
- **Nested params use dotted keys.** If `params.yaml` has `model: { n_estimators: 100 }`, reference it as `model.n_estimators` in the `params:` list.
- **Don't list parameters the script doesn't actually use.** Listing them anyway means DVC re-runs the stage when those unused params change — surprising and noisy.
- **`params.yaml` is committed to git.** It's source-of-truth config, not secrets. Treat it like a values file.
- **Hand-edit `dvc.yaml` and `params.yaml`.** No CLI helpers exist — same as Day 14.
- **The script imports `yaml.safe_load`.** Without that, parameter changes wouldn't reach the model — DVC's dep tracking would still notice the change and re-run, but the script would use stale hardcoded values. DVC doesn't *enforce* that the script actually reads `params.yaml`; it just tracks the param values as deps. Discipline is on the author.

## Why this matters

Hyperparameters are the most-tuned thing in any ML project. Hard-coding them in `train.py` means every experiment is a code change — clutters git history, makes diffs noisy, and obscures the actual "what did I try" trail. `params.yaml` externalises them so:

- Experiments are config diffs, not code diffs
- DVC can hash params and re-run only what's stale
- `dvc.lock` becomes a complete record of "this model was trained with these hyperparameters on this data" — the audit trail every regulator-friendly ML team needs

This pattern extends through Domain 3 (MLflow tracking) and Domain 4 (Optuna/FLAML for hyperparameter sweeps) — `params.yaml` is the seed of the experiment-tracking story.

## Use case

You're iterating on `n_estimators`. Try 100, 200, 500, 1000. Each is a one-line edit + `dvc repro`. DVC re-trains only what's stale (just the `train` stage — data prep is untouched). `dvc.lock` keeps a record of which param produced which model file. Six months later, "what hyperparameters did the model deployed in May use?" is `git log dvc.lock`.

## Resources

- [DVC docs — Parameters](https://dvc.org/doc/user-guide/project-structure/dvcyaml-files#parameters)
- [`params` in `dvc.yaml`](https://dvc.org/doc/user-guide/pipelines/defining-pipelines#parameters)
- [notes/dvc.md § Pipelines](../../notes/dvc.md#pipelines--dvcyaml-and-dvclock)
