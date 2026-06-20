---
description: "Task list for 009-healthkit-signals"
---

# Tasks: HealthKit Signals

**Input**: Design documents from `specs/009-healthkit-signals/`
**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/interfaces.md](contracts/interfaces.md), [quickstart.md](quickstart.md)

**Tests**: Test-first is MANDATORY for logic (`@Model`, `Services/`, `@Observable` view-models) per Constitution **X** — write the test, RUN it, confirm it **FAILS (RED)**, then implement to **GREEN**, then refactor. SwiftUI **views are EXEMPT** (build + on-simulator run; HTML mockup gate per Constitution I). Tests use **Swift Testing** (`@Test`/`#expect`), `@testable import app_four`, in-memory `ModelConfiguration(isStoredInMemoryOnly: true)`.

**Build/test command** (project memory): prefix with `env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0`; `xcodebuild test -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:app-fourTests/<Suite>`.

**Corrections applied vs the design-feeder impl plan**: (1) original Task 13 (A2 check-in→sleep bridge) **dropped** — excluded by clarification; (2) all test imports are `@testable import app_four` (not `app_two`); (3) `DailySignals` has **no** `@Attribute(.unique)`, all attributes optional/defaulted, uniqueness enforced in `SignalsStore.upsert` (research D1); (4) menstrual flow uses `HKCategoryValueVaginalBleeding`, raw `2=light,3=medium,4=heavy`, `1/5/unknown→nil` (research D2); (5) sleep stored as 5-step `SleepLevel` + efficiency→`SleepLevel` heuristic (not a 3-value string); rendered with the bed icon + indigo + named scale per DESIGN.md — **no** `SleepLevel: SignalLevel` colour-bead conformance (research D5, owner decision 2026-06-20).

---

## Phase 1: Setup

- [X] T001 Confirm `feat/healthkit-signals` is checked out and establish a green baseline by running one existing suite (e.g. `-only-testing:app-fourTests/Store` or `CheckInViewModelTests`); record the pass count.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The day-keyed model, value types, day-key/DTOs, sleep-bead conformance, and the store — shared by all three user stories.

**⚠️ CRITICAL**: No user story can begin until this phase is complete.

### Tests (test-first · RED — MANDATORY) ⚠️

- [X] T002 [P] RED: `DailySignalsTests` in `app-fourTests/DailySignalsTests.swift` — assert a new `DailySignals` defaults all four sources to `.none` and all signal fields to `nil`; assert the type compiles with no `@Attribute(.unique)`. Run; MUST FAIL (type not found).
- [X] T003 [P] RED: `SignalDayKeyTests` in `app-fourTests/SignalDayKeyTests.swift` — `dayStart(for:calendar:)` zeroes time components and yields the same key for different times on the same local day (timezone/DST cases). Run; MUST FAIL.

### Implementation

- [X] T004 [P] Create `SignalSource` enum (`case none, healthKit, manual`; `String, Codable, Sendable`) in `app-four/Models/SignalSource.swift`.
- [X] T005 [P] Create `MenstrualFlow` enum (`case light, medium, heavy, spotting`; `String, Codable, Sendable, CaseIterable`) in `app-four/Models/MenstrualFlow.swift`.
- [X] T006 Create `DailySignals` `@Model` in `app-four/Models/DailySignals.swift` — per [data-model.md](data-model.md): **no `@Attribute(.unique)`**; every attribute optional or defaulted (`dayStart: Date = .distantPast`, `updatedAt: Date = .now`, `sleepSource: SignalSource = .none`, …, `isMockData: Bool = false`); `sleepLevelValue: String?`; `cycleSymptomsJSON: String?` with a computed `cycleSymptoms: [String]` accessor. Turns T002 GREEN. (deps: T004, T005)
- [X] T007 Register `DailySignals.self` in **both** `Schema([...])` arrays in `app-four/App/AppModelContainer.swift` (container ~L9–16 and previewContainer ~L63–70). (deps: T006)
- [X] T008 [P] Create `SignalDayKey.dayStart(for:calendar:)` and the Sendable DTOs (`SleepDTO{hours,level:SleepLevel?}`, `ActivityDTO`, `HeartDTO`, `CycleDTO`, `DaySignalsDTO`) in `app-four/Services/HealthKit/HealthSignalsDTO.swift`. Turns T003 GREEN.
- [X] ~~T009 Add `SleepLevel: SignalLevel` conformance~~ — **CUT (2026-06-20, owner decision: follow DESIGN.md).** Sleep renders with the bed icon + sleep indigo + named `SleepLevel` scale (Restless→Deep); the colour bead ramp stays deferred (DESIGN.md:49,106). No conformance added. Data layer unaffected (sleep stored as `SleepLevel` + hours).
- [X] T010 RED: `SignalsStoreTests` in `app-fourTests/SignalsStoreTests.swift` — `upsert(dayStart:)` returns the same row on repeat (count stays 1; idempotent, FR-003); `fetch` returns nil for a missing day. Run; MUST FAIL. (deps: T006)
- [X] T011 Implement `SignalsStore` (`@MainActor @Observable`, injected `ModelContext`, `fetch`/`upsert`/`fetchRange`/`save`; `upsert` normalizes via `SignalDayKey`, `fetchLimit = 1`) in `app-four/Store/SignalsStore.swift`. Turns T010 GREEN. (deps: T006, T008)

