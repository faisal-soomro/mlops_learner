# Day 15 — Walkthrough

Parameter wiring lab. Single plant — a key typo in `params.yaml`. The interesting half of the lab is the second `dvc repro`, which proves parameter changes drive per-stage staleness.

## Starting state

Three-stage pipeline already correct from Day 14. Added:

- `src/models/train.py` reads `params["n_estimators"]`, trains a RandomForest, writes `models/model.pkl`
- `dvc.yaml` has a new `train` stage with `params: - n_estimators`
- `params.yaml` exists with the **wrong key**:

```yaml
# params.yaml
n_estimator: 100      # ← singular; everyone else expects plural
```

## Step 1 — run the broken state

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

ERROR: failed to reproduce 'train': Parameters 'n_estimators' are missing from 'params.yaml'.
```

DVC named the plant precisely — `Parameters 'n_estimators' are missing from 'params.yaml'`. Three things to note:

1. **First two stages succeeded** because they don't declare any `params`. The plant was scoped to `train`.
2. **The error came from DVC's dep resolution, not from Python.** DVC reads `params.yaml`, looks up the names declared in `params:`, fails fast. The script never ran — no `KeyError` traceback because no `train.py` invocation.
3. **`dvc.lock` was partially updated** — `process_data` and `split_data` are now recorded, just not `train`. Next `dvc repro` will hash-match them and skip.

This is the run-broken-state-first pattern paying off — yesterday's process change ([memory: run-broken-state-first]) immediately gave us the exact error to fix.

## Step 2 — fix the plant

One-letter edit in `params.yaml`:

```yaml
n_estimators: 100        # singular → plural
```

```bash
$ dvc repro
Stage 'process_data' didn't change, skipping
Stage 'split_data' didn't change, skipping
Running stage 'train':
> python src/models/train.py
Trained RandomForestClassifier with n_estimators=100
Updating lock file 'dvc.lock'
```

`process_data` and `split_data` hash-matched against `dvc.lock` from Step 1's partial run, so they skipped. Only `train` executed. `dvc.lock` updated with `train`'s entry.

## Step 3 — demonstrate parameter-driven staleness

Bumped `n_estimators` to 200 in `params.yaml`. Re-ran:

```bash
$ dvc repro
Stage 'process_data' didn't change, skipping
Stage 'split_data' didn't change, skipping
Running stage 'train':
> python src/models/train.py
Trained RandomForestClassifier with n_estimators=200
Updating lock file 'dvc.lock'
```

This is the lab's actual lesson. The data didn't change. The script didn't change. Only one number in one config file changed — and DVC:

1. Re-hashed `train`'s deps (file hashes plus the value of `n_estimators` from `params.yaml`)
2. Found a mismatch with `dvc.lock`'s recorded hash
3. Re-ran `train` (and only `train`)
4. Updated `dvc.lock` with the new param value and the new model artifact's hash

`dvc.lock` is now a per-experiment record: "this `model.pkl` was trained with `n_estimators=200` on this `train.csv` using this `train.py`." Six months from now, `git log dvc.lock` is the audit trail.

## How `params:` works (the mental model)

DVC's `params:` block is a *dependency declaration*, not a parameter-passing mechanism:

- **The script reads `params.yaml` itself** via `yaml.safe_load`. DVC doesn't pass env vars or argv.
- **DVC's job is staleness.** It reads the named values, includes them in the stage's hash, writes them to `dvc.lock`. Change a value → hash changes → stage re-runs.
- **The contract has to match in three places**: the key in `params.yaml`, the name in `dvc.yaml`'s `params:` block, and the dict key the script reads. All three were `n_estimators` except `params.yaml`. Hence the lab.

DVC doesn't enforce that the script actually reads `params.yaml` — it just hashes the value. If your script hard-codes the param, DVC will obediently re-run when the param changes, but the script will use the hard-coded value anyway. Discipline is on the author.

See [notes/dvc.md § Parameters](../../notes/dvc.md#parameters--paramsyaml-and-the-params-block) for nested keys, per-file params syntax, and the "don't declare unused params" rule.

## What I'd watch for next time

- **Typos in `params.yaml` keys silently break grader runs.** The error is specific enough to fix in 10 seconds — but only if you ran the broken state first. If you'd skipped that and gone straight to bumping `n_estimators` to 200, you'd have been hunting "why is `train` not re-running" with no error message.
- **Stage `params:` is the contract.** Anything the script reads from `params.yaml` should be declared as a stage param. Anything that *isn't* declared won't trigger re-runs when changed — the model gets stale silently.
- **`dvc.lock` is the audit trail.** Read it with `cat dvc.lock` after parameter changes — you'll see the new value recorded under the stage's `params` block.

## Connections

- [notes/dvc.md § Parameters](../../notes/dvc.md#parameters--paramsyaml-and-the-params-block) — full pattern reference
- This pattern is the seed of Domain 3 (MLflow tracking — same idea, richer storage) and Domain 4 (Optuna/FLAML — same idea, swept programmatically)
