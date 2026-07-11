# Tasks: View-Layer Audit Remediation

**Input**: Design documents from `specs/022-view-audit-remediation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/visual-behaviors.md, quickstart.md

**Tests**: Test-first is MANDATORY for logic (view-models, services) per Constitution **Principle X** — write the test, RUN it, confirm **RED**, then implement to **GREEN**, then refactor. SwiftUI **views are EXEMPT** (verified by build + on-simulator/`RenderPreview` run). Tests use **Swift Testing** (`@Test`/`#expect`).

**Line numbers** in tasks are hints from the audit (taken against the pre-fix tree); re-locate by symbol after the `feat/spm-designsystem` WIP is resolved, as lines may shift.

> **BLOCKED until WIP resolved.** Do not start Phase 1+ until the in-flight `feat/spm-designsystem` uncommitted changes are committed/stashed and `fix/022-view-audit-remediation` is branched off a clean base, AND `.specify/feature.json` is repointed to `specs/022-view-audit-remediation` (it was reset to 021 by a concurrent workstream).

## Phase 1: Setup

- [ ] T001 Confirm clean working tree on `fix/022-view-audit-remediation`; repoint `.specify/feature.json` to `specs/022-view-audit-remediation`
- [ ] T002 Create `app-four/Extensions/` group/folder for relocated shared utilities (used by T040)
- [ ] T003 Baseline: run `mcp__xcode__BuildProject` + `RunAllTests` (tab `windowtab1`) and record green baseline before any change

---

## Phase 2: Foundational

**No blocking foundational work** — the six stories are independent. Proceed to Phase 3. (Dead-code removal order within US4 is handled inside that phase.)

---

## Phase 3: User Story 1 — Detail toolbar parity (Priority: P1) 🎯 MVP

**Goal**: Date title + Delete appear when a check-in is opened from the Calendar tab, matching Insights.
**Independent Test**: Open a check-in from Calendar → date title + working Delete; identical to Insights; no double nav bar.

### Implementation (SwiftUI view — exempt from unit-test-first; verified by build + sim run)

- [ ] T004 [US1] Wrap the sheet content in `NavigationStack` at the Calendar call site — `.sheet(item: $detailRef) { NavigationStack { RecordingDetailView(...) } }` in `app-four/Views/Library/CalendarLibraryView.swift` (~L37)
- [ ] T005 [US1] Confirm `RecordingDetailView` does NOT add its own `NavigationStack` (avoid double-nesting on the Insights push path) in `app-four/Views/RecordingDetailView.swift`
- [ ] T006 [US1] Verify on simulator: open from Calendar → date `.principal` + Delete `.topBarTrailing` present and Delete works; open from Insights → identical; delete-out-from-under guard still holds (quickstart US1)

**Checkpoint**: `BuildProject` + `RunAllTests` green; US1 demoable.

---

## Phase 4: User Story 2 — AX5 chip legibility (Priority: P1)

**Goal**: Mood/sleep/medication chip labels scale to AX5 without clipping.
**Independent Test**: `RenderPreview` `TimelineChip` at Dynamic Type AX5 → labels large + unclipped; default unchanged.

### Implementation (SwiftUI view — exempt)

- [ ] T007 [US2] Replace `.font(.system(size: 12, weight: .medium))` with `Typography.label` in `app-four/Views/Components/TimelineChip.swift` (~L25)
- [ ] T008 [US2] Ensure the chip row adapts at AX5 (allow wrapping / vertical growth; no `minimumScaleFactor` hack) in `TimelineChip.swift` and its container `app-four/Views/Components/TimelineRow.swift`
- [ ] T009 [US2] Verify via `RenderPreview` (Dynamic Type override **AX 5**): labels scale, "Taken Concerta 36mg" not clipped; default-size render pixel-unchanged

**Checkpoint**: Build green; AX5 capture compared to pre-fix design-review shot.

---

## Phase 5: User Story 3 — Debug-in-Release fence (Priority: P2)

