# Squirl Documentation

This directory contains the engineering, product, and design documentation for **Squirl** (Xcode target `app-four`).

## Quick Links

| Document | Audience | Purpose |
|----------|----------|---------|
| [`../README.md`](../README.md) | New team members & stakeholders | Project overview, build instructions, high-level architecture |
| [`ONBOARDING.md`](ONBOARDING.md) | New engineers | Day-one setup, codebase tour, first tasks |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | All engineers | Branching, PRs, code review, style conventions |
| [`engineering/ARCHITECTURE.md`](engineering/ARCHITECTURE.md) | All engineers | System architecture, data flow, layer responsibilities |
| [`ui/ARCHITECTURE.md`](ui/ARCHITECTURE.md) | Frontend engineers | UI patterns, navigation, state flow, accessibility |
| [`ui/VIEW_MODELS.md`](ui/VIEW_MODELS.md) | All engineers | ViewModel catalog and responsibilities |
| [`ui/COMPONENTS.md`](ui/COMPONENTS.md) | Frontend engineers | Reusable component catalog |
| [`engineering/SERVICES.md`](engineering/SERVICES.md) | Backend/service engineers | Service protocols, implementations, DI seams |
| [`engineering/DATA_MODEL.md`](engineering/DATA_MODEL.md) | All engineers | SwiftData schema, relationships, migration notes |
| [`engineering/DEVELOPMENT.md`](engineering/DEVELOPMENT.md) | All engineers | Build, run, test, debug, simulator workflows |
| [`engineering/TESTING.md`](engineering/TESTING.md) | All engineers | Testing strategy, conventions, CI notes |
| [`engineering/OPERATIONS.md`](engineering/OPERATIONS.md) | Release engineers | Release process, app store, troubleshooting runbook |
| [`ADRs/`](ADRs/) | All engineers | Architecture Decision Records |
| [`product/README.md`](product/README.md) | Product & engineering | PRD-lite, persona, success metrics, roadmap |
| [`../DESIGN.md`](../DESIGN.md) | Design & frontend engineers | Design system "Paper & Pollen" |
| [`design/UI_REQUIREMENTS.md`](design/UI_REQUIREMENTS.md) | Design & frontend engineers | Per-screen UI/UX requirements |
| [`BACKLOG.md`](BACKLOG.md) | Product & engineering | Milestones and feature stages |
| [`TODO.md`](TODO.md) | Engineering | Load-bearing pre-launch gaps |

## Per-Screen UI Docs

UI documentation is centralized under [`docs/ui/`](ui/):

- [`docs/ui/README.md`](ui/README.md) — UI docs index
- [`docs/ui/ARCHITECTURE.md`](ui/ARCHITECTURE.md) — UI architecture and patterns
- [`docs/ui/VIEW_MODELS.md`](ui/VIEW_MODELS.md) — ViewModel catalog
- [`docs/ui/COMPONENTS.md`](ui/COMPONENTS.md) — Component catalog
- [`docs/ui/screens/check-in.md`](ui/screens/check-in.md) — Check-in screen
- [`docs/ui/screens/library.md`](ui/screens/library.md) — Calendar / Library screen
- [`docs/ui/screens/insights.md`](ui/screens/insights.md) — Insights screen
- [`docs/ui/screens/settings.md`](ui/screens/settings.md) — Settings screen
- [`docs/ui/screens/recording-detail.md`](ui/screens/recording-detail.md) — Recording detail screen
- [`docs/ui/screens/extraction-review.md`](ui/screens/extraction-review.md) — Extraction review screen
- [`app-four/Views/README.md`](../app-four/Views/README.md) — Views directory pointer
- [`app-four/ViewModels/README.md`](../app-four/ViewModels/README.md) — ViewModels directory pointer

## Documentation Conventions

- **Subsystem docs live next to their code.** Example: `app-four/Services/NoteExtraction/README.md`.
- **Engineering docs live under `docs/engineering/`.**
- **Product docs live under `docs/product/`.**
- **ADRs live under `docs/ADRs/`** and follow the format `NNN-short-title.md`.
- **Archive is not authoritative.** Anything in `docs/archive/` may be outdated; verify against current code.

## Updating Docs

When you change architecture, service contracts, data models, UI structure, ViewModel responsibilities, or build/test workflows, update the corresponding document in the same PR. Docs that drift from code are worse than no docs.
