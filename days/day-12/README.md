# Day 12 — Configure a DVC Remote (SeaweedFS S3-compatible)

**TL;DR:** Fix the three plants in `.dvc/config` (wrong bucket, wrong port, no default), then `dvc push`. Verify the object lands under `files/md5/...` in the SeaweedFS bucket.

## Task

A `.dvc/config` declares a remote named `s3` for the fraud-detection project, but `dvc push` fails. Correct it so the remote points at the right bucket on the SeaweedFS S3 endpoint, mark it default, and push the data.

### Acceptance criteria

- Remote `s3` exists, with:
  - `url = s3://dvc-storage`
  - `endpointurl = http://localhost:8333`
  - `access_key_id = weedadmin`, `secret_access_key = weedadmin123` (already set, leave alone)
- A `[core]` section sets `remote = s3` (default remote)
- `dvc push` succeeds without errors
- SeaweedFS bucket `dvc-storage` contains at least one object under the `files/md5/...` prefix (verify in the Filer UI)

## Starting state (the plants)

```ini
['remote "s3"']
    url = s3://dvc-wrong-bucket           ← wrong bucket
    endpointurl = http://localhost:9999    ← wrong port
    access_key_id = weedadmin
    secret_access_key = weedadmin123
                                            ← no [core] section, not default
```

## Lab environment

- SeaweedFS S3 endpoint: `http://localhost:8333`
- Filer UI: forwarded port `8888` → buckets under `/buckets/`
- Bucket: `dvc-storage` (already created)
- Creds: `weedadmin / weedadmin123` (already in config)
- DVC: tracks `data/raw/transactions.csv` from Day 11

## Diagnosis table

| Symptom (running `dvc push`) | Probable cause | Fix |
|---|---|---|
| `ERROR: configuration error - no remote specified` | No `[core] remote = s3` | `dvc remote default s3` |
| `Failed to connect ... localhost:9999` | Wrong endpoint port | `dvc remote modify s3 endpointurl http://localhost:8333` |
| `403 Forbidden` or `NoSuchBucket: dvc-wrong-bucket` | Wrong bucket in `url` | `dvc remote modify s3 url s3://dvc-storage` |

The three CLI commands above modify `.dvc/config` for you — don't hand-edit unless you want to. `dvc remote ...` writes the right schema and you avoid typos.

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

## How to run

```bash
cd /root/code/fraud-detection

# Inspect the current config (sanity check)
cat .dvc/config

# Fix the three plants
dvc remote modify s3 url s3://dvc-storage
dvc remote modify s3 endpointurl http://localhost:8333
dvc remote default s3

# Verify the rewritten config
cat .dvc/config

# Push the tracked data
dvc push

# Optional: confirm what got pushed
dvc status -c        # "Cache and remote 'origin' are in sync"
```

## Gotchas

- **DVC ships its own boto3-style S3 client** — it expects standard S3 config keys: `url`, `endpointurl`, `access_key_id`, `secret_access_key`. Optional: `region`, `use_ssl`, `verify`. For SeaweedFS (http, no region) the defaults work.
- **Credentials in `.dvc/config` get committed to git.** That's fine for this lab (local SeaweedFS, throwaway creds) but **never do this for production**. Use `dvc remote modify --local` (writes to `.dvc/config.local`, gitignored) or environment variables (`AWS_ACCESS_KEY_ID`, etc.) for real creds.
- **`dvc push` doesn't auto-commit anything to git.** It pushes the cache contents to the remote. The `.dvc` pointer files are git's responsibility.
- **The `url` must start with `s3://`** for the S3-compatible backend. Even though SeaweedFS isn't AWS, DVC uses the S3 scheme to pick the right client; the `endpointurl` is what actually directs the requests away from AWS.
- **You may need to install `dvc-s3`** if DVC complains about missing S3 support. Lab probably has it pre-installed; if not: `pip install 'dvc[s3]'` or `uv pip install 'dvc[s3]'`.
- **Object layout in the bucket:** DVC writes files under `files/md5/<first-2-hash-chars>/<remaining-30-chars>`. Same content-addressed shape as `.git/objects/` and `.dvc/cache/` — see [notes/git-internals.md](../../notes/git-internals.md).

## Why this matters

The local `.dvc/cache/` is your own machine only. Without a remote, DVC tracking is no better than a single-developer git LFS without a server: hash references point at nothing once you clone elsewhere. A remote (S3, GCS, Azure, SSH, HDFS, even another local directory) is where DVC stores the bytes so teammates can `dvc pull` and reconstruct the data that matches any past commit.

SeaweedFS specifically is an open-source S3-compatible object store that runs anywhere — useful for homelab DVC remotes, air-gapped environments, or just avoiding AWS bills during learning. It speaks enough of the S3 API that `dvc remote add -d s3 s3://bucket --endpoint-url ...` Just Works.

## Use case

You're working on the fraud-detection model on your laptop. Your teammate's on theirs. You both clone the repo, both want to reproduce `model.pkl` from last week. With a DVC remote: `dvc pull` fetches the dataset bytes the committed `.dvc` pointers reference, regardless of who originally trained the model. Without a remote: only the person whose laptop holds the original cache can reproduce anything.

## Resources

- [DVC docs — Remote storage](https://dvc.org/doc/user-guide/data-management/remote-storage)
- [`dvc remote add` reference](https://dvc.org/doc/command-reference/remote/add)
- [`dvc remote modify` reference](https://dvc.org/doc/command-reference/remote/modify)
- [DVC + S3-compatible (incl. SeaweedFS/MinIO) setup](https://dvc.org/doc/user-guide/data-management/remote-storage/amazon-s3)
- [SeaweedFS S3 API docs](https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API)