**Checkpoint**: Foundational suites (`DailySignalsTests`, `SignalDayKeyTests`, `SignalsStoreTests`) all GREEN. Model + store ready; no `@Attribute(.unique)`; schema registered.

---

## Phase 3: User Story 1 - Record & review a day's signals by hand (Priority: P1) 🎯 MVP

**Goal**: View and manually enter all four signal groups for any day; values persist and are independent per day — with Apple Health absent.

**Independent Test**: On a simulator with no Health data, enter values for all four groups, save, relaunch, reopen the day → values persist; a second day is independent (SC-001, SC-005).

### Tests (test-first · RED — MANDATORY) ⚠️

- [X] T012 [P] [US1] RED: `DaySignalsEditorViewModelTests` in `app-fourTests/DaySignalsEditorViewModelTests.swift` — editing a group sets its source to `.manual`; clearing all of a group's values resets it to `.none` (A5/FR-012); an untouched group keeps its existing source. Run; MUST FAIL.

### Implementation

- [X] T013 [US1] Implement `DaySignalsEditorViewModel` (`@Observable @MainActor`) in `app-four/ViewModels/DaySignalsEditorViewModel.swift` — `load()` from the store, `save()` writes per-group values and sets source `.manual` when a group has any value / `.none` when fully cleared. Turns T012 GREEN. (deps: T011)
- [ ] T014 [US1] HTML mockup gate (Constitution I): create `docs/superpowers/plans/2026-06-13-signals-editor-mockup.html` and `…-signals-summary-mockup.html` (four sections, per-field **source indicator**, sleep 5-step `SleepLevel` control, Paper & Pollen tokens) and **STOP for approval**. Blocks T015–T016.
- [ ] T015 [US1] Implement `DaySignalsEditorSheet` in `app-four/Views/Signals/DaySignalsEditorSheet.swift` — four sections; sleep uses a 5-step `SleepLevel` picker (D5); each section shows a source indicator; bound to the VM. Verify by build + Preview/simulator. (deps: T013, T014)
- [ ] T016 [US1] Implement `DaySignalsSummaryView` in `app-four/Views/Signals/DaySignalsSummaryView.swift` — reads `DailySignals` via the store, renders sleep with the bed icon + sleep indigo + named `SleepLevel` (per DESIGN.md; no colour beads) and activity/heart/cycle as plain values, each with a source glyph; opens the editor; **no sync yet** (manual-only). Build + run on simulator (no Health data) → shows "—" then persists manual edits (SC-001/SC-005). (deps: T013, T014)
- [ ] T017 [US1] Surface the summary/editor from an existing day surface (where a day is viewed) so the MVP is reachable; build + run. (deps: T016)

**Checkpoint**: US1 fully functional — manual entry + per-day view + persistence, zero HealthKit. Shippable MVP.

---

## Phase 4: User Story 2 - Automatically fill signals from Apple Health (Priority: P2)

**Goal**: Grant read access once; recent days populate from Apple Health on open and on manual refresh; first grant backfills 30 days; days with no data stay empty and manually fillable.

**Independent Test**: With mock/seeded data, granting access fills days from Apple Health; a day with no data stays empty; manual refresh re-runs import (SC-002, SC-003).

### Setup for US2

- [ ] T018 [US2] In Xcode, add the **HealthKit** capability to the `app-four` target (generates `app-four/app-four.entitlements`, `com.apple.developer.healthkit`); do **not** enable Clinical Records or background delivery. Add `NSHealthShareUsageDescription` (read, on-device rationale) to `app-four/Info.plist`; do **not** add `NSHealthUpdateUsageDescription` (read-only, FR-017).

### Tests (test-first · RED — MANDATORY) ⚠️

- [ ] T019 [P] [US2] RED: `HealthKitSampleMappingTests` in `app-fourTests/HealthKitSampleMappingTests.swift` — flow mapping `2→.light, 3→.medium, 4→.heavy`, `1/5/unknown→nil` (D2 corrected integers); sleep efficiency→`SleepLevel` at the committed cutoffs and `nil` when `inBed ≤ 0`/non-finite (D5). Run; MUST FAIL.
- [ ] T020 [US2] RED: `SignalSyncCoordinatorTests` (merge + sync) in `app-fourTests/SignalSyncCoordinatorTests.swift` — the full merge matrix: `.none`→fill+`.healthKit`; `.healthKit`→overwrite; `.manual`→untouched; activity/heart merge independently; `sync(from:to:)` fills rows from the mock reader and saves once; `syncPreservesManualEdits`. Run; MUST FAIL. (deps: T021 for the mock)

