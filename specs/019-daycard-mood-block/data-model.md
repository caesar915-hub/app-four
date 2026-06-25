# Phase 1 Data Model — Day-card mood-block redesign

**No new persisted data. No schema change. CloudKit-compatibility posture (Principle IX) untouched.** This feature changes only how existing data is *drawn*. This document records the reused inputs and the new *presentation* constants (which are design tokens, not model state).

## Reused entities (read-only inputs — unchanged)

| Entity | Source | Used for | Change |
|---|---|---|---|
| `MoodLibraryViewModel.TimelineDay` | existing | the day (label, date, `nodes`) a card renders | none |
| `DayTimeline.Node` | existing | one check-in row (`time`, `recording`, `intakeDoses`, `rings`) | none — read; the bead/row re-arranges it |
| `Recording` | SwiftData `@Model` | `mood`, `energyLevel`, `focusLevel`, `moodColor`, chips | none |
| `DayCardSummary` | 014 (`Views/Components/DayCardSummary.swift`) | folded summary: representative `mood`, `energy`, `focus`, `mostRecentMedicationName` | none — reused as-is; now also supplies the **block tint mood** (R2) |
| `MoodLevel` | NoteExtraction enum (+ `MoodLevel+Palette`) | mood level 1–5 → colours/glyph | **EDIT (additive)**: new pure tint/word accessors (below); existing cases/`color`/`fill`/`deepFill`/`onColor` unchanged |
| `DayTimeline.Ring` | existing | medication-phase % per node | none — bead still draws it |

## New presentation tokens (design constants, not data)

These are added to `DesignSystem` / `MoodLevel+Palette`; they hold no runtime state and persist nothing.

| Token | Location | Value (intent, tunable) | Purpose |
|---|---|---|---|
| `Opacity.moodBlock` | `DesignSystem/Opacity.swift` | ~0.22 | header mood-tint block over `cardBackground` |
| `Opacity.moodBadge` | `DesignSystem/Opacity.swift` | ~0.50 | cream-disc badge fill |
| `Metrics.headerMoodBadge` | `DesignSystem/Metrics.swift` | ~42 | badge diameter (folded + strip header) |
| `MoodLevel.blockTint` *(or `DayCardPalette`)* | `Models/MoodLevel+Palette.swift` | `color.opacity(moodBlock)` | block background per level |
| `MoodLevel.badgeTint` | same | `color.opacity(moodBadge)` | badge disc per level |
| `MoodLevel.wordColor` | same | `deepFill` | mood-word colour on the tint |

> The mood-word/badge/block accessors are the **only new logic** and are covered test-first (`DayCardPaletteTests`, see research R7 / quickstart). They are pure functions of the `MoodLevel` case — no I/O, no async, no persistence.

## Removed

| Removed | Reason |
|---|---|
| `MoodBanner` (view) | superseded by the inline row head (R4); only caller was `TimelineRow` |
| Whole-card mood **wash** in `DayCard` (`averageFill.opacity(moodWash)`) | tint relocates to the header (R1) |
| **Time inside `TimelineBead`** | time moves inline into the row head (R4) |
| `Opacity.moodWash`, `Opacity.moodCircle`, `Metrics.headerMoodCircle` | retire **only if** no remaining caller (grep first; Principle III) |
