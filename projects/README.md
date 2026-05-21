# projects/

Real-world use cases built alongside the 100-day lab series. Where `days/` is one task per day and `notes/` is cross-cutting concepts, `projects/` is the **integration layer** — longer-arc work that ties multiple days together into something that actually does a thing.

## Convention

- Each project gets its own directory: `projects/<project-name>/`.
- Every project directory has at minimum a `README.md` (design doc + status + which days it draws on).
- Code, scripts, or template files relevant to the project can live inside its directory, or the README can link out to a separate repo if the project grows large enough to warrant one.
- Projects are *worked on alongside* the daily labs, not after them. A project may stall, advance, or finish at any time. Status is tracked in the project's own README.

## When to start a project

When a domain (or several days) clearly synthesises into something that could exist on its own:

- A small ML training pipeline at the end of Domain 1 (project setup).
- A reproducible-data-pipeline mini-project at the end of Domain 2 (DVC).
- A model-registry-backed training loop at the end of Domain 3 (MLflow).
- An end-to-end inference service at the end of Domain 7 (serving).

Each is roughly the size of a weekend's work and reuses the previous projects' scaffolding.

## When a project is "done"

When the README's acceptance/exit criteria are met *and* the lessons have been folded back into:

- `notes/` (any cross-cutting takeaways).
- `days/day-XX/walkthrough.md` (anything that re-illuminates a lab).
- `BACKLOG.md` (any follow-up items the project surfaced).

A project being "done" doesn't mean the code stops evolving — it means we stopped *learning* from it and the value is captured back into the durable artifacts.

## Index

| Project | Domain(s) | Status | Description |
|---|---|---|---|
| [mlops-learner-template](mlops-learner-template/) | 1 | In progress | Opinionated Cookiecutter template baking in every Day 1-9 pattern. Used to scaffold downstream toy projects. |
