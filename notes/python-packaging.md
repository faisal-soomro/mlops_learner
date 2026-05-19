# Python packaging — mental model

Cross-cutting notes on how Python packaging works. Referenced from any day that touches `pyproject.toml`, `pip install`, wheels, sdists, etc. Built up over time — add to it whenever a packaging concept surfaces in a lab.

## Contents

- [What's a PEP?](#whats-a-pep)
- [`setup.py` vs `setuptools` vs `pyproject.toml`](#setuppy-vs-setuptools-vs-pyprojecttoml)
- [The `setuptools>=40.8.0` fallback (PEP 517)](#the-setuptools4080-fallback-pep-517)
- [PEP 503 — distribution name normalisation](#pep-503--distribution-name-normalisation)
- [Frontends and backends](#frontends-and-backends)
- [Pinning, ranges, and lockfiles](#pinning-ranges-and-lockfiles)
- [Project layout: `src/` vs flat](#project-layout-src-vs-flat)
- [See also](#see-also)

## What's a PEP?

**PEP** = **Python Enhancement Proposal**. A numbered document that proposes a change to Python — the language, the standard library, or the packaging ecosystem. Python's RFC system: someone writes a PEP, the community discusses it, and if accepted, it becomes the spec everyone implements.

PEPs are plain English (mostly), freely readable at [peps.python.org](https://peps.python.org/). You don't need to read them cover-to-cover — but knowing the PEP number lets you grep the doc when something surprises you.

PEPs you've probably already touched without realising:

- **PEP 8** — the style guide. Why ruff has a code group called `E` (pycodestyle errors): they're enforcing PEP 8 rules.
- **PEP 484** — type hints. Why `def f(x: int) -> str` works.
- **PEP 20** — the Zen of Python (`import this`).

Packaging-specific PEPs (the cluster that built up the modern system over ~10 years):

| PEP | What it standardised |
|---|---|
| **PEP 440** | Version string format (`1.2.3`, `2.0.0rc1`, `>=3.10`) |
| **PEP 503** | Distribution name normalisation (hyphens / underscores / case) |
| **PEP 517** | Build-system interface (frontends ↔ backends) |
| **PEP 518** | `pyproject.toml` itself as the config file |
| **PEP 621** | Standard `[project]` metadata table |
| **PEP 660** | Editable installs via `pip install -e .` |

## `setup.py` vs `setuptools` vs `pyproject.toml`

These three are easy to conflate. The mental model:

- **`setuptools`** = the **library** that produces wheels and sdists. The build backend. Same library across every era.
- **`setup.py`** = a **Python script** that configures setuptools, originally also the entry point for building. Legacy.
- **`pyproject.toml`** = a **config file** (TOML, no execution) standardised by PEP 517/518/621 as the modern way to configure any backend, including setuptools.

One library; three eras of configuring it:

| Era | What you wrote | How it was read |
|---|---|---|
| pre-2016 | `setup.py` (Python script) | **Executed.** Tools imported and inspected. |
| ~2016–2020 | `setup.cfg` (INI, declarative) + stub `setup.py` | Parsed. No execution for most metadata. |
| 2020+ | `pyproject.toml` (TOML, declarative, tool-agnostic) | Parsed. Standardised across all build backends. |

**Old `setup.py`:**

```python
from setuptools import setup

setup(
    name="fraud_detection",
    version="0.1.0",
    install_requires=["scikit-learn", "pandas", "numpy"],
)
```

This is **Python code**. To know `install_requires`, a tool has to *run* the file. It could read the network, branch on env vars, do anything. PyPI executed strangers' `setup.py` files for years.

**Today's `pyproject.toml`** decomposes into three layers, each with a different audience:

```
┌────────────────────────────────────────────────┐
│ [build-system]    ← frontends (pip, build, uv) │
│   requires        ← "install this to build me" │
│   build-backend   ← "ask this thing to build"  │
├────────────────────────────────────────────────┤
│ [project]         ← anyone reading metadata    │
│   name            ← standard, PEP 621          │
│   version         ← every backend reads it     │
│   dependencies    ← the same way               │
├────────────────────────────────────────────────┤
│ [tool.setuptools] ← setuptools-specific knobs  │
│ [tool.ruff]       ← ruff-specific knobs        │
│ [tool.black]      ← black-specific knobs       │
└────────────────────────────────────────────────┘
```

- **`[build-system]`** — contract between *frontends* (pip, build, uv) and *backends* (setuptools, hatch, flit, poetry-core). Frontend-agnostic.
- **`[project]`** — **PEP 621**: standardised metadata every backend reads identically. Switch from setuptools to hatch tomorrow: `[build-system]` changes, `[project]` doesn't.
- **`[tool.<name>]`** — wild west: each tool carves out its own namespace. Why one file can configure your build, linter, formatter, and test runner without collisions.

**Why this matters in practice:**

- `pip install some-package` has to know its dependencies *before* downloading it (for the resolver). `setup.py` meant executing arbitrary Python on every candidate. `pyproject.toml` is just data — fast and safe.
- **Reproducibility.** A `setup.py` could read the system time and pick a version. A `pyproject.toml` can't. Build twice → same metadata.
- **Static analysis.** `validate-pyproject`, `pyproject-fmt`, IDEs can lint TOML. No equivalent for arbitrary Python.
- **Tool portability.** A team can migrate from setuptools to hatch without rewriting `[project]`.

So "use `pyproject.toml` instead of `setup.py`" doesn't mean "use a new build tool." It means "stop configuring setuptools with a Python script; configure it with declarative TOML." Setuptools is still doing the work.

## The `setuptools>=40.8.0` fallback (PEP 517)

If you run `python -m build` on a `pyproject.toml` with **no `[build-system]` section**, the output says:

```
* Installing packages in isolated environment:
  - setuptools >= 40.8.0
```

That magic number isn't invented by `build`. It's defined by the PEPs:

- **PEP 518:** *"If the `pyproject.toml` file is absent, or the `build-system` table is missing, the source tree is not using this specification, and tools should revert to legacy behaviour."*
- **PEP 517:** *"If `pyproject.toml` is missing or `build-backend` is missing, the source tree is treated as if `build-backend = 'setuptools.build_meta:__legacy__'`, with `requires` of `['setuptools >= 40.8.0', 'wheel']`."*

So every PEP 517-compliant frontend (`python -m build`, `pip`, `uv build`, `pdm build`) falls back the same way. `40.8.0` is the oldest setuptools that knows how to act as a PEP 517 backend.

**The silent-failure trap:** the legacy backend reads metadata from `setup.py` / `setup.cfg`, **not** from `[project]`. If you have a modern `[project]` table but no `[build-system]`, the legacy fallback **silently ignores** `[project]` and looks for metadata in `setup.py` instead. Your `name`, `version`, `dependencies` are discarded. Build is green; artifact is wrong.

**Why setuptools 61 is the practical line:**

- **40.8.0** — can act as a PEP 517 backend, but still reads metadata from `setup.py` / `setup.cfg`.
- **61.0** — first version that reads `[project]` from `pyproject.toml` (PEP 621). Where the declarative workflow actually starts.

**Rule of thumb:** every `pyproject.toml` should declare `[build-system]` explicitly. Don't rely on the fallback.

## PEP 503 — distribution name normalisation

When you write `name = "fraud-detection"` in `pyproject.toml`, you'll see the same package referred to as `fraud-detection`, `fraud_detection`, or `Fraud_Detection` in different places. All of them refer to the same package.

### The rule

**PEP 503** says: when comparing two distribution names, normalise both first. Normalisation:

1. Lowercase everything.
2. Replace runs of `_`, `-`, and `.` with a single `-`.

All of these are **equivalent**:

```
fraud-detection
fraud_detection
fraud.detection
Fraud_Detection
FRAUD---detection
```

All normalise to `fraud-detection`. PyPI treats them as the same package. `pip install fraud_detection` and `pip install fraud-detection` resolve to the exact same thing.

### Canonical form in each context

| Context | Canonical form | Example |
|---|---|---|
| `name` in `pyproject.toml` | **Whatever you wrote.** No automatic normalisation. | `name = "fraud-detection"` or `name = "fraud_detection"` — both valid |
| Wheel filename | Underscore form | `fraud_detection-0.1.0-py3-none-any.whl` |
| sdist filename | Underscore form | `fraud_detection-0.1.0.tar.gz` |
| METADATA file's `Name:` field | **Whatever you wrote** in `pyproject.toml` | `Name: fraud_detection` |
| Importable module name | **Whatever directory you have under `src/`** | `import fraud_detection` |
| `pip install <name>` | Either — PEP 503 normalises both sides | `pip install fraud-detection` works |
| `pip show <name>` / `pip uninstall <name>` | Same — normalised | Either form works |
| pip's "Installing collected packages" line | Hyphen form | `fraud-detection-0.1.0` |
| PyPI URL | Hyphen form | `pypi.org/project/fraud-detection/` |

Why wheel filenames use underscores: the wheel spec (PEP 427) makes the filename look like `<name>-<version>-<python>-<abi>-<platform>.whl`. Hyphens are used as field separators, so hyphens inside the *name* get converted to underscores to avoid ambiguity.

### Distribution name vs import name

This is the part that bites people: the *importable* name has **nothing to do with PEP 503**.

```
distribution name  (pyproject.toml `name`):  fraud_detection
                                             └─ pip sees this
package name        (directory in src/):     fraud_detection
                                             └─ Python's `import` sees this
```

Distribution name (what you `pip install`) and package name (what you `import`) **don't have to match**. They almost always do, by convention, but Python doesn't enforce it. Famous examples:

| `pip install` | `import` |
|---|---|
| `scikit-learn` | `sklearn` |
| `Pillow` | `PIL` |
| `PyYAML` | `yaml` |
| `beautifulsoup4` | `bs4` |
| `opencv-python` | `cv2` |

And the reverse trap — Python's `import` system **cannot** parse a hyphen:

```python
import fraud-detection   # SyntaxError: hyphen is the minus operator
```

So if your distribution name has a hyphen, you have two options:

- Name the package directory with an underscore (`src/fraud_detection/`) → `import fraud_detection` works, distribution stays `fraud-detection`. Common in the wild.
- Name everything with underscores. Cleaner.

### Where this trips people up

- **Searching PyPI / pip:** `pip install fraud_detection` and `pip install fraud-detection` are equivalent. Don't waste time wondering which one is "right" — they're the same package to pip.
- **Dependency declarations:** `dependencies = ["scikit-learn"]` and `dependencies = ["scikit_learn"]` both resolve to the same package on PyPI. Convention is to use hyphens (matches the project's website).
- **Imports never match installs blindly.** `pip install scikit-learn` → `import sklearn`. Read the project's README to find the import name; never assume.
- **Wheel filename ≠ distribution name in source.** When checking "did I produce the right wheel?", the *filename* alone is misleading (hyphen→underscore conversion masks errors). Check the `Name:` line in METADATA.

### Historical note

Pre-PEP 503 (pre-2015), pip treated `Foo` and `foo` as different packages on PyPI, and dependency resolution broke in subtle ways. PEP 503 was a cleanup — codifying case-insensitive and separator-insensitive names. Old behaviour still surfaces occasionally in error messages from very old tooling.

## Frontends and backends

The PEP 517 split:

- **Frontend** = the tool the *user* runs. `pip install`, `python -m build`, `uv build`, `pdm build`. Reads `pyproject.toml`, sets up the build environment, calls the backend.
- **Backend** = the library that *produces* the wheel. `setuptools`, `hatch`, `flit-core`, `poetry-core`, `pdm-backend`. Configured by `build-backend = "<name>.build_meta"` (or equivalent) in `[build-system]`.

Why the split exists: any frontend can build any backend's project. `pip install poetry-project` works without pip knowing anything about poetry — pip reads `[build-system]`, installs `poetry-core`, and asks it to build.

Day-to-day implication: switching backends (e.g. setuptools → hatch) is a `[build-system]` change, not a tooling migration. The frontends you already use keep working.

## Pinning, ranges, and lockfiles

When you declare `dependencies` in `pyproject.toml`, you're answering one of two different questions depending on what you're shipping. Get this wrong and you either poison the dependency graph for downstream users (library mistake) or ship a service that drifts every time it's rebuilt (application mistake).

### The two jobs of `dependencies`

**1. The wheel is a library** — other code `pip install`s it as a dependency.

Unpinned (range-bound) dependencies are **correct** here. If your library pins `scikit-learn==1.8.0` and another library in the same environment needs `scikit-learn==1.7.5`, the resolver picks one and the other breaks. This is the **diamond dependency problem**: two transitive paths to the same package require incompatible versions. The more libraries pin tightly, the more often the resolver fails outright.

Convention for libraries:

```toml
dependencies = [
    "scikit-learn>=1.4,<2",   # range, not a pin
    "pandas>=2.0,<3",
    "numpy>=1.26,<3",
]
```

Declare the *minimum* you actually need (anything older breaks because you use an API that doesn't exist there) and the *maximum* you've tested against (typically the next major version, because semver says majors can break). That gives the resolver room.

Never pin exactly (`==1.8.0`) in a library. It poisons the graph for everyone downstream.

**2. The wheel is an application** — `pip install`ed standalone, into its own environment (a Docker image, a serverless package, a VM venv) where nothing else lives.

Unpinned dependencies are **dangerous** here. No other code competes for the resolver, so pinning costs you nothing — and unpinned means your environment drifts on every rebuild. Today: `scikit-learn==1.8.0`. Tomorrow: `1.8.1` (subtle API change in `predict_proba`). Same wheel, different runtime behaviour. The "worked Tuesday, broke Thursday, no code changes" failure mode.

For applications, the answer is **not** to pin in `dependencies` (the field doesn't know whether you're a library or an app — same schema either way). The answer is **lockfiles**: a separate file that pins every transitive dep to an exact version, and is what your deployment actually installs from.

This is the Day 3 pattern with `uv pip compile`:

```
requirements.in   ← loose: "scikit-learn"      (the abstract dep, like [project].dependencies)
requirements.txt  ← pinned: "scikit-learn==1.8.0" + 40 transitive deps
```

The wheel declares "I need scikit-learn (any version in this range)." The lockfile records "this exact set of versions is what we ran in CI and what production runs."

### Mental model

```
        Library                          Application
        ───────                          ───────────
[project].dependencies:           [project].dependencies:
  loose ranges                      loose ranges
  ("scikit-learn>=1.4,<2")          (same — same field)

         +                                 +

   Nothing else needed              Lockfile pinning everything:
   The library only declares          uv.lock
   what it can work with.             requirements.txt
                                      poetry.lock
                                    Deployment installs from this.
```

Same `[project].dependencies`; different deployment story. The wheel is portable; the lockfile is what makes the environment reproducible.

### When unpinned ranges still bite

Even with proper ranges in a library:

- **Upper bound too tight.** You wrote `scikit-learn>=1.4,<2` in 2024. scikit-learn 2.0 ships in 2027. Your library is *fine* with 2.0, but the bound says no — every downstream user gets resolution failures until you release a new version with `<3`. Common pattern. Be conservative with upper bounds; only add them if you know the next major breaks you.
- **Upper bound too loose.** You wrote `scikit-learn>=1.4` with no upper. scikit-learn 2.0 ships, breaks `predict_proba`'s return type, your library breaks for every user who upgrades. Cap at the next major (`<2`) if you haven't tested the next version.
- **Lower bound too loose.** You wrote `pandas` with no lower bound. A user installs an environment with `pandas==1.0` (2020). Your code uses `df.style.format` keyword args that didn't exist until pandas 1.4. Cryptic runtime failure, not install-time. Pin lower bounds at the version where you actually started using the feature.
- **Pre-release versions.** Without a `<2` upper bound, `pip install` might pull `2.0.0rc1`. PEP 440 skips pre-releases by default *unless* the only matching version is a pre-release. Edge case, but ugly when it hits.

### The MLOps angle

Particularly sharp for ML projects:

- **Reproducibility is a research requirement.** "Train with the same code and data → get the same weights" only works if the environment is identical. scikit-learn's RNG behaviour, NumPy's BLAS choices, pandas dtype promotion have all changed subtly between minor versions. Without a lockfile, no reproducibility.
- **Models are pinned to versions implicitly.** A model trained with `scikit-learn==1.4` deserialises (pickle) cleanly into `scikit-learn==1.4`. Into `1.5` it might work; into `2.0` it definitely won't. The wheel that *trained* the model and the wheel that *serves* it have to install compatible deps — unpinned ranges don't enforce that.

The standard ML setup:

```
[project].dependencies in pyproject.toml:     ranges  ("scikit-learn>=1.4,<2")
requirements.txt / uv.lock in the repo:        pins   ("scikit-learn==1.8.0")
Docker image: installs from requirements.txt           ↑ this is what production runs
Model registry: records `fraud_detection==0.1.0` + the lockfile hash
```

Three layers of versioning, all consistent. Wheel = portable; lockfile = reproducible; image = deployable.

### Rule of thumb

| You're shipping | In `[project].dependencies` |
|---|---|
| A library others depend on (`pip install fraud_detection`) | Ranges only: `>=X,<Y`. No `==`. Pair with a separate lockfile for your own CI. |
| An application that runs standalone (inference service, CLI tool) | Ranges in `[project]` *and* a separate lockfile. Deploy from the lockfile. |
| A model-as-package (data team's code that produces/consumes a specific model artifact) | Tight ranges matching the model's training env: `scikit-learn>=1.8,<1.9`. Combined with a lockfile. The model is the constraint. |

### Day 7 specifically

The lab wheel was unpinned because the spec said `dependencies = ["scikit-learn", "pandas", "numpy"]` literally. In a real fraud-detection project: `dependencies = ["scikit-learn>=1.8,<2", "pandas>=2.0,<3", "numpy>=1.26,<3"]` *and* a `requirements.txt` lockfile alongside, regenerated whenever the ranges change.

The lab taught the *mechanism* (declaring deps in `pyproject.toml`); real-world practice is mechanism + lockfile.

## Project layout: `src/` vs flat

Two ways to organise a Python package's source tree. The difference looks cosmetic; it's not.

### What each looks like

**Flat layout** (older, simpler):

```
fraud-detection/
├── pyproject.toml
├── fraud_detection/
│   ├── __init__.py
│   ├── train.py
│   └── serve.py
└── tests/
    └── test_train.py
```

The package directory sits at the project root, alongside `pyproject.toml`.

**`src/` layout** (modern recommendation):

```
fraud-detection/
├── pyproject.toml
├── src/
│   └── fraud_detection/
│       ├── __init__.py
│       ├── train.py
│       └── serve.py
└── tests/
    └── test_train.py
```

The package directory lives one level deeper, inside `src/`. This is what Day 4 set up and what Day 7's `[tool.setuptools.packages.find] where = ["src"]` pointed at.

### Why `src/` exists — the bug it prevents

When Python starts a script, it puts the script's directory at the *front* of `sys.path`. That means anything sitting next to your code becomes importable, **even if you haven't installed the package**.

With **flat layout**, this is dangerous:

```
fraud-detection/
├── pyproject.toml
├── fraud_detection/        ← your package
└── train_quickly.py        ← a one-off script run from this directory
```

If you run `python train_quickly.py` from `fraud-detection/`, then `import fraud_detection` works *whether or not* you've actually installed the wheel. Python finds the directory next to the script and treats it as the package.

Sounds convenient. It's a trap:

- **You can't tell if your package is installable.** Tests pass locally because `fraud_detection/` happens to be on the path. CI builds and installs the wheel, then runs tests — `import fraud_detection` works for an entirely different reason. The two might disagree. First time you find out is when the wheel ships to staging and some submodule isn't actually included.
- **Stdlib shadowing.** A file `fraud_detection/random.py` next to the script means `import random` inside it might find *your* `random.py` instead of the stdlib's, because the project root is at the front of `sys.path`. Classic example: a file called `email.py` silently breaks `smtplib` because `smtplib` does `import email` and gets yours. Cryptic bugs.
- **Editable installs lie.** `pip install -e .` works either way. But with flat layout, you can't tell whether your import is resolving via the editable install or via the implicit "next-to-the-script" mechanism. They look identical until they don't.

With **`src/` layout**, none of this happens. Nothing in `src/` is importable until the package is installed (editable or otherwise) — because `src/` itself isn't a package and isn't on `sys.path`. You have to actually install the wheel (or `pip install -e .`) to import the code. The first time `import fraud_detection` works, you *know* the install is real.

### The cycle the layout enforces

The `src/` layout forces this loop:

```
edit code  →  pip install -e .  (or pip install dist/...whl)  →  python -c "import fraud_detection"
```

With flat layout, you can skip the install step and accidentally develop against an environment that doesn't match production.

### When to use flat layout

A handful of legitimate cases:

- **Single-file scripts** that aren't packaged at all. No `pyproject.toml`, no `__init__.py`, just `python script.py`. Flat is fine — there's no package to confuse.
- **Vendor / wrapper layouts** where you genuinely want `import` to find both the package and some sibling utilities without installing. Rare.
- **Legacy projects** with flat layout already and working CI. Don't migrate just for the sake of it.

For anything new, especially anything that gets packaged into a wheel and shipped: **`src/`**.

### A subtle setuptools detail

With flat layout, setuptools' auto-discovery sometimes picks up wrong things — `tests/`, `docs/`, leftover directories — and includes them in the wheel. With `src/`, the rule is simple: "everything under `src/` is a package." Less to misconfigure, less to surprise you when `pip show -f fraud_detection` shows a `tests/__init__.py` you didn't mean to ship.

### Quick summary

| Layout | Importable without install? | Recommended? |
|---|---|---|
| Flat | **Yes** — accidentally. Source of subtle bugs. | Legacy only. |
| `src/` | **No** — by design. Forces the install loop. | Default for anything new. |

If you scan well-maintained Python projects on GitHub today, `src/` is the default. Cookiecutter templates default to it. The Packaging User Guide recommends it. Modern setuptools (and hatch, flit, pdm) auto-discover it. The argument is settled in practice; the only reason to use flat is "this project predates 2020."

## See also

- [Python Packaging User Guide](https://packaging.python.org/en/latest/) — canonical, kept current.
- [pyproject.toml index of PEPs](https://packaging.python.org/en/latest/specifications/declaring-project-metadata/) — every field in `[project]`, with the PEP that defines it.
- `days/day-07/walkthrough.md` — first time we hit this on the journey, with raw build output.
