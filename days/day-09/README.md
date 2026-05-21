# Day 9 — Create a Custom ML Project Template with Cookiecutter

> **Step-by-step run-through:** see [walkthrough.md](walkthrough.md). For the cross-cutting writeup on Jinja2 (delimiters, expressions, whitespace control, the grader trap), see [`notes/jinja2.md`](../../notes/jinja2.md). This README is the TL;DR.

## Task

Fix the broken Cookiecutter template at `/root/code/mlops-template/` and use it to generate a project at `/root/code/churn-model/`.

**Acceptance criteria:**

- `cookiecutter.json` declares four variables:
  - `project_name` (default `my-ml-project`)
  - `author` (default `xFusionCorp`)
  - `python_version` (default `3.11`)
  - `ml_framework` with choices `sklearn`, `pytorch`, `tensorflow`
- The template directory is named `{{cookiecutter.project_name}}/` (literal, not the rendered name).
- That directory contains files `README.md`, `requirements.txt` and directories `data/`, `models/`, `src/`, `tests/`.
- The generated `requirements.txt` contains:
  - `scikit-learn` when `ml_framework == "sklearn"`
  - `torch` when `ml_framework == "pytorch"`
  - `tensorflow` when `ml_framework == "tensorflow"`
- The generated `README.md` references both `project_name` and `author`.
- Generating with `cookiecutter /root/code/mlops-template/ -o /root/code/ --no-input project_name=churn-model ml_framework=sklearn` produces:
  - `/root/code/churn-model/requirements.txt` containing `scikit-learn`
  - `/root/code/churn-model/README.md` mentioning `xFusionCorp` (default author).

## Why this matters

Project templating is the next layer up from a standard layout (Day 4) and packaging (Day 7). Instead of every new ML project rebuilding the same skeleton by hand, the team codifies the skeleton once and stamps out new repos with `cookiecutter <template> -o ...`. The template can express *conditional* shape — different framework deps, different config files for different model types — so the same template covers a family of projects.

This is the pattern behind [Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/), every cloud-provider's "ML project starter," and most internal platform teams' onboarding tooling. The same idea later powers ArgoCD ApplicationSets, Helm charts, Terraform modules — write the skeleton once, parameterise the variant.

## How to run

The final shape:

```
mlops-template/
├── cookiecutter.json
└── {{cookiecutter.project_name}}/
    ├── README.md
    ├── requirements.txt
    ├── data/
    ├── models/
    ├── src/
    └── tests/
```

`cookiecutter.json`:

```json
{
    "project_name": "my-ml-project",
    "author": "xFusionCorp",
    "python_version": "3.11",
    "ml_framework": ["sklearn", "pytorch", "tensorflow"]
}
```

`{{cookiecutter.project_name}}/requirements.txt` (Jinja2 conditional):

```jinja
{% if cookiecutter.ml_framework == 'sklearn' %}
scikit-learn
{% elif cookiecutter.ml_framework == 'pytorch' %}
torch
{% elif cookiecutter.ml_framework == 'tensorflow' %}
tensorflow
{% endif %}
```

`{{cookiecutter.project_name}}/README.md` — must reference both `project_name` and `author`:

```jinja
# {{ cookiecutter.project_name }}

ML project by **{{ cookiecutter.author }}**.
```

Reference copies of all four files (plus the four empty subdirs with `.gitkeep`) are in this directory.

Generate:

```bash
cookiecutter /root/code/mlops-template/ -o /root/code/ \
    --no-input project_name=churn-model ml_framework=sklearn
```

Verify:

```bash
cat /root/code/churn-model/requirements.txt   # contains: scikit-learn
grep xFusionCorp /root/code/churn-model/README.md
ls /root/code/churn-model/                    # data models src tests README.md requirements.txt
```

## Diagnosis — the four issues planted in this lab

| File | Issue | Fix |
|---|---|---|
| `cookiecutter.json` | `ml_framework` variable missing entirely | add `"ml_framework": ["sklearn", "pytorch", "tensorflow"]` (list → choice prompt) |
| `{{cookiecutter.project_name}}/requirements.txt` | Jinja uses `=` (assignment) instead of `==` (comparison) on all three branches | rewrite to `{% if cookiecutter.ml_framework == 'sklearn' %}` etc. |
| `{{cookiecutter.project_name}}/requirements.txt` | missing closing `{% endif %}` | add `{% endif %}` at the bottom of the conditional |
| `{{cookiecutter.project_name}}/README.md` | `{{ cookiecutter.Author }}` capitalised | Jinja is case-sensitive — match the JSON key, `{{ cookiecutter.author }}` |

Other classes of break the lab could equally plant (catalogue for future-you):

- Template dir named `{{cookiecutter.name}}` or `{{cookiecutter.project}}` — wrong variable. The literal directory name must match a `cookiecutter.json` key.
- `ml_framework` declared as a JSON *string* instead of a list — works for Jinja `if` chains, but loses the choice-prompt semantics the acceptance implies.
- `cookiecutter.json` key names that don't match what the template uses (e.g. JSON has `framework`, Jinja references `cookiecutter.ml_framework`) — produces `UndefinedError`.
- Missing `data/`/`models/`/`src/`/`tests/` in template — generated project is missing the standard layout. Empty dirs need a `.gitkeep` to survive git.

## Key gotchas

- **`ml_framework` must be a JSON list, not a string.** Lists become choice prompts (first element is default). A bare string is treated as free text and the Jinja `if/elif` chain still works — but the lab's acceptance "choices `sklearn`, `pytorch`, `tensorflow`" implies the choice-prompt form.
- **Template directory name uses the same variable syntax as file contents** (`{{cookiecutter.project_name}}`). Cookiecutter renames the directory at generation time. The literal name on disk is `{{cookiecutter.project_name}}/` (two open-braces, two close-braces, no escaping).
- **Empty directories don't survive `git`.** Add a `.gitkeep` (empty file) to each so git tracks them. Cookiecutter generates them either way *if* they exist in the template — `git clone`d templates may have lost them.
- **`-o` is the output *parent* directory.** `-o /root/code/` produces `/root/code/churn-model/`, not `/root/code/`.
- **`--no-input` plus `key=value` pairs** lets you script generation without the interactive prompts. Without `--no-input`, cookiecutter prompts for every variable in `cookiecutter.json`.
- **Jinja whitespace control (use carefully).** `{% if ... -%}` / `{%- endif %}` strip surrounding whitespace and produce a one-line `requirements.txt`. *But* some graders / linters do literal `{% endif %}` string matching and reject the dashed form. If the grader complains about "mismatched Jinja tags" despite the file being structurally valid, drop the dashes. Cosmetic blank lines around the rendered content are usually fine.

## Resources

- [Cookiecutter docs](https://cookiecutter.readthedocs.io/) — short, readable; the [first-time](https://cookiecutter.readthedocs.io/en/stable/first_steps.html) and [advanced usage](https://cookiecutter.readthedocs.io/en/stable/advanced/) pages are the relevant 20 minutes.
- [Cookiecutter Data Science](https://cookiecutter-data-science.drivendata.org/) — the most-used ML template; the layout in Day 4 is a subset.
- [Jinja2 — Template Designer](https://jinja.palletsprojects.com/en/stable/templates/) — the language inside `{{ ... }}` and `{% ... %}`; whitespace control with `-` is what matters most for cookiecutter.
- [Hypermodern Cookiecutter](https://cjolowicz.github.io/posts/hypermodern-python-06-ci-and-documentation/) — a worked example of a more elaborate Python template.
