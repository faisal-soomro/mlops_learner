# Day 12 — Walkthrough

Third Domain 2 lab. Clean execution — three plants, three commands, push, verify. Worth a short writeup because Days 10-12 collectively cover enough DVC ground that the cross-cutting patterns now live in [notes/dvc.md](../../notes/dvc.md); this walkthrough just captures the day-specific run.

## Starting state

After Day 11. Repo has DVC initialised, `transactions.csv` tracked via DVC, and a `.dvc/config` declaring an `s3` remote — but the remote is broken.

```ini
['remote "s3"']
    url = s3://dvc-wrong-bucket           ← wrong bucket
    endpointurl = http://localhost:9999    ← wrong port
    access_key_id = weedadmin
    secret_access_key = weedadmin123
                                            ← no [core] section, not default
```

SeaweedFS is running with the actual bucket `dvc-storage` on port `8333`.

## Step 1 — fix the three plants

Three `dvc remote` commands. Used the CLI, not hand-edits — see [notes/dvc.md § Don't hand-edit .dvc/config](../../notes/dvc.md#dont-hand-edit-dvcconfig).

```bash
$ cd /root/code/fraud-detection
$ dvc remote modify s3 url s3://dvc-storage
$ dvc remote modify s3 endpointurl http://localhost:8333
$ dvc remote default s3
$ cat .dvc/config
[core]
    remote = s3
['remote "s3"']
    url = s3://dvc-storage
    endpointurl = http://localhost:8333
    access_key_id = weedadmin
    secret_access_key = weedadmin123
```

Three commands wrote three diffs into the ini file. The `[core] remote = s3` block is new — `dvc remote default <name>` is the command that writes it.

## Step 2 — push

```bash
$ dvc push
Collecting                                 |1.00 [00:00,  761entry/s]
Pushing
1 file pushed
```

One file — the MD5-cached bytes of `transactions.csv`. The "Collecting" phase walks `.dvc` pointer files to figure out which cache entries are needed; "Pushing" uploads them to the configured default remote.

## Step 3 — verify in the bucket

Opened the SeaweedFS Filer UI on port 8888, navigated to `/buckets/dvc-storage/`. Object present under `files/md5/<2-char-prefix>/<remaining>`. Same content-addressed layout as `.dvc/cache/` locally and `.git/objects/` — see [notes/git-internals.md](../../notes/git-internals.md) for why every tool in this family reaches for that shape.

## What I'd watch for next time

- **`dvc remote modify` over hand-edits.** Easy to typo the section header `['remote "s3"']` — the quotes inside brackets are fussy. CLI gets it right every time.
- **The `s3://` scheme is not AWS-specific.** It's DVC's selector for "use the S3 client"; `endpointurl` is what actually directs traffic. Works the same for SeaweedFS, MinIO, Ceph, Backblaze, R2, etc.
- **Credentials in `.dvc/config` got committed to git.** Fine in this lab (throwaway local creds). For real work, use `--local` to write to `.dvc/config.local` (gitignored). See [notes/dvc.md § Credentials and .dvc/config.local](../../notes/dvc.md#credentials-and-dvcconfiglocal).

## Connections

- The cross-cutting DVC patterns now live in [notes/dvc.md](../../notes/dvc.md) — that's the right place to look first when starting Days 13-19.
- Content-addressed storage shape: [notes/git-internals.md](../../notes/git-internals.md).
