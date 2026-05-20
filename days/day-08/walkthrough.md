# Day 8 — Walkthrough

The actual run, preserved. The [README](README.md) describes the final shape; this file shows what pre-commit printed at each step and what we learned along the way.

## Starting state

`/root/code/fraud-detection/.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v2.3.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check_yaml

  - repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.1.0
    hooks:
      - id: ruff-lint

  - repo: https://github.com/psf/black-pre-commit-mirror
    hooks:
      - id: black
```

Four things wrong:

1. `id: check_yaml` — underscore; correct id is `check-yaml`.
2. `repo: .../charliermarsh/ruff-pre-commit` — old fork name. The grader requires `astral-sh/ruff-pre-commit` literally. Tool-side, GitHub redirects, so pre-commit never complains.
3. `id: ruff-lint` — not a real hook id; correct is `ruff`.
4. Black block missing `rev:` — required key.

## Step 0 — cheapest signal: `pre-commit run --all-files`

Pre-commit fails *config validation* before it tries to resolve hooks. First error:

```
An error has occurred: InvalidConfigError:
==> File .pre-commit-config.yaml
==> At Config()
==> At key: repos
==> At Repository(repo='https://github.com/psf/black-pre-commit-mirror')
=====> Missing required key: rev
```

**What this proved:**

- Validation phases are ordered. Pre-commit checks the config shape first, then hook resolution, then execution. We get one error class at a time — handy for step-by-step debugging.
- Any string in `rev:` clears this error. The value gets rewritten by `autoupdate` later, so don't waste lab time looking it up. `rev: 24.10.0` (or `rev: TODO`) is fine.

## Step 1 — add `rev:` to black

```yaml
  - repo: https://github.com/psf/black-pre-commit-mirror
    rev: 24.10.0
    hooks:
      - id: black
```

Re-run. Next error:

```
[INFO] Initializing environment for https://github.com/pre-commit/pre-commit-hooks.
[WARNING] repo uses deprecated stage names (commit, push) which will be removed in a future version.
[ERROR] `check_yaml` is not present in repository https://github.com/pre-commit/pre-commit-hooks.
        Typo? Perhaps it is introduced in a newer version?
        Often `pre-commit autoupdate` fixes this.
```

**What this proved:**

- We moved past config validation into hook resolution. Different phase, different error class.
- The deprecated-stage-names warning is from `v2.3.0` (very old). The pre-commit project renamed `commit` / `push` stages to `pre-commit` / `pre-push`. `autoupdate` would fix it; we ignore it for now.
- Hook ids universally use hyphens, not underscores. The "underscore vs hyphen" trap shows up again later for ruff.

## Step 2 — fix `check_yaml` → `check-yaml`

Re-run. Next error:

```
[INFO] Initializing environment for https://github.com/charliermarsh/ruff-pre-commit.
[ERROR] `ruff-lint` is not present in repository https://github.com/charliermarsh/ruff-pre-commit.
```

**Note what's *not* in this error:** no complaint about the URL. GitHub silently redirects `charliermarsh/ruff-pre-commit` → `astral-sh/ruff-pre-commit`, so pre-commit happily clones it. The hook id is what's surfaced.

This is the moment where "tool silence ≠ grader pass" matters — we'll come back to this.

## Step 3 — fix `ruff-lint` → `ruff`

Re-run:

```
[INFO] Initializing environment for https://github.com/psf/black-pre-commit-mirror.
[INFO] Installing environment for https://github.com/pre-commit/pre-commit-hooks.
[INFO] Installing environment for https://github.com/charliermarsh/ruff-pre-commit.
[INFO] Installing environment for https://github.com/psf/black-pre-commit-mirror.
Trim Trailing Whitespace.................................................Failed
- hook id: trailing-whitespace
- exit code: 1
- files were modified by this hook

Fixing process.py

Fix End of Files.........................................................Passed
Check Yaml...............................................................Passed
ruff.....................................................................Passed
black....................................................................Passed
```

All five hooks ran. `trailing-whitespace` *failed* and *fixed* `process.py` in the same step — exit code 1 with the message `files were modified by this hook`.

