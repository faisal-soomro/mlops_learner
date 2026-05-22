# Day 10 — Install and Initialize DVC

**TL;DR:** Run `dvc init` inside an existing git repo, then commit the files DVC creates (`.dvc/`, `.dvcignore`) with the message `Initialize DVC`.

## Task

xFusionCorp's ML team is adopting DVC so datasets and model files are versioned separately from code. Initialise DVC inside the existing repo at `/root/code/fraud-detection/` and record the initialisation in git.

### Acceptance criteria

- `dvc init` has been run inside `/root/code/fraud-detection/`
- `.dvc/` directory and `.dvcignore` file exist alongside the existing working tree
- Every file DVC produced is staged
- A new git commit exists with the message exactly `Initialize DVC`
- The DVC VS Code extension surfaces the "DVC TRACKED" section in the EXPLORER and a DVC indicator in the status bar

## Starting state

```
fraud-detection/
├── .git/
├── .gitignore
├── README.md
├── data/raw/
├── models/
└── src/
```

One initial commit on `main`. Nothing broken — this is a fresh-init task.

## Expected final state

```
fraud-detection/
├── .dvc/              ← new
│   ├── .gitignore
│   ├── config
│   └── tmp/           ← gitignored
├── .dvcignore         ← new
├── .git/
├── .gitignore
├── README.md
├── data/raw/
├── models/
└── src/
```

`git log` should show two commits: the original initial commit, plus `Initialize DVC`.

## How to run

```bash
cd /root/code/fraud-detection
dvc init
git status                    # confirm what dvc created
git add .dvc .dvcignore
git commit -m "Initialize DVC"
```

That's it. `dvc init` is idempotent-ish — it errors if `.dvc/` already exists, so don't re-run blindly.

## Gotchas

- **`dvc init` must run inside a git repo.** It errors otherwise — DVC is designed to ride alongside git, not replace it. (Use `dvc init --no-scm` for non-git dirs, but that's not this task.)
- **`.dvc/tmp/` and `.dvc/cache/` are auto-gitignored** by the `.dvc/.gitignore` DVC writes for you. Don't try to commit them.
- **Commit message must be exact** — the grader probably matches on it. `Initialize DVC`, capital I, no period.
- **Anonymized usage analytics** are on by default. DVC prints a notice on first init. Not required for the task, but if you want to opt out: `dvc config core.analytics false` (would need a second commit).

## Why this matters

Without DVC, large files end up in git history forever — a 2GB dataset committed once means every future `git clone` pulls 2GB. `.gitignore`-ing the data dodges the bloat but loses versioning entirely: you can't reproduce "the model trained on last week's data" because last week's data is gone. DVC fixes this by storing the bytes in external storage (S3, GCS, local cache) and committing only small `.dvc` pointer files to git. Git stays small; data stays versioned.

## Use case

You're training a fraud-detection model. Each week the data team drops a new snapshot into `data/raw/`. Without DVC, you either commit the snapshots (history explodes) or .gitignore them (no way to reproduce older models). With DVC, you `dvc add data/raw/snapshot.csv` — the file goes to DVC cache + remote, and `snapshot.csv.dvc` (a few hundred bytes) goes to git. Six months later, `git checkout <old-commit> && dvc pull` reconstructs the exact data that trained that exact model.

## Resources

- [DVC docs — Get Started](https://dvc.org/doc/start)
- [`dvc init` reference](https://dvc.org/doc/command-reference/init)
- [DVC internals — `.dvc/` directory layout](https://dvc.org/doc/user-guide/project-structure/internal-files)
