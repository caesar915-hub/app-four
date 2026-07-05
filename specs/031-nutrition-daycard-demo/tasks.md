# Tasks: Nutrition & Exercise Signals on the Day Card (Demo)

**Input**: Design documents from `/specs/031-nutrition-daycard-demo/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/interfaces.md, quickstart.md (all committed at `984ccc68`)

**Tests**: MANDATORY test-first (Constitution X) for all logic — each Tests block is written, run, and confirmed **RED** before its implementation block. SwiftUI views are EXEMPT (mockup-gated — all three mockups approved 2026-07-05 — and verified by build + owner device run; **no simulator** per house rule, owner runs the suite).

**Organization**: By user story. US1 (folded tokens on demo data) is the MVP; US2 (unfolded timeline) and US3 (real HealthKit) build on it independently of each other.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

**Purpose**: Branch verification + the design-system lanes every story's UI needs.

- [X] T001 Verify branch `feat/nutrition-signals-demo` is at/ahead of `984ccc68` with clean status; confirm mockups exist in docs/superpowers/plans/ (three 2026-07-05-nutrition-*.html files)
- [X] T002 [P] Add `Palette.nutritionFood` (clay #B5674A light / #CB8266 dark) and `Palette.nutritionExercise` (teal #3E8E86 light / #5FAEA5 dark) beside the existing signal colors in Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Palette+Signals.swift (or the file where `Palette.medication` lives)
- [X] T003 [P] Record the two new lanes in DESIGN.md Decisions Log (owner approval = Pair 2 mockup sign-off 2026-07-05); bump the `Updated:` timestamp header via `date "+%Y-%m-%d %H:%M %Z"`

**Checkpoint**: package + app still build.

---

## Phase 2: Foundational (blocking all stories)

**Purpose**: The event entity, DTO, day-summary math, store access, and VM plumbing that US1–US3 all sit on.

### Tests (write → run → confirm RED)

- [X] T004 [P] Write app-fourTests/Models/NutritionEventTests.swift: defaults (`sourceValue == healthKit`, `isMockData == false`, all metrics nil, `kindValue == "food"`), kind computed-property bridging both directions — in-memory ModelContainer fixture per existing DailySignalsTests pattern
- [X] T005 [P] Write summary cases in app-fourTests/Services/NutritionEventGroupingTests.swift: Σ per metric over food events; `kcalOut` = Σ exercise kcal ONLY (no food contribution, no DailySignals input); each Σ nil when no contributor; mixed-source events → summary source `.manual` if any contributor manual else `.healthKit`
- [X] T006 [P] Write fetch/insert cases in app-fourTests/Store/SignalsStoreEventTests.swift: `fetchEvents(from:to:)` range inclusion (23:58 event belongs to its day — SignalDayKey edge), `insertMockEvent` persists with `isMockData == true`
- [X] T007 [P] Write mapping cases in app-fourTests/ViewModels/MoodLibraryViewModelNutritionTests.swift: events group by day key into `TimelineDay.nutrition`; days without events get nil; summary values surface for folded tokens; `debugMockMode` off hides mock events (fixture: container with Recording + MedicationEvent + NutritionEvent, per existing VM test pattern)
- [X] T008 Run the suite; confirm T004–T007 tests FAIL (RED) — commit the failing tests

### Implementation (make them GREEN)

- [X] T009 [P] Create app-four/Models/NutritionEvent.swift: `@Model` per data-model.md (all attributes optional/defaulted, no unique — Constitution IX) + `NutritionEventKind` enum + kind/source computed bridges
- [X] T010 [P] Add `NutritionEventDTO` (Sendable) to app-four/Services/HealthKit/HealthSignalsDTO.swift per contracts §1
- [X] T011 Create app-four/Services/HealthKit/NutritionEventGrouping.swift with `summary(for:)` (contracts §2; `hourlyFoodEvents` arrives in US3, T031)
- [X] T012 Add `fetchEvents(from:to:)` + `insertMockEvent(_:)` to app-four/Store/SignalsStore.swift (date-range `#Predicate` only — no `isEmpty`/unsupported operations per SwiftData predicate rules)
- [X] T013 Extend app-four/ViewModels/MoodLibraryViewModel.swift: `signalsStore` init param, `DayNutrition`/`NutritionEventItem`/`NutritionSummary` value types, observable `nutritionByDay`, `loadNutrition()` (mock-mode filter mirroring `loadMedicationEvents()` at line ~129), `TimelineDay.nutrition`
- [X] T014 Wire `AppDependencies.signalsStore` into the VM init in app-four/Views/Library/CalendarLibraryView.swift (init-arg only; the `.task` sync trigger is US3)
- [X] T015 Run the suite: T004–T007 GREEN, zero regressions elsewhere; refactor if needed, keep green — commit

