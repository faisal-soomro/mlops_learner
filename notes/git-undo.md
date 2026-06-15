# Git "undo" verbs

Git has at least five commands that all sound like "undo," and they all do different things. This note is the cheat sheet.

## Contents

- [The five verbs at a glance](#the-five-verbs-at-a-glance)
- [`git reset` — move HEAD, optionally rewrite working tree](#git-reset--move-head-optionally-rewrite-working-tree)
- [`git revert` — make a new commit that inverts an old one](#git-revert--make-a-new-commit-that-inverts-an-old-one)
- [`git restore` — restore working-tree or index contents](#git-restore--restore-working-tree-or-index-contents)
- [`git checkout` — the legacy multi-tool](#git-checkout--the-legacy-multi-tool)
- [`git commit --amend` — modify the last commit](#git-commit---amend--modify-the-last-commit)
- [Decision tree](#decision-tree)
- [The three places a file lives in git](#the-three-places-a-file-lives-in-git)
- [Recovery: undoing an undo](#recovery-undoing-an-undo)

## The five verbs at a glance

| Command | Modifies | Safe for pushed commits? | Use it when |
|---|---|---|---|
| `git reset` | HEAD, optionally index/working tree | ❌ No — rewrites history | Local-only commits you want to redo |
| `git revert` | Adds a new commit | ✅ Yes — adds rather than rewrites | Undoing a commit that's already public |
| `git restore` | Working tree and/or index only | ✅ Yes — doesn't touch commits | Discarding unstaged changes, unstaging files |
| `git checkout` | Working tree, index, or HEAD (depending) | ⚠️ Mixed — depends on usage | Older muscle memory; prefer `restore` / `switch` for new code |
| `git commit --amend` | The last commit | ❌ No — rewrites the tip | Fixing the last commit before it's pushed |

## `git reset` — move HEAD, optionally rewrite working tree

`reset` moves the current branch's HEAD pointer backwards. Three flavours differ in how aggressively they touch your files.

| Mode | HEAD moves? | Index changes? | Working tree changes? |
|---|---|---|---|
| `--soft` | yes | no | no |
| `--mixed` (default) | yes | yes (reset to new HEAD) | no |
| `--hard` | yes | yes | yes (irreversibly!) |

### `--soft`

```bash
git reset --soft HEAD~1
```

Removes the last commit. Everything that *was* in that commit is now staged. Use this when you want to **recommit the same changes plus more** — e.g. "I committed too early and need to add a forgotten file" or "I made a typo in the message."

### `--mixed` (default — no flag needed)

```bash
git reset HEAD~1
```

Removes the last commit. Changes are now in the working tree, **unstaged**. Use when you want to **re-decide what to stage**.

### `--hard`

```bash
git reset --hard HEAD~1
```

Removes the last commit *and* throws away the changes. Use only when you're sure you want to delete work. The reflog can sometimes recover from this (see [Recovery](#recovery-undoing-an-undo)) but don't rely on it.

### Resetting more than one commit

`HEAD~1` is "one commit back." `HEAD~3` is "three commits back." `HEAD~N` is "N commits back." You can also reset to a specific hash: `git reset --soft abc1234`.

## `git revert` — make a new commit that inverts an old one

```bash
git revert abc1234
```

Doesn't rewrite history — it creates a **new commit** whose changes are the inverse of `abc1234`. The old commit stays in history; the new one cancels it out.

This is the right tool for **anything that's been pushed**. Force-pushing a `reset` over a shared branch breaks every other collaborator's local clone. `revert` is safe because it's just another commit on top.

```bash
# Revert the last commit
git revert HEAD

# Revert a range (creates one revert commit per commit in the range)
git revert HEAD~3..HEAD

# Revert but stage the inverse changes without committing
git revert --no-commit abc1234
```

## `git restore` — restore working-tree or index contents

Introduced in Git 2.23 (2019) to split `checkout`'s overloaded duties. Two flags decide what gets restored:

| Command | What it does |
|---|---|
| `git restore <file>` | Discard unstaged changes in `<file>` (working tree → matches index) |
| `git restore --staged <file>` | Unstage `<file>` (index → matches HEAD); changes remain in working tree |
| `git restore --source=HEAD~3 <file>` | Restore `<file>` to what it was at `HEAD~3` |
| `git restore --staged --worktree <file>` | Both: unstage AND discard unstaged changes |

This is the modern replacement for `git checkout -- <file>` (discard) and `git reset HEAD <file>` (unstage). Cleaner because the verb tells you it's about *files*, not commits or branches.

## `git checkout` — the legacy multi-tool

Before 2.23, `git checkout` was overloaded to mean:
- Switch branches (`git checkout main`)
- Create a branch (`git checkout -b feature`)
- Discard file changes (`git checkout -- foo.py`)
- Restore a file to a past version (`git checkout abc1234 -- foo.py`)

All still work. But `switch` (for branches) and `restore` (for files) are the modern split. Use them in new muscle memory; `checkout` is fine when you know what you mean.

## `git commit --amend` — modify the last commit

```bash
# Fix the last commit message
git commit --amend -m "new message"

# Add staged changes to the last commit (keep old message)
git add forgotten.py
git commit --amend --no-edit
```

Replaces the last commit with a new one. Hash changes — same content as a `reset --soft` + new commit, but written as one operation.

**Use only on unpushed commits.** Amending after push requires force-push to share, which is destructive for collaborators (see CLAUDE.md global guidance).

**This project's convention:** prefer `git reset --soft HEAD~1` + new commit over `--amend`. The reset-and-recommit flow is more explicit about what you're doing, and a pre-commit hook failure leaves you with the changes safely staged rather than potentially-lost.

## Decision tree

```
Did the bad thing get pushed?
├── Yes → git revert (always safe; adds a new commit)
└── No  → Did you make a commit, or just stage/edit something?
         ├── Made a commit
         │   ├── Want to add more / fix message → git reset --soft HEAD~1 (then recommit)
         │   ├── Want to re-decide what to stage → git reset HEAD~1
         │   └── Want to throw away the work     → git reset --hard HEAD~1
         └── Just staged or edited
             ├── Want to unstage a file          → git restore --staged <file>
             ├── Want to discard unstaged edits  → git restore <file>
             └── Want to discard staged edits    → git restore --staged --worktree <file>
```

## The three places a file lives in git

Understanding which place each command touches makes this all click.

```
working tree  →  index (staging area)  →  HEAD (last commit)
              ↑                        ↑
              git add                  git commit
```

| Command | Touches working tree? | Touches index? | Touches HEAD? |
|---|---|---|---|
| `git restore <file>` | ✅ | | |
| `git restore --staged <file>` | | ✅ | |
| `git restore --staged --worktree <file>` | ✅ | ✅ | |
| `git reset --soft HEAD~1` | | | ✅ |
| `git reset --mixed HEAD~1` | | ✅ | ✅ |
| `git reset --hard HEAD~1` | ✅ | ✅ | ✅ |
| `git revert HEAD` | ✅ | ✅ | ✅ (adds new commit) |
| `git commit --amend` | | | ✅ (replaces tip) |

## Recovery: undoing an undo

If you `reset --hard` and panic, **try the reflog first**:

```bash
git reflog
```

This shows every position HEAD has been in recently — including the commit you just nuked. To recover:

```bash
git reset --hard HEAD@{1}   # "where HEAD was one move ago"
# or directly by hash from the reflog output
git reset --hard abc1234
```

The reflog is local-only and prunes after 90 days by default (`gc.reflogExpire`). It's a safety net for *recent* mistakes, not long-term recovery.

If even the reflog has been pruned, your last hope is `git fsck --lost-found` — it surfaces dangling commits not reachable from any ref. Hit-or-miss but worth trying.

## Why this matters for MLOps

You'll redo commits more often during MLOps work than during regular feature dev — labs and tutorials have grader-required exact commit messages, and "I committed before adding the .dvc pointer" is a common mistake (literally Day 11 of this roadmap). Knowing `reset --soft` vs `--amend` is the difference between "fix it cleanly in 10 seconds" and "force-push and hope nobody notices."