### Implementation

- [ ] T021 [P] [US2] Create `MockHealthDataReading` (stubbed state + `[DaySignalsDTO]`, `readCallCount`) in `app-fourTests/Mocks/MockHealthDataReading.swift` (the one sanctioned single-threaded test-double `@unchecked Sendable`).
- [ ] T022 [US2] Create `HealthDataReading` protocol + `HealthAuthorizationState` in `app-four/Services/HealthKit/HealthDataReading.swift` (per [contracts/interfaces.md](contracts/interfaces.md) C1).
- [ ] T023 [US2] Implement `HealthKitSampleMapping` pure funcs (corrected flow integers; efficiency→`SleepLevel`) in `app-four/Services/HealthKit/HealthKitSampleMapping.swift`. Turns T019 GREEN.
- [ ] T024 [US2] Implement `SignalSyncCoordinator` (`@MainActor`) merge funcs + `sync(from:to:)`/`sync(lastDays:)` in `app-four/Store/SignalSyncCoordinator.swift` — per-group provenance gate; upsert→merge→save once. Turns T020 GREEN. (deps: T011, T022)
- [ ] T025 [US2] Add `healthService: HealthDataReading` to `app-four/Store/AppServices.swift` (after `summarizationService`) and wire `MockHealthDataReading` into `app-fourTests/Mocks/MockAppServices.swift`; keep existing suites green. (deps: T022)
- [ ] T026 [US2] Implement `HealthKitServiceImpl` actor (the **only** `import HealthKit`) in `app-four/Services/HealthKit/HealthKitServiceImpl.swift` — `isHealthDataAvailable` gate; `requestAuthorization(toShare:[],read:)`; per-day reads via `HKSampleQueryDescriptor`/`HKStatisticsQueryDescriptor` `.result(for:)`; sleep = sum of `asleepCore/Deep/REM/Unspecified` + `inBed`; activity sums; heart averages; flow via `HKCategoryValueVaginalBleeding` (D2/D3); returns DTOs only. Device-verified (not unit-tested). (deps: T022, T023)
- [ ] T027 [US2] Wire production DI in `app-four/Store/AppDependencies.swift` — construct `HealthKitServiceImpl`, `SignalsStore`, `SignalSyncCoordinator`; pass `healthService` into the `AppServices(...)` bundle; build the app target. (deps: T024, T025, T026)
- [ ] T028 [US2] Implement `HealthAccessPrimerView` in `app-four/Views/Signals/HealthAccessPrimerView.swift` — one-time plain-language primer before the system sheet (FR-005); "Connect" calls `requestAuthorization()`, "Not now" leaves the manual path usable. Build + Preview. (deps: T022)
- [ ] T029 [US2] Wire read-on-open + pull-to-refresh into `DaySignalsSummaryView` (`coordinator.sync(lastDays: 30)` in `.task`/`.refreshable`, then re-fetch the day). Build + run on simulator (sync returns empty → manual path intact). (deps: T016, T024, T027)
- [ ] T030 [US2] Manual device verification: grant access → recent days populate with the Apple Health source; first grant backfills ~30 days (SC-002, SC-003). Record in the PR.

**Checkpoint**: US2 functional — Apple Health import fills days; manual path still works; denied/unavailable degrade to empty editable fields (FR-014).

---

## Phase 5: User Story 3 - Trust whose value is shown (Priority: P3)

**Goal**: Hand-entered values are never overwritten by import and survive refresh; each value shows its source; clearing a value re-enables Apple Health fill.

**Independent Test**: Hand-enter a value, run an import with different data for that day → the hand-entered value is unchanged and labeled "Added by you"; clear it, re-import → it takes the Apple Health value (SC-004, SC-006).

### Tests (test-first · RED — MANDATORY) ⚠️

- [ ] T031 [P] [US3] RED: add a mixed-provenance round-trip case to `app-fourTests/SignalSyncCoordinatorTests.swift` — one day seeded with a `.manual` sleep group, a `.none` activity group, and a `.healthKit` heart group; run `sync` with conflicting DTOs for all three; assert manual preserved, none→filled+`.healthKit`, healthKit→refreshed (FR-009/010/011). Run; MUST FAIL if any gap, else confirms the invariant end-to-end. (deps: T024)

### Implementation