**The exit-1-on-success gotcha:** the hook did its job. The file is now correct. But pre-commit signals failure (exit 1) so that the would-be commit is blocked — the user needs to re-stage the autofixed file and re-commit. In CI, this means a fresh PR with whitespace issues sees a *red* hook on the first run even though everything got fixed; you re-run and it's green. The semantics are "commit cannot proceed as-is," not "hook didn't work."

## Step 4 — re-run, confirm green

```
Trim Trailing Whitespace.................................................Passed
Fix End of Files.........................................................Passed
Check Yaml...............................................................Passed
ruff.....................................................................Passed
black....................................................................Passed
```

All five passing. Then:

```bash
pre-commit install
# pre-commit installed at .git/hooks/pre-commit
```

This is the step the task explicitly calls out separately from `pre-commit run`:

- `pre-commit install` writes the git hook at `.git/hooks/pre-commit`. From now on, `git commit` invokes pre-commit automatically.
- `pre-commit run --all-files` is a manual one-shot invocation against every tracked file — what we'd do in CI, or as a sanity check.

Both are required; doing one is not the other.

## Step 5 — grader fails on the URL

The grader returned:

> The ruff-pre-commit URL must reference the astral-sh organisation — found 'https://github.com/charliermarsh/ruff-pre-commit'

This is the most important lesson of the day. The tool ran cleanly with `charliermarsh/...` because GitHub redirects, but the grader does *literal string matching* on the URL.

**What this proved:**

- Tools fail loud on syntax and resolution errors but stay silent for "wrong but functional" content. A redirected URL, a deprecated-but-still-resolving hook id, a successfully-formatted file with a wrong heading — all of these slip past the tool and bite the grader.
- The acceptance criteria are the contract. The tool is one of several partial verifications.
- The fix order in this lab matters: I should have re-read the criteria *first*, before letting pre-commit's error stream drive what I changed.

Fixed:

```yaml
  - repo: https://github.com/astral-sh/ruff-pre-commit
```

Grader green.

## Step 6 — `pre-commit autoupdate`

After everything was working, ran `autoupdate`. It queries each referenced repo and rewrites the `rev:` pins to the latest released tags. Output is the diff of what changed; in our case the three repos all jumped versions:

- `pre-commit/pre-commit-hooks` v2.3.0 → current (latest at run-time)
- `astral-sh/ruff-pre-commit` v0.1.0 → current
- `psf/black-pre-commit-mirror` 24.10.0 → current

This is the standard "I don't want to look up versions by hand" flow. Workflow is:

1. Write the config with rough `rev:` values (or `rev: TODO`).
2. `pre-commit autoupdate` rewrites them to whatever's current.
3. Commit the resulting pins. Now they're frozen until you re-run autoupdate.

The deprecated-stage-names warning from Step 1 also went away because the newer `pre-commit-hooks` release uses the modern stage names (`pre-commit` / `pre-push`).

## Gotchas worth remembering

- **Acceptance criteria > tool errors.** The single biggest lesson today. Before declaring done, walk back through every acceptance bullet against the final state.
- **Hook ids use hyphens.** `check_yaml`, `ruff_lint`, `endoffile_fixer` — all invalid. Universal across pre-commit.
- **GitHub redirects mask repo-rename mistakes.** `charliermarsh/ruff-pre-commit` resolves cleanly via redirect — `autoupdate` would rewrite the URL, the grader catches it, the tool itself never complains. Worth knowing for any tooling that takes a URL.
- **Exit 1 with "files were modified" is success.** The hook ran and fixed; pre-commit blocks the commit so you re-stage and re-commit. CI gotcha.
- **`pre-commit install` ≠ `pre-commit run`.** Two different actions. The task required both.
- **`autoupdate` is the version-discovery flow.** Don't lookup tag names manually.

## What this day proves for the rest of the course

Pre-commit is the floor of automated checks. Day 76+ (CI/CD) runs the same hooks in GitHub Actions; Day 86+ (orchestration) treats `pre-commit run` as one stage in a longer pipeline. The hooks themselves are the same tools we already configured: ruff (Day 6), black (Day 6). The pattern — repo + rev + hook id — is the same shape DVC uses for `dvc.yaml` stages, Argo uses for workflow steps, and so on. Reusable, named, version-pinned tool invocations are the substrate everything else runs on.