**Goal**: No internal test/diagnostic screen compiled into or reachable in Release; Done dismisses.
**Independent Test**: Release build → no `Test*` compiled; Debug → diagnostics work + Done dismisses.

### Implementation

- [ ] T010 [US3] Determine the active compilation condition: check build settings for `TESTFLIGHT`; use `#if DEBUG || TESTFLIGHT` if defined, else `#if DEBUG` (match the existing 5-tap trigger gate in `app-four/Views/SettingsView.swift` ~L247-249)
- [ ] T011 [US3] Grep-verify zero refs, then delete `app-four/Views/TestSchemaView.swift`
- [ ] T012 [US3] Fence the `.sheet(isPresented: $showingDebug) { TestServicesView() }` presentation AND the `showingDebug` `@State` behind the chosen `#if` in `app-four/Views/SettingsView.swift` (~L71-73)
- [ ] T013 [US3] Fence the `TestServicesView` definition behind the same `#if`, and wire `@Environment(\.dismiss)` into the no-op "Done" button in `app-four/Views/TestServicesView.swift` (~L153-157)
- [ ] T014 [US3] Verify: Release `BuildProject` succeeds with no `Test*` symbols compiled; Debug build → diagnostics reachable, Done dismisses

**Checkpoint**: Both configurations build green.

---

## Phase 6: User Story 4 — Dead-code sweep (Priority: P2)

**Goal**: Zero orphaned files/members; build + tests green; behavior unchanged.
**Independent Test**: grep each removed symbol → zero prod refs; `BuildProject` + `RunAllTests` green; smoke flows unchanged.

### Tests for User Story 4 (test-first · RED — MANDATORY for logic) ⚠️

- [ ] T015 [P] [US4] RED: retarget `app-fourTests/ViewModels/ProcessingViewModelTests.swift` to assert on persisted `Recording.summaryStatus` transitions (generating → ready/failed); run and confirm it fails against the about-to-change pipeline

### Implementation (ordered per research.md R6)

- [ ] T016 [US4] Delete `app-four/Views/Components/SummaryCard.swift` (references `SummaryState`) — FIRST, before T017
- [ ] T017 [US4] Remove `summaryState`, the `SummaryState` enum, and `topicTags` (+ their assignments) from `app-four/ViewModels/RecordingDetailViewModel.swift`
- [ ] T018 [US4] Remove `exportJSON()` + the now-orphaned `storageService` property and its `init` wiring from `app-four/ViewModels/RecordingDetailViewModel.swift`
- [ ] T019 [US4] Remove the `ProcessingState` machine + `state` from `app-four/ViewModels/ProcessingViewModel.swift` (pipeline becomes plain methods; `Recording.summaryStatus` is SoT); remove `retry()` and the dead `duration`/`language` params; update call sites in `app-four/ViewModels/CheckInViewModel.swift` (~L260, L427) → turn T015 GREEN
- [ ] T020 [US4] Remove `stop()`, `beginScrubbing()`, `endScrubbing()`, `isScrubbing`, and the unreachable `.loading` case from `app-four/ViewModels/AudioPlaybackViewModel.swift`; simplify the `startProgressPolling` guard
- [ ] T021 [US4] Remove the title-editing machinery (`name`/`userDidSetTitle`/`originalTitle` + dead `confirm()` branch) from `app-four/ViewModels/ExtractionReviewViewModel.swift`
- [ ] T022 [US4] Drop the `elevated` param + dead branch from `app-four/DesignSystem/Card.swift`; delete `app-four/DesignSystem/Elevation.swift`
- [ ] T023 [P] [US4] Delete `app-four/ViewModels/LibraryViewModel.swift` and `app-fourTests/ViewModels/LibraryViewModelTests.swift`
- [ ] T024 [P] [US4] Delete `app-four/Views/Components/TopicChip.swift`
- [ ] T025 [P] [US4] Delete `app-four/Views/Components/TimelineDaySection.swift`
- [ ] T026 [P] [US4] Delete `app-four/Views/Insights/InsightsPreviewSupport.swift`
- [ ] T027 [P] [US4] Remove the `.topic` case + `topic(...)`/`topicChip(category:)` factories from `app-four/Views/Components/Chip.swift`
- [ ] T028 [P] [US4] Remove `isCapturing` + its 50ms sleep (fix the misleading doc) in `app-four/Views/Feedback/ScreenshotCapture.swift`
- [ ] T029 [US4] Grep-verify zero production refs for every removed symbol/file; `BuildProject` + `RunAllTests` green; smoke: detail/summary/playback/calendar/insights/settings unchanged

