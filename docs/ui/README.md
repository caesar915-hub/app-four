# Squirl UI Documentation

_Last updated: 2026-06-28_

This directory contains the canonical user-interface documentation for Squirl.

## Documents

| Document | Purpose |
|----------|---------|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Navigation model, `ScreenContainer`, View/ViewModel responsibilities, state flow, patterns, accessibility, pitfalls |
| [`VIEW_MODELS.md`](VIEW_MODELS.md) | Catalog of every ViewModel: state, methods, dependencies |
| [`COMPONENTS.md`](COMPONENTS.md) | Reusable component catalog |
| [`screens/check-in.md`](screens/check-in.md) | Check-in capture screen |
| [`screens/library.md`](screens/library.md) | Calendar / Library screen |
| [`screens/insights.md`](screens/insights.md) | Insights dashboard |
| [`screens/settings.md`](screens/settings.md) | Settings screen |
| [`screens/recording-detail.md`](screens/recording-detail.md) | Recording detail screen |
| [`screens/extraction-review.md`](screens/extraction-review.md) | Extraction review / edit sheet |

## Conventions

- UI docs are centralized here rather than spread across `app-four/Views/`.
- Each screen doc describes user flows, UI states, ViewModel ownership, and related specs.
- Diagrams use Mermaid.
- When code changes, update the matching doc in the same PR.
