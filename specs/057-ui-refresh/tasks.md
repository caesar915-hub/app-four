# Tasks: UI Refresh from the Pencil design (057)

**Input**: Design documents from `/specs/057-ui-refresh/` and `shipaton_plan/UI_REFRESH_PLAN.md` (step IDs `UI-xx` are the stable ticket IDs; task IDs below map onto them).

**Prerequisites**: plan.md, spec.md, `DESIGN.md`, `research/`.

**Tests**: Test-first is MANDATORY for logic (view-models, pure helpers) per Constitution **Principle X** — RED → GREEN → refactor. SwiftUI views are EXEMPT (build + simulator + screenshot pack). Tests use Swift Testing.

## Format for Each Task
`- [ ] T### [P?] [UI-xx] Description — files`. `[P]` = parallelisable. `[x]` = done and green on the full serial suite.

## Phase 1: Setup (docs — UI-01…UI-05)
- [x] T001 [UI-01] DESIGN.md rewritten from the pen; research pack + exports committed — `DESIGN.md`, `specs/057-ui-refresh/research/`, `docs/design/pen/`
- [x] T002 [UI-02] Decisions recorded (all recommendations accepted) — `shipaton_plan/DEVLOG.md`, `DESIGN.md` §16
- [x] T003 [UI-03] Epic UI ticket table + backlog rows — `shipaton_plan/SEPTEMBER_PLAN.md`, `shipaton_plan/BACKLOG.md`
- [ ] T004 [UI-04] Pre-flight chain (owner-gated: merge #44/#45, resolve #41, 055 + 1.1, archive 053/054, Oct 1 ritual, re-cut) — git state
- [x] T005 [UI-05] Spec Kit 057 documents — this directory
- [x] T006 [UI-05b] Constitution I waiver recorded instead of the design-system mockup — `plan.md` Complexity Tracking

## Phase 2: Foundational (Phase B — blocking for every screen)
- [x] T010 [UI-06] Colour tokens, ramps, dark pairs, aliases — `Tokens/*.swift`, `NewLook.swift`, `Theme.swift`, `Palette*.swift`, `MoodLevel+Palette.swift`
- [x] T011 [UI-06] `TokenContrastTests` (AA in light + dark) — `app-fourTests/DesignSystem/TokenContrastTests.swift`
- [x] T012 [UI-06] Pinned palette tests re-baselined — `DayCardPaletteTests`, `RecordingMoodDisplayTests`
- [x] T013 [UI-07] Typography roles + alias map — `Typography.swift`
- [x] T014 [UI-08] Layout tokens, `CardStyle`, `HairlineDivider`, `SectionHeading`, `PageTitleBlock` — `Spacing/Radius/Metrics.swift`, `Components/*`
- [x] T015 [UI-09] Button styles — `Buttons.swift`
- [x] T016 [UI-10] `BillChip`, `ChipRow`, `ChipButton`, `FlowLayout` (moved) — `Components/BillChip.swift`, `Components/FlowLayout.swift`
- [x] T017 [UI-11] `NavPill`/`NavHeader`, `ToggleRow`, `RadioRow`, `SegmentedPicker`, `InfoRow` — `Components/*`
- [x] T018 [UI-17] Icon map — `Icons.swift`
- [x] T019 [UI-12] Glyph art + SVG path parser; sprout / bolt / target redrawn; `IdentityIcon` — `Glyphs/*`, `Components/IdentityIcon.swift`
- [x] T020 [UI-13] RED → GREEN: sleep names + ramp (`SignalGlyphTests`); `MoonGlyph`; `SleepLevel: SignalLevel` — `SignalLevel.swift`, `GlyphSignal.swift`
- [x] T021 [UI-14] `MedicationBadge`, `ProgressTrack`, `SignalMiniBar`, `MedicationPill`, capsule restyle — `Components/MedicationBadge.swift`, `Glyphs/CapsuleGlyph.swift`
- [x] T022 [UI-15] `CheckInRing` — `Components/CheckInRing.swift`
- [x] T023 [UI-16] `LevelTilePicker` — `Components/LevelTilePicker.swift`
- [x] T024 [UI-18] `FloatingTabBar`, `AddButton`, `FloatingChrome`, `HidesFloatingChromeKey`; `RootTabView` + `ScreenContainer` chrome-less roots — `Components/FloatingTabBar.swift`, `Components/ChromeVisibility.swift`, `app-four/Views/RootTabView.swift`, `app-four/DesignSystem/ScreenContainer.swift`
- [ ] T025 [UI-19] SandboxApp design gallery re-pointed at the atoms (deferred to the PR)

**Checkpoint**: foundations built; 552 tests green (2026-09-28).

## Phase 3: User Story 1 — check-in trio (UI-20…UI-23, UI-34) 🎯 wave 1
### Tests (RED first)
- [ ] T030 [UI-34] `flowProgressPerState` (idle ⅓ · recording/processing ⅔ · done 1) — `CheckInViewModelTests`
- [ ] T031 [UI-22] `ingestAudioLevelStoresLevel` (the ring glow source) — `CheckInViewModelTests`
### Implementation
- [ ] T032 [UI-34] `CheckInViewModel.flowProgress`, `audioLevel`; delete the never-assigned `.paused` case — `CheckInViewModel.swift`, `Models/AppEnums.swift`
- [ ] T033 [UI-21] Hub (A): header, ring ⅓ + Speak / Log medications / Write notes, caption; hint flag retired (FR-018) — `Views/CheckIn/CheckInView.swift`
- [ ] T034 [UI-22] Listening (B): prompt card + dots + hairline progress, ring ⅔ + timer + Stop & save / Cancel, cap cue swap, save-failed recovery, level glow — same file
- [ ] T035 [UI-23] Saved (C): ring 211 + check tile, title, subtitle, "Go back home", settle (Reduce Motion gated) — same file
- [ ] T036 [UI-15] `WelcomeView` uses `CheckInRing`; `CrescentRing.swift` and retired `Metrics.CheckIn.*` / `Typography.timer` / `Opacity.deEmphasis` deleted — `Views/Onboarding/WelcomeView.swift`

## Phase 4: User Story 2 — Calendar / Mood Journal (UI-24, UI-25, UI-35…37) wave 1
### Tests (RED first)
- [ ] T040 [UI-35] `DoseStatus` thresholds + boundaries — `MedicationBarViewModelTests`
- [ ] T041 [UI-36] `DayCardSummary.mostRecentMedicationDose` / `sleepLevel` — `FoldedDayCardHeaderTests`
### Implementation
- [ ] T042 [UI-35] `MedicationBarViewModel.DoseDisplay.status` — `ViewModels/MedicationBarViewModel.swift`
- [ ] T043 [UI-25] Medication bar restyle, month header + week strip, expanded day card, previous-day cards, `•••` menu, empty state, bottom inset — `Views/Library/*`, `Views/Components/{CalendarHeaderView,CalendarDayCell,DayCard,FoldedDayCardHeader,DayCardSummary,TimelineRow,MedicationBarView}.swift`
- [ ] T044 [UI-25] Delete the private `DoseTrack` / `Chip` duplicates before the package types enter their files

## Phase 5: secondary surfaces wave 1 (UI-33a)
- [ ] T050 [UI-33a] `MedicationLogSheet`, `TextCheckInComposer` (`LevelTilePicker` replaces `GlyphRampPicker`, which is deleted), onboarding restyle — `Views/Components/MedicationLogSheet.swift`, `Views/CheckIn/TextCheckInComposer.swift`, `Views/Onboarding/*`

## Phase 6: wave-1 gates (UI-53, UI-50)
- [ ] T060 [UI-53] Light/dark + AX + VoiceOver mini-pass on the four wave-1 screens; screenshot pack — attached to the PR
- [ ] T061 [UI-50] PR: build + serial suite, `/code-review` findings addressed, owner device QA (owner), merge (owner)

## Phase 7: User Stories 3–5 — wave 2 (UI-26…UI-33b, UI-38…UI-42, UI-44…UI-49, UI-52)
- [ ] T070 [UI-27] Day Details (tests first: `relativeTitleByDay`) — `Views/RecordingDetailView.swift`, `ViewModels/RecordingDetailViewModel.swift`
- [ ] T071 [UI-28] Edit Check-In (tests first: `isDirtyTracksEveryField`, `medicationRowsGroupByName`) — `Views/ExtractionReviewView.swift`, `ViewModels/ExtractionReviewViewModel.swift`
- [ ] T072 [UI-40] `fix/insights-sleep-mood-gate` (own PR, tests first) — `ViewModels/InsightsViewModel+Signals.swift`
- [ ] T073 [UI-30] Insights (tests first: bubble diameter, rhythm tint, range span) — `Views/InsightsView.swift`, `Views/Insights/*`
- [ ] T074 [UI-32] Settings + the eight must-keep rows (after 055 is merged into the branch; tests first: `titleLineVariants`) — `Views/SettingsView.swift`, `Views/Settings/*`
- [ ] T075 [UI-33b] Secondary surfaces wave 2 — `Views/Paywall/*` (except `RevenueCatPaywallHost`), `JournalExportSection`, `AcknowledgementsView`
- [ ] T076 [UI-44…UI-49] Dead code, dark/AX/VoiceOver passes, copy sweep, alias deletion (close both Complexity Tracking rows)

## Dependencies & Execution Order
Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 (wave-1 PR) → Phase 7 in the listed order. Within a story: tests → implementation → build + serial suite → commit.
