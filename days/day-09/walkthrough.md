# Day 9 — Walkthrough

The actual run, preserved. The [README](README.md) lists the four issues; this file shows them in the order they surfaced, what each fix proved, and the grader-vs-tool divergence at the end.

## Starting state

`/root/code/mlops-template/`:

```
mlops-template/
├── README.md                     (template's own README, separate from project's)
├── cookiecutter.json
└── {{cookiecutter.project_name}}/
    ├── README.md
    ├── requirements.txt
    ├── data/.gitkeep
    ├── models/.gitkeep
    ├── src/.gitkeep
    └── tests/.gitkeep
```

Directory structure was correct. Four bugs were planted inside the files:

1. `cookiecutter.json` missing `ml_framework`.
2. `requirements.txt` using `=` (assignment) instead of `==` (comparison).
3. `requirements.txt` missing `{% endif %}`.
4. `README.md` referencing `cookiecutter.Author` (capitalised).

## We chose run-first

Two approaches discussed:

- **Inspect-first** — read the files end-to-end, spot bugs by eye.
- **Run-first** — let cookiecutter point at errors one at a time.

We went run-first to see how cookiecutter surfaces errors in practice. The render produced four error iterations, and one important "tool silence" finding (which I had wrongly predicted differently before the run).

## Iteration 1 — `cookiecutter.Author` UndefinedError

```bash
cookiecutter /root/code/mlops-template/ -o /root/code/ --no-input project_name=churn-model ml_framework=sklearn
```

```
Unable to create file 'README.md'
Error message: 'collections.OrderedDict object' has no attribute 'Author'
Context: { ... "cookiecutter": { ..., "author": "xFusionCorp", ... } }
```

**What this proved:**

- Cookiecutter renders files in alphabetical order: `README.md` before `requirements.txt`. The Jinja-syntax bugs in `requirements.txt` (next two iterations) were masked behind `README.md` failing first. Worth knowing for any "the error is on file X" assumption — it's just the first file alphabetically.
- **`ml_framework` is missing from the context** (`cookiecutter` dict has `author`, `project_name`, `python_version` only). This contradicted my earlier guess that CLI `--no-input ml_framework=sklearn` overrides land in the context regardless. **They do not** — cookiecutter silently drops CLI keys not declared in `cookiecutter.json`. That bug would have surfaced at runtime too, once we got past README.md.
- Jinja is case-sensitive: `cookiecutter.Author` ≠ `cookiecutter.author`.

**Fix:** `Author` → `author` in `README.md`.

## Iteration 2 — `=` (assignment) instead of `==`

```
File "requirements.txt", line 1, in template
jinja2.exceptions.TemplateSyntaxError: expected token 'end of statement block', got '='
    {% if cookiecutter.ml_framework = 'sklearn' %}
```

**What this proved:**

- Jinja, like Python, distinguishes `=` (assignment) from `==` (comparison). Inside `{% if %}`, only comparison is meaningful — single-equals is a parse error.
- The trap is universal for anyone coming from shells/SQL/older config languages where `=` is comparison.

**Fix:** all three `=` → `==` in `requirements.txt`.

## Iteration 3 — missing `{% endif %}`

```
File "requirements.txt", line 5, in template
jinja2.exceptions.TemplateSyntaxError: Unexpected end of template.
    Jinja was looking for the following tags: 'elif' or 'else' or 'endif'.
    The innermost block that needs to be closed is 'if'.
```

**What this proved:**

- Jinja control structures are *explicitly* terminated. Unlike Python's whitespace-defined scope, Jinja embeds tags inside non-code text — there's no indentation cue, so closing tags are mandatory.
- The error message names the unclosed block (`if`), which is useful when templates nest.

**Fix:** add `{% endif %}` at the bottom of the conditional.

## Iteration 4 — `ml_framework` missing from `cookiecutter.json`

```
Unable to create file 'requirements.txt'
Error message: 'collections.OrderedDict object' has no attribute 'ml_framework'
Context: { ... "cookiecutter": { ..., "author": "xFusionCorp", ... } }
```

The expected error from Iteration 1's "context dump" prediction. CLI overrides are *not* implicit declarations — variables must be in `cookiecutter.json` to make it into the context.

**Fix:** add to `cookiecutter.json`:

```json
"ml_framework": ["sklearn", "pytorch", "tensorflow"]
```

