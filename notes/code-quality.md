# Code quality — formatters, linters, and the ruff/black overlap

Cross-cutting notes on Python code-quality tooling. The big picture: a *formatter* mechanically rewrites style; a *linter* finds bugs and smells. Both belong in CI because they catch different classes of problem. The ecosystem is currently consolidating around `ruff` — but most teams still run `ruff` (lint) + `black` (format) together, so understanding both is the default.

## Contents

- [Formatter vs linter — different jobs](#formatter-vs-linter--different-jobs)
- [Why both in CI](#why-both-in-ci)
- [Ruff config — the 0.1+ schema migration](#ruff-config--the-01-schema-migration)
- [Common ruff codes worth recognising](#common-ruff-codes-worth-recognising)
- [`per-file-ignores` over scattered `# noqa`](#per-file-ignores-over-scattered--noqa)
- [`# noqa` specificity](#-noqa-specificity)
- [Black `target-version` warning](#black-target-version-warning)
- [Pin tool versions](#pin-tool-versions)
- [`ruff format` vs `black` — where the ecosystem is heading](#ruff-format-vs-black--where-the-ecosystem-is-heading)
- [See also](#see-also)

## Formatter vs linter — different jobs

- **Formatter (`black`, `ruff format`)** rewrites code to a canonical style — line breaks, quote style, spacing, trailing commas. Effectively zero knobs by design. `black --check` exits non-zero if any file *would* change; CI uses that to gate merges. The pitch is "stop arguing about style; commit the diff."
- **Linter (`ruff`, `flake8`, `pylint`)** finds actual bugs and smells: unused imports, undefined names, comparison to `None` with `==`, import ordering. Ruff is the modern default — Rust-fast, drop-in for flake8 + isort + many pylint rules, in one pass.

The two surfaces don't overlap:

- A formatter cannot tell you `import os` is unused. That's a lint check (`F401`).
- A linter does not standardise where line breaks fall in a long signature. That's a formatter's job.

## Why both in CI

Running both on every PR gives a stable, mechanical floor:

- Reviewers stop nitpicking whitespace and start reviewing logic.
- New contributors get one canonical style without reading a 40-page style guide.
- Drift between developers' editors becomes invisible — the formatter normalises it on save or in CI.

For ML code specifically: notebooks-turned-scripts are *full* of unused imports (leftovers from "let me just try this"), `import *`, and inconsistent indentation. Ruff + black clean those up automatically before anyone reads the diff.

## Ruff config — the 0.1+ schema migration

Pre-ruff-0.1 config:

```toml
[tool.ruff]
line-length = 120
select = ["E", "F", "W", "I"]   # ← top-level
```

Ruff 0.1+ moved lint-only settings under a sub-table:

```toml
[tool.ruff]
line-length = 120                # global

[tool.ruff.lint]
select = ["E", "F", "W", "I"]   # ← under .lint
```

Ruff still *reads* the old form but warns:

```
The top-level linter settings are deprecated in favour of their counterparts in the `lint` section.
```

Use the new form. Other lint settings that moved: `ignore`, `extend-select`, `per-file-ignores`, `unfixable`, `fixable`. Global settings (`line-length`, `target-version`, `exclude`) stay at the top level.

## Common ruff codes worth recognising

| Code | Meaning | Common cause |
|---|---|---|
| `F401` | imported but unused | `import os` left over from an earlier draft |
| `F811` | redefinition of unused name | function or import defined twice |
| `F821` | undefined name | typo'd variable, or use-before-define |
| `F841` | local variable assigned but never used | `result = ...` that's never read |
| `E501` | line too long | only fires if line > `line-length` |
| `E711` | comparison to None | `x == None` instead of `x is None` |
| `E712` | comparison to True/False | `if x == True:` instead of `if x:` |
| `I001` | import block unsorted/unformatted | stdlib mixed with third-party, no blank lines |
| `W291` / `W293` | trailing whitespace | self-explanatory |

The full table is at <https://docs.astral.sh/ruff/rules/>. Don't memorise — read the offending file's output, the code is right there.

**Don't enable `select = ["ALL"]`.** It includes mutually contradictory rules and stylistic choices most teams reject. Start with `E F W I` and add specific codes as the team agrees on them.

## `per-file-ignores` over scattered `# noqa`

Some rules are wrong *for some files* but right elsewhere. Configure that centrally, not by sprinkling `# noqa` everywhere:

```toml
[tool.ruff.lint.per-file-ignores]
"tests/*" = ["S101", "ARG"]      # asserts and unused fixture args are fine in tests
"notebooks/*" = ["E402"]         # imports-not-at-top is fine in notebook-as-script
"src/__init__.py" = ["F401"]    # re-exports are intentionally "unused" here
```

Why centralise:

- Reviewers see policy in one place.
- Adding a new test file doesn't require remembering to add `# noqa` lines.
- The exemption is *scoped* — `S101` is still enforced outside `tests/`.

## `# noqa` specificity

If a real lint hit *does* need silencing in code, write the specific code:

```python
import os  # noqa: F401  -- imported for side effect
```

Not bare `# noqa` (silences everything on the line and never expires) and not `# type: ignore` (that's mypy, different tool).

Specific codes mean: the next reviewer can see exactly what was suppressed and why, and when ruff adds a new rule that catches a real bug on the same line, it still fires.

## Black `target-version` warning

If you see:

```
Warning: Python 3.X cannot parse code formatted for Python 3.Y
```

…the run still succeeded — black just couldn't run its post-format AST safety check because the interpreter executing black is older than the (inferred) target version.

Fix by pinning the target explicitly:

```toml
[tool.black]
line-length = 120
target-version = ["py312"]   # whatever you actually run on
```

This both silences the warning and lets black run its safety check.

## Pin tool versions

Black is deliberately opinionated and occasionally changes formatting between versions. Pin it (in `requirements-dev.txt` or `pyproject.toml` dev deps) so CI and devs format identically:

```
black==24.10.0
ruff==0.7.4
```

Without pins, two developers on different versions will fight over the same file. Ruff is more disciplined about backwards compatibility but still worth pinning.

## `ruff format` vs `black` — where the ecosystem is heading

Ruff now ships a formatter (`ruff format`) that is roughly 99% black-compatible. Many teams have migrated to ruff-only — one tool, one config, one binary. Black is still the safer "default formatter" choice today because it's been stable for years and every IDE has a pre-baked plugin, but the trajectory is consolidation toward ruff.

If you're starting a new project: try ruff-only. If you're adding tooling to an existing project that already runs black: keep both, it works.

## See also

- [ruff docs](https://docs.astral.sh/ruff/) — the [rules reference](https://docs.astral.sh/ruff/rules/) is the most useful page.
- [ruff configuration](https://docs.astral.sh/ruff/configuration/) — full `pyproject.toml` schema; covers `[tool.ruff]` vs `[tool.ruff.lint]`.
- [Black — The Uncompromising Code Formatter](https://black.readthedocs.io/) — short, opinionated.
- [Astral's "ruff format" announcement](https://astral.sh/blog/the-ruff-formatter) — context on the ruff/black overlap.
- [PEP 8](https://peps.python.org/pep-0008/) — the style guide the `E`/`W` codes ultimately encode.
- `days/day-06/` — the lab that produced this content; the day's README has the specific broken pyproject.toml diagnosis.
