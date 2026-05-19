# Backlog

Outstanding work across the repo. Items here are tracked but not yet done.

When you clear an item:

- Strike it through and move it to **Done** at the bottom (with the commit hash), or
- Delete it if it's superseded.

Don't let this file get stale. If something here is no longer worth doing, delete it with a one-line note in the commit.

## Conventions

**Reconstructed walkthroughs** carry a banner at the top:

> ⚠️ **Reconstructed walkthrough.** Outputs in this file are extrapolated from what the lab *would* produce, not captured from a real session. The next time someone runs this lab, replace the extrapolated outputs with the real ones. Tracked in [BACKLOG.md](../../BACKLOG.md).

The banner stays until someone replaces the extrapolated outputs with a real run.

---

## Days 1-6 — walkthrough.md backfill

These days were completed before the README/walkthrough split convention emerged (see Day 7). They need:

- A `walkthrough.md` reconstructed from the day's README + general knowledge of the tools.
- The README trimmed to TL;DR style (task + acceptance criteria + final-state recipe + key gotchas + pointers).
- A clear banner on the walkthrough flagging the outputs as extrapolated.

### Acceptance criteria (per day)

- `walkthrough.md` exists, terse (steps + expected behaviour, no fabricated terminal outputs that look real).
- Banner present at top of `walkthrough.md`.
- README trimmed to TL;DR, with pointers to walkthrough.md and any relevant notes/ file.
- BACKLOG item for that day moved to Done.

### Items

(none — all six reconstructed walkthroughs created; see Done section. Days 1-6 READMEs trimmed to TL;DR.)

### When the next person re-runs a Day 1-6 lab

Replace the extrapolated outputs with the real ones, remove the reconstructed banner, and tick the item off this list. Commit message should mention that the walkthrough has been verified against a real lab run.

---

## notes/ extractions from earlier days

Topical content that's currently buried in a single day's README/walkthrough and would be better placed in `notes/` where it can grow across days.

### Acceptance criteria (per file)

- New `notes/<topic>.md` exists, with a Contents TOC.
- Content extracted from the source day(s) without losing anything.
- The source day's README now links to the note instead of duplicating the content.
- `notes/README.md` index updated.

### Items

(none — all three notes extractions cleared; see Done section.)

---

## Held — extract when more material accrues

Worth doing eventually but not enough material yet. Promote to active items when the second relevant day lands.

- **`notes/binding-and-ports.md`** (Day 2 + Domain 7 model serving). 0.0.0.0 vs 127.0.0.1 vs hostname, port collisions, `ss -tlnp`, the reverse-proxy pattern. Promote when Day 57 (Flask) or Day 58 (FastAPI) lands.
- **`notes/python-environments.md`** (Day 1 + Day 3). `venv` vs `virtualenv` vs `conda` vs `uv venv`. Promote when something new touches the topic.

---

## Done

- `notes/makefile.md` — extracted from Day 5 README; Day 5 trimmed to link to it. (commit: f794d97)
- `notes/code-quality.md` — extracted from Day 6 README; Day 6 trimmed to link to it. (commit: f794d97)
- `notes/ml-project-layout.md` — extracted from Day 4 README; Day 4 trimmed to link to it. (commit: f794d97)
- Day 1 reconstructed `walkthrough.md` + README trimmed to TL;DR. (commit: pending)
- Day 2 reconstructed `walkthrough.md` + README trimmed to TL;DR. (commit: pending)
- Day 3 reconstructed `walkthrough.md` + README trimmed to TL;DR. (commit: pending)
- Day 4 reconstructed `walkthrough.md` + README walkthrough banner added. (commit: pending)
- Day 5 reconstructed `walkthrough.md` + README walkthrough banner added. (commit: pending)
- Day 6 reconstructed `walkthrough.md` + README walkthrough banner added. (commit: pending)
