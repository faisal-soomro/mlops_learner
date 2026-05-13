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

### Per-day README structure
Every `days/day-XX/README.md` must include these sections, in order:
1. **Task** — what is being built today (one-liner + acceptance criteria)
2. **Why this matters** — the problem this tool/practice solves; what breaks without it
3. **Use case** — a concrete real-world scenario where you'd reach for this
4. **How to run** — commands to reproduce the working code in this directory
5. **Resources** — curated links (official docs, blog posts, talks) for deeper reading

Write the explanatory sections in plain language — they're learning notes, not marketing copy. Prefer concrete examples ("without DVC, a 2GB dataset ends up in git history forever") over abstract claims ("DVC improves reproducibility").
