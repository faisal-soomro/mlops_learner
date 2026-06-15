# Day 11 — Walkthrough

Second Domain 2 lab. Move an existing dataset from git tracking to DVC tracking — the canonical "fix a teammate's mistake" scenario. Three real surprises hit during the run.

## Starting state

After Day 10:

```
fraud-detection/
├── .dvc/
├── .dvcignore
├── data/raw/
│   └── transactions.csv     ← committed to git, the problem
└── README.md
```

`git ls-files data/raw/` confirmed `transactions.csv` was in the git index.

## Step 1 — untrack from git, keep on disk

```bash
$ git rm --cached data/raw/transactions.csv
rm 'data/raw/transactions.csv'

$ ls data/raw/
transactions.csv          # still on disk

$ git status
On branch main
Changes to be committed:
        deleted:    data/raw/transactions.csv

Untracked files:
        data/
```

The `rm 'data/raw/transactions.csv'` output is **git's index operation, not a filesystem delete** — `--cached` strips the file from the staging area / index but the bytes on disk are untouched. `ls` confirmed.

`git status` listed `data/` (just the directory name) under untracked rather than the specific file — that's git's default behaviour when *every* file in a directory is untracked. Once we `git add` the .dvc pointer + .gitignore, the directory expands and individual files show up.

## Step 2 — `dvc add` (surprise #1: no auto-stage)

```bash
$ dvc add data/raw/transactions.csv
100% Adding...|██████████████████████████████████████████|1/1 [00:00, 50.41file/s]

To track the changes with git, run:

        git add data/raw/transactions.csv.dvc data/raw/.gitignore

To enable auto staging, run:

        dvc config core.autostage true
```

I'd predicted in the lab's README that `dvc add` might auto-stage the way `dvc init` did. **Wrong.** Auto-staging is opt-in per-command:

- `dvc init` — auto-stages by default (no flag needed)
- `dvc add` (and others like `dvc remote add`) — needs `dvc config core.autostage true` set first

The reasoning is reasonable: `init` runs once, on a clean repo, and the artifacts are obvious; `add` runs many times against arbitrary files, so DVC defers to git for explicit staging. Fair design.

What DVC produced:
- `data/raw/transactions.csv.dvc` — the pointer file (small YAML with the MD5 hash, size, and path)
- `data/raw/.gitignore` — **per-directory ignore**, containing just `/transactions.csv`

The bytes of `transactions.csv` were moved into `.dvc/cache/<hash-prefix>/<hash-suffix>` (the content-addressed store — same shape as `.git/objects/`, see [notes/git-internals.md](../../notes/git-internals.md)). The file in `data/raw/` is now a link/reflink/copy from the cache, depending on filesystem.

## Step 3 — surprise #2: cwd trap

This is the embarrassing part. I'd `cd`'d into `data/raw/` between commands to look at the `.gitignore`, then ran:

```bash
$ git add data/raw/.gitignore data/raw/transactions.csv.dvc
warning: could not open directory 'data/raw/data/raw/': No such file or directory
fatal: pathspec 'data/raw/.gitignore' did not match any files
```

`git add` interprets paths **relative to the cwd**, not the repo root. From inside `data/raw/`, `data/raw/.gitignore` becomes `./data/raw/data/raw/.gitignore` — doesn't exist.

The commit went through anyway (because the staged deletion from Step 1 was still there), but it was **incomplete** — only the deletion got committed, not the new pointer/gitignore:

```
[main 28cbe79] Track transactions dataset with DVC
 1 file changed, 11 deletions(-)
 delete mode 100644 data/raw/transactions.csv
```

Lesson: **run git commands from repo root unless you have a specific reason not to.** Or use `git -C <path>` to be explicit.

## Step 4 — surprise #3: redoing the commit cleanly

The bad commit was local-only (not pushed), so the fix was to undo it and recommit properly. Three options for "undo last commit":

| Command | Effect | When to use |
|---|---|---|
| `git reset --soft HEAD~1` | Removes the commit, **keeps changes staged** | Recommit with different/additional content |
| `git reset --mixed HEAD~1` (default) | Removes the commit, **keeps changes unstaged** | Re-decide what to stage |
| `git reset --hard HEAD~1` | Removes the commit, **discards changes** | Throwaway work |
| `git commit --amend` | Modifies the last commit in place | Only when nothing pushed; CLAUDE.md global guidance is to prefer new commits |

I used `--soft` because the staged deletion was already correct — I just needed to add the two missing files alongside it before recommitting.

```bash
$ cd /root/code/fraud-detection
$ git reset --soft HEAD~1
$ git status
Changes to be committed:
        deleted:    data/raw/transactions.csv
Untracked files:
        data/

$ git add data/raw/.gitignore data/raw/transactions.csv.dvc
$ git status
Changes to be committed:
        new file:   data/raw/.gitignore
        deleted:    data/raw/transactions.csv
        new file:   data/raw/transactions.csv.dvc

$ git commit -m "Track transactions dataset with DVC"
[main 16c3d72] Track transactions dataset with DVC
 3 files changed, 6 insertions(+), 11 deletions(-)
 create mode 100644 data/raw/.gitignore
 delete mode 100644 data/raw/transactions.csv
 create mode 100644 data/raw/transactions.csv.dvc
```

One clean commit with the deletion *and* the two new files. Grader green.

See [notes/git-undo.md](../../notes/git-undo.md) for the full reset/revert/restore/checkout/amend matrix.

## What I'd watch for next time

- **Stay at repo root** for git commands. cd into subdirectories only when running directory-specific tools (e.g. `dvc` doesn't care, but `git` does).
- **Read DVC's CLI output.** It explicitly told us `git add data/raw/transactions.csv.dvc data/raw/.gitignore` and pointed at the `core.autostage` config. Following that line-by-line would've avoided the cwd mistake.
- **Per-directory `.gitignore`** is normal git behaviour. DVC didn't reinvent anything — it just dropped a `.gitignore` next to the data it tracks, and git's closest-gitignore-wins rule handles the rest.

## Connections

- DVC's content-addressed cache (`.dvc/cache/`) mirrors `.git/objects/` — same shape, different scope. See [notes/git-internals.md](../../notes/git-internals.md).
- The cwd-relative path behaviour is one of those gotchas that applies to most CLI tools (`git`, `gh`, `dvc`, `make` from a sub-Makefile). Worth internalising once.
- New cross-cutting note from this lab: [notes/git-undo.md](../../notes/git-undo.md).