**Checkpoint**: Suite green; ProcessingViewModelTests asserts persisted status.

---

## Phase 7: User Story 5 — Insights perf + modern idiom (Priority: P3)

**Goal**: Insights stays smooth at scale; tab bar + styling use current APIs.
**Independent Test**: 100+ seeded recordings → smooth paging; `Tab(value:)` selection correct.

### Tests for User Story 5 (test-first · characterization — MANDATORY for logic) ⚠️

- [ ] T030 [P] [US5] Write characterization `@Test`s asserting `moodShares`/`signalStrips`/`signalAverages`/`rhythmMatrix`/`connections` outputs for a seeded month in `app-fourTests/ViewModels/` (must pass on current code and stay green after the refactor)

### Implementation

- [ ] T031 [US5] Cache `monthRecordings` + `SignalKind`→levels groupings into a stored snapshot recomputed on `currentMonth` change in `app-four/ViewModels/InsightsViewModel.swift` + `app-four/ViewModels/InsightsViewModel+Signals.swift`; hoist the kind-independent filter out of `rhythmMatrix`'s inner loop → keep T030 green
- [ ] T032 [P] [US5] Migrate `.tabItem`+`.tag` → `Tab("…", systemImage:, value:)` builder in `app-four/Views/RootTabView.swift` (keep the existing `Tab` enum selection binding)
- [ ] T033 [P] [US5] `foregroundColor` → `foregroundStyle` at `app-four/Views/Components/FoldedDayCardHeader.swift` (~L56, L58, L59); keep the load-bearing `Text` `+` concat
- [ ] T034 [US5] Verify: 100+ recordings → smooth Insights paging; tab switching correct

**Checkpoint**: Suite green; perf characterization holds.

---

## Phase 8: User Story 6 — Polish, previews, contrast (Priority: P3)

**Goal**: Consistent inputs/sheets, working previews, AA dark-mode secondary text.
**Independent Test**: dark-mode contrast ≥ AA; ExtractionReview/DayCard previews render; inputs show placeholders.

### Tests for User Story 6 (test-first · for the logic items only) ⚠️

- [ ] T035 [P] [US6] RED: characterization `@Test`s for the shared `MonthCursor` (availableMonths/isCurrentMonth/prev/next) in `app-fourTests/ViewModels/` before extraction

### Implementation

