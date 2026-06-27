# Plan 028 — Insights Weekday Signal Strips

## Files to Modify

### 1. `app-four/ViewModels/InsightsViewModel+Signals.swift`

**Add `weekdayLabel: String?` to `SignalBead`** (nil for date-keyed beads — backward compat):

```swift
struct SignalBead {
    let date: Date
    let level: (any SignalLevel)?
    let recordingID: UUID?
    let weekdayLabel: String?
}
```

Update the existing `signalStrips` init call to pass `weekdayLabel: nil`.

**Add `weekdaySignalStrips` computed property** (after `signalStrips`):
- Slot order: `[(2,"Mo"),(3,"Tu"),(4,"We"),(5,"Th"),(6,"Fr"),(7,"Sa"),(1,"Su")]`
- Groups `monthRecordings` by `calendar.component(.weekday, from:)`
- For each slot: arithmetic mean of numericValues → `Int(avg.rounded())` → `resolvedLevel(kind:numericValue:)`
- Empty slot → `level: nil`
- Uses `Date(timeIntervalSinceReferenceDate: Double(weekday))` as a synthetic unique ID date
- Reuses existing private helpers: `signalLevel(for:from:)`, `resolvedLevel(kind:numericValue:)`, `stripSummary(kind:)`

### 2. `app-four/Views/Insights/SignalStripsView.swift`

- `let onBeadTap: (Date) -> Void` → `var onBeadTap: ((Date) -> Void)? = nil`
- Replace `ScrollView + LazyHStack` with `HStack(spacing: 0)`
- Each `BeadButton` gets `.frame(maxWidth: .infinity, minHeight: 44)`
- `BeadButton` takes `glyphSignal: GlyphSignal` and `action: (() -> Void)?`
- Bead content: `SignalGlyph(glyphSignal, level: bead.level?.numericValue, size: 28, decorative: true)` — handles empty via built-in `EmptySignalGlyph`
- `VStack(spacing: Spacing.xs)` with optional weekday label below: `Typography.text(9, weight: .medium)`, `Theme.textSecondary`
- `Button` wrapper only when `action != nil`
- A11y: weekday bead → `"Mo: Good"` / `"Mo: no data"`; date bead → existing date-label format

### 3. `app-four/Views/InsightsView.swift`

In `signalsSection`:
- Subtitle: `"Average by weekday — this month"`
- `SignalStripsView(strips: viewModel.weekdaySignalStrips)` (no closure)

## Weekday Averaging Logic

```
byWeekday = group monthRecordings by calendar.component(.weekday, from: createdAt)
for each (weekday, label) in [(2,"Mo")...(1,"Su")]:
    recs = byWeekday[weekday] ?? []
    values = recs.compactMap { signalLevel(for: kind, from: $0)?.numericValue }
    level = values.isEmpty ? nil : resolvedLevel(kind: kind, numericValue: Int(mean(values).rounded()))
```

`Double.rounded()` uses `.toNearestOrAwayFromZero` — 2.5 → 3, 3.5 → 4. Tests must verify this.

## Tests

See `tasks.md` for the 6 required unit tests. Tests are written before implementation (Constitution X).
