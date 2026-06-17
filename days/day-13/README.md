# Day 13 — Pull DVC-Tracked Data from Remote

**TL;DR:** Credentials are missing from `.dvc/config` on this fresh clone. Add `access_key_id = weedadmin` and `secret_access_key = weedadmin123` via `dvc remote modify`, then `dvc pull`. Verify `data/raw/transactions.csv` reappears on disk.

## Task

A new teammate has cloned the fraud-detection repo onto a fresh machine. The `.dvc/transactions.csv.dvc` pointer is there, but the actual data file is missing — `dvc pull` is failing. Fix the config and pull.

### Acceptance criteria

- `s3` remote has both credentials set:
  - `access_key_id = weedadmin`
  - `secret_access_key = weedadmin123`
- `dvc pull` succeeds without errors
- `data/raw/transactions.csv` exists on disk
- Its content matches the MD5 hash recorded in `data/raw/transactions.csv.dvc`

## Starting state (the plant)

```ini
[core]
    remote = s3

['remote "s3"']
    url = s3://dvc-storage
    endpointurl = http://localhost:8333
                                            ← no access_key_id
                                            ← no secret_access_key
```

URL and endpoint are correct (matches Day 12's working state). Just the credentials were dropped on the clone — probably stripped from a teammate's `.dvc/config.local` that never made it into the shared repo.

## Diagnosis table

| Symptom (running `dvc pull`) | Probable cause | Fix |
|---|---|---|
| `Unable to locate credentials` / `NoCredentialsError` | No `access_key_id` / `secret_access_key` in config and no env vars set | `dvc remote modify s3 access_key_id weedadmin` + same for secret |
| `403 Forbidden` after adding creds | Typo in key/secret | Re-run modify with the correct value |
| `NoSuchBucket` / connection error | Wrong `url` or `endpointurl` | Not the plant today — these are already correct |

## Expected final `.dvc/config`

```ini
[core]
    remote = s3

['remote "s3"']
    url = s3://dvc-storage
    endpointurl = http://localhost:8333
    access_key_id = weedadmin
    secret_access_key = weedadmin123
```

(Matches Day 12's final state.)

## How to run

```bash
cd /root/code/fraud-detection

# Confirm the data is missing
ls data/raw/

# Add the credentials
dvc remote modify s3 access_key_id weedadmin
dvc remote modify s3 secret_access_key weedadmin123

# Verify config
cat .dvc/config

# Pull from the remote
dvc pull

# Confirm the data is back
ls data/raw/
```

## Gotchas

- **Credentials in `.dvc/config` get committed to git.** This lab puts them there because the grader checks the file. For real production, use `--local` (writes to gitignored `.dvc/config.local`) or environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`). See [notes/dvc.md § Credentials and .dvc/config.local](../../notes/dvc.md#credentials-and-dvcconfiglocal).
- **`dvc pull` reads from the *default* remote.** `[core] remote = s3` is already set; if it weren't, you'd need `dvc pull -r s3` or `dvc remote default s3`.
- **MD5 mismatch detection is automatic.** After `dvc pull` finishes, `dvc status` (no flags) compares the file's current hash to the one in the `.dvc` pointer. If they differ, you'll see "modified" — the lab grader likely runs this implicitly.
- **No `git pull` needed here.** The `.dvc` pointer was already in the clone. We're only restoring the *data*, not the *pointers*.

## Why this matters

`dvc pull` is the symmetric inverse of `dvc push`. Once you have a remote configured and a `.dvc` pointer file in git, anyone with the repo + credentials can reconstruct the exact data: `git clone` brings the small pointers; `dvc pull` resolves the hashes against the remote and fetches the bytes. The pull-on-fresh-clone scenario is the *whole point* of DVC — without it, "reproduce this model from six months ago" stays a lie.

## Use case

You're onboarding to the fraud-detection project on a new laptop. You `git clone` and see `data/raw/transactions.csv.dvc` but no `transactions.csv`. That's correct — the pointer is in git, the data is in the DVC remote. `dvc pull` finishes the clone. Same scenario for CI: a fresh runner that needs to retrain the model pulls the data it needs from the remote.

## Resources

- [DVC docs — `dvc pull`](https://dvc.org/doc/command-reference/pull)
- [DVC docs — Data and Model Versioning](https://dvc.org/doc/start/data-management/data-versioning)
- [notes/dvc.md](../../notes/dvc.md) — cross-day DVC patterns
