<!-- Created: 2026-07-16 18:55 (WEST) · Updated: 2026-07-16 19:20 (WEST) -->
# Tasks: New Look Check-in + Insights Re-skin (a04–a07)

**Input**: [spec.md](spec.md) · [plan.md](plan.md). Tests: gauge-level change is test-first (Constitution X); re-skin is view-exempt (owner device QA, no simulator).

## Phase 1: Foundational

- [X] T001 Add `NewLook.selectionSoft` (light `#96C19F`, dark derived, doc-commented ring-gradient-end scope) in `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift`; bump `Metrics.CheckIn.promptBarHeight` 3→4 in `Metrics.swift`.
- [X] T002 RED — add gauge-level test to `app-fourTests/ViewModels/InsightsViewModelTests.swift`: `SignalAverage.level` equals the ordinal the `fillLabel` word encodes (boundary avg case). Fails to compile (no `level` field).
- [X] T003 GREEN — `level: Int` on `SignalAverage`, computed in `InsightsViewModel+Signals.swift` (`signalAverages`); suite green.

## Phase 2: US1 — CheckIn a04–a06

- [X] T004 [US1] `app-four/Views/CheckIn/CrescentRing.swift`: gradient stops → `selection`/`selectionSoft`/`selection`; geometry + RM gates untouched.
- [X] T005 [US1] `app-four/Views/CheckIn/CheckInView.swift`: hub pills (white card capsules + shadow; speak = selection/onSelection), prompt card wrap + selection accents + Title-24 type, saved disc/Done → selection (local full-width capsule style; `.primary` untouched), recovery Try-again → ink/onInk capsule. All animation gates preserved.
- [X] T006 [US1] Grep gate: zero `Theme.meadow`/`Theme.accent` in `app-four/Views/CheckIn/`; `swiftc -parse` both files.

## Phase 3: US2 — Insights a07

- [X] T007 [US2] `app-four/Views/InsightsView.swift`: delete paging machinery (page/scrollTarget/paging/scrollPosition/activeSectionID/headerOpacity/tab-reset); continuous `ScrollView` + `VStack` with title block, month chips, carded sections, connections block; keep edge fade, navigationDestination, empty state, `.trackScreen`.
- [X] T008 [US2] Chips: `MonthSelectorScrollView.swift` → `newLookChip` grammar; `MoodLegend.swift` → white hairline capsules with dot + label + (count).
- [X] T009 [US2] `SignalAverageGauges.swift`: consume `average.level` (delete both `Int(fraction*5)` re-derivations); visual parity otherwise.
- [X] T010 [US2] `ConnectionCardsView.swift`: MiniBar fill → `Palette.medication`; gated card gains flat `NewLook.card` fill under dashed hairline.
- [X] T011 [US2] Dead code: delete `selectedDay` + sheet wiring + `calendarDay(for:)` (`InsightsViewModel.swift`), `DayDetailSheet.swift` (git rm), `onBeadTap` (`SignalStripsView.swift`); delete `InsightsSectionHeader.swift` if unreferenced after T007. Grep gates: zero refs; zero `Theme.accent` in `Insights/`.
- [X] T012 [US2] `swiftc -parse` all touched files; full-repo grep SC-002.

## Phase 4: Polish & gates

- [ ] T013 Docs: DEVLOG entry, BACKLOG (💡/📐→🔨), quickstart.md device-QA checklist (below), WORKLOG regen.
- [ ] T014 (OWNER GATE) Device QA vs a04–a07 (light+dark, RM, AX sizes, VoiceOver): check-in all states incl. recovery + auto-start; Insights continuous scroll + every section + month switch + connections; med bar identical everywhere.
- [ ] T015 Adversarial review of the full diff → fix confirmed findings → PR (stacked); retarget after the tower merges.

## Dependencies
T001→(T002→T003)→{T004,T005}→T006; T003→T007→{T008,T009,T010,T011}→T012→T013→T014→T015. US1 ∥ US2 after Phase 1.
