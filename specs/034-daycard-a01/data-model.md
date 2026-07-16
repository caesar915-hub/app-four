# Data Model + Render Contract — DayCard a01

No persisted schema changes. One derived summary field; the rest is view binding.

## Derived: `DayCardSummary.sleep`

- **Type**: `@MainActor var sleep: String?` (matches `Recording.sleepLabel`, which is `@MainActor`).
- **Rule**: the most recent captured sleep for the day. Nodes are newest-first (`DayTimelineBuilder`), so return the first node whose `recording?.sleepLabel` is non-nil.
- **Value**: the existing `Recording.sleepLabel` ("7h sleep" / "calm sleep"); `nil` when no check-in that day logged sleep.
- **No new storage**: reads existing `Recording.sleepHours` / `sleepQuality` / `decodedSleepEvent` via `sleepLabel`.

```
sleep: String? = day.nodes.lazy.compactMap { $0.recording?.sleepLabel }.first
```

### Test-first (Constitution X) — `FoldedDayCardHeaderTests`

- `sleepComesFromMostRecentRecording` — two nodes, both with sleep; newest wins.
- `sleepFallsBackToOlderNode` — newest node has no sleep, older does → older's value.
- `noSleepAnywhereYieldsNil` — no node logged sleep → `nil`.
- `sleepHoursFormatsWithoutDecimalWhenWhole` — 7.0h → "7h sleep" (guards the existing formatter through the new path).

These reference `DayCardSummary.sleep`, which does not exist yet → RED, then GREEN once the property lands.

## Render contract — Folded (`308:2122`)

| Element | Binds to |
|---|---|
| Card fill | `level.blockTint` (folded header fills the card) |
| Sprout | `SignalGlyph(.mood, level: level.numericValue, size: Metrics.dayHeaderGlyph, decorative: true)` |
| Mood word | `level.displayLabel`, `Typography.text(24,.bold,.title2)`, `level.wordColor` |
| Weekday | 3-letter uppercase from `day.date` (`"EEE"` → `.uppercased()`), caps-13, `inkPrimary`; middle "·" `inkSecondary` |
| Summary chips | energy (bolt+word, primary) · focus (aperture+word, primary) · med (capsule+`summary.mostRecentMedicationName`, `Palette.medication`) · sleep (bed glyph + `summary.sleep`, primary text) — 5px dot separators, wrapping |
| Trailing | `chevron.down`, `inkSecondary` |
| Empty day | existing calm copy, no tint (unchanged) |

## Render contract — Unfolded (`308:1957`)

**Collapsed band** (replaces the folded header when expanded):

| Element | Binds to |
|---|---|
| Band fill | `level.blockTint` |
| Label | "GREAT · MON" caps-13: word=`level.wordColor`, "·"=`inkSecondary`, weekday=`inkPrimary` |
| Trailing | `chevron.up` (rotation of the same chevron), `inkSecondary` |

**Entry row** (per check-in node, `TimelineRow` rebuilt):

| Element | Binds to |
|---|---|
| Disc | `Circle().fill(rowLevel.badgeTint)`, `Metrics.rowMoodDisc` (43), holding `SignalGlyph(.mood, level: rowLevel, size: 30, decorative: true)` |
| Mood word | `rowLevel.displayLabel`, `Typography.text(24,.bold,.title2)`, `rowLevel.wordColor` |
| Time | `node.time` "HH:mm" (`Typography.caption`/13 regular), `inkSecondary` |
| ⋯ affordance | `Circle().strokeBorder(inkSecondary, 1.5)`, `Metrics.moreAffordance` (30), `ellipsis` glyph inside, `inkSecondary` — decorative (whole row taps to detail) |
| Chip line | energy (bolt+word primary) · focus (aperture+word primary) · med names (capsule+name, `Palette.medication`, name only) · sleep (`recording.sleepLabel` text only, `Palette.sleepIndigo`) · feelings ("♥ "+joined, `inkSecondary`, cap 4+overflow) · side-effects (joined, `inkSecondary`, cap 4+overflow) — 5px dot separators, wrapping |
| Removed | `TimelineBead`, medication-phase ring, vertical connector column |
| Navigation | tap anywhere (incl. ⋯) → `onTapRecording(recording.id)` (unchanged) |

## Entities (read-only)

- `MoodLibraryViewModel.TimelineDay` — `date`, `label`, `nodes`. Weekday derived from `date`.
- `DayTimeline.Node` — `time`, `recording`, `intakeDoses`. Row mood = `MoodLevel(name: recording.mood)`.
- `Recording` — `mood`, `energyLevel`, `focusLevel`, `sleepLabel`, `feelings()`, `sideEffects()`.
