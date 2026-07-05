# Implementation Plan: Nutrition & Exercise Signals on the Day Card (Demo)

**Branch**: `feat/nutrition-signals-demo` | **Date**: 2026-07-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/031-nutrition-daycard-demo/spec.md`

## Summary

Display four Apple Health signals (dietary kcal, protein, caffeine, active energy) on the calendar Day card: two folded summary tokens (kcal + caffeine, mockup V3) and, unfolded, food/exercise events as first-class timeline rows interleaved with mood check-ins (mockup variant A) plus a per-day totals footer whose energy-out is the workout sum. Technical approach: a new `NutritionEvent` SwiftData `@Model` (per-event, persisted, mock-partitioned), read from HealthKit via `HKSampleQueryDescriptor` — food correlations with hourly loose-sample fallback, workouts via `statistics(for:)` — merged through the existing `SignalSyncCoordinator` provenance rules, seeded deterministically by `MockDataGenerator`, and surfaced through `MoodLibraryViewModel.TimelineDay` into the existing card views. Two new design-system lanes: clay (food) and teal (exercise).

## Technical Context

**Language/Version**: Swift 6+ (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26), SwiftData, HealthKit (read-only), Swift Concurrency — no third-party additions

**Storage**: SwiftData (`NutritionEvent` new `@Model`; `DailySignals` unchanged); mock/real partition via existing `isMockData` flag

**Testing**: Swift Testing (`@Test`/`#expect`), in-memory `ModelContainer` fixtures, `MockHealthDataReading` actor stub — test-first per Constitution X

**Target Platform**: iOS 26+ (clarified session 2026-07-05)

**Project Type**: Mobile app, single Xcode target `app-four` + SPM package `SquirlDesignSystem`

**Performance Goals**: No perceptible calendar-scroll regression with 30 seeded days — one range fetch per timeline rebuild, no per-card queries

**Constraints**: On-device only (Constitution VI); calendar never triggers the HealthKit permission sheet (FR-010); read-only surface (FR-013); demo branch stacked on unmerged PR #8

**Scale/Scope**: ~30 days × (≤6 food + ≤2 exercise) events; 1 new model, 1 service-protocol method, 2 store methods, 1 coordinator merge path, 3 new/edited views, 1 VM extension, ~6 test files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. SwiftUI-First** — all UI SwiftUI on iOS 26 APIs; three approved HTML mockups precede every new view (V3 folded / variant A rows / Pair 2 hues).
- [x] **II. Test-Build-Ship** — plan ends with build + full suite green before "done"; quickstart.md defines the verification run.
- [x] **III. Correctness Over Speed** — energy-out=workouts-only tradeoff surfaced in spec Clarifications; no stubs; deprecated `totalEnergyBurned` avoided in favor of `statistics(for:)`.
- [x] **IV. Minimal Surface** — no new store class (event methods live on existing `SignalsStore`); one event entity with a `kind` discriminator instead of two models; no feature flags (branch is the gate).
- [x] **V. Solo Git Discipline** — one revertable feature on `feat/nutrition-signals-demo`; `/code-review` before any merge; demo branch explicitly flagged as stacked (spec Assumptions).
- [x] **VI. On-Device Privacy** — HealthKit read-only, data persisted locally, no cloud; logging counts/durations only.
- [x] **VII. Deterministic, Measured Extraction** — N/A (no NLP-extraction changes; lexicon untouched).
- [x] **VIII. Service-Oriented Architecture** — HealthKit access stays behind `HealthDataReading` in `Services/`, injected via `AppDependencies`; `MoodLibraryViewModel` stays `@MainActor @Observable`; queries run in the `HealthKitServiceImpl` actor off-main.
- [x] **IX. Pre-Release Data Posture** — `NutritionEvent` is CloudKit-compatible: every attribute optional or defaulted, no `@Attribute(.unique)`; dedup enforced by replace-on-sync logic, not schema.
- [x] **X. Test-First Development** — model, store methods, coordinator merge, grouping mapper, seeding, and VM derivation are all RED-first with Swift Testing; SwiftUI views exempt (mockups + build + owner device run).

