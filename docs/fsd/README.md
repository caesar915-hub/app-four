<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# Squirl — Functional Specification Document (FSD)

This directory is the Functional Specification Document for **Squirl**, a privacy-first, on-device iOS check-in journal for adults with ADHD (SwiftUI + SwiftData).

## Documented source

- **Repository:** `/Users/caesargrey/Projects/app-four`
- **Branch:** `main`
- **Commit:** `43eb6515a63a0eca957a79aad257da380c73edd4`

All `path:line` citations in this document set refer to that commit on `main` (readable via `git show main:<path>`). The working tree may be on a different branch and is **not** the documented source.

## Conventions

### Requirement identifiers

- **Functional requirements** are numbered per area: `FR-<AREA>-NN`, where `<AREA>` is a short code for the file's domain (e.g. `FR-NAV-01`, `FR-CAP-03`). Numbers are stable within a file; never renumber a shipped requirement — mark superseded ones instead.
- **Non-functional requirements** are numbered globally: `NFR-NN` (see [11-nonfunctional.md](11-nonfunctional.md)).
- Each requirement is written as a bold ID, a short title, and a precise description, quoting exact user-facing strings and exact constants (durations, sizes, thresholds) from the source.

### Per-file template

Each area file follows this section order:

1. **Purpose** — what the area does and why it exists.
2. **Scope** — what is in and out of scope; cross-links to sibling files.
3. **Actors & triggers** — who/what initiates behavior (user, system, intents, timers).
4. **Functional requirements** — the numbered `FR-…` statements.
5. **User flows** — normative step sequences.
6. **UI states** — state inventory and transitions.
7. **Validation & constants** — exact thresholds, durations, sizes, and defaults.
8. **Edge cases** — failure and boundary behavior.
9. **Acceptance criteria** — verifiable conditions per requirement group.
10. **Source references** — `path:line` citations (on `main`) backing the key claims.

### "Implemented, dormant in 1.0" flag

The specification documents the system **as built**, including code that is implemented but not reachable or not surfaced in the 1.0 product (e.g. App Intents with `isDiscoverable = false`, settings sections that exist but are unmounted, enum cases nothing ever sets). Such items are flagged inline as **“Implemented, dormant in 1.0”** with the reason where known. Dormant does not mean planned or guaranteed — it means the code exists on `main` and is inactive.

## File index

| File | Contents |
|---|---|
| [README.md](README.md) | This index — documented source, conventions, file map. |
| [01-overview.md](01-overview.md) | Product purpose, users, principles, architecture, glossary. |
| [02-navigation-and-shell.md](02-navigation-and-shell.md) | App shell, tabs, onboarding, deep links, App Intents. |
| [03-check-in-capture.md](03-check-in-capture.md) | Voice & text check-in capture flow. |
| [04-processing-and-extraction.md](04-processing-and-extraction.md) | Transcription pipeline, NL signal extraction, extraction review. |
| [05-library-and-history.md](05-library-and-history.md) | Calendar library, day cards, recording detail, playback. |
| [06-insights.md](06-insights.md) | Insights visualizations, computations, connection cards. |
| [07-medications.md](07-medications.md) | Medication catalog, dose logging, dose guard, medication bar. |
| [08-settings-and-data.md](08-settings-and-data.md) | Settings, export, privacy, feedback, diagnostics. |
| [09-data-model.md](09-data-model.md) | SwiftData schema, entities, migrations. |
| [10-architecture-and-services.md](10-architecture-and-services.md) | DI, service protocols, store layer, design-system package. |
| [11-nonfunctional.md](11-nonfunctional.md) | Accessibility, privacy/security, performance, reliability. |

## Source references

- Product context: `PRODUCT.md`, `DESIGN.md` (repo root)
- Exploration notes (basis for this document set, compiled from `main` with `path:line` citations): `build/fsd-notes/01-shell-capture.md` through `build/fsd-notes/06-data-settings.md`
