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
- **Real-world projects live in `projects/<project-name>/`** — longer-arc work synthesising multiple days (typically the end of a domain). See `projects/README.md` for the convention. Projects run *alongside* daily labs, not after them.

### Teaching style — pass the task fast, learn deeply after

**Hard constraint:** lab tasks are timed (60 minutes). During the task, optimise for *passing*, not for pedagogy. Save the deep explanation for after the grader is green.

**Artifact timing:** each lab artifact has a specific time it's created.

| Artifact | When |
|---|---|
| `days/day-XX/` directory + `README.md` (TL;DR) + reference config files | **At lab start, before any chat diagnosis.** This is the user's study sheet *during* the lab. |
| `days/day-XX/walkthrough.md` | Built collaboratively *during* the lab; finalised on grader green. |
| `notes/<topic>.md` extractions | After grader green and commit, as follow-up. |

Three-phase workflow:

**Phase 1 — lab start (after seeing the broken state):**
- **Wait for the user to share the lab's relevant files first** — the broken `cookiecutter.json`, the broken `pyproject.toml`, the broken `Makefile`, whatever the lab planted. Ask for them if not provided. Do not create Phase 1 artifacts purely from the task description, because:
  - the diagnosis table is more accurate when it points at *real* plants, not generic possibilities;
  - the reference files match the lab's actual shape (e.g. an outer template README, an unexpected subdirectory, a particular pin format);
  - any "this case is unusual" detail that only shows up on inspection lands in the README on first write rather than as a later correction.
- Once the broken state is in hand, create `days/day-XX/README.md` with the TL;DR: task statement, acceptance criteria, target final-state (the corrected config / code), run commands, **diagnosis table grounded in the actual issues**, key gotchas, resources. Same content that would otherwise get blurted in chat — but in the file, not the chat.
- Drop reference files showing the correct final shape (`pyproject.toml`, `.pre-commit-config.yaml`, `Makefile`, etc.).
- This file is reference material the user reads alongside the chat.

**Phase 2 — lab in progress (chat is step-by-step, walkthrough is WIP):**
- In chat, walk through one diagnostic step at a time. Wait for the user's response before moving on. **Do not blurt the full diagnosis in chat** — it's already in the README for reference.
- Start `walkthrough.md` as a WIP — capture actual outputs, surprises, the order in which errors surfaced, gotchas hit.
- Only stop to teach if the user hits a real wall — otherwise keep moving.
- Before declaring "looks done," cross-check the final state against every acceptance-criterion bullet. Tool silence ≠ grader pass — a grader can check things tools never complain about (exact URLs, file presence, version pins).

**Phase 3 — after grader green (deep, slow):**
1. **Pause.** Acknowledge the pass, don't propose commits.
2. **Discuss.** Ask what surprised the user, what's worth digging into, what should land in `walkthrough.md`. Let the user drive.
3. **Finalise `walkthrough.md`** with the captured run — the long-form "when I first ran this it said Y, which surprised me because Z" narrative, PEP refs, the why-the-tool-behaves-this-way explanations.
4. **Promote cross-cutting takeaways to `notes/<topic>.md`.** *Default to extracting* whenever the day produced enough conceptual material to stand on its own as a note — don't wait for a "second day." Defer (`BACKLOG.md` Held) only if there genuinely isn't enough material yet. Wire the new note into `notes/README.md` index and link it from the day's README + walkthrough.
5. **Tick the day's box in the root `README.md`** — `- [ ]` → `- [x]`.
6. **Update `BACKLOG.md`** if any items were cleared, promoted, or newly added today.
7. **Commit only when the user explicitly says so.** After commit, replace `pending` hashes in BACKLOG with the real hash.

In other words: **README and reference files exist from minute one; chat is interactive teaching; walkthrough is the post-hoc narrative; notes are the cross-cutting extracts.** Don't conflate them.

### Where things live: days/ vs notes/

The repo separates two kinds of writeup:

- **Day-specific** ("what happened in this lab, what the tool printed, the gotchas I hit today") → `days/day-XX/walkthrough.md`
- **Cross-cutting** ("how does Python packaging work in general", "what is a PEP", "what's the difference between Argo and Prefect") → `notes/<topic>.md`

When a discussion after a task uncovers something that *isn't* about today's lab — a mental model, a tooling primer, a recurring trap — it goes in `notes/`, not in `walkthrough.md`. Days link out to notes; notes don't need to know which days reference them. Add to a note whenever you re-learn or refine something. They're living documents.

`notes/README.md` maintains the index.

Every file in `notes/` opens with a **Contents** section linking to each `##` heading. Update the TOC whenever a new section is added or a heading is renamed — out-of-date TOCs are worse than missing ones.

### Reconstructed walkthroughs

For days completed before the README/walkthrough split convention existed (Days 1-6), `walkthrough.md` may be *reconstructed* — written from the README + general knowledge of the tool, not from a captured session. These files open with this banner:

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

Rules for writing them:

- **Terse, not best-guess.** Show the *steps* and expected *behaviour* ("the build should succeed; the wheel filename should match X"). Don't fabricate terminal outputs that look like they came from a real session — that's worse than no outputs because it looks authoritative when it isn't.
- **Banner stays** until someone replaces the extrapolated content with a real run.
- Every reconstructed walkthrough has a matching entry in `BACKLOG.md`.

### BACKLOG.md

Outstanding work tracked at the repo root. Items grouped by category (per-day backfill, notes/ extractions, held-for-later). When clearing an item, move it to the **Done** section with the commit hash.

Don't accumulate items indefinitely — if something stops being worth doing, delete it with a one-line note in the commit.

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
