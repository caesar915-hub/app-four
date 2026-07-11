# Phase 1 — Data Model

**No schema change in this feature.** This remediation touches the view layer; the SwiftData model graph is unchanged. Recorded here only to document the one source-of-truth clarification.

## Affected entity

### `Recording` (existing `@Model`) — unchanged schema

- No attributes added, removed, or retyped. No relationships changed.
- The existing `summaryStatus` attribute becomes the **single source of truth** for the summary/processing state shown in the UI, replacing the duplicate in-memory `ProcessingViewModel.state` machine (which no view observed). This is a *consumption* change in the view-model layer, not a model change.
- Constitution IX (Pre-Release Data Posture) is unaffected: no new `@Attribute(.unique)`, no new required/non-defaulted attribute, CloudKit-compatibility preserved.

## State (UI-derived, not persisted-schema)

Summary/processing UI derives from `Recording.summaryStatus` transitions:

```
(none) → generating → ready
                    ↘ failed
```

`ProcessingViewModelTests` is retargeted to assert these transitions on the persisted recording rather than on the removed enum (see research.md R4).

## Removed types (dead — not entities)

`RecordingDetailViewModel.SummaryState`, `ProcessingViewModel.ProcessingState`, `LibraryViewModel`, and view structs `SummaryCard`/`TopicChip`/`TimelineDaySection` are deleted. None are persisted; none participate in the SwiftData graph. See [views-audit](../../docs/audits/2026-06-25-views-audit.md) for the full inventory.
