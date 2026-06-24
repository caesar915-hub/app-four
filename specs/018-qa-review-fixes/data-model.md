# Phase 1 Data Model: QA fixes (018)

**No data-model changes.**

All three fixes (A1 calendar dot, A2 med-bar scroll fade, A3 Log-Dose colour) are SwiftUI view/styling changes. This feature:

- adds, removes, and migrates **no** SwiftData `@Model` types or attributes;
- changes **no** persisted value (`UserDefaults`, `@AppStorage`, SwiftData);
- introduces **no** new entity, service, or view-model state.

The schema and CloudKit-compatibility posture (Constitution IX) are untouched (spec FR-015).

### Entities consumed read-only (unchanged)

| Entity | Used by | Change |
|--------|---------|--------|
| `CalendarMonthModel.DayCell` (`marker`: `.mood`/`.neutral`/`.none`, `isFuture`, `isInMonth`) | A1 — `CalendarDayCell` reads `cell.marker` to render the dot | none — only the *rendering* of the existing `marker` changes (above-selection days no longer suppressed) |
| Medication bar view-model state (phase/name) | A2 — bar height is *measured*, its content unchanged | none |
| `MedicationCatalogEntry` (doseOptions/onset/duration) | A3 — Log-Dose sheet styling only | none |

No state transitions, validation rules, or relationships are added or modified.
