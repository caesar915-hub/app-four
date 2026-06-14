# app-four docs

Map of the project's documentation. Source of truth for *where things live*.

> Agent rules are in [`/CLAUDE.md`](../CLAUDE.md) (must stay at repo root — auto-loaded).

## Planning (kept at `docs/` root — `/recap` and CLAUDE hard-code these paths)
- [BACKLOG.md](BACKLOG.md) — every feature/idea by stage (💡 Idea → 📐 Plan → 🔨 In code → ✅ Shipped) + milestones + ship checklist.
- [DEVLOG.md](DEVLOG.md) — chronological *why* narrative; written by `/recap`.
- [TODO.md](TODO.md) — foundational / pre-launch action list (the load-bearing gaps).

## product/
Product definition — PRD, persona, success metric, monetization. _(To be written — see [TODO.md](TODO.md).)_

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
