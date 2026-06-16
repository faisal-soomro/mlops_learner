# DVC — patterns across days

Cross-cutting DVC concepts that surface across multiple labs in Domain 2 (Days 10-19). Pure day-specific output goes in the day's `walkthrough.md`; the patterns and design choices live here.

## Contents

- [The mental model](#the-mental-model)
- [The `.dvc/` directory](#the-dvc-directory)
- [The content-addressed cache](#the-content-addressed-cache)
- [Auto-staging behaviour (per command)](#auto-staging-behaviour-per-command)
- [`dvc remote` — the storage layer](#dvc-remote--the-storage-layer)
- [Credentials and `.dvc/config.local`](#credentials-and-dvcconfiglocal)
- [The git/DVC handoff pattern](#the-gitdvc-handoff-pattern)
- [Don't hand-edit `.dvc/config`](#dont-hand-edit-dvcconfig)
- [Where each thing lives](#where-each-thing-lives)

## The mental model

DVC = git-for-large-files. Identical *shape* to git (content-addressed object store, pointer files, init/add/commit/push verbs), different *scope* (multi-GB datasets and models, where git's object store breaks down).

You commit small `.dvc` pointer files to git. The actual bytes live in `.dvc/cache/` locally and on a configured **remote** (S3, GCS, SeaweedFS, local dir, SSH, HDFS, etc.). `dvc push` syncs cache → remote; `dvc pull` syncs remote → cache.

The two-layer split is what keeps git history small even when datasets are huge.

## The `.dvc/` directory

Created by `dvc init`:

```
.dvc/
├── .gitignore           # ignores everything in .dvc/ except this + config
├── config               # ini-style DVC config (remotes, cache settings)
├── config.local         # gitignored secrets variant (not created until --local used)
├── cache/               # content-addressed object store (appears after first dvc add)
│   └── files/md5/<2chars>/<30chars>
└── tmp/                 # runtime scratch — gitignored
    ├── btime            # boot time, used to detect stale locks
    ├── lock, rwlock     # concurrency control
    ├── exps/            # experiments metadata
    └── celery/          # Celery broker (file-based queue) for queued experiments
        └── broker/{control,in,processed}, result/
```

`.dvc/tmp/celery/` exists from the moment of `dvc init` — DVC pre-creates the Celery message queue layout so subsequent `dvc exp run --queue` commands don't need to check-and-create. None of `tmp/` is committed.

## The content-addressed cache

`.dvc/cache/files/md5/<first-2-hash-chars>/<remaining-30-chars>` is the same shape as `.git/objects/<2>/<38>` — directory shard by hash prefix to avoid filesystem slowdowns with millions of files in one dir. See [git-internals.md](git-internals.md) for the original pattern.

When you `dvc add data/raw/file.csv`:
1. Compute MD5 of the file
2. Move bytes into `.dvc/cache/files/md5/<prefix>/<rest>`
3. Replace `file.csv` in the working tree with a link/reflink/copy from the cache (filesystem-dependent)
4. Write `file.csv.dvc` pointer (small YAML: hash + size + path)
5. Write/update `.gitignore` in the file's directory so git stops tracking it

Same hash → same cache entry → same remote object. Cross-branch and cross-file deduplication is automatic.

## Auto-staging behaviour (per command)

`dvc init` and `dvc add` are inconsistent about git auto-staging — worth memorising:

| Command | Auto-stages git? | Notes |
|---|---|---|
| `dvc init` | ✅ yes (always) | Stages `.dvc/.gitignore`, `.dvc/config`, `.dvcignore` immediately |
| `dvc add <file>` | ❌ no (opt-in) | Tells you what to `git add`; enable globally with `dvc config core.autostage true` |
| `dvc remote add/modify` | ❌ no | Modifies `.dvc/config`; stage manually |
| `dvc push` / `dvc pull` | n/a | Touches only the cache/remote, not git |

Reasoning: `init` runs once on a clean repo with obvious artifacts; `add` runs many times against arbitrary files, so DVC defers to git for explicit staging. Fair design, but trips people up on the first `dvc add` after `dvc init`.

## `dvc remote` — the storage layer

A "remote" is just a configured location DVC pushes/pulls bytes to/from. Supported backends include S3 (and S3-compatible: SeaweedFS, MinIO, Ceph, Backblaze, R2), GCS, Azure Blob, SSH/SFTP, HDFS, WebDAV, OSS, Google Drive, and `local` (just another directory on disk).

Key commands:

```bash
# Add a remote
dvc remote add <name> <url>                  # e.g. dvc remote add s3 s3://mybucket
dvc remote add -d <name> <url>               # -d = also mark as default

# Modify an existing remote
dvc remote modify <name> <key> <value>       # writes to .dvc/config
dvc remote modify --local <name> <key> <value>   # writes to .dvc/config.local (gitignored)

# Mark a remote as default
dvc remote default <name>

# List remotes
dvc remote list

# Remove a remote
dvc remote remove <name>
```

### S3-compatible (non-AWS) backends

DVC has one S3 client; you switch endpoints via `endpointurl` to talk to non-AWS stores:

```ini
['remote "s3"']
    url = s3://my-bucket
    endpointurl = http://localhost:8333    # SeaweedFS / MinIO / etc.
    access_key_id = ...
    secret_access_key = ...
```

The `url` scheme stays `s3://` — that's how DVC picks the S3 client. `endpointurl` redirects requests away from AWS. Optional keys: `region`, `use_ssl`, `verify` (for self-signed certs).

May need to install the S3 extra: `pip install 'dvc[s3]'` or `uv pip install 'dvc[s3]'`.

## Credentials and `.dvc/config.local`

**`.dvc/config` is committed to git.** Putting `secret_access_key = ...` there means the secret is in git history forever, leakable to anyone with repo access (or anyone who finds an old fork). For lab use it's fine; for production it's catastrophic.

Three production-safe patterns:

1. **`.dvc/config.local`** — gitignored variant. Write with `--local`:
   ```bash
   dvc remote modify --local s3 access_key_id $AWS_ACCESS_KEY_ID
   dvc remote modify --local s3 secret_access_key $AWS_SECRET_ACCESS_KEY
   ```
   DVC merges `config` and `config.local` at runtime, with `config.local` winning.
2. **Environment variables** — DVC respects `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` for S3 backends, and equivalent vars for GCS/Azure. No config entry needed.
3. **IAM roles / instance profiles** — when running on EC2 / EKS / similar, the SDK picks up credentials automatically. Best option when available.

The `.dvc/.gitignore` DVC ships ignores `config.local`, so the gitignore is set up correctly out of the box.

## The git/DVC handoff pattern

When a teammate accidentally commits a large file to git, the fix is to **transfer ownership**:

```bash
git rm --cached <file>          # untrack from git, keep on disk
dvc add <file>                  # track with DVC; creates .dvc pointer + per-dir .gitignore
git add <file>.dvc <dir>/.gitignore
git commit -m "Track <file> with DVC"
```

Notes on this:
- `git rm --cached` *must* come before `dvc add` — DVC refuses to take ownership of a file git is tracking.
- DVC writes a **per-directory `.gitignore`** (e.g. `data/raw/.gitignore`), not the repo-root one. Closest-gitignore-wins is normal git behaviour; DVC just leans on it.
- The historical bytes are still in git history. Cleaning that requires `git filter-repo` or BFG — out of scope for normal workflow, but worth knowing when a 5GB file ends up committed.

## Don't hand-edit `.dvc/config`

Use `dvc remote add / modify / default` to mutate config. Same discipline as `git config user.name` over editing `.git/config`:

- The CLI writes the correct ini schema (section headers, key names, value escaping)
- The CLI knows which scope to write to (`config` vs `config.local` via `--local`)
- Typos in hand-edited section headers (`['remote "s3"']` is fussy) silently break the remote without an error you'd notice

Read the file all you want; mutate via the CLI.

## Where each thing lives

| Concept | Filesystem location | Committed? |
|---|---|---|
| DVC config (non-secret) | `.dvc/config` | ✅ yes |
| DVC config (secrets) | `.dvc/config.local` | ❌ no (gitignored) |
| Local cache | `.dvc/cache/files/md5/<2>/<30>` | ❌ no |
| Runtime scratch | `.dvc/tmp/` | ❌ no |
| Pointer files | `<dir>/<file>.dvc` | ✅ yes |
| Per-dir gitignores | `<dir>/.gitignore` | ✅ yes |
| Remote bytes | wherever the remote is | n/a (remote-side) |
