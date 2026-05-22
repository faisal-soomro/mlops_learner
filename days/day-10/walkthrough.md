# Day 10 — Walkthrough

First Domain 2 lab. After nine days of "lab plants a broken config, diagnose and fix," Day 10 was the opposite shape: clean repo, two commands, done. Worth slowing down anyway because most of the interesting bits aren't in the commands — they're in the *output* and the *files DVC dropped on disk*.

## Starting state

Repo at `/root/code/fraud-detection/` on `master`, one initial commit. Working tree:

```
fraud-detection/
├── .gitignore
├── README.md
├── data/raw/
├── models/
└── src/
```

Standard ML project skeleton (the `data/raw,processed` + `src/` shape from [notes/ml-project-layout.md](../../notes/ml-project-layout.md)). Nothing broken.

## Step 1 — confirm DVC is installed

```bash
$ dvc --version
3.67.1
```

DVC was pre-installed in the lab. 3.x is current (3.0 shipped 2023); older 2.x tutorials still work but a few flags differ.

## Step 2 — `dvc init`

```bash
$ cd /root/code/fraud-detection
$ dvc init
Initialized DVC repository.

You can now commit the changes to git.

+---------------------------------------------------------------------+
|                                                                     |
|        DVC has enabled anonymous aggregate usage analytics.         |
|     Read the analytics documentation (and how to opt-out) here:     |
|             <https://dvc.org/doc/user-guide/analytics>              |
|                                                                     |
+---------------------------------------------------------------------+

What's next?
------------
- Check out the documentation: <https://dvc.org/doc>
- Get help and share ideas: <https://dvc.org/chat>
- Star us on GitHub: <https://github.com/treeverse/dvc>
```

That `treeverse/dvc` URL surprised me — I assumed it was a typo for `iterative/dvc` (Iterative being the company behind DVC). Checked:

```bash
$ curl -sIL https://github.com/iterative/dvc | grep -i "^location\|^HTTP"
HTTP/2 301
location: https://github.com/treeverse/dvc
HTTP/2 200
```

`iterative/dvc` 301-redirects to `treeverse/dvc`. **Iterative was acquired by Treeverse** (the company behind [lakeFS](https://lakefs.io/), itself a "git-for-data" tool). So the CLI banner is correct — DVC moved orgs. The interesting story isn't a typo; it's that two competing data-versioning tools now live under the same roof.

## Step 3 — what DVC created

```bash
$ git status
On branch master
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   .dvc/.gitignore
        new file:   .dvc/config
        new file:   .dvcignore
```

**Already staged.** I expected to type `git add` next; didn't have to. DVC auto-stages the init artifacts because it knows you're inside a git repo and will want to commit them immediately. Older DVC versions (2.x) didn't do this; you had to add manually.

Two ways to opt out of git-aware init:

- `dvc init --no-scm` — initialise DVC in a non-git directory. No auto-stage because there's no git.
- `dvc init --subdir` — initialise DVC in a subdirectory of a git repo. Tracks the subdir-relative paths, useful in monorepos.

For this lab, the default is right.

### The full file tree after init

```
fraud-detection/
├── .dvc/
│   ├── .gitignore           # ignores everything in .dvc/ except config + this file
│   ├── config               # DVC config (remote URLs, cache settings)
│   └── tmp/                 # runtime scratch — gitignored
│       ├── btime
│       ├── celery/
│       │   ├── broker/{control,in,processed}
│       │   └── result/
│       ├── dag.md
│       └── exps/cache/
├── .dvcignore               # DVC's analog to .gitignore (which files DVC should skip)
├── .git/
├── .gitignore
├── README.md
├── data/raw/
├── models/
└── src/
```

The contents of `.dvc/tmp/` were the second surprise. I'd run *zero* DVC commands besides `init`, but `tmp/exps/cache/` already had cache directory shards in it, and `tmp/celery/broker/{control,in,processed}` looked like a message queue.

It is. DVC uses [Celery](https://docs.celeryq.dev/) (a distributed task queue) to run queued experiments in the background — `dvc exp run --queue` enqueues work into the file-based broker you see there. `init` pre-creates the directory skeleton so subsequent commands don't have to check-and-create on every invocation.

All of `.dvc/tmp/` is gitignored by the `.dvc/.gitignore` DVC wrote for us. It's runtime state, not source.

## Step 4 — commit

```bash
$ git commit -m "Initialize DVC"
[master d680be3] Initialize DVC
 3 files changed, 6 insertions(+)
 create mode 100644 .dvc/.gitignore
 create mode 100644 .dvc/config
 create mode 100644 .dvcignore
```

Three files, six lines of insertions. The commit message has to be exact — the grader likely string-matches `Initialize DVC`.

## Grader hint that wasn't a step

> Once initialisation is complete, the DVC extension will detect the new `.dvc/` directory and surface the DVC TRACKED section in the EXPLORER panel together with a DVC indicator in the bottom status bar.

This sentence isn't a task step — it's a UI confirmation cue. The DVC VS Code extension (pre-installed in the lab) watches for `.dvc/` directories and shows a panel + status-bar badge once it finds one. Not graded; just visual feedback that the extension is alive.

## What I'd watch for next time

- **Commit-message matching is brittle.** `Initialize DVC` only. Not `Initialise DVC` (UK spelling), not `Initialize dvc.`, not `init DVC`. Grader-tests are literal-string-matching; treat them like jinja2 graders ([notes/jinja2.md](../../notes/jinja2.md)).
- **`.dvc/tmp/` filling up over time** — once you start running experiments and pipelines, this directory grows. Safe to delete if you're not mid-run, but you'll lose queued experiments.
- **Don't manually edit `.dvc/config`** unless you know what you're doing. Use `dvc config <key> <value>` or `dvc remote add` so DVC writes the right schema.

## Connections

- `.dvc/cache/` (which we haven't created yet — appears on first `dvc add`) is **content-addressed storage**, the exact same shape as `.git/objects/`. See [notes/git-internals.md](../../notes/git-internals.md) for why every "versioning" tool ends up reaching for this pattern.
- The ML project skeleton this DVC repo sits on top of is from [notes/ml-project-layout.md](../../notes/ml-project-layout.md).
