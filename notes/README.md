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