- [ ] T036 [P] [US6] `Task.sleep(nanoseconds:)` → `Task.sleep(for:)` at `CheckInViewModel.swift` (~L321, L442), `RecordingDetailViewModel.swift` (~L147), `AudioPlaybackViewModel.swift` (~L110)
- [ ] T037 [P] [US6] Replace per-render `DateFormatter` with `Date.FormatStyle`/`static let` in `app-four/Views/SettingsView.swift` (~L26-30) and `app-four/Views/Components/DayDetailSheet.swift`
- [ ] T038 [US6] `AudioPlaybackViewModel.currentTime` → `private(set)` in `app-four/ViewModels/AudioPlaybackViewModel.swift`
- [ ] T039 [US6] Drop redundant `effectiveDose` from `DoseDisplay`; point readers (`MedicationBarView.swift` ~L112, L133) at `dose` in `app-four/ViewModels/MedicationBarViewModel.swift`
- [ ] T040 [US6] Relocate `Calendar.startOfMonth` → `app-four/Extensions/Calendar+Month.swift`; extract a shared `MonthCursor` consumed by `InsightsViewModel` + `MoodLibraryViewModel` → keep T035 green
- [ ] T041 [P] [US6] One-type-per-file: split `RootContainerView` out of `app-four/App/SquirlApp.swift` → `app-four/App/RootContainerView.swift`; split `FlowLayout` out of `app-four/Views/Components/TagFlowView.swift`
- [ ] T042 [P] [US6] `TextEditor` → `TextField(axis:.vertical)` + placeholder in `app-four/Views/Feedback/IssueReportView.swift` (~L76) and `app-four/Views/CheckIn/TextCheckInComposer.swift`
- [ ] T043 [US6] `IssueReportView` parallel-boolean sheets → one `enum FeedbackSheet: Identifiable` + `.sheet(item:)` in `app-four/Views/Feedback/IssueReportView.swift` (~L25-27)
- [ ] T044 [P] [US6] Add `accessibilityAddTraits(.isSelected)` to the selected item in `app-four/Views/Insights/MonthSelectorScrollView.swift` (~L20-36)
- [ ] T045 [P] [US6] Add a `#Preview` to `app-four/Views/ExtractionReviewView.swift`; add a populated-day `#Preview` to `app-four/Views/Components/DayCard.swift` (and an Insights populated preview)
- [ ] T046 [US6] Verify dark-mode secondary-text contrast ≥ WCAG AA (the previously-flagged subtitle) via `RenderPreview` Dark + a contrast check

**Checkpoint**: Suite green; previews render; contrast AA.

---

## Phase 9: Polish & Cross-Cutting

- [ ] T047 Run full `quickstart.md` validation across all six stories; final `BuildProject` + `RunAllTests` green
- [ ] T048 Update `docs/BACKLOG.md` (stage → ✅ for this remediation) and `docs/DEVLOG.md` (decisions: remove-both, single-source-of-truth summary status, debug fence)
- [ ] T049 Open PR `fix/022-view-audit-remediation` → run `/code-review` on the diff; surface findings. **Do NOT merge** (human approves).

---

## Dependencies & Execution Order

- **Setup (Phase 1)** → must repoint `feature.json` + clean tree first.
- **US1, US2** (P1): independent; smallest, highest value — do first.
- **US3, US4** (P2): independent of P1; US4 has strict internal order (T016 before T017; T015 RED before T019 GREEN; T022 Card before Elevation delete).
- **US5, US6** (P3): independent; US5 T030 characterization before T031; US6 T035 before T040.
- **Polish (Phase 9)**: after all desired stories.

### Within each story

- Logic: test (RED/characterization) before implementation; SwiftUI views verified by build + run.
- Build + full suite green is the "done" bar per story (Constitution II).

### Parallel opportunities

- US1 and US2 can proceed together (different files).
- Within US4: T023–T028 are `[P]` (independent deletions) after T016–T022 land.
- Within US6: T036, T037, T041, T042, T044, T045 are `[P]`.

---

## Implementation Strategy

**MVP** = US1 + US2 (the two P1 user-facing fixes) — smallest shippable, highest value. Then US3+US4 (release hygiene + dead-code), then US5+US6.

Each story: implement → `BuildProject` + `RunAllTests` green → commit per logical unit. Stop at the first story that won't go green and report. No merge to `main`.

---

## Notes

- `[P]` = different files, no incomplete-task dependency.
- Verify logic tests FAIL (RED) before implementing (Principle X); characterization tests stay green across refactors.
- Audit line numbers are hints — re-locate by symbol after the WIP resolves.
- Full file/symbol inventory + rationale: [docs/audits/2026-06-25-views-audit.md](../../docs/audits/2026-06-25-views-audit.md) and [docs/audits/2026-06-25-ios-design-review.md](../../docs/audits/2026-06-25-ios-design-review.md).