JSON list → choice prompt (first element is default; only those three values accepted with `--no-input` overrides).

## Iteration 5 — green render, then grader red

```bash
cookiecutter /root/code/mlops-template/ -o /root/code/ --no-input project_name=churn-model ml_framework=sklearn --overwrite-if-exists
# (no output)
```

Cookiecutter is silent on success. Verification:

```bash
ls /root/code/churn-model/         # README.md data models requirements.txt src tests
cat /root/code/churn-model/requirements.txt   # scikit-learn
grep xFusionCorp /root/code/churn-model/README.md   # Created by xFusionCorp.
```

But the rendered `requirements.txt` had blank lines around `scikit-learn` (Jinja leaves the trailing newline of each `{% ... %}` tag in the output). I suggested whitespace control to clean it up:

```jinja
{% if cookiecutter.ml_framework == 'sklearn' -%}
scikit-learn
{% elif ... -%}
...
{%- endif %}
```

That produced a clean one-line output. The grader then failed:

```
Mismatched Jinja tags: 1 {% if %} block(s) but 0 {% endif %} tag(s).
Every {% if %} needs a matching {% endif %}.
```

**The grader-vs-tool divergence:**

- Jinja2 *correctly parsed* `{%- endif %}` as the matching closing tag. Tool-side, the template was valid.
- The grader does *literal* `{% endif %}` string matching. `{%- endif %}` doesn't contain that substring, so the grader counts zero closing tags.

**Lesson:** same as Day 8 (the `charliermarsh/...` URL trap). Acceptance verifiers may do dumber matching than the runtime tool. Stylistic improvements that pass the tool can fail the grader. Stick to the boring form unless you've verified the grader tolerates the variation.

**Fix:** dropped `-` from `{%- endif %}` → `{% endif %}`. Kept the if/elif `-%}` dashes (those passed). Re-render, re-grade. Green.

## Final shape (post-grader)

`cookiecutter.json`:

```json
{
    "project_name": "my-ml-project",
    "author": "xFusionCorp",
    "python_version": "3.11",
    "ml_framework": ["sklearn", "pytorch", "tensorflow"]
}
```

`{{cookiecutter.project_name}}/requirements.txt`:

```jinja
{% if cookiecutter.ml_framework == 'sklearn' %}
scikit-learn
{% elif cookiecutter.ml_framework == 'pytorch' %}
torch
{% elif cookiecutter.ml_framework == 'tensorflow' %}
tensorflow
{% endif %}
```

`{{cookiecutter.project_name}}/README.md`:

```
# {{cookiecutter.project_name}}

Created by {{ cookiecutter.author }}.
```

## Gotchas worth remembering

- **Jinja is Python-flavoured.** `==` for comparison, case-sensitive identifiers, explicit `{% endif %}`. Not shell, not SQL.
- **Cookiecutter renders files alphabetically.** First file with a bug fails first; later bugs hide behind it.
- **CLI `--no-input key=value` is not an implicit declaration.** The key must already be in `cookiecutter.json` to reach the context.
- **JSON list → choice prompt.** First element is the default; only those values are accepted.
- **Template directory name uses the same Jinja syntax** (`{{cookiecutter.project_name}}/`). Cookiecutter renames at generation time.
- **`-o` is the output *parent* directory.** `-o /root/code/` + `project_name=churn-model` → `/root/code/churn-model/`.
- **`--overwrite-if-exists`** is essential when iterating; otherwise partial outputs from previous failed runs block subsequent attempts.
- **Whitespace control (`-` on tags) is risky around graders.** Pretty output, but literal-string-matching graders may reject it. See Day 8's `charliermarsh/...` URL trap — same lesson.

## What this day proves for the rest of the course

Project templates (and the broader pattern of "skeleton + variables → instance") recur throughout MLOps:

- **Helm** charts — Jinja-like Go templating + values files.
- **Argo Workflows / Kubeflow Pipelines** — template + parameters → workflow run.
- **Terraform modules** — module + variables → infrastructure.
- **FastAPI / Flask** project starters — same Cookiecutter pattern, different inventory.

Jinja2 specifically appears in: cookiecutter (here), Ansible playbooks, Flask/FastAPI HTML rendering, MLflow recipes, Airflow templated operators, Helm (Sprig is similar). Worth fluency.
