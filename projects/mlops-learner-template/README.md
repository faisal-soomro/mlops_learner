# Project — `mlops-learner-template`

An opinionated Cookiecutter template that bakes every Day 1-9 pattern into a single project skeleton. Used to scaffold downstream toy projects ready for Domain 2 onwards.

## Status

In progress (planning).

## Why

Domain 1 produced nine separate skills (venv, lockfile, layout, Makefile, lint/format, packaging, pre-commit, scaffolding). They sit fine in their own day directories as study artifacts, but until they're *integrated* in one repo, the contradictions and gaps don't surface:

- `requirements.txt` (Day 1, from `pip freeze`) vs `requirements.in` (Day 3 spec) vs `pyproject.toml` `dependencies` (Day 7). Which one is the source of truth?
- `Makefile` (Day 5) drives setup, but `pre-commit` (Day 8) wants its own install step. How do they compose?
- `ruff`/`black` config (Day 6) sits in `pyproject.toml` (Day 7). What's the minimum complete `pyproject.toml`?

Solving these in one template is the practice that turns nine separate labs into one coherent skeleton.

## What it produces

A generated project that's *already*:

- Scaffolded with the Day 4 layout (`data/{raw,processed}/`, `src/{data,features,models,utils}/`, `tests/`, `configs/`, `notebooks/`, `models/`).
- Packaged with a working Day 7 `pyproject.toml` (`[build-system]`, `[project]`, `[tool.setuptools.packages.find]`).
- Pinned with a Day 3 `requirements.in` + a compiled `requirements.txt` lockfile.
- Linted/formatted with a Day 6 `[tool.ruff]` / `[tool.ruff.lint]` / `[tool.black]` configuration.
- Orchestrated with a Day 5 `Makefile` (`setup`, `data`, `train`, `test`, `lint`, `clean`, `all`).
- Guarded with a Day 8 `.pre-commit-config.yaml` running `ruff` + `black` + the standard file-fixers.
- Optionally Jupyter-ready with a Day 2 `jupyter_lab_config.py`.

The user fills in `project_name`, `author`, `python_version`, `ml_framework`. The template stamps out the right framework dep (Day 9 `requirements.txt` Jinja conditional).

## Acceptance criteria

- `cookiecutter <this-template> -o ~/projects --no-input project_name=titanic-baseline ml_framework=sklearn` produces a directory at `~/projects/titanic-baseline/` containing every file/directory above.
- `cd ~/projects/titanic-baseline && make setup && make all` runs end-to-end without error against a placeholder dataset.
- `pre-commit run --all-files` exits 0 on the generated project.
- `python -m build` produces a wheel.
- The downstream project is ready to plug into Domain 2 (DVC) without further scaffolding work.

## Design choices to resolve

These are the open questions we'll answer while building. Captured here so the choices are visible rather than buried in the resulting files.

| Question | Default leaning |
|---|---|
| `requirements.in` vs `pyproject.toml` `dependencies` as source of truth? | `pyproject.toml` (single source). Generate `requirements.in` is unnecessary; `uv pip compile pyproject.toml` produces a lockfile directly. |
| `Makefile` `setup` create the venv or assume the user did? | Create it (`python -m venv .venv && .venv/bin/pip install -e .`). |
| Default `python_version`? | `3.11` (matches Day 9). |
| Ruff version pin in `.pre-commit-config.yaml` and in `pyproject.toml` — keep them in sync how? | Pre-commit runs `pre-commit autoupdate` periodically; `pyproject.toml` ruff version drifts. Either pin via `[tool.uv]` constraints, or only declare ruff in pre-commit (developer never installs it directly). Tentative: latter. |
| `Black` alongside ruff format, or just ruff format? | Just ruff format (ecosystem direction; one less tool). |
| Reference a `notes/python-packaging.md`-style "what's where" inside the generated project's README? | Yes — short link list pointing at this repo's notes/. |
| `jupyter_lab_config.py` always present, or opt-in via cookiecutter variable? | Opt-in (`include_jupyter: ["yes", "no"]`). Most projects don't want it. |

## Build steps

1. Decide on the open questions above (collaboratively).
2. Create the template skeleton at `projects/mlops-learner-template/template/` (so the project README and the template live side by side).
3. Render once with a known set of inputs.
4. Run the generated project's `make all` to confirm end-to-end.
5. Run `pre-commit run --all-files` on the generated project.
6. Run `python -m build` on the generated project.
7. Mark this project Done in `projects/README.md`; fold any lessons back into the relevant `notes/`.

## What this project teaches

Less new material, more *integration*. The point is to feel where Day 1-9 patterns clash and to write down the team-level decisions (which file is the source of truth, what `make setup` actually does, etc.) that no individual day forced you to confront.

## Days drawn on

Days 1-9, all of Domain 1.
