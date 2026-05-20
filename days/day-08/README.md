# Day 8 — Configure Pre-Commit Hooks for ML Repository

> **Step-by-step run-through with what each step proves and the gotchas hit:** see [walkthrough.md](walkthrough.md). For the cross-cutting writeup on pre-commit (lifecycle, autoupdate, error phases, exit-1-on-success, mirror repos), see [`notes/pre-commit.md`](../../notes/pre-commit.md). This README is the TL;DR.

## Task

Correct the team's broken `.pre-commit-config.yaml` at `/root/code/fraud-detection/` so `pre-commit run --all-files` executes every required hook.

**Acceptance criteria:**

- Five hooks declared: `trailing-whitespace`, `end-of-file-fixer`, `check-yaml` (from `pre-commit/pre-commit-hooks`); `ruff` (from `astral-sh/ruff-pre-commit`); `black` (from `psf/black-pre-commit-mirror`).
- Every repository entry includes a `rev:` field.
- `pre-commit install` registers the hooks with git.
- `pre-commit run --all-files` runs all five hooks.

## Why this matters

Pre-commit is the floor of CI-on-developer-laptop. The same hooks that protect `main` from bad commits run *before* the commit lands — feedback in seconds instead of waiting for a CI cycle. For ML code (notebook leftovers, drifting style, unsorted imports), most violations are mechanically fixable; pre-commit either auto-fixes them or refuses the commit.

The pattern also captures *upstream* tool versions: each repo has its own `rev:` pin, and `pre-commit autoupdate` queries the upstream and rewrites the pins. The team's config is the single source of truth for "which lint/format tools, which versions, do we enforce."

## How to run

The final shape of `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.7.4
    hooks:
      - id: ruff

  - repo: https://github.com/psf/black-pre-commit-mirror
    rev: 24.10.0
    hooks:
      - id: black
```

(A reference copy is in [`.pre-commit-config.yaml`](.pre-commit-config.yaml). `autoupdate` will refresh the `rev:` values to current.)

Then:

```bash
cd /root/code/fraud-detection
pre-commit autoupdate       # refresh rev pins to current
pre-commit install          # register .git/hooks/pre-commit
pre-commit run --all-files  # run all hooks against tracked files
```

## Diagnosis — what the lab plants

| Symptom | Cause | Fix |
|---|---|---|
| `InvalidConfigError: Missing required key: rev` | a `repo:` block has no `rev:` | add a `rev:` (any value — `autoupdate` rewrites) |
| `'check_yaml' is not present in repository` | hook id uses underscore | `id: check-yaml` (hyphen) |
| `'ruff-lint' is not present in repository` | wrong hook id | `id: ruff` |
| Grader fails with "must reference astral-sh" but tool runs fine | `charliermarsh/ruff-pre-commit` works via GitHub redirect, but the grader string-matches the URL | use `astral-sh/ruff-pre-commit` literally |
| Exit 1 with "files were modified by this hook" | `trailing-whitespace` / `end-of-file-fixer` auto-fixed something | re-run; second pass should be clean |
| Warning: `repo uses deprecated stage names (commit, push)` | older hook repo declares `stages: [commit]` instead of `[pre-commit]` | `pre-commit autoupdate` rewrites the pin to a version that uses the new names |

## Key gotchas

- **Acceptance criteria are the source of truth, not tool errors.** A `charliermarsh/ruff-pre-commit` URL "works" because GitHub redirects — `pre-commit` will run successfully against it — but the grader checks the literal text. Cross-check every acceptance bullet against the final file before declaring done.
- **Hook ids use hyphens, not underscores.** Universal across pre-commit hooks.
- **`rev:` is required even when you don't know the value.** Add `rev: TODO`, run `autoupdate`, and pre-commit picks the latest tag for you. The standard discovery flow.
- **"Files were modified by this hook" is exit-code 1.** The hook *worked* — it auto-fixed the file — but pre-commit signals "the commit cannot proceed" because the file changed. CI gotcha: a green hook on a fresh PR may flip red on a `trailing-whitespace` autofix. Run twice if needed.
- **`pre-commit install` is separate from `pre-commit run`.** `install` writes `.git/hooks/pre-commit`; `run` invokes the hooks once manually. The task requires both.

## Resources

- [pre-commit docs](https://pre-commit.com/) — short, readable; the [configuration reference](https://pre-commit.com/#pre-commit-configyaml---top-level) is the page worth bookmarking.
- [pre-commit-hooks (the official "hooks repo")](https://github.com/pre-commit/pre-commit-hooks) — full list of built-in hooks and their IDs.
- [astral-sh/ruff-pre-commit](https://github.com/astral-sh/ruff-pre-commit) — ruff's pre-commit integration.
- [psf/black-pre-commit-mirror](https://github.com/psf/black-pre-commit-mirror) — black's pre-commit integration; note "mirror" — the canonical black repo doesn't ship a `.pre-commit-hooks.yaml`, so this mirror is the right one to reference.
- [pre-commit autoupdate](https://pre-commit.com/#pre-commit-autoupdate) — the standard way to discover and pin current versions.
