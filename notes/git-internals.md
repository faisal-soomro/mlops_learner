# Git internals — the `.git/` directory

Cross-cutting note. Git is content-addressed storage with a thin layer of pointers on top. Once you see the shape of `.git/`, a lot of git's surface behaviour stops feeling magical.

## Contents

- [The 30-second mental model](#the-30-second-mental-model)
- [The `.git/` directory layout](#the-git-directory-layout)
- [`.git/objects/` — the content store](#gitobjects--the-content-store)
- [The four object types](#the-four-object-types)
- [`.git/refs/` and `HEAD` — pointers into objects](#gitrefs-and-head--pointers-into-objects)
- [`.git/index` — the staging area](#gitindex--the-staging-area)
- [What "corruption" actually means](#what-corruption-actually-means)
- [Why this matters for MLOps tools](#why-this-matters-for-mlops-tools)
- [Inspecting objects yourself](#inspecting-objects-yourself)

## The 30-second mental model

Git stores **content**, not diffs. Every file you commit is hashed (SHA-1, soon SHA-256) and the bytes are written to a file under `.git/objects/`. Directory structures, commits, and tags are also stored as objects in the same store. Branches and tags are just **named pointers** that say "the current tip is this hash."

That's the whole thing. Everything else — `git log`, `git diff`, `git checkout`, `git merge` — is computed on top of this object database.

## The `.git/` directory layout

```
.git/
├── HEAD                    # which branch (or commit) is currently checked out
├── config                  # repo-local config (remotes, user.email, etc.)
├── description             # used by gitweb; usually ignored
├── index                   # the staging area (binary file)
├── hooks/                  # client-side hooks (pre-commit, etc.)
├── info/
│   └── exclude             # repo-local gitignore (not committed)
├── logs/                   # reflog — every ref movement, locally
│   ├── HEAD
│   └── refs/heads/main
├── objects/                # ← THE CONTENT STORE
│   ├── 5a/
│   │   └── 6271743e99d5e... # one object file
│   ├── pack/               # packed objects (compression for old objects)
│   └── info/
└── refs/                   # named pointers into objects/
    ├── heads/              # local branches
    │   └── main
    ├── tags/
    └── remotes/
        └── origin/
            └── main
```

## `.git/objects/` — the content store

Every piece of content git knows about lives here, **content-addressed by its SHA-1 hash**.

Layout: `.git/objects/<first 2 chars of hash>/<remaining 38 chars>`. The two-char prefix split is a filesystem-friendliness trick — directories with millions of entries are slow on most filesystems, so git shards them by the first byte of the hash.

Each object file is **zlib-compressed**. You can't just `cat` it — you need `git cat-file` (see below).

**Content-addressed** means: two files with identical bytes share one object. If you commit `data.csv` and then commit it again unchanged on another branch, there's still only one blob on disk. Deduplication is free.

## The four object types

| Type | What it is | Contains |
|---|---|---|
| **blob** | file contents | just the bytes, no filename or mode |
| **tree** | a directory | list of `(mode, name, hash)` entries pointing to blobs and subtrees |
| **commit** | a snapshot | pointer to one root tree, parent commit hash(es), author, committer, message |
| **tag** | an annotated tag | pointer to a commit, tag name, tagger, message, optional signature |

The hierarchy: a **commit** points to one **tree** (the root directory), which points to **blobs** (files) and other **trees** (subdirectories), recursively. Walking back through parent commits gives you history. **Tags** are just labelled pointers, optionally signed.

Filenames live in trees, *not* in blobs. The same blob can appear under different names across history without duplication.

## `.git/refs/` and `HEAD` — pointers into objects

Branches and tags are **plain text files** containing a commit hash:

```bash
$ cat .git/refs/heads/main
d680be3c4f8a91b...
```

That's it. A branch is one line. Creating a branch is `echo <hash> > .git/refs/heads/<name>`. Deleting a branch is `rm .git/refs/heads/<name>`. (Don't actually do this — use `git branch` — but it's worth knowing how lightweight refs are.)

`HEAD` is similar but indirected:

```bash
$ cat .git/HEAD
ref: refs/heads/main
```

It points to a branch (which points to a commit). When you `git checkout <commit-hash>` directly, `HEAD` contains the hash instead of a `ref:` line — that's the "detached HEAD" state.

## `.git/index` — the staging area

The index is a **binary file** listing what'll go into the next commit: filenames, modes, and the hash of each file's currently-staged blob. When you `git add foo.py`, git hashes `foo.py`, writes the blob to `.git/objects/`, and updates the index to point at it. `git commit` then converts the index into a tree object and creates a commit pointing to it.

This is why `git add` is necessary even for already-tracked files: it re-snapshots them into the index. Skipping it means the commit captures the *previously-staged* version.

## What "corruption" actually means

Object database corruption is rare but catastrophic. The usual scenarios:

- **Truncated object file** — disk full mid-write, killed `git gc`, filesystem crash
- **Permissions wrong** — git can't read its own files (`chmod`-gone-wrong, container UID mismatch)
- **Manual deletion** — someone ran `rm -rf .git/objects/<some-dir>/` thinking it was scratch
- **Pack file damage** — `.git/objects/pack/*.pack` is a compressed archive of many objects; one bad byte can lose thousands of objects

Symptoms: `git log` errors with `fatal: bad object`, `git fsck` lists missing objects, `git checkout <old-branch>` fails because the tree it points to is unreachable. **Refs still look fine** — the branch file is intact, it just points at a hash whose object is gone.

Recovery options (in order of how much you'll lose):

1. `git fsck --full` — diagnose what's missing
2. Restore from a clone (`git clone` from origin or another machine) — usually the fastest fix
3. `git reflog` — local-only log of ref movements; sometimes lets you recover commits that aren't referenced by any branch
4. `git fsck --lost-found` — surfaces dangling objects you might be able to graft back

If `.git/` is gone entirely and you have no remote, the working tree alone is unrecoverable as history — you can only `git init` and start over.

## Why this matters for MLOps tools

Several MLOps tools either **ride on top of** `.git/objects/`-style storage or **deliberately bypass it**:

- **DVC** — uses its own content-addressed cache at `.dvc/cache/` for *large* files (because git's object store is slow and bloated for multi-GB blobs). The shape is identical: hash-prefixed directory sharding, deduplicated by content. DVC then commits small `.dvc` pointer files to git's object store.
- **Git LFS** — same idea, different implementation. Pointer file in git, real bytes elsewhere.
- **MLflow** — stores experiment artifacts outside git entirely, but uses content-addressed storage internally for the same dedup reasons.
- **OCI image layers** — Docker images are content-addressed by layer digest; identical layers across images are stored once. Same pattern, different scope.

Once you've internalised "content-addressed store + named pointers," you'll recognise the shape everywhere: container registries, package mirrors, BitTorrent, IPFS. Git just happens to be where most developers see it first.

## Inspecting objects yourself

```bash
# What type is this object?
git cat-file -t <hash>

# Show its contents (decompressed and pretty-printed)
git cat-file -p <hash>

# Show all objects reachable from HEAD
git rev-list --objects --all

# Verify integrity of the whole object database
git fsck --full

# Find the object for a specific file at a specific commit
git ls-tree <commit-hash> path/to/file.py

# What's HEAD pointing at right now?
cat .git/HEAD
git rev-parse HEAD
```

A useful warm-up: in any git repo, find your latest commit hash with `git rev-parse HEAD`, then `git cat-file -p <hash>`. You'll see the commit object's fields (tree, parent, author, committer, message). Then `git cat-file -p <tree-hash-from-that-output>` shows the directory listing. Recurse into a subtree, eventually land on a blob, `git cat-file -p` it, and you've just walked the entire content graph by hand.