- [ ] T032 [US3] Ensure the merge rule fully satisfies T031 (manual sticky across a full sync round-trip); add code only if the test exposes a gap. (deps: T024)
- [ ] T033 [US3] Finalize source indicators to the approved mockup across `DaySignalsEditorSheet` (per-section "From Apple Health" / "Added by you" / "Not set" pills) and `DaySignalsSummaryView` (source glyphs), with accessibility labels (FR-013/SC-006). Build + run. (deps: T015, T016, T029)
- [ ] T034 [US3] Manual device verification: edit an imported value → it flips to "Added by you" and **survives pull-to-refresh** (SC-004). Record in the PR.

**Checkpoint**: All three stories independently functional; provenance correct and visible.

---

## Phase 6: Polish & Cross-Cutting

- [ ] T035 Run the **full** `app-fourTests` target (no `-only-testing`) → all GREEN, no regressions; record the count (Constitution II).
- [ ] T036 Build the app target clean (`xcodebuild build -scheme app-four …`) → BUILD SUCCEEDED, no new warnings (keep actor-isolation warnings at zero).
- [ ] T037 Run the [quickstart.md](quickstart.md) validation scenarios end-to-end — including SC-007: confirm no health values leave the device (no network egress was added; FR-016).
- [ ] T038 [P] File a backlog item: strip the pre-existing `@Attribute(.unique) var id: UUID` from `Recording`/`AppSettings`/`ModelMetadata`/`TranscriptionSegment` (Constitution IX CloudKit cleanup; research D1) in `docs/BACKLOG.md` — separate feature, not this PR.
- [ ] T039 [P] Move the "HealthKit signals" row 📐 Plan → 🔨 In code in `docs/BACKLOG.md` (branch `feat/healthkit-signals` + plan link); add a `docs/DEVLOG.md` checkpoint entry.
- [ ] T040 Open the PR and run `/code-review`; attach the manual device-verification results (T030, T034).

---

## Dependencies & Execution Order

- **Setup (T001)** → no deps.
- **Foundational (T002–T011)** → blocks all stories. Order: RED tests (T002, T003, T010) precede their impl (T006, T008, T011); enums (T004, T005) before the model (T006); model before schema (T007) and store (T011).
- **US1 (T012–T017)** → after Foundational. T012 RED before T013; mockup gate (T014) blocks the views (T015, T016).
- **US2 (T018–T030)** → after Foundational. Independently testable from US1. T019/T020 RED before T023/T024; mock (T021) before coordinator tests; actor (T026) + DI (T027) before the read-on-open wiring (T029).
- **US3 (T031–T034)** → after US2 (needs the coordinator + import to exist to prove stickiness and show the Apple Health source). T031 RED before T032.
- **Polish (T035–T040)** → after the desired stories.

### Within each story

Tests RED → confirmed failing → implement to GREEN → refactor (Constitution X). Models before services before view-models before views. Views are build+run (exempt), gated by the mockup.

## Parallel Opportunities

- Foundational: T002 ‖ T003 (tests); T004 ‖ T005 ‖ T008 ‖ T009 (independent files).
- US2: T019 (mapping test) ‖ T021 (mock); T023 ‖ (after) — mapping vs coordinator touch different files.
- Polish: T038 ‖ T039 (different concerns; both touch BACKLOG.md so commit sequentially).
- Across stories: with one developer, run sequentially P1 → P2 → P3; the phases are structured so US1 ships alone.

## Parallel Example: Foundational

```bash
# RED tests together:
Task: "DailySignalsTests in app-fourTests/DailySignalsTests.swift"
Task: "SignalDayKeyTests in app-fourTests/SignalDayKeyTests.swift"
# Independent implementation files together:
Task: "SignalSource enum in app-four/Models/SignalSource.swift"
Task: "MenstrualFlow enum in app-four/Models/MenstrualFlow.swift"
Task: "SignalDayKey + DTOs in app-four/Services/HealthKit/HealthSignalsDTO.swift"
Task: "SleepLevel:SignalLevel in app-four/Models/SleepLevel+SignalLevel.swift"
```

## Implementation Strategy

- **MVP = Phase 1 + 2 + 3 (US1)**: manual daily signals + per-day view, no HealthKit. Stop, validate (SC-001/SC-005), demo.
- **Increment 2 = US2**: Apple Health import + primer.
- **Increment 3 = US3**: provenance trust surface + source indicators.
- One task (or RED→GREEN pair) per commit; stop at any checkpoint to validate the story independently.

## Notes

- The one hard human gate is **T014** (HTML mockup approval) — required before any SwiftUI view (Constitution I).
- Device-only verifications (T030, T034) are inherent to HealthKit (the simulator has no Health data), not placeholders.
- `HealthKitServiceImpl` (T026) is the sole `import HealthKit`; everything else tests with DTOs/mocks.
