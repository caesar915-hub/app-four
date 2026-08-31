# app-four docs

Map of the project's documentation. Source of truth for *where things live*.

> Agent rules are in [`/CLAUDE.md`](../CLAUDE.md) (must stay at repo root — auto-loaded).

## Planning

> 🧊 **September 2026:** the two files below are **FROZEN** for the Shipaton sprint
> (2026-09-01 → 2026-09-30). Live planning lives in
> [`shipaton_plan/`](../shipaton_plan/) — [SEPTEMBER_PLAN.md](../shipaton_plan/SEPTEMBER_PLAN.md)
> (plan + release train), [BACKLOG.md](../shipaton_plan/BACKLOG.md) (state),
> [DEVLOG.md](../shipaton_plan/DEVLOG.md) (why). Unfrozen by the exit ritual on 2026-10-01.

- [BACKLOG.md](BACKLOG.md) — every feature/idea by stage (💡 Idea → 📐 Plan → 🔨 In code → ✅ Shipped) + milestones + ship checklist. *Frozen for September.*
- [DEVLOG.md](DEVLOG.md) — chronological *why* narrative. *Frozen for September.*
- [TODO.md](TODO.md) — foundational / pre-launch action list (the load-bearing gaps).

Written by `/morning` (standup) and `/evening` (wrap). *`/recap` was never merged to `main` and is not a valid command — `/morning` replaces it.*

## product/
Product definition — PRD, persona, success metric, monetization.

> **Canonical master product docs are maintained separately, not here.** The master PRD
> and FSD live in a separate private docs repo (seeded 2026-06-24 from this repo's
> `impeccable-design/PRODUCT.md`, `DESIGN.md`, constitution, BACKLOG, and the per-feature
> `specs/`). This repo remains the source of truth for the **per-feature** specs under
> `specs/NNN-*/`; the master docs consolidate them app-wide. Update the masters there when
> specs change materially.

## engineering/
- [ARCHITECTURE.md](engineering/ARCHITECTURE.md) — MVVM + Store + DI, SwiftData schema, ML model management.
- [next-ml.md](engineering/next-ml.md) — strategy for replacing/augmenting the NLP extraction layer.
- _Planned:_ `migrations.md` (SwiftData versioning — P0), `privacy.md`, `testing.md`.

## design/
- [UI_REQUIREMENTS.md](design/UI_REQUIREMENTS.md) — design-system tokens + per-screen UI/UX requirements.

## superpowers/
Skill-managed `specs/` (design specs) and `plans/` (implementation plans), dated. Left as-is.

## archive/
Superseded docs kept for history. Not authoritative — verify against current code before trusting.

---
**Conventions:** subsystem READMEs live next to their code (e.g. `app-two/Services/NoteExtraction/README.md`), not here.
Internal docs are kept out of the app source tree so they aren't bundled into the shipped `.app`.