**Checkpoint**: data layer + VM plumbing complete; nothing visible in UI yet.

---

## Phase 3: User Story 1 — Nutrition at a glance on the folded card (P1) 🎯 MVP

**Goal**: Folded cards show kcal + caffeine tokens (mockup V3) from deterministic demo data.

**Independent test**: demo mode on a device with no food logs → folded tokens across ~30 days; skip days show none; VoiceOver reads the values (quickstart §2.2, SC-001).

### Tests (RED first)

- [X] T016 [P] [US1] Write app-fourTests/Utils/MockDataGeneratorNutritionTests.swift: 30-day window, ~2 skip days, determinism (two runs → identical values), caffeine inversely correlated with mock med days, 3–4 food events at realistic hours + 0–1 workouts per day, all `isMockData == true` / `source == .healthKit`
- [X] T017 [US1] Run suite; confirm T016 FAILS (RED) — commit

### Implementation

- [X] T018 [US1] Add `seedNutritionEvents(context:)` to app-four/Utils/MockDataGenerator.swift per research D11 (values pure functions of dayOffset — no RNG, no `Date.now` beyond the existing generator anchor); call it from `generate(context:)`
- [X] T019 [US1] Run suite: T016 GREEN — commit
- [X] T020 [US1] (View — exempt, mockup V3) Extend `parts` in app-four/Views/Components/FoldedDayCardHeader.swift: append ≤2 `Part(kind: nil, systemImage:)` tokens — `fork.knife` "N kcal", `cup.and.saucer.fill` "N mg" — colored `Palette.nutritionFood`, only when `day.nutrition?.summary` has the value; extend the combined `accessibilityLabel` (lines ~115–119) with "N calories eaten, N milligrams caffeine"
- [ ] T021 [US1] Owner checkpoint: build + device run — seed mock data, verify folded tokens light/dark, skip days empty, VoiceOver label, Dynamic Type wrap (quickstart §2.2, §4)

**Checkpoint**: MVP demonstrable — folded story complete on demo data.

---

## Phase 4: User Story 2 — Meals & workouts as timeline entries, unfolded (P2)

**Goal**: Expanded card interleaves food/exercise rows with check-ins + totals footer (mockup variant A).

**Independent test**: expand a seeded day → 8 entries in time order, clay/teal lanes, read-only rows, footer with "—" placeholders; nutrition-only day expands (quickstart §2.2–2.3, SC-002).

### Tests (RED first)

- [X] T022 [P] [US2] Add interleave cases to app-fourTests/ViewModels/MoodLibraryViewModelNutritionTests.swift: merged food/exercise items order correctly among check-in nodes using the existing row ordering convention (3 check-ins + 4 food + 1 workout fixture → 8 positions asserted); nutrition-only day yields `nutrition != nil` with empty nodes
- [X] T023 [US2] Run suite; confirm T022 FAILS (RED) — commit

### Implementation

- [X] T024 [US2] Implement the time-merge in app-four/ViewModels/MoodLibraryViewModel.swift (expose ordered display items on `TimelineDay` or `DayNutrition` so views do zero sorting); run suite → GREEN — commit
- [X] T025 [P] [US2] (View — exempt, variant A) Create app-four/Views/Components/NutritionEventRow.swift: 28pt hollow bead (1.5pt stroke, 12% tint) on the 38pt rail, `fork.knife`/`flame.fill` glyph, name in lane color (14pt, 600), SF Mono values with muted units, time right of name, no chevron/no button trait; single combined VoiceOver element; #Preview for food/exercise/partial variants
- [X] T026 [P] [US2] (View — exempt) Create app-four/Views/Components/DayNutritionFooter.swift: hairline top, 4 metrics with "—" placeholders, trailing provenance glyph (`heart.fill`/`pencil`) with a11y label; indent variants (50pt rail vs full-width); #Preview full/partial/manual
- [X] T027 [US2] (View — exempt) Edit app-four/Views/Components/DayCard.swift: expansion gate → `isExpanded && (!day.nodes.isEmpty || day.nutrition != nil)` (line ~23); expanded VStack renders the VM's merged item order (TimelineRow | NutritionEventRow) + footer last; nutrition-only day renders footer full-width
- [ ] T028 [US2] Owner checkpoint: build + device run — interleaved day, nutrition-only day expands, read-only rows, footer placeholders, dark mode, VoiceOver on rows/footer (quickstart §2, §4)

