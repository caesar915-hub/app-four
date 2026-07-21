# Insights Screen


_Last updated: 2026-06-28_
The Insights screen surfaces patterns from the user's check-ins through a vertically paging dashboard scoped to a selected month.

## Files

| File | Purpose |
|------|---------|
| `InsightsView.swift` | Paging scroll container, empty state, navigation |

## Supporting Components

Components used by this screen live in `Views/Insights/`:

| Component | Purpose |
|-----------|---------|
| `MonthSelectorScrollView.swift` | Horizontal month selector |
| `MoodBubbleChart.swift` | Mood distribution bubble chart |
| `MoodLegend.swift` | Mood chart legend |
| `SignalStripsView.swift` | Weekday signal strips |
| `SignalAverageGauges.swift` | Average signal gauges |
| `DailyRhythmMatrix.swift` | Time-of-day rhythm matrix |
| `ConnectionCardsView.swift` | Signal connection cards |
| `InsightsSectionHeader.swift` | Section title + subtitle |

## ViewModel

- [`InsightsViewModel`](../../../app-four/ViewModels/InsightsViewModel.swift)
- [`InsightsViewModel+Signals`](../../../app-four/ViewModels/InsightsViewModel%2BSignals.swift)

## Sections

The screen pages vertically through five full-viewport sections:

1. **Breakdown** — mood bubble chart and legend.
2. **Signals** — weekday signal strips for mood, energy, focus; sleep is deferred (shown as "Sleep · not tracked yet").
3. **Averages** — average signal gauges.
4. **Daily Rhythm** — dominant signal level by time of day.
5. **Connections** — pattern cards across signals.

## Connections Unlock Thresholds

The Connections section shows cards only when enough data exists:

- **Medication × Focus:** 4 medication days
- **Energy × Mood:** 5 high-energy days
- **Sleep × Mood:** 3 good-sleep days AND 3 poor-sleep days

## User Flows

### Change Month

1. User scrolls the month selector.
2. `currentMonth` updates.
3. All sections recompute from `monthRecordings`.

### Tab Switch

- Switching to the Insights tab resets the scroll to the first section (`.breakdown`).

### Empty State

If the selected month has no data, a prompt encourages the user to check in.

## Screen Container

`InsightsView` is wrapped in `ScreenContainer` without scrollable content (the internal paging scroll owns its own scroll) and with a `NavigationPath` for pushing detail.

## Key Behaviors

- Paging snaps one section per flick via `.scrollTargetBehavior(.paging)`.
- Section headers dim when not active (`activeSectionID`).
- Sleep tracking is deferred; a dashed chip explains it is not yet tracked.

## Related Specs

- Spec 006 — Signal glyphs
- Spec 014 — Daily card
