# notes/

Cross-cutting learnings that aren't tied to a single day. When a concept surfaces in a lab and is going to keep showing up, it goes here instead of (or in addition to) the day's `walkthrough.md`.

## Convention

- **Day-specific** ("what happened in this lab, what the tool printed") → `days/day-XX/walkthrough.md`
- **Cross-cutting** ("how does Python packaging work in general") → `notes/<topic>.md`

Days link out to notes. Notes don't need to know which days reference them.

Add to a note whenever you re-learn or refine something — these are living documents, not one-shot writeups.

## Index

| Topic | What's in it |
|---|---|
| [python-packaging.md](python-packaging.md) | What's a PEP, `setup.py` vs `setuptools` vs `pyproject.toml`, the `setuptools>=40.8.0` fallback, PEP 503 name normalisation, frontends vs backends, pinning vs ranges vs lockfiles, `src/` vs flat layout |
| [docker-for-python.md](docker-for-python.md) | Wheels vs Docker images (what each packages, when to reach for which), the native-dep trap, multi-stage venv copy, distroless, PEX/shiv/Nuitka/PyInstaller, the MLOps wheel→image→deploy cycle |
| [ml-project-layout.md](ml-project-layout.md) | The standard `data/{raw,processed}`, `src/{data,features,models,utils}`, `tests/`, `configs/` skeleton; what each directory is for; `__init__.py` vs PEP 420 namespace packages; `src/` vs flat layout |
| [makefile.md](makefile.md) | Why `make` for ML, what `.PHONY` actually does, recipe-per-shell model, `source`/`cd` traps, `:=` vs `=`, offensive-security angle (silent test suppression, recipe injection, untrusted source trees) |
| [code-quality.md](code-quality.md) | Formatter vs linter, ruff 0.1+ schema migration (`[tool.ruff.lint]`), common rule codes, `per-file-ignores`, `# noqa` specificity, black `target-version` warning, ruff/black overlap |
| [pre-commit.md](pre-commit.md) | `install` vs `run`, `autoupdate` flow, three-phase error ordering (config / hook resolution / execution), exit-1-on-success "files were modified" semantics, mirror-repo pattern, hook-ids-are-hyphens, "tool silence ≠ grader pass" lesson |
| [jinja2.md](jinja2.md) | Delimiter shapes (`{{ }}` vs `{% %}`), Python-flavour expressions, explicit closing tags, whitespace control (`-`), filters, undefined-variable behaviour, reading context dumps, the literal-string-matching grader trap |
