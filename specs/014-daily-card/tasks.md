---
description: "Task list for 014 Daily Card — Folded Summary, Opens to the Day"
---

# Tasks: Daily Card — Folded Summary, Opens to the Day

**Input**: Design documents from `specs/014-daily-card/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/)
**Branch**: `feat/daycard-update`

**Tests**: Test-first is **MANDATORY for logic** (pure state/derivation types, `@MainActor @Observable` view-models) per Constitution **Principle X** — write the test, run it, confirm **RED**, then implement to **GREEN**, then refactor. **SwiftUI views are EXEMPT** (verified by build + on-simulator run + the HTML mockups). `@AppStorage` preferences are view state and are **also exempt** (matching the existing `MedicationBar*` settings). Tests use **Swift Testing** (`@Test`/`#expect`).

**Organization**: Grouped by the 4 user stories from spec.md so each is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description with file path`

- **[P]** = parallelizable (different file, no dependency on an incomplete task)
- **[USx]** = the user story it serves (story phases only)

---

## Phase 1: Setup

- [X] T001 Confirm baseline build + full Swift Testing suite are GREEN on `feat/daycard-update` before any change, via `ios-debugger-agent` (XcodeBuildMCP), iPhone 17 sim, light + dark.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Additive design-system tokens that replace today's hardcoded literals (FR-018, tokens-only). Shared by US1/US2/US3. Plain constants → no tests.

**⚠️ No user-story work begins until this phase completes.**

- [X] T002 [P] Create `Opacity` enum (`moodWash = 0.16`, `deEmphasis = 0.34`) in app-four/DesignSystem/Opacity.swift
- [X] T003 [P] Add `Radius.chip = 15` to app-four/DesignSystem/Radius.swift
- [X] T004 [P] Add `Spacing.ringStroke = 3.3` to app-four/DesignSystem/Spacing.swift
- [X] T005 [P] Add `Metrics.timeBead = 54` and `Metrics.headerMoodCircle = 58` to app-four/DesignSystem/Metrics.swift

**Checkpoint**: Tokens exist; views reference them instead of literals.

---

## Phase 3: User Story 1 — Read a whole day at a glance (Priority: P1) 🎯 MVP

**Goal**: Each day renders **folded** — mood-glyph circle · weekday · one line `mood · energy · focus · medication-name` (logged signals only) — readable without tapping.

**Independent Test**: Render days with varied/partial signals; confirm each folded card reads mood/energy/focus/medication on one line with the mood circle, omits unlogged signals, and an empty day reads "No check-ins this day. That's alright."

### Tests for User Story 1 (test-first · RED — MANDATORY) ⚠️

> Write FIRST, run, confirm FAIL before implementing.

- [X] T006 [P] [US1] `FoldedDayCardHeaderTests` — summary content: omit unlogged signals/no placeholders (FR-002); multi-med day yields the **most-recent** check-in's med name only (FR-003); no-med day yields `nil`; empty day's summary is exactly `"No check-ins this day. That's alright."` (FR-004). File: app-fourTests/Views/FoldedDayCardHeaderTests.swift

### Implementation for User Story 1

- [X] T007 [US1] Create `FoldedDayCardHeader` (mood circle + weekday + `·`-joined summary; pure `mostRecentMedicationName = day.nodes.first { !$0.intakeDoses.isEmpty }?.intakeDoses.first?.name`; empty-state copy; `Typography.fraunces(18)` mood word + `relativeTo:` body; VoiceOver `.accessibilityElement(children: .combine)` reusing `signalAccessibilityLabel`; mood glyph `.accessibilityHidden(true)`) in app-four/Views/Components/FoldedDayCardHeader.swift — turns T006 GREEN
- [X] T008 [US1] Refactor `DayCard` to a constant header (uses `FoldedDayCardHeader`) with `isExpanded: Bool` + `onToggleExpand: () -> Void` inputs; replace `cornerRadius: 20`→`Radius.card`, fixed `.system(size:14,weight:.heavy)` weekday→a `relativeTo:` `Typography` token (FR-015), wash `0.16`→`Opacity.moodWash`; header `.frame(minHeight: Metrics.minTapTarget)` + `.contentShape(Rectangle())`; card draws **no selection accent border/outline** — selection is conveyed only by top-position + expansion (FR-012, FR-018, FR-015, WCAG 2.5.5) in app-four/Views/Components/DayCard.swift
- [X] T009 [US1] In `CalendarLibraryView.timelineList`, render `DayCard(day:isExpanded:false, onToggleExpand:{})` so the list shows folded cards (expand interaction arrives in US2); keep `ForEach(...).id(day.date)` in app-four/Views/Library/CalendarLibraryView.swift

**Checkpoint**: Folded read works end-to-end. MVP demoable.

---

## Phase 4: User Story 2 — Open a day to see its check-ins (Priority: P1)

**Goal**: A header tap toggles a card independently (multiple may be open); the summary collapses (shrink-on-open), revealing time-ordered check-ins — each a time-in-medication-phase-ring + % beneath, mood word, energy/focus glyphs, chips.

**Independent Test**: Tap a folded card → expands to check-in rows with phase rings; tap again → collapses; open two cards at once; Reduce Motion makes it instant.

### Tests for User Story 2 (test-first · RED — MANDATORY) ⚠️

- [X] T010 [P] [US2] `DayCardExpandStateTests` — pure `ExpandedDayCards.toggling(_:)`: toggling a date adds it; toggling again removes it; toggling date B leaves A untouched (multiple open) (FR-005). File: app-fourTests/Views/DayCardExpandStateTests.swift

### Implementation for User Story 2

- [X] T011 [US2] Create pure value type `ExpandedDayCards` wrapping `Set<Date>` with `func toggling(_ date: Date) -> ExpandedDayCards` and `func contains(_:) -> Bool` (start-of-day keys) in app-four/Views/Library/ExpandedDayCards.swift — turns T010 GREEN
- [X] T012 [US2] In `CalendarLibraryView`: add `@State private var expandedCards = ExpandedDayCards()`; header tap → `withAnimation(reduceMotion ? nil : Motion.smooth) { expandedCards = expandedCards.toggling(day.date) }`; pass `isExpanded: expandedCards.contains(day.date)` + `onToggleExpand` to each `DayCard` (`reduceMotion` already at L18) in app-four/Views/Library/CalendarLibraryView.swift
- [X] T013 [US2] In `DayCard`: when `isExpanded`, reveal `ForEach(day.nodes)` of `TimelineRow` below the constant header (summary line collapses); rotate `chevron.down` `.rotationEffect(.degrees(isExpanded ? 180 : 0))` within the parent animation gate (FR-005, FR-006, FR-008) in app-four/Views/Components/DayCard.swift
- [X] T014 [US2] Redesign the expanded check-in row: time inside the medication-phase ring with the `%` **beneath** as the redundant non-color readout (FR-020), reading `DayTimeline.Ring.progress` (computed via `MedicationEvent.effectProgress(at:)` — **never recompute**), then mood word + energy/focus `SignalGlyph`s + chips, rendering **only logged** signals/chips (no empty slots, FR-007); no-med node omits the ring; replace `TimelineBead` fixed `.system(size:14)`/`(size:10)` with `relativeTo:` tokens + `.monospacedDigit()`, ring stroke `4`→`Spacing.ringStroke`, diameters→`Metrics.timeBead`/`headerMoodCircle` (FR-006, FR-015, FR-018, FR-020) in app-four/Views/Components/TimelineRow.swift and app-four/Views/Components/TimelineBead.swift

**Checkpoint**: US1 + US2 work — read folded, tap to open redesigned check-ins, multiple open, Reduce Motion honored.

---

## Phase 5: User Story 3 — Focus a date by selecting it (Priority: P2)

**Goal**: Selecting a calendar date moves that day to the top, removes more-recent days from the **list**, greys more-recent days in the **week-row** (opacity + a second cue), and auto-expands the selected day (a user setting, default ON). Today loses its calendar ring.

**Independent Test**: Select several dates; confirm each jumps to top + auto-expands, more-recent days vanish from the list and grey (with a non-color cue) in the row, older days remain below, re-selecting the same date is idempotent, today shows only the "Today" pill, and toggling auto-expand OFF makes selection scroll-without-opening.

> **Settings mechanism**: the auto-expand preference is `@AppStorage("autoExpandOnSelection")` (default `true`), matching the existing `MedicationBar*` toggles ([MedicationBarSettingsSection.swift](app-four/Views/Settings/MedicationBarSettingsSection.swift) writes, [MedicationBarView.swift](app-four/Views/Components/MedicationBarView.swift) reads). **No** `AppSettings` schema change, **no** `SettingsViewModel` change (avoids the disabled-suite dependency and keeps the pre-release schema untouched — Principle IX/IV).

### Tests for User Story 3 (test-first · RED — MANDATORY) ⚠️

- [X] T015 [P] [US3] Extend `MoodLibraryViewModelTests` for `timelineDaysFilteredToSelectedDate(_:)`: returns only days `<= selected`; `selected` is first; days `> selected` excluded; days `< selected` retained; order stays newest-first (FR-010, FR-009, FR-016). File: app-fourTests/ViewModels/MoodLibraryViewModelTests.swift
- [X] T016 [P] [US3] Extend `DayCardExpandStateTests` for `ExpandedDayCards.selecting(_:autoExpand:)`: clears all then inserts `[selected]` when `autoExpand` true, `[]` when false; re-selecting the already-sole member is idempotent (FR-009, FR-019). File: app-fourTests/Views/DayCardExpandStateTests.swift

### Implementation for User Story 3

- [X] T017 [US3] Add pure `func timelineDaysFilteredToSelectedDate(_ selectedDate: Date) -> [TimelineDay]` to `MoodLibraryViewModel` (existing month filter **plus** `startOfDay(day.date) <= startOfDay(selectedDate)`; newest-first; no new `@Observable` property) in app-four/ViewModels/MoodLibraryViewModel.swift — turns T015 GREEN
- [X] T018 [US3] Extend `ExpandedDayCards` with `func selecting(_ date: Date, autoExpand: Bool) -> ExpandedDayCards` (remove all, then insert `date` iff `autoExpand`) in app-four/Views/Library/ExpandedDayCards.swift — turns T016 GREEN
- [X] T019 [P] [US3] Add a user-controllable "Auto-expand selected day" toggle bound to `@AppStorage("autoExpandOnSelection") var autoExpandOnSelection = true` in a new Settings section app-four/Views/Settings/DayCardSettingsSection.swift (mirror `MedicationBarSettingsSection`), and add it to app-four/Views/SettingsView.swift (FR-019)
- [X] T020 [US3] In `CalendarLibraryView`: render `ForEach(viewModel.timelineDaysFilteredToSelectedDate(selectedDay))`; add `@AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true`; in `selectDay`/`scrollList` (inside the existing `withAnimation(reduceMotion ? nil : Motion.smooth)`) set `expandedCards = expandedCards.selecting(target, autoExpand: autoExpandOnSelection)`; keep idempotent re-select (FR-009, FR-010, FR-019) in app-four/Views/Library/CalendarLibraryView.swift
- [X] T021 [US3] `CalendarDayCell`: delete the `else if cell.isToday { Circle().strokeBorder(...) }` ring branch and drop `cell.isToday` from the bold-weight rule (FR-013); add `isAboveSelection: Bool` input → `Opacity.deEmphasis` on number+marker **plus** `.regular` weight **and** suppress the mood marker dot (render `Color.clear`) as the non-color cue (FR-011, FR-014) in app-four/Views/Components/CalendarDayCell.swift
- [X] T022 [US3] Compute `isAboveSelection` (`cell.date > selectedDay && cell.date <= today`) per cell and pass it into `CalendarDayCell` in app-four/Views/Library/CalendarLibraryView.swift (and/or app-four/Views/Components/CalendarHeaderView.swift)

**Checkpoint**: US1 + US2 + US3 work — selection focuses a day, filters the list, greys the row, auto-expands per setting, no today-ring.

---

## Phase 6: User Story 4 — Read without color or with large text (Priority: P3)

**Goal**: Every signal and all card text remain legible in greyscale, at the largest Dynamic Type, and via VoiceOver; Reduce Motion is honored; layout order stays stable. (Much is wired in US1–US3; this phase verifies and closes gaps. Views are unit-test-exempt — verified on device.)

**Independent Test**: View the screen desaturated and at the largest standard Dynamic Type; confirm every signal is distinguishable and no text clips; VoiceOver reads a folded card as one element and exposes rows when open.

- [X] T023 [US4] Audit that every card/row text token is `relativeTo:`-based (Dynamic Type) across `DayCard`, `FoldedDayCardHeader`, `TimelineRow`, `TimelineBead`; fix any remaining fixed `.system(size:)` (FR-015) — files above
- [ ] T024 [US4] Verify on sim: VoiceOver folded card = one combined element with a spoken signal summary, expanded rows individually focusable, mood glyph decorative (FR-017)
- [ ] T025 [US4] Verify on sim: greyscale (Color Filters) — every signal level + the greyed week-row days + the med-phase ring (% readout) stay distinguishable (FR-014, FR-011, FR-020); Reduce Motion makes fold/scroll instant; and the medication-bar · calendar · list order does not reshuffle across data states (FR-016, SC-008)
- [X] T026 [US4] Verify on sim at the largest standard Dynamic Type size: weekday, summary line, mood words, times, % remain legible/non-clipped (FR-015, SC-005)

**Checkpoint**: All four stories complete and accessible.

---

## Phase 7: Polish & Cross-Cutting

- [X] T027 Token-grep the changed views for raw literals (corner radii, font sizes, paddings, opacities, colors) — confirm zero ad-hoc values remain (FR-018), matching the 008 "no literals" bar
- [ ] T028 Run [quickstart.md](quickstart.md) validation scenarios end-to-end on the sim, **light + dark**
- [X] T029 Build + full Swift Testing suite GREEN on `feat/daycard-update` (Principle II); confirm the new logic tests pass and nothing regressed
- [X] T030 [P] Log the 014 build to docs/DEVLOG.md (the why + verification result); move the backlog row to 🔨 In code
- [ ] T031 Open PR for `feat/daycard-update`; run `/code-review` on the diff before merge (Principle V)

---

## Dependencies & Execution Order

### Phase order
- **Setup (P1)** → **Foundational (P2, tokens)** blocks all stories → **US1 (P3)** → **US2 (P4)** → **US3 (P5)** → **US4 (P6)** → **Polish (P7)**.
- US2 depends on US1's `DayCard`/`onToggleExpand` shape; US3 depends on US2's `ExpandedDayCards` + the expand wiring; US4 verifies US1–US3.

### Within each story
- Tests (RED) **before** implementation (GREEN), then refactor (Principle X).
- Pure types/methods (`ExpandedDayCards`, `timelineDaysFilteredToSelectedDate`, `mostRecentMedicationName`) before the views that consume them.

### Parallel opportunities
- **Foundational**: T002–T005 all [P] (separate token files).
- **US1**: T006 alone before T007–T009 (sequential — shared `DayCard`/list files).
- **US2**: T010 before T011; T012–T014 sequential where files overlap.
- **US3**: tests T015/T016 [P] (different files); impl T017 (VM), T018 (state), T019 (Settings) are [P] across their files; then T020/T022 (CalendarLibraryView) sequential; T021 (CalendarDayCell) [P] with the VM/state/Settings work.

### Parallel example — US3
```text
# RED together (different files):
T015 MoodLibraryViewModelTests · T016 DayCardExpandStateTests
# Then GREEN across different files in parallel:
T017 MoodLibraryViewModel · T018 ExpandedDayCards · T019 DayCardSettingsSection · T021 CalendarDayCell
# Then sequential (same file): T020 → T022 in CalendarLibraryView
```

---

## Implementation Strategy

- **MVP = US1**: Setup → Foundational → US1, then STOP and validate the folded read on the sim. Demoable on its own.
- **Incremental**: add US2 (open/shrink) → US3 (selection/filter/auto-expand) → US4 (a11y verification), each independently testable, `main` releasable after each merge.
- **Test-first gate**: never write an implementation task ahead of its RED test (Principle X). The three logic units (filter, the `ExpandedDayCards` state machine, most-recent-med) are the test-first core; SwiftUI views + the `@AppStorage` preference are verified by build + sim + the HTML mockups.

---

## Requirement coverage

- **FR-001/002/003/004** → US1 (T006–T009). **FR-005/006/007/008/020** → US2 (T010–T014). **FR-009/010/011/012/013/019** → US3 (T015–T022) [FR-012 in T008]. **FR-014/015/016/017/018** → spread across US1–US3 and verified in US4 (T023–T026; FR-016/SC-008 in T025).
- **SC-001..008** → exercised by the per-story Independent Tests + the quickstart pass (T028).

## Notes

- [P] = different files, no incomplete-task dependency.
- Verify each logic test FAILS (RED) before implementing it (Principle X); commit after each task or logical group.
- The list filters more-recent days **out** (FR-010); the calendar row greys them **in place** (FR-011) — two surfaces, two rules; do not conflate.
- Never recompute the medication-phase `%` in the view — read `DayTimeline.Ring.progress` (Principle IV; avoids drift from the med bar).
- Auto-expand uses `@AppStorage` (not `AppSettings`/`SettingsViewModel`), matching the codebase's `MedicationBar*` toggle pattern — no schema change, no dependency on the currently-disabled `SettingsViewModelTests`.
