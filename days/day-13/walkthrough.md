# Day 13 — Walkthrough

Pull-side counterpart to Day 12. Short writeup — nothing conceptually new beyond what's already in [notes/dvc.md](../../notes/dvc.md).

## Starting state

Fresh clone of the fraud-detection repo. `data/raw/transactions.csv.dvc` is present (pointer in git), but `transactions.csv` itself is gone. `.dvc/config` declares the `s3` remote with url + endpoint set, but **no credentials**.

```ini
[core]
    remote = s3
['remote "s3"']
    url = s3://dvc-storage
    endpointurl = http://localhost:8333
```

## Step 1 — confirm the data is missing

```bash
$ ls data/raw/
transactions.csv.dvc
```

Only the pointer. The actual CSV is absent (and would be ignored by git anyway thanks to the per-directory `.gitignore` written by `dvc add` back on Day 11).

## Step 2 — add credentials, pull

```bash
$ dvc remote modify s3 access_key_id weedadmin
$ dvc remote modify s3 secret_access_key weedadmin123
$ dvc pull
Collecting                         |1.00 [00:00,  666entry/s]
Fetching
Building workspace index           |2.00 [00:00,  699entry/s]
Comparing indexes                  |4.00 [00:00, 3.03kentry/s]
Applying changes                   |1.00 [00:00, 1.20kfile/s]
A       data/raw/transactions.csv
1 file fetched and 1 file added

$ ls data/raw/
transactions.csv  transactions.csv.dvc
```

`dvc pull`:
1. Walks the `.dvc` pointer files in the workspace
2. Compares the hashes they reference against the local cache (none here, fresh clone)
3. Fetches the missing bytes from the default remote
4. Materialises the working-tree file from the cache (link/reflink/copy depending on filesystem)

`A` in the output = "added" — same convention as `git status`.

## The onboarding paper-cut

This lab is mechanically trivial — two CLI commands plus a `dvc pull`. But it captures the **most common DVC onboarding failure**: someone clones the repo, runs `dvc pull`, gets an opaque auth error, doesn't know whether the bug is in the config, their env vars, their IAM role, the bucket policy, or the data itself.

Recognising "missing credentials in `.dvc/config`" as one specific shape of that failure mode is the real lesson. Diagnosis checklist when `dvc pull` blows up on a fresh clone:

1. `cat .dvc/config` — are credentials there, in the expected shape?
2. `cat .dvc/config.local` (if it exists) — same question
3. `env | grep -i aws` — env vars set?
4. `dvc remote list` — is *something* configured as default?
5. `curl <endpointurl>` — is the remote actually reachable from this machine?

For this lab, item 1 surfaced it instantly. In real life, the bug is usually item 3 (missing env vars on a CI runner) or item 5 (firewall between the new machine and the S3-compatible store).

## Connections

- [notes/dvc.md](../../notes/dvc.md) — the patterns this lab exercised (credentials story, pull-from-remote)
- Day 12 was the symmetric push; Day 13 is the pull. Together they're the complete remote round-trip.
