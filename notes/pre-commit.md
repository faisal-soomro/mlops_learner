# `pre-commit` — lifecycle, mechanics, and the gotchas

Cross-cutting notes on the [pre-commit](https://pre-commit.com/) framework. It's the floor of "automated checks on every commit": a tool that orchestrates other tools (ruff, black, file-fixers, custom scripts) by repo + version + hook id, runs them in a git hook, and refuses the commit if any of them fail. The same hooks then run in CI for the cases where a developer skipped the local check.

## Contents

- [Why `pre-commit` exists](#why-pre-commit-exists)
- [The two-verb mental model: `install` vs `run`](#the-two-verb-mental-model-install-vs-run)
- [Config shape](#config-shape)
- [`autoupdate` — the version discovery flow](#autoupdate--the-version-discovery-flow)
- [Three-phase error ordering](#three-phase-error-ordering)
- [Exit-1-on-success: "files were modified by this hook"](#exit-1-on-success-files-were-modified-by-this-hook)
- [Hook ids use hyphens](#hook-ids-use-hyphens)
- [Mirror repos — why `psf/black-pre-commit-mirror` and not `psf/black`](#mirror-repos--why-psfblack-pre-commit-mirror-and-not-psfblack)
- [The deprecated stage names migration](#the-deprecated-stage-names-migration)
- [Tool silence ≠ grader/CI pass](#tool-silence--gradercI-pass)
- [See also](#see-also)

## Why `pre-commit` exists

Three problems on every shared codebase:

- **Style drift.** Without an enforced formatter, every PR contains both real changes and whitespace noise. Reviewers spend cycles on the noise.
- **Forgotten checks.** Engineers know they're "supposed to" run lint/format before pushing, but forget. CI catches it five minutes later, which is too late — the context has already shifted.
- **Per-tool config sprawl.** Ruff, black, mypy, isort each have their own config and their own way of being invoked. New joiners need a flowchart to know what to run.

`pre-commit` collapses all three: one config file, one binary, one command. The hooks run automatically on `git commit` and fail loud if anything's wrong.

The same `.pre-commit-config.yaml` runs in CI (typically `pre-commit run --all-files`), so local and CI verdicts cannot diverge.

## The two-verb mental model: `install` vs `run`

`install` and `run` are **orthogonal**. Neither requires the other; they touch different parts of the system; they can be invoked in any order, independently, or not at all. They solve different problems.

| Verb | What it touches | What it checks | When to use |
|---|---|---|---|
| `pre-commit install` | Writes `.git/hooks/pre-commit`. Does **not** run any hooks. | Nothing yet — only registers the automatic invocation. | Once per clone. |
| `git commit` (after install) | Uses the installed hook. | The **staged** files for this commit. | Implicit on every commit. |
| `pre-commit run` | Nothing in `.git/`. Just runs hooks once. | Staged files by default. | One-off sanity check before pushing. |
| `pre-commit run --all-files` | Same as above. | **Every** tracked file, ignores staging. | In CI; whenever you change the config and want to validate the whole tree. |
| `pre-commit autoupdate` | Rewrites `rev:` pins in `.pre-commit-config.yaml`. | Nothing — purely a version-bump operation. | Periodically. |
| `pre-commit uninstall` | Removes `.git/hooks/pre-commit`. | Nothing. | Rarely — when migrating frameworks. |

So you can:

- **Run only `pre-commit run`** — works fine, validates the tree once. But future `git commit` invocations skip pre-commit entirely; you're relying on yourself remembering to run it.
- **Run only `pre-commit install`** — every commit is automatically gated, but you don't sanity-check the whole tree (only newly staged files).
- **Both** — what most teams do. `install` once per clone (so every commit is protected); `run --all-files` in CI (so the whole tree stays clean).

What `install` does *not* do:

- It does not validate the config.
- It does not run any hook.
- It does not exit non-zero on a broken config.

So `pre-commit install` succeeding is not proof the config is correct. To validate the config, `pre-commit run --all-files` (or any `pre-commit run`) is the verb that does the work.

**The lab takeaway:** when a task says "register the hooks with git *and* run them against tracked files," it's calling out both operations explicitly because doing one is genuinely not doing the other.

## Config shape

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
        args: [--fix]   # optional per-hook arguments

  - repo: https://github.com/psf/black-pre-commit-mirror
    rev: 24.10.0
    hooks:
      - id: black
```

Top-level `repos:` is a list. Each item is one upstream repo with:

- `repo:` — the URL.
- `rev:` — the version tag to use. Required even if you don't know which value you want (use any string and let `autoupdate` rewrite it).
- `hooks:` — list of hooks to enable from that repo. Each item is at least `id:`, optionally `args:`, `files:`, `exclude:`, `language_version:`, `stages:`, and others.

The set of *available* hook ids per repo is defined by that repo's `.pre-commit-hooks.yaml`. Pre-commit clones each repo into `~/.cache/pre-commit/` on first use, reads the manifest, and matches your `id:` against it.

## `autoupdate` — the version discovery flow

```bash
pre-commit autoupdate
```

Walks every `repo:` entry, asks GitHub for the latest released tag, rewrites `rev:` in place. Standard "I don't want to look up versions by hand" flow:

1. Write the config with rough or placeholder `rev:` values (literally `rev: TODO` works).
2. Run `pre-commit autoupdate`.
3. Commit the result.

The output is a diff of what changed:

```
[https://github.com/astral-sh/ruff-pre-commit] updating v0.1.0 -> v0.7.4
[https://github.com/psf/black-pre-commit-mirror] updating 24.10.0 -> 24.10.0
[https://github.com/pre-commit/pre-commit-hooks] updating v2.3.0 -> v5.0.0
```

Re-running `pre-commit autoupdate` is the maintenance pattern — periodically refresh the pins, review the diff, commit if happy.

`--repo <URL>` limits the update to one repo, useful when you specifically want one upstream tool's latest but don't want to bump others.

## Three-phase error ordering

When `pre-commit run --all-files` fails, the failure comes from one of three phases. Knowing which phase tells you where to look.

**Phase 1 — config validation.** Pre-commit parses the YAML against its schema. Errors look like:

```
An error has occurred: InvalidConfigError:
==> File .pre-commit-config.yaml
=====> Missing required key: rev
```

Common: missing `rev:`, missing `repos:` top-level, wrong key names.

**Phase 2 — hook resolution.** Pre-commit clones each upstream repo (cached after first use), reads its `.pre-commit-hooks.yaml`, and checks that every `id:` you declared exists. Errors look like:

```
[ERROR] `check_yaml` is not present in repository https://github.com/pre-commit/pre-commit-hooks.
        Typo? Perhaps it is introduced in a newer version?
```

Common: typo in `id:`, hook moved between repos, hook removed in newer version.

**Phase 3 — execution.** Each hook actually runs against the target files. Errors are the tool's own output ("Trim Trailing Whitespace ... Failed", with the file list).

Read the first error. If it's a config-validation message, you can't trust *any* subsequent output because phase 2 and 3 never ran. Fix phase 1 first, re-run, fix the next phase. The lab-debugging shape is "one phase at a time."

## Exit-1-on-success: "files were modified by this hook"

```
Trim Trailing Whitespace.................................................Failed
- hook id: trailing-whitespace
- exit code: 1
- files were modified by this hook

Fixing process.py
```

The hook *worked* — it found trailing whitespace and removed it. But pre-commit reports it as Failed with exit 1.

**The reason:** pre-commit's contract is "if this hook fails, refuse the commit." A hook that auto-fixes files is doing useful work, but the developer's *original* committed files were wrong — they had whitespace. Pre-commit blocks the commit so the developer re-stages the fixed files (`git add`) and re-commits.

The semantics:

- `Passed` — hook ran, no issues found, no changes made.
- `Failed, files were modified` — hook ran, fixed the issue, but the original commit would not have included the fix. Re-stage and re-commit; second run will pass.
- `Failed, no files modified` — hook found an issue it could not auto-fix (e.g. ruff finding `F821` undefined name). The developer must edit and re-run.

**CI gotcha.** A fresh PR with formatting issues sees a *red* `pre-commit` job on the first run because of the autofix. The fix is to either:

- run pre-commit twice in CI (`pre-commit run --all-files || pre-commit run --all-files`), or
- enforce that developers run pre-commit *locally before pushing* (which is the point of `pre-commit install`), or
- use `pre-commit.ci` (a hosted service) that opens auto-fix PRs back into the branch.

Most teams pick the second. Some additionally use `pre-commit.ci` for catch-all.

## Hook ids use hyphens

`trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `ruff`, `black`. Not `trailing_whitespace`, not `check_yaml`. Universal across pre-commit hooks.

Pre-commit will tell you, but the underscore-vs-hyphen trap recurs often enough that the heuristic is worth memorising: when in doubt, hyphens.

## Mirror repos — why `psf/black-pre-commit-mirror` and not `psf/black`

Some tool maintainers don't want to ship a `.pre-commit-hooks.yaml` in their main repo — it implies a maintenance commitment, the file shape changes as pre-commit evolves, and the tool's release cadence may not match pre-commit's expectations.

The workaround: a *mirror* repo whose only purpose is to publish `.pre-commit-hooks.yaml` pointing at the real tool. `psf/black-pre-commit-mirror` is that for black. It's tagged to match black's releases; the hook id `black` invokes the real `black` binary installed in pre-commit's isolated environment.

This is why the URL is `psf/black-pre-commit-mirror`, not `psf/black`. The latter would *technically* work if pre-commit's authors added the file, but they haven't. Always check upstream's own pre-commit docs to find the right repo.

Same pattern for some other tools — when in doubt, search `<tool> pre-commit` and look for an official mirror.

## The deprecated stage names migration

Older hook repos declared:

```yaml
stages: [commit, push]
```

Newer pre-commit (≥3.2) renamed these to:

```yaml
stages: [pre-commit, pre-push]
```

The new names match the actual git hook names — less ambiguous. The old names still work but pre-commit prints a warning:

```
[WARNING] repo uses deprecated stage names (commit, push)
```

`autoupdate` against any current upstream picks a version that uses the new names, and the warning disappears. If you're seeing this warning, your `rev:` pins are old — re-run `autoupdate`.

## Tool silence ≠ grader/CI pass

A subtle but important point: pre-commit ran cleanly against `https://github.com/charliermarsh/ruff-pre-commit` (the old fork name) because GitHub silently redirects the URL to `astral-sh/ruff-pre-commit`. The tool never complained. But a downstream verifier (grader, CI policy, audit) doing literal string matching on the URL will fail.

General lesson: **tools fail loud for syntax and resolution errors but stay silent for "wrong but functional" content.** Acceptance criteria are the contract. Before declaring a config done, cross-check every literal requirement (exact URLs, exact hook ids, presence of `rev:`, exact file location) against the final file. The tool running cleanly is necessary but not sufficient.

This is the same lesson that applies to:

- `pip install scikit-learn` vs the deprecated stub `pip install sklearn` (both "work" but one fails any audit).
- A wheel filename with normalised dashes that hide an underscore-vs-hyphen mistake in `[project] name`.
- A Makefile that targets `tests/` but isn't `.PHONY` (silent no-op).

The same pattern across tools: most of the time the runtime is forgiving and downstream verifiers are not. Cross-check.

## See also

- [pre-commit.com](https://pre-commit.com/) — the canonical docs. Short.
- [pre-commit-hooks (the built-in hooks repo)](https://github.com/pre-commit/pre-commit-hooks) — every standard hook (`trailing-whitespace`, `check-yaml`, `check-merge-conflict`, ...).
- [pre-commit.ci](https://pre-commit.ci/) — hosted service that runs `autoupdate` and submits PRs.
- [ruff's pre-commit guide](https://docs.astral.sh/ruff/integrations/#pre-commit) and [black's pre-commit guide](https://black.readthedocs.io/en/stable/integrations/source_version_control.html) — official guidance from each tool.
- `days/day-08/` — the lab that produced this content; the day's README and walkthrough have the specific broken config and the run.
