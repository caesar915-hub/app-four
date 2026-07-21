# Library (Calendar) Screen


_Last updated: 2026-06-28_
The Library screen combines a collapsible calendar with a day-grouped timeline. It is the main place to browse past check-ins and medication doses.

## Files

| File | Purpose |
|------|---------|
| `CalendarLibraryView.swift` | Calendar + timeline container, navigation, empty state |

## ViewModel & Models

- [`MoodLibraryViewModel`](../../../app-four/ViewModels/MoodLibraryViewModel.swift) — month-scoped data for calendar and timeline
- [`CalendarMonthModel`](../../../app-four/ViewModels/CalendarMonthModel.swift) — value-type calendar grid
- [`DayTimeline`](../../../app-four/ViewModels/DayTimeline.swift) / [`DayTimelineBuilder`](../../../app-four/ViewModels/DayTimeline.swift) — timeline node builder

## User Flows

### Browse by Day

1. Calendar shows the current month; days with entries are tinted.
2. Tapping a day scrolls the timeline to that day and expands its card.
3. Out-of-month taps page the calendar to the target month first.

### Browse by Month

1. User expands the calendar header to month view.
2. Paging is bounded by the earliest month with data and the current month.
3. After paging, the timeline jumps to the newest day in the new month.

### Open Detail

1. Tapping a recording row appends its `id` to the `NavigationPath`.
2. `RecordingDetailView` is pushed.

### Tab Switch

- Switching to the Calendar tab pops any pushed detail and jumps to today.

### Empty State

If no entries exist, a `ContentUnavailableView` prompts the user to record.

## Screen Container

`CalendarLibraryView` is wrapped in `ScreenContainer` with the medication bar overlay and owns a `NavigationPath` bound to `ScreenContainer` for pushing detail.

## Key Behaviors

- Timeline is filtered to the selected date and older; future days are never shown.
- Calendar week-row is not filtered; future days are greyed in place.
- Card expansion is controlled by `ExpandedDayCards` view state.
- `autoExpandOnSelection` and `alwaysExpandCards` are user preferences stored in `@AppStorage`.

## Supporting Components

Components used by this screen live in `Views/Components/`:

| Component | Purpose |
|-----------|---------|
| `CalendarHeaderView.swift` | Week/month calendar header |
| `CalendarDayCell.swift` | Individual day cell |
| `DayCard.swift` | Folding card for one day's entries |
| `FoldedDayCardHeader.swift` | Day card header with mood tint |
| `TimelineRow.swift` | Single recording/dose row inside a day card |
| `TimelineBead.swift` | Timeline connector bead |

## Related Specs

- Spec 001 — Calendar header scroll fade
- Spec 019 — Day card mood block (`specs/019-daycard-mood-block/`)