**Checkpoint**: full demo works end-to-end on seeded data.

---

## Phase 5: User Story 3 — Real Apple Health data wins (P3)

**Goal**: Real dietary/workout reads via the service actor; calendar syncs silently; real replaces demo per day.

**Independent test**: with access granted via Insights, log food/caffeine/workout in Health → calendar shows real values for that day, seeded elsewhere, no prompt from calendar (quickstart §3, SC-003/SC-006).

### Tests (RED first)

- [X] T029 [P] [US3] Add hourly-bucketing cases to app-fourTests/Services/NutritionEventGroupingTests.swift: loose samples same hour → one event; hour boundary splits; never emits all-nil event; correlation-claimed samples excluded from loose input (mapper operates on extracted values — no HealthKit import)
- [X] T030 [P] [US3] Add replace cases to app-fourTests/Store/SignalsStoreEventTests.swift: `replaceHealthKitEvents(dayStart:with:)` deletes only `source == .healthKit && !isMockData` rows for that day; mock rows and `.manual` rows survive; second call with same DTOs → no duplicates
- [X] T031 [P] [US3] Extend app-fourTests/Mocks/MockHealthDataReading.swift with `setNutritionEvents(_:)` + range recording; add sweep cases to app-fourTests/Store/SignalSyncCoordinatorTests.swift: events written during `sync(from:to:)`, `.unavailable` short-circuits, re-sync replaces (count stable)
- [X] T032 [P] [US3] Add real-wins matrix to app-fourTests/ViewModels/MoodLibraryViewModelNutritionTests.swift: (mock on/off) × (real present/absent) per data-model rules — never mixed within a day
- [X] T033 [US3] Run suite; confirm T029–T032 FAIL (RED) — commit

### Implementation

- [X] T034 [US3] Add `readNutritionEvents(from:to:)` to app-four/Services/HealthKit/HealthDataReading.swift (contracts §1) and implement `NutritionEventGrouping.hourlyFoodEvents` in app-four/Services/HealthKit/NutritionEventGrouping.swift
- [X] T035 [US3] Implement `replaceHealthKitEvents(dayStart:with:)` in app-four/Store/SignalsStore.swift and the event sweep inside `sync(from:to:)` in app-four/Store/SignalSyncCoordinator.swift (single `store.save()`, existing once-per-day gate)
- [X] T036 [US3] Run suite: T029–T032 GREEN — commit
- [X] T037 [US3] Implement the HealthKit queries in app-four/Services/HealthKit/HealthKitServiceImpl.swift (device-verified, no unit test): extend `readTypes` (+3 dietary types + `HKObjectType.workoutType()`); food correlations via `HKSampleQueryDescriptor` + `.correlation(type:predicate:)` (name from `HKMetadataKeyFoodType`, contained samples via `objects(for:)`); loose dietary samples via `.quantitySample` minus correlation-claimed UUIDs → `hourlyFoodEvents`; workouts via `.workout(_:)` with `duration` + `statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()` — NOT deprecated `totalEnergyBurned` (research D2–D4); units kcal/.gram/.milli-gram
- [X] T038 [P] [US3] (View — exempt) Add the sync trigger to app-four/Views/Library/CalendarLibraryView.swift `.task`: only when `didOfferHealthAccess` → `await coordinator.syncRecentIfNeeded(lastDays: 30)` then `viewModel.loadNutrition()`; never present the primer (FR-010)
- [X] T039 [P] [US3] Update app-four/Info.plist `NSHealthShareUsageDescription` and app-four/Views/Signals/HealthAccessPrimerView.swift copy to include "nutrition and workouts"
- [ ] T040 [US3] Owner checkpoint: device run per quickstart §3 — grant via Insights, log real food/caffeine/workout, verify values match Health app, real-wins with mock on, footer kcal-out = workout sum, no prompt from calendar

**Checkpoint**: all three display stories complete.

---

## Phase 6: User Story 4 — Health sync control & deletion (P4)

**Goal**: Settings "Apple Health" section — one switch gating every HealthKit read, plus explicit delete of all imported copies (FR-015–FR-017, added 2026-07-05 after US1 review).

**Independent test**: toggle off → no read on any surface; delete → all Health-sourced values vanish (031 events AND 009 day-signal groups) while manual/demo data survive; re-enable → next visit re-imports (quickstart §5, SC-007).

### Setup (mockup gate)

- [X] T044 [US4] Settings mockup produced for owner validation: docs/superpowers/plans/2026-07-05-health-settings-mockup.html (native grouped chrome per DESIGN.md 2026-06-24 exemption; 4 states: on / paused / delete dialog / empty)

