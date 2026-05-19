# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# 100 Days of MLOps

A hands-on, day-by-day learning roadmap covering the full MLOps lifecycle — from ML project setup to production orchestration and observability.

## Structure
- 100 days, 12 domains
- Each day is a focused, practical task
- Progressive: later days build on earlier ones
- No repo-wide build/test/lint — each day is a self-contained mini-project with its own tooling and README. Run commands from within `days/day-XX/`.

## Domains (in order)
1. **Days 1–9**: ML Project Setup — venv, uv, project structure, code quality, packaging
2. **Days 10–19**: DVC — data versioning, pipelines, experiments, remote storage
3. **Days 20–30**: MLflow — experiment tracking, model registry, lifecycle management
4. **Days 31–40**: Model Training — scikit-learn, Optuna, FLAML, PyTorch, production pipelines
5. **Days 41–49**: Feature Store & Data Quality — Feast, Vault secrets, Great Expectations
6. **Days 50–56**: Docker for ML — training images, multi-stage, compose, GPU, CI builds
7. **Days 57–66**: Model Serving — Flask, FastAPI, BentoML, A/B testing, canary deploys
8. **Days 67–75**: Monitoring — Prometheus, Grafana, Evidently, drift detection, auto-retrain
9. **Days 76–84**: CI/CD for ML — linting, data/model validation, CML, deployment, rollback
10. **Days 85–91**: Orchestration — Argo Workflows, Prefect, CronWorkflows, production pipelines
11. **Days 92–96**: Kubernetes — model deployment, HPA, KServe, Kubeflow, GitOps with ArgoCD
12. **Days 97–100**: Capstone — end-to-end MLOps system tying all domains together

## Tech Stack
Python, uv, DVC, MLflow, scikit-learn, PyTorch, Optuna, FLAML, Feast, Great Expectations,
Docker, FastAPI, Flask, BentoML, Prometheus, Grafana, Evidently, GitHub Actions, CML,
Argo Workflows, Prefect, Kubernetes, KServe, Kubeflow, ArgoCD, HashiCorp Vault

## Git

**Git author must be:** `faisal-soomro <h.faisalsoomro@gmail.com>`. If `git config user.name` or `user.email` differ, flag it before committing. Set per-repo with:

```bash
git config user.name "faisal-soomro"
git config user.email "h.faisalsoomro@gmail.com"
```

**Contextual history:** Commit when a batch of changes represents a meaningful unit of work (e.g. a completed day, a config fix, a new domain). Don't let unrelated changes pile up into one vague commit.

## Conventions
- Each day gets its own directory: `days/day-XX/`
- Working code goes in the day directory
- Keep it practical — runnable code over theory
- When a day depends on earlier work, reference it explicitly (e.g. "uses the DVC pipeline from day-19") rather than copying code
- Mark progress by checking off the box in the root `README.md` when a day's acceptance criteria are met

### Teaching style — pass the task fast, learn deeply after

**Hard constraint:** lab tasks are timed (60 minutes). During the task, optimise for *passing*, not for pedagogy. Save the deep explanation for after the grader is green.

Two-phase workflow:

**Phase 1 — during the task (fast):**
- Give a *compact* diagnosis (the table, the bullet list — what's wrong and what to change).
- The user edits and runs. Minimal back-and-forth.
- Only stop to teach if the user hits a real wall — otherwise keep moving.
- Reference files in `days/day-XX/` are fine to look at once during the task, for sanity-checking. Don't make the user derive every edit from scratch under the clock.

**Phase 2 — after the task passes (deep):**
- Capture what just happened in `days/day-XX/walkthrough.md`: the actual outputs, what each step proved, the gotchas hit along the way, the "I'd want to remember this six months from now" notes.
- This is where the long-form explanation lives — PEP refs, why the tool behaves a certain way, what the lesson generalises to.
- The README stays as the canonical "what is this day, how to run it, resources."

In other words: **be a fast assistant during the lab; be a thorough teacher after.** Don't trade one for the other.

When writing instructions during a task: prefer "here's what's wrong, edit these N lines, then run X" over "now look at the output and tell me what you see." When writing `walkthrough.md` after: the slow narrative ("when I first ran this it said Y, which surprised me because Z") is exactly what's wanted.

### Where things live: days/ vs notes/

The repo separates two kinds of writeup:

- **Day-specific** ("what happened in this lab, what the tool printed, the gotchas I hit today") → `days/day-XX/walkthrough.md`
- **Cross-cutting** ("how does Python packaging work in general", "what is a PEP", "what's the difference between Argo and Prefect") → `notes/<topic>.md`

When a discussion after a task uncovers something that *isn't* about today's lab — a mental model, a tooling primer, a recurring trap — it goes in `notes/`, not in `walkthrough.md`. Days link out to notes; notes don't need to know which days reference them. Add to a note whenever you re-learn or refine something. They're living documents.

`notes/README.md` maintains the index.

Every file in `notes/` opens with a **Contents** section linking to each `##` heading. Update the TOC whenever a new section is added or a heading is renamed — out-of-date TOCs are worse than missing ones.

### Don't rush to commit — discuss first

After a task passes, **do not auto-commit**. The discussion of what happened, what was learned, and what should be captured in `walkthrough.md` is the most valuable part of the day — committing closes that window prematurely.

Flow:

1. Task passes (grader green).
2. **Pause.** Acknowledge the pass, but don't propose commit messages yet.
3. **Discuss.** Ask if there's anything that surprised the user, anything they want to dig into, anything that should be added to `walkthrough.md`. Let them drive.
4. Update `walkthrough.md` / README based on the discussion.
5. Only commit when the user explicitly says "commit" (or equivalent).

The user knows they'll commit eventually — they don't need a reminder. They do need the space to think about what just happened.

### Per-day README structure
Every `days/day-XX/README.md` must include these sections, in order:
1. **Task** — what is being built today (one-liner + acceptance criteria)
2. **Why this matters** — the problem this tool/practice solves; what breaks without it
3. **Use case** — a concrete real-world scenario where you'd reach for this
4. **How to run** — commands to reproduce the working code in this directory
5. **Resources** — curated links (official docs, blog posts, talks) for deeper reading

Write the explanatory sections in plain language — they're learning notes, not marketing copy. Prefer concrete examples ("without DVC, a 2GB dataset ends up in git history forever") over abstract claims ("DVC improves reproducibility").
