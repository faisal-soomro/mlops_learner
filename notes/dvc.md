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
- [Pipelines — `dvc.yaml` and `dvc.lock`](#pipelines--dvcyaml-and-dvclock)
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

## Pipelines — `dvc.yaml` and `dvc.lock`

`dvc add` (Days 11-13) versions individual files. `dvc.yaml` versions **the relationship between files** — a content-hashed DAG where each node is a stage (a command), each edge is a dep/output relationship, and re-running is staleness-driven.

### Shape of `dvc.yaml`

```yaml
stages:
  process_data:
    cmd: python src/data/process_data.py
    deps:
      - data/raw/transactions.csv
      - src/data/process_data.py
    outs:
      - data/processed/clean_transactions.csv

  split_data:
    cmd: python src/data/split_data.py
    deps:
      - data/processed/clean_transactions.csv    # ← this line wires the DAG edge
      - src/data/split_data.py
    outs:
      - data/processed/train.csv
      - data/processed/test.csv
```

Each stage declares:
- **`cmd`** — the literal shell command DVC will run
- **`deps`** — files whose changes should trigger this stage to re-run (input data, scripts, params)
- **`outs`** — files this stage produces (DVC auto-tracks these, no `dvc add` needed)

### The DAG is built from deps + outs

DVC builds the dependency graph by matching: if stage B has a `dep` whose path matches another stage's `outs`, B depends on that stage. That's the *only* way DVC knows two stages are connected. **Missing a dep doesn't error at runtime** — DVC will happily run both stages in YAML-declaration order on first `dvc repro`. The breakage is silent: `dvc status` won't flag downstream stages as stale when upstream inputs change.

Inspect the DAG with:

```bash
dvc dag                # ASCII art
dvc dag --dot          # Graphviz format
dvc dag <stage>        # dag for just one stage and its ancestors
```

Look for disconnected nodes — if two stages should be wired and aren't, you've found a missing dep.

### `dvc.lock` — the hash manifest

`dvc repro` writes a `dvc.lock` file capturing the actual MD5 of every dep and out of every stage at the time of the last successful run. It's how DVC decides what's stale:

- On the next `dvc repro`, for each stage:
  1. Compute the current MD5 of every dep
  2. Compare against `dvc.lock`
  3. If all match → stage is fresh, skip
  4. If any differ → stage is stale, re-run, then update `dvc.lock`

This is hash-based staleness, not timestamp-based. `touch` won't invalidate anything; an actual content change will.

**Commit `dvc.lock` alongside `dvc.yaml`.** Without it, "reproducible" stops being reproducible — teammates would re-run everything from scratch.

### `dvc repro` execution model

- Computes the full DAG from `dvc.yaml`
- Topologically orders the stages
- For each stage in order: checks dep hashes against `dvc.lock`; skips if matched, runs if not
- Each stage's `outs` are placed under DVC's control (cache + working tree)
- Updates `dvc.lock` as it goes

Useful flags:
- `dvc repro --force` — re-run everything regardless of staleness
- `dvc repro <stage>` — run a specific stage and its ancestors
- `dvc repro --downstream <stage>` — run a stage and its descendants
- `dvc repro --dry` — show what would run without running

### `dvc.yaml` vs `.dvc/config` — different mutability models

| File | Hand-edit OK? | CLI helper |
|---|---|---|
| `.dvc/config` | No — too easy to typo section headers | `dvc remote add/modify/default` |
| `dvc.yaml` | Yes — the standard workflow | `dvc stage add` (only creates new stages, not edits existing) |

For pipelines you edit the YAML by hand. Indentation matters (it's YAML); two-space, consistent throughout.

### Failure modes seen in labs

| Symptom | Root cause |
|---|---|
| `python: can't open file '<path>'` | Typo in `cmd` (wrong script path) |
| `output '<path>' does not exist` (after stage ran fine) | `outs` filename mismatch with what the script actually wrote |
| `dvc dag` shows disconnected stages; `dvc status` clean despite upstream change | Missing `dep` wiring between stages — silent breakage |
| `Stage '<X>' didn't change, skipping` when you expected a re-run | `dvc.lock` matches; either nothing actually changed, or the changed file isn't in `deps` |

The third one is the pernicious one: the pipeline produces correct outputs on first run, and only breaks on the second run after upstream data changes. Always check `dvc dag` after defining stages.

## Where each thing lives

| Concept | Filesystem location | Committed? |
|---|---|---|
| DVC config (non-secret) | `.dvc/config` | ✅ yes |
| DVC config (secrets) | `.dvc/config.local` | ❌ no (gitignored) |
| Local cache | `.dvc/cache/files/md5/<2>/<30>` | ❌ no |
| Runtime scratch | `.dvc/tmp/` | ❌ no |
| Pointer files | `<dir>/<file>.dvc` | ✅ yes |
| Per-dir gitignores | `<dir>/.gitignore` | ✅ yes |
| Pipeline definition | `dvc.yaml` | ✅ yes |
| Pipeline hash manifest | `dvc.lock` | ✅ yes |
| Remote bytes | wherever the remote is | n/a (remote-side) |
