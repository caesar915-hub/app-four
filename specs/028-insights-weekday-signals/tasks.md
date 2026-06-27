# Tasks 028 — Insights Weekday Signal Strips

## Implementation Tasks

- [x] Create SpecKit files (spec.md, plan.md, tasks.md)
- [ ] Add `weekdayLabel: String?` to `SignalBead` + update `signalStrips` call
- [ ] Add `weekdaySignalStrips` computed property to `InsightsViewModel+Signals.swift`
- [ ] Update `SignalStripsView.swift` — HStack, glyphs, weekday labels, optional tap
- [ ] Update `InsightsView.swift` — subtitle + call site
- [ ] Write 6 unit tests in `InsightsViewModelTests.swift`
- [ ] Build passes
- [ ] All 6 tests green

## Unit Tests (write before implementation)

1. `weekdayStrips_groupsByWeekday` — recordings only on Monday → Mo slot has level, all others nil
2. `weekdayStrips_averagesRound` — levels 3+4 on Wednesday → avg 3.5 → rounds to 4
3. `weekdayStrips_averagesRoundDown` — levels 2+3 on Friday → avg 2.5 → rounds to 3
4. `weekdayStrips_emptyMonthAllNil` — no recordings → all 7 beads have `level == nil`
5. `weekdayStrips_slotOrder` — first bead label is "Mo", last is "Su"
6. `weekdayStrips_allThreeKinds` — produces 3 strips (mood/energy/focus)

## Owner Verification (device build)

- [ ] 3 strips × 7 slots, no scroll
- [ ] Correct glyphs (sprout/bolt/aperture) coloured by average level
- [ ] Mo–Su labels below each glyph
- [ ] Dashed placeholder for no-data weekdays
- [ ] Subtitle reads "Average by weekday — this month"
