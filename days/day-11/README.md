# Day 11 — Track a Dataset with DVC

**TL;DR:** Move `data/raw/transactions.csv` from git tracking to DVC tracking. `git rm --cached` to untrack (keep on disk), `dvc add` to track via DVC (creates pointer + gitignore), commit with `Track transactions dataset with DVC`.

## Task

A teammate committed `data/raw/transactions.csv` directly to git. Team standard: every file under `data/` is tracked by DVC, not git. Fix it.

### Acceptance criteria

- `data/raw/transactions.csv` no longer tracked by git, but still exists on disk
- `data/raw/transactions.csv.dvc` (the pointer file) exists
- `data/raw/.gitignore` exists and excludes `transactions.csv`
- A git commit exists with the message exactly `Track transactions dataset with DVC`
- The pointer + new gitignore are staged in that commit
- DVC VS Code extension shows the dataset under "DVC TRACKED"

## Starting state

```
fraud-detection/
├── .dvc/                  ← DVC initialised on Day 10
│   ├── .gitignore
│   ├── config
│   └── tmp/
├── .dvcignore
├── data/raw/
│   └── transactions.csv   ← tracked by git (the problem)
└── README.md
```

## Expected final state

```
fraud-detection/
├── .dvc/
├── .dvcignore
├── data/raw/
│   ├── .gitignore                    ← new, contains "/transactions.csv"
│   ├── transactions.csv              ← still on disk, ignored by git, tracked by DVC
│   └── transactions.csv.dvc          ← new, the DVC pointer (small YAML file)
└── README.md
```

## How to run

```bash
cd /root/code/fraud-detection

# 1. Untrack from git without deleting from disk
git rm --cached data/raw/transactions.csv

# 2. Track with DVC — creates pointer file + .gitignore in data/raw/
dvc add data/raw/transactions.csv

# 3. Check what changed
git status

# 4. Stage and commit
git add data/raw/.gitignore data/raw/transactions.csv.dvc
git commit -m "Track transactions dataset with DVC"
```

The `git rm --cached` step puts the deletion in the staging area; `git commit` at the end captures it along with the new files.

## Gotchas

- **`git rm` without `--cached` deletes the file from disk.** Always use `--cached` when moving a file from git to DVC tracking.
- **Order matters.** `dvc add` will error if the file is still tracked by git (DVC won't fight git for ownership). Do `git rm --cached` first.
- **Commit message must be exact** — `Track transactions dataset with DVC`. Grader is literal-string-matching.
- **The .dvc pointer is small (~200 bytes), so it's safe to commit.** It contains the MD5 hash of the data, the size, and the path. The actual file bytes are now in `.dvc/cache/` (content-addressed, by hash) — same shape as `.git/objects/`. See [notes/git-internals.md](../../notes/git-internals.md).
- **`dvc add` may auto-stage** the new `.dvc` pointer and `.gitignore` (Day 10 saw this with `dvc init`). Check `git status` and only add if needed.
- **Don't `dvc add` the whole `data/` directory blindly** in this lab — the task is specifically about `transactions.csv`.

## Why this matters

The whole point of DVC is keeping data *out* of git history. Once a file is committed to git, its bytes are in `.git/objects/` forever — even after deleting it from the working tree, every clone still pulls the historical version. `git rm --cached` removes it from the *current* working tree's git index, but the bytes already in history remain. (Real cleanup of historical bytes needs `git filter-repo` or BFG; not in scope here.)

`dvc add`:
1. Computes the MD5 of the file
2. Moves the bytes into `.dvc/cache/<first-2-hash-chars>/<remaining-hash-chars>` (content-addressed)
3. Replaces the file in the working tree with a hardlink/reflink/symlink/copy to the cache entry (depending on filesystem + config)
4. Writes a `.dvc` pointer file containing the hash, size, and path
5. Writes (or updates) a `.gitignore` in the file's directory so git stops tracking it

So future clones get: git pulls the small `.dvc` pointer; `dvc pull` resolves the hash against a configured remote (S3, GCS, etc.) and fetches the actual bytes. The repo stays small.

## Use case

You've trained a model on this week's transaction snapshot. Six months later a regulator asks "show me the exact data this model was trained on." With DVC: `git checkout <commit-hash>` rewinds the pointer; `dvc pull` fetches the matching data from the remote. With pure git: either the data was committed (and the repo is now multi-gigabyte) or it wasn't (and the data is gone).

## Resources

- [DVC docs — Data and Model Versioning](https://dvc.org/doc/start/data-management/data-versioning)
- [`dvc add` reference](https://dvc.org/doc/command-reference/add)
- [`git rm --cached`](https://git-scm.com/docs/git-rm#Documentation/git-rm.txt---cached) — git docs
- [notes/git-internals.md](../../notes/git-internals.md) — why DVC's cache shape mirrors `.git/objects/`
