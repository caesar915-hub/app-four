# Phase 0 Research: Nutrition & Exercise Signals on the Day Card (Demo)

All HealthKit API claims below were verified against Apple documentation via sosumi on 2026-07-05 — none are asserted from memory. Codebase claims were verified against the working tree on `feat/nutrition-signals-demo` (base `eaf72ef3`).

## D1 — Meal grouping: HKCorrelation `.food` with hourly fallback

**Decision**: Query food correlations first; samples not contained in any correlation are bucketed into one event per clock hour (spec Clarification Q1).

**Rationale**: Verified at [sosumi.ai/documentation/healthkit/hkcorrelation](https://sosumi.ai/documentation/healthkit/hkcorrelation): HKCorrelation "groups multiple related samples into a single entry"; food correlations "can contain … fat, protein, carbohydrates, energy, and vitamins"; contained samples come from `objects(for:)` ("returns a set containing all the objects of the specified type in the correlation"); the food's display name comes from `HKMetadataKeyFoodType`. Source apps that group (e.g. MyFitnessPal) yield named meals; loose samples still form sane hourly events.

**Alternatives considered**: hourly-only bucketing (loses names + splits meals at hour boundaries); one-entry-per-sample (3 rows per meal — rejected in clarify).

## D2 — Query API: `HKSampleQueryDescriptor` (async)

**Decision**: All new reads use `HKSampleQueryDescriptor(predicates:sortDescriptors:limit:)` + `result(for:)` inside the existing `HealthKitServiceImpl` actor.

**Rationale**: Verified at [sosumi.ai/documentation/healthkit/hksamplequerydescriptor](https://sosumi.ai/documentation/healthkit/hksamplequerydescriptor) — Swift-concurrency one-shot snapshot query, iOS 15.4+ (well under the iOS 26 minimum). Sample predicates verified at [sosumi.ai/documentation/healthkit/hksamplepredicate](https://sosumi.ai/documentation/healthkit/hksamplepredicate): `.correlation(type:predicate:)`, `.workout(_:)`, `.quantitySample(type:predicate:)` (all iOS 15.4+). Matches the stack's existing `HKStatisticsQueryDescriptor` style — no callback bridging.

**Alternatives considered**: legacy `HKSampleQuery` + continuation (needless bridging); `HKAnchoredObjectQueryDescriptor` (incremental anchors are over-engineering for a demo whose sync is replace-per-day).

## D3 — Workout energy: `statistics(for:)`, not `totalEnergyBurned`

**Decision**: Per workout: `duration` and `workoutActivityType` properties; active energy via `workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()`.

**Rationale**: Verified at [sosumi.ai/documentation/healthkit/hkworkout](https://sosumi.ai/documentation/healthkit/hkworkout): **`totalEnergyBurned` is deprecated**; docs direct to the statistics-based API (`statistics(for:)` / `allStatistics`). Using the deprecated property would violate Constitution I/III.

**Alternatives considered**: summing raw activeEnergyBurned quantity samples in the workout interval (double-count risk with non-workout movement; statistics API is authoritative per workout).

## D4 — Types, units, authorization set

**Decision**: Read types added to `readTypes`: `HKQuantityType(.dietaryEnergyConsumed)` (unit `.kilocalorie()`), `HKQuantityType(.dietaryProtein)` (`.gram()`), `HKQuantityType(.dietaryCaffeine)` (`.gramUnit(with: .milli)`), and `HKObjectType.workoutType()`. Correlation queries need no separate authorization — access is governed by the contained quantity types.

**Rationale**: `dietaryCaffeine` verified at [sosumi.ai/documentation/healthkit/hkquantitytypeidentifier/dietarycaffeine](https://sosumi.ai/documentation/healthkit/hkquantitytypeidentifier/dietarycaffeine): mass unit, **cumulative**, iOS 8+. Dietary energy/protein follow the same cumulative dietary pattern (energy/mass). Milligrams for caffeine matches the mockup contract ("220 mg").

## D5 — Persistence: one `NutritionEvent` `@Model`, `DailySignals` unchanged

**Decision**: New standalone `@Model NutritionEvent` with a `kind` discriminator (`food` | `exercise`); **no new fields on `DailySignals`**. Folded tokens and the totals footer are derived from events (Q3 made energy-out a workout sum, and food totals are sums of food events, so no per-day nutrition aggregate is needed anywhere).

**Rationale**: Per-event persistence was decided in clarify (Q2). Deriving totals from events keeps one source of truth — a stored aggregate could disagree with the visible timeline, which FR-004 explicitly forbids ("footer always reconciles with the visible timeline"). `DailySignals.activeEnergyKcal` (Activity group) stays untouched and is deliberately NOT the footer source.

**Alternatives considered**: nutrition fields on `DailySignals` (the pre-clarify plan) — dropped because it duplicates derivable state; two separate models — rejected in plan Complexity notes.

## D6 — Re-sync dedup: replace-per-day

**Decision**: `SignalsStore.replaceHealthKitEvents(dayStart:with:)` deletes that day's events where `source == .healthKit && isMockData == false`, then inserts the fresh DTOs. Mock rows and (future) manual rows are never touched.

**Rationale**: Spec Key Entities: "re-syncing the same day replaces that day's Apple Health-sourced events rather than duplicating them." Replace-per-day is idempotent without any unique constraint (Constitution IX forbids `@Attribute(.unique)`), and sidesteps HK-UUID bookkeeping a demo doesn't need.

**Alternatives considered**: upsert by `HKSample.uuid` (needs a stored external-id attribute + anchored queries — heavier, no demo benefit).

## D7 — "Real wins per day"

**Decision**: In `MoodLibraryViewModel.loadNutrition()`: fetch the month range once; group events by day key. In mock mode, if a day has ≥1 real (`isMockData == false`) event with any nutrition/exercise value, that day uses ONLY real events; otherwise its mock events. Mock mode off → real events only.

**Rationale**: Implements spec FR-009 at the read site with plain code; store fetch stays predicate-simple (`#Predicate` on date range only, partition applied in memory where the mixed-mode comparison logic is testable).

## D8 — VM plumbing (mirrors `medicationEvents` pattern)

**Decision**: `MoodLibraryViewModel` gains a `signalsStore` init parameter (wired from `AppDependencies.signalsStore` at [CalendarLibraryView.swift:22](../../app-four/Views/Library/CalendarLibraryView.swift#L22)); an observable `nutritionByDay: [Date: DayNutrition]` (events + derived `NutritionSummary`), populated by `loadNutrition()` in `init` and re-called after sync; `TimelineDay` gains `nutrition: DayNutrition?`. `timelineDays` reads the dictionary → Observation recomputes the cards.

**Rationale**: Exactly the existing `loadMedicationEvents()` shape ([MoodLibraryViewModel.swift:129-136](../../app-four/ViewModels/MoodLibraryViewModel.swift#L129-L136)) — no new reactive machinery; out-of-band SwiftData writes are handled by the explicit reload after sync, same as medication events' notification-driven reload.

## D9 — Sync trigger & scope

**Decision**: Extend `SignalSyncCoordinator`'s existing once-per-day sweep (`syncRecentIfNeeded(lastDays: 30)`) to also read + replace nutrition events per day. `CalendarLibraryView.task`: only if `didOfferHealthAccess` is already true → `await coordinator.syncRecentIfNeeded(lastDays: 30)` then `viewModel.loadNutrition()`. The HealthKit primer remains exclusively in the Insights `DayDetailSheet` flow.

**Rationale**: FR-010 (calendar never prompts); one gate, one sweep, no second coordinator. Info.plist `NSHealthShareUsageDescription` and `HealthAccessPrimerView` copy extend to "nutrition and workouts" so the *existing* prompt covers the new types.

**Note**: users who granted access before this feature won't see the new types' toggles until the system sheet is re-requested; `requestAuthorization` with the extended `readTypes` presents only the new types — acceptable, and only reachable via the Insights flow.

## D10 — Design-system lanes (approved Pair 2)

**Decision**: Add to `SquirlDesignSystem` palette: `nutritionFood` clay `#B5674A` (dark `#CB8266`), `nutritionExercise` teal `#3E8E86` (dark `#5FAEA5`). Record both lanes in DESIGN.md's Decisions Log (owner approval = mockup Pair 2 sign-off, 2026-07-05). Glyphs: SF Symbols `fork.knife`, `flame.fill`, `cup.and.saucer.fill` — no new `GlyphSignal` case (spec 023 rule: custom glyphs for core signals, SF Symbols for context).

**Known tradeoff (surfaced per Constitution III)**: clay shares the warm lane with mood-1/2 burnt orange; owner accepted this with eyes open in the hue A/B round.

## D11 — Mock seeding determinism

**Decision**: `MockDataGenerator.seedNutritionEvents(context:)` — 30 days back from now, values a pure function of `dayOffset` (hash-free arithmetic, no RNG): 3–4 food events at realistic hours (07:40/10:30/13:05/20:15 pattern with per-day jitter derived from dayOffset), caffeine 0–400 mg **inversely correlated with the mock medication days** the generator already creates, 0–1 workouts (duration 20–45 min, 150–450 kcal), ~2 of 30 days skipped. All rows `isMockData = true`, `source = .healthKit`.

**Rationale**: FR-008 requires determinism across re-seeds (stable demo); deriving from `dayOffset` avoids seeding an RNG and matches the existing generator's date-anchored style.

## D12 — Performance

**Decision**: One `fetchEvents(range:)` per timeline rebuild (visible month), grouped in memory; card views receive value structs. No `@Query` in views, no per-card fetches.

**Rationale**: ≤ ~240 events per month is trivial for a single indexed-by-nothing fetch; keeps FR/SC scroll-smoothness by construction and matches the VM-derivation architecture (Constitution VIII).