**Result: PASS (pre-research and post-design).** No Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/031-nutrition-daycard-demo/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── interfaces.md    # Phase 1 output
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
app-four/
├── Models/
│   └── NutritionEvent.swift                    # NEW @Model (kind: food|exercise)
├── Services/HealthKit/
│   ├── HealthDataReading.swift                 # EDIT: + readNutritionEvents(from:to:)
│   ├── HealthKitServiceImpl.swift              # EDIT: + readTypes, correlation/workout/loose-sample queries
│   ├── HealthSignalsDTO.swift                  # EDIT: + NutritionEventDTO
│   └── NutritionEventGrouping.swift            # NEW pure mapper: correlations + hourly fallback → DTOs
├── Store/
│   ├── SignalsStore.swift                      # EDIT: + fetchEvents(range:) / replaceHealthKitEvents(day:with:)
│   ├── SignalSyncCoordinator.swift             # EDIT: + event sync in the once-per-day sweep
│   └── AppDependencies.swift                   # (no change — existing nodes suffice)
├── ViewModels/
│   └── MoodLibraryViewModel.swift              # EDIT: + SignalsStore param, TimelineDay.nutrition, loadNutrition()
├── Views/
│   ├── Components/
│   │   ├── DayCard.swift                       # EDIT: gate + footer slot + event rows in expanded VStack
│   │   ├── FoldedDayCardHeader.swift           # EDIT: V3 tokens in parts + a11y label
│   │   ├── NutritionEventRow.swift             # NEW (variant A row: hollow bead, name, values)
│   │   └── DayNutritionFooter.swift            # NEW (totals strip)
│   └── Library/CalendarLibraryView.swift       # EDIT: VM wiring + .task sync-then-reload
├── Utils/
│   └── MockDataGenerator.swift                 # EDIT: + seedNutritionEvents(context:)
└── Info.plist                                  # EDIT: NSHealthShareUsageDescription + nutrition/workouts

Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/
└── Palette+Signals.swift (or sibling)          # EDIT: + nutritionFood (clay), nutritionExercise (teal)

app-fourTests/
├── Models/NutritionEventTests.swift            # NEW
├── Services/NutritionEventGroupingTests.swift  # NEW (pure mapper — no HealthKit import)
├── Store/SignalsStoreEventTests.swift          # NEW
├── Store/SignalSyncCoordinatorTests.swift      # EDIT: + event merge cases
├── Utils/MockDataGeneratorNutritionTests.swift # NEW
├── ViewModels/MoodLibraryViewModelNutritionTests.swift  # NEW
└── Mocks/MockHealthDataReading.swift           # EDIT: + stubbed events
```

**Structure Decision**: Single Xcode target extended in place, mirroring the 009 stack layer-for-layer (Model → DTO → Service actor → Store → Coordinator → VM → Views). The only genuinely new architectural element is the pure `NutritionEventGrouping` mapper, kept HealthKit-free at the value level for unit testing (same pattern as the existing `HealthKitSampleMapping`). Grouping itself operates on HK types inside the service actor; the pure mapper handles bucketing/derivation logic on already-extracted values.

## Complexity Tracking

No constitution violations to justify. Two deliberate simplicity choices worth recording:

| Choice | Simpler than | Because |
|--------|-------------|---------|
| Event methods on existing `SignalsStore` | New `NutritionEventStore` + DI node | Same domain, same context, 3 methods; a second store adds a dependency edge for nothing (Principle IV) |
| One `NutritionEvent` model with `kind` | Separate `FoodEvent` + `ExerciseEvent` models | Fields overlap (start, name, kcal, source, mock flag); two models double store/seed/test surface |