### Tests (RED first)

- [X] T045 [P] [US4] Add gate cases to app-fourTests/Store/SignalSyncCoordinatorTests.swift: `healthSyncEnabled == false` → `sync(lastDays:)`/`syncRecentIfNeeded` return without calling the reader (readCallCount stays 0) and report a distinct disabled result; flag back on → reads resume; in-flight semantics untouched
- [X] T046 [P] [US4] Add deletion cases to app-fourTests/Store/SignalsStoreEventTests.swift (+ a DailySignals case): `deleteImportedHealthData()` removes `source == .healthKit && !isMockData` NutritionEvents AND clears HealthKit-sourced groups on DailySignals rows (fields nil, source `.none`); manual-source rows, mock rows, and `.manual` groups survive
- [X] T047 [US4] Run suite; confirm T045–T046 FAIL (RED) — commit

### Implementation

- [X] T048 [US4] Implement the guard in app-four/Store/SignalSyncCoordinator.swift (single `healthSyncEnabled` check at the sweep entry points, UserDefaults-backed so the Settings toggle and coordinator share state) and `deleteImportedHealthData()` in app-four/Store/SignalsStore.swift; run suite → GREEN — commit
- [X] T049 [US4] (View — exempt, T044 mockup) Add the "Apple Health" section to app-four/Views/SettingsView.swift: `Toggle("Sync from Apple Health")` on `@AppStorage("healthSyncEnabled")` (default true), "Last sync" row, destructive "Delete Imported Health Data…" with `confirmationDialog` (copy per mockup: manual/demo kept, Health itself unchanged), same dialog offered inline on toggle-off ("Stop and delete?", default Keep); post `.nutritionEventsDidChange` after delete; footer notes permission lives in the Health app
- [ ] T050 [US4] Owner checkpoint: toggle off → no sync from calendar/Insights (Last sync stays); delete → nutrition tokens/rows AND 009 signal rows vanish, mock demo survives with mock mode on; re-enable → next visit re-imports; VoiceOver pass on the section

**Checkpoint**: user controls the sync lifecycle end-to-end.

---

## Phase 7: Polish & Ship Gates

- [ ] T041 [P] Regression pass: day with zero nutrition renders identically to pre-feature build (quickstart §4, SC-004 / FR-014); full owner QA per quickstart §2–4
- [ ] T042 [P] Update docs/BACKLOG.md (031 stage/state) and docs/DEVLOG.md checkpoint entry; real date via `date "+%Y-%m-%d %H:%M %Z"`
- [ ] T043 Final suite + build green (Constitution II), then open PR to `feat/healthkit-signals` (stacked; flag spec-029 collision + PR #8 conflict status in the body) and run `/code-review`; owner device QA is the merge gate — demo branch does NOT merge to main

---

## Dependencies

```
Setup (T001–T003)
  └─► Foundational (T004–T015)   ← RED gate T008 before T009–T014
        ├─► US1 (T016–T021)      ← RED gate T017; MVP
        │     ├─► US2 (T022–T028) ← RED gate T023 (needs TimelineDay.nutrition in cards, T020 pattern)
        │     └─► US3 (T029–T040) ← RED gate T033; independent of US2
        │           └─► US4 (T044–T050) ← RED gate T047; gates the sync US3 wires
        └───────────► Polish (T041–T043) after US1–US4
```

- US2 and US3 are mutually independent — parallelizable after US1.
- T037 (service impl) depends on T034 (protocol + mapper) but not on any US2 task.
- US4 follows US3 (same coordinator/store files); its T045 test file overlaps US3's T031 — serialize those.

## Parallel opportunities

- **Foundational tests**: T004, T005, T006, T007 — four files, fully parallel.
- **Foundational impl**: T009, T010 parallel; T011–T013 sequential-ish (T013 imports T009/T011 types).
- **US2 views**: T025, T026 parallel after T024.
- **US3 tests**: T029–T032 — four files, fully parallel.
- **Cross-story**: after US1, one session can run US2 (T022–T028) while another runs US3 (T029–T040) — zero file overlap except the shared VM test file (T022 vs T032: coordinate or serialize those two).

## Implementation strategy

**MVP = Phase 1 + 2 + US1** (T001–T021): folded tokens on deterministic demo data — the demo already lands its caffeine-next-to-meds story. Ship gates at every checkpoint: suite green before moving phase; owner device QA at T021 / T028 / T040 / T050; nothing merges without `/code-review` + owner QA (T043).
