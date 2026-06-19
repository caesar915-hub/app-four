# Spec Kit — the app-four build workflow

**Spec Kit is the main, end-to-end workflow for this project.** Every feature goes
through it: spec → plan → tasks → implement. It is constitution-gated — see
[.specify/memory/constitution.md](../.specify/memory/constitution.md) (v1.2.0),
which defines the non-negotiables every spec and plan must satisfy.

**superpowers (`/spec`, `/design-*`, HTML mockups) is design only.** It is the
design-exploration feeder: it produces mockups and design records under
`docs/superpowers/`. Those are inputs a Spec Kit spec references — they are NOT a
parallel build workflow. Build always runs through Spec Kit.

---

## Spec-Driven Development, in one breath

Define **what** and **why** before **how**. The spec locks requirements; the plan
locks architecture; tasks are TDD-ordered so tests come before implementation;
each task is one clean, revertable checkpoint.

## The pipeline

| Step | Command | Produces | Gate |
|---|---|---|---|
| 0 | `/speckit-constitution` | `.specify/memory/constitution.md` | Already done (v1.2.0). Re-run only to amend. |
| 1 | `/speckit-clarify` | clarifying Q&A folded into the spec | Run FIRST when scope is fuzzy — front-loads `[NEEDS CLARIFICATION]` as questions instead of buried tags. |
| 2 | `/speckit-specify` | `specs/NNN-slug/spec.md` (what & why) | User stories + acceptance criteria. No architecture, no code. |
| 3 | `/speckit-plan` | `plan.md`, `research.md`, `data-model.md`, contracts | **Constitution Check (I–X) must PASS** before Phase 0. |
| 4 | `/speckit-tasks` | `tasks.md` (numbered, TDD-ordered) | Tests are **MANDATORY + test-first** for logic (models/services/VMs/extraction) per Principle X; SwiftUI views exempt (build + run). |
| 5 | `/speckit-implement` | code, one task per session | **RED→GREEN→refactor per task** — write the failing test first, confirm it fails, then implement. Build + full suite green before stopping. |

## Operating rules

- **Constitution first.** It gates every spec and plan. Confirm it reflects the
  non-negotiables before running anything (it does — v1.1.0).
- **One feature per spec.** `/speckit-specify` takes a single feature → one
  `specs/NNN-slug/`. Don't bundle two milestones into one spec.
- **Don't hand-edit the spec markdown.** Pass clarifications back as chat messages
  so the agent updates the file and keeps it internally consistent.
- **One task per session.** Open a fresh session per task; reference it explicitly
  ("work on task 005"). Never run multiple tasks in one session — it collapses
  context and defeats the TDD ordering. Each finished task = a clean checkpoint.
- **Split fat tasks.** Any task touching more than one layer (model + view + test)
  is too big — split it.
- **MCP hygiene.** Load planning-phase MCP servers (web search, docs) only when
  strictly needed; they consume context aggressively. Drop them after
  `/speckit-plan`.
- **No issue export.** Tasks are markdown only — fine for solo. Revisit if work is
  handed to others (v0.9+).

## This project's PRD inputs (standing)

| Input | Value |
|---|---|
| Product name | **Squirl** (codename / module `app-four`) |
| Problem | Voice-logging a daily check-in takes too long in existing apps |
| Core loop | Speak → transcribe (on-device) → extract tags → view trends |
| Target user — v0.8 | Solo dogfood |
| Target user — v0.9 | 1–2 trusted testers |
| Target user — v1.0 | App Store strangers |
| Hard constraints | On-device only · SwiftUI + SwiftData + Swift 6 (strict concurrency) · iOS 26+ |
| In scope (active) | HealthKit signals — read-only, on-device — spec [009-healthkit-signals](../specs/009-healthkit-signals/spec.md) (brought into scope 2026-06-20) |
| Out of scope (now) | LLM trend summaries · iCloud sync · multilingual |
| Active focus | v0.8.1 (Insights palette) → v0.9 (onboarding + first-run UX) — intermediate milestones TBD by owner |

State (stage of each item) lives in [BACKLOG.md](BACKLOG.md); the chronological
*why* lives in [DEVLOG.md](DEVLOG.md); cross-session facts live in `memory/`.
This file is the *workflow*; those are the *content*.
