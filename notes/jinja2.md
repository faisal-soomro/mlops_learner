# Jinja2 — the template language under everything

Cross-cutting notes on [Jinja2](https://jinja.palletsprojects.com/). It's the Python-ecosystem default template engine and shows up in: cookiecutter (Day 9), Ansible playbooks, Flask/FastAPI HTML rendering, MLflow recipes, Airflow templated operators, dbt models. Helm uses Go templates with the Sprig library — different language, same mental model.

The 80/20: variables (`{{ x }}`), control structures (`{% if %}`, `{% for %}`), filters (`{{ x | upper }}`), whitespace control (`-`), and the Python-flavour traps below.

## Contents

- [The two delimiter shapes](#the-two-delimiter-shapes)
- [Python-flavour, not shell-flavour](#python-flavour-not-shell-flavour)
- [Control structures need explicit closing](#control-structures-need-explicit-closing)
- [Whitespace control: `-` strips around the tag](#whitespace-control---strips-around-the-tag)
- [Filters](#filters)
- [Undefined variables raise, by default](#undefined-variables-raise-by-default)
- [What "context" means and how to read the error dump](#what-context-means-and-how-to-read-the-error-dump)
- [The grader trap — literal-string matching vs valid Jinja](#the-grader-trap--literal-string-matching-vs-valid-jinja)
- [See also](#see-also)

## The two delimiter shapes

```
{{ expression }}     ← interpolation: output the expression's value
{% statement %}      ← control: if/elif/else/endif, for/endfor, set, include, ...
{# comment #}        ← comment: not in output
```

Three rules to remember:

- `{{ ... }}` is for *expressions* (anything that has a value). `{{ x + 1 }}`, `{{ x | upper }}`, `{{ cookiecutter.project_name }}`.
- `{% ... %}` is for *statements* (anything that controls flow). `{% if x == 1 %}`, `{% for item in xs %}`, `{% endif %}`.
- Mixing them is a parse error: `{{ if x %}}` won't work.

## Python-flavour, not shell-flavour

Inside `{% if %}` and `{{ }}`, expressions follow Python conventions, with a few Jinja-specific additions:

| What | Jinja | Shell / SQL |
|---|---|---|
| Equality | `==` | `=` |
| Inequality | `!=` | `<>` |
| Boolean and/or | `and`, `or`, `not` | `&&`, `||`, `!` |
| Identifier case | case-sensitive (`Author` ≠ `author`) | varies, often case-insensitive |
| String literals | single or double quotes, either fine | varies |
| Membership | `in` (`'a' in xs`) | varies |

The `=` (assignment) vs `==` (comparison) trap is the most common one. `=` is only valid in `{% set x = 1 %}` (assignment); inside `{% if %}`, it's a syntax error.

## Control structures need explicit closing

Jinja templates sit inside non-code text (HTML, YAML, plain text). There's no indentation to define scope, so every control structure has an explicit terminator:

```jinja
{% if cond %} ... {% elif other %} ... {% else %} ... {% endif %}
{% for x in xs %} ... {% endfor %}
{% block name %} ... {% endblock %}
{% with x = 1 %} ... {% endwith %}
```

Forget `{% endif %}` and Jinja prints:

```
TemplateSyntaxError: Unexpected end of template.
Jinja was looking for the following tags: 'elif' or 'else' or 'endif'.
The innermost block that needs to be closed is 'if'.
```

The error always names the unclosed block — useful when blocks nest.

## Whitespace control: `-` strips around the tag

```jinja
{% if x -%}        ← strips whitespace AFTER the tag
   {%- if y %}     ← strips whitespace BEFORE the tag
   {%- endif -%}   ← strips both sides
{% endif %}
```

Without `-`, every `{% ... %}` tag leaves its surrounding whitespace (including the trailing newline) in the output. Templates that produce config files often look like:

```
\n
\n
scikit-learn\n
\n
```

…instead of the desired:

```
scikit-learn\n
```

Add `-` on the appropriate side of each tag to fix. `{% if cond -%}` strips after; `{%- endif %}` strips before. Both `{%- endif -%}` strips both.

Two related global options if you don't want to dash every tag:

- `trim_blocks=True` — newlines after `{% ... %}` blocks are stripped automatically.
- `lstrip_blocks=True` — whitespace at the *start* of a block tag's line is stripped.

Cookiecutter doesn't enable these by default, which is why the per-tag `-` shows up so much in cookiecutter templates.

## Filters

`x | filter_name` applies a filter. Reads left-to-right (Unix pipe style):

```jinja
{{ name | upper }}                    ← FOO
{{ value | default('unknown') }}      ← uses 'unknown' if undefined
{{ items | join(', ') }}              ← "a, b, c"
{{ name | lower | capitalize }}       ← chained
{{ x | int }}, {{ x | float }}        ← type coercion
{{ items | length }}                  ← len()
{{ d | tojson }}                      ← JSON-encode (handy in YAML/JSON templates)
```

Full list: [Jinja docs — Builtin Filters](https://jinja.palletsprojects.com/en/stable/templates/#list-of-builtin-filters). Most-used by far: `default`, `upper`/`lower`, `join`, `length`, `tojson`, `replace`.

## Undefined variables raise, by default

`{{ cookiecutter.nonexistent }}` raises `UndefinedError` at render time. In production, you can configure the environment with `undefined=StrictUndefined` (raise) or `undefined=ChainableUndefined` (silently produce empty string) — but the default Jinja behaviour in most tools (cookiecutter, Ansible) is to raise.

The error message shows the *context dump* — every variable currently in scope. Read it like a dict:

```
'collections.OrderedDict object' has no attribute 'Author'
Context: {
    "cookiecutter": {
        "author": "xFusionCorp",
        ...
    }
}
```

Two things to spot here:

- The exact attribute name being looked up (`Author`) — usually a typo or case mismatch.
- Whether the *expected* key is present (`author` is there, lowercase). If so, fix the lookup; if not, fix the context (i.e. the upstream config that defines variables).

The `_cookiecutter` / `cookiecutter` double-context shape is cookiecutter-specific — Jinja templates outside cookiecutter have whatever context the caller provides.

## What "context" means and how to read the error dump

"Context" is the dict of variables available inside the template. The renderer (cookiecutter, Ansible, Flask, ...) builds the context from its inputs:

- Cookiecutter: `cookiecutter.json` defaults + CLI overrides for declared keys + hook outputs.
- Ansible: facts, host_vars, group_vars, play vars, extra-vars.
- Flask: whatever the view function passes to `render_template(..., **kwargs)`.

A surprising one: **CLI overrides for keys not declared in `cookiecutter.json` are silently dropped.** So `cookiecutter <src> --no-input ml_framework=sklearn` does *not* put `ml_framework` in the context unless `cookiecutter.json` declares it. The same shape recurs across tools — context is built from declared inputs, not arbitrary CLI noise.

## The grader trap — literal-string matching vs valid Jinja

Stylistic Jinja improvements can pass the tool and fail a downstream checker doing literal regex/string matching on the template source. Two examples seen so far:

- **Whitespace control around `endif`.** `{%- endif %}` is valid Jinja and matches the opening `{% if %}` correctly. But a grader counting occurrences of the literal substring `{% endif %}` reads zero matches and reports "mismatched tags."
- **Variable interpolation styles.** `{{cookiecutter.x}}` and `{{ cookiecutter.x }}` are both valid; some graders match only one form.

**Lesson:** when a grader (or any literal-string checker) is in the loop, prefer the boring form. The clever form may be more correct from the renderer's perspective but the checker doesn't know that.

This is the same shape as Day 8's `charliermarsh/ruff-pre-commit` URL — runtime tool was happy with the GitHub redirect, the grader did literal string matching, failed. Pattern: **tool silence ≠ downstream pass.**

## See also

- [Jinja docs](https://jinja.palletsprojects.com/) — short and well-written; the [Template Designer Documentation](https://jinja.palletsprojects.com/en/stable/templates/) is the page that matters.
- [Jinja API docs](https://jinja.palletsprojects.com/en/stable/api/) — for when you're calling Jinja from Python directly (Flask, custom renderers).
- [Cookiecutter docs — Templating](https://cookiecutter.readthedocs.io/en/stable/advanced/template_extensions.html) — cookiecutter-specific Jinja features (extensions, hooks).
- [Ansible — Templating](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html) — Jinja in playbooks, with Ansible-specific filters.
- `days/day-09/` — the lab where these gotchas surfaced (Cookiecutter ML project template).
