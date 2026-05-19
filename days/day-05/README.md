# Day 5 — Create a Makefile for ML Workflow Automation

## Task

The team's draft Makefile at `/root/code/fraud-detection/Makefile` doesn't complete `make all`. Bring it in line with the standard.

**Acceptance criteria:**
- Six targets declared, each in `.PHONY`: `setup`, `data`, `train`, `test`, `clean`, `all`.
- `setup` — create venv at `mlops-venv/`, install from `requirements.txt`.
- `data` — `python src/data/process_data.py`.
- `train` — `python src/models/train.py`.
- `test` — `pytest tests/`.
- `clean` — remove every `__pycache__/`, remove `.pytest_cache/`, clear `models/`.
- `all` — runs `setup data train test` in that order.
- Recipes indented with **real tabs**, not spaces.
- `make all` exits 0.

## Why this matters

`make` is the lowest-common-denominator task runner — every dev box, CI image, and container has it already. One `Makefile` becomes the contract for "how do I build this project," and a new joiner can `make setup && make all` without reading docs.

For the cross-cutting writeup — what `.PHONY` actually does, recipe execution semantics, the offensive-security angle — see [`notes/makefile.md`](../../notes/makefile.md). The sections below focus on this lab.

## Use case

The fraud-detection project has four moving parts: pulling data, training, testing, and cleaning artifacts. Each one is one command today, but in a month `data` will be three steps, `train` will take CLI args, and a new joiner will write a shell script that mostly-but-not-quite reproduces what CI does. `make` keeps the single source of truth: CI runs `make all`, the dev runs `make all`, the README points at `make`. When the data step grows, the recipe grows — nothing else has to learn about it.

This same pattern recurs throughout the course. The DVC `dvc.yaml` (day 14+) is a more sophisticated version of the same idea. So is an Argo `Workflow` (day 86). `make` is the gateway drug.

## How to diagnose the broken Makefile

Run `make all` in `/root/code/fraud-detection/` and read the error. Common failure modes the lab plants:

| Symptom | Cause | Fix |
|---|---|---|
| `Makefile:N: *** missing separator. Stop.` | Recipe indented with spaces, not a tab. | Replace leading whitespace on recipe lines with a tab character. `cat -A Makefile` shows tabs as `^I`, spaces as ` `. |
| Target rebuilds nothing / "is up to date" | Target name matches a real file or directory (e.g. `test/` exists, so `make test` thinks it's already built). | Add the target to `.PHONY`. |
| `python: command not found` after `setup` | `setup` created the venv but later targets call bare `python`, not `mlops-venv/bin/python`. | The task spec literally says `python src/...` so leave it — assume `python` is on PATH on the lab box. |
| `pytest: command not found` | `pytest` not in `requirements.txt`. | Add `pytest` to `requirements.txt`, or run after `setup` activates the venv. |
| `all` runs targets in the wrong order | `all: test train setup data` etc. | `all: setup data train test`. `make` runs prerequisites left to right (when not parallelised). |
| `clean` only clears top-level `__pycache__` | `rm -rf __pycache__` instead of recursive | `find . -type d -name __pycache__ -exec rm -rf {} +`. |
| `clean` removes the `models/` directory itself | `rm -rf models/` instead of `rm -rf models/*` | "Clears the contents of `models/`" — keep the directory, drop the contents. |

A reference [`Makefile`](Makefile) is in this directory.

## How to run

On the lab box:

```bash
cd /root/code/fraud-detection
# fix the Makefile (see diagnosis table)
make clean    # safe to run; verifies the target works
make all      # should exit 0
```

Quick verifications:

```bash
make -n all   # dry-run: print what would happen, don't run it
grep -P '^\t' Makefile | head    # every recipe line should be tab-prefixed
```

## Notes & gotchas

Lab-specific:

- **`.PHONY` is not cosmetic.** This lab's `tests/` directory makes `make test` silently no-op without `.PHONY: test`. The lab will fail in that exact way.
- **`clean` removes the *contents* of `models/`, not the directory itself.** `rm -rf models/*`, not `rm -rf models/`.
- **`all: setup data train test`** in that order. `make` runs prerequisites left to right.
- **Recipe indentation is real tabs.** Most editors convert tabs to spaces. `cat -A Makefile` shows tabs as `^I`. VS Code: `"[makefile]": { "editor.insertSpaces": false }`.

The cross-cutting writeup — what `.PHONY` does, why each recipe line runs in a separate shell, `:=` vs `=`, the offensive-security angle — lives in [`notes/makefile.md`](../../notes/makefile.md).

## Resources

- [GNU Make manual](https://www.gnu.org/software/make/manual/make.html) — comprehensive; the [Phony Targets](https://www.gnu.org/software/make/manual/make.html#Phony-Targets) and [Recipe Syntax](https://www.gnu.org/software/make/manual/make.html#Recipes) sections are the relevant 10 minutes.
- [Makefile tutorial by example](https://makefiletutorial.com/) — readable, runnable, covers 90% of what you'll write.
- [Software Carpentry — Make lesson](https://swcarpentry.github.io/make-novice/) — gentle intro tied to a real data-processing example.
- [Your Makefiles are wrong (Tundra)](https://tech.davis-hansson.com/p/make/) — opinionated takedown of common mistakes; pairs well with the gotchas above.
- [POSIX `make`](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/make.html) — the portable subset, useful if you ever care about non-GNU make.
