# Interface Contracts: Nutrition & Exercise Signals on the Day Card (Demo)

Contracts follow the 009 stack's layering. Types referenced here are defined in [data-model.md](../data-model.md).

## 1. Service seam — `HealthDataReading` (EDIT)

```swift
protocol HealthDataReading: Sendable {
    // existing: authorizationState(), requestAuthorization(), readSignals(from:to:)
    /// Timestamped food + workout events for each day in [startDay, endDay] inclusive.
    /// Food: HKCorrelation .food groups first (name from HKMetadataKeyFoodType),
    /// then loose dietary samples bucketed per clock hour. Exercise: HKWorkouts
    /// (duration + statistics(for: .activeEnergyBurned)). Never throws for "no data";
    /// denial is indistinguishable from empty (existing HK read-auth semantics).
    func readNutritionEvents(from startDay: Date, to endDay: Date) async throws -> [NutritionEventDTO]
}
```

**Implementation contract** (`HealthKitServiceImpl`, actor):
- `readTypes` grows by: `.dietaryEnergyConsumed`, `.dietaryProtein`, `.dietaryCaffeine` quantity types + `HKObjectType.workoutType()` (research D4).
- Queries via `HKSampleQueryDescriptor` with `.correlation(type:predicate:)`, `.workout(_:)`, `.quantitySample(type:predicate:)` (research D2).
- A dietary sample contained in a fetched food correlation MUST NOT also produce a loose-sample event (no double counting).
- Units: kcal `.kilocalorie()`, protein `.gram()`, caffeine `.gramUnit(with: .milli)`.
- `requestAuthorization` stays read-only (`toShare: []`).

## 2. Pure mapper — `NutritionEventGrouping` (NEW)

HealthKit-free value logic, fully unit-testable (pattern: `HealthKitSampleMapping`):

```swift
enum NutritionEventGrouping {
    /// Buckets loose (non-correlated) dietary values into one DTO per clock hour.
    static func hourlyFoodEvents(loose: [LooseDietarySample], calendar: Calendar) -> [NutritionEventDTO]
    /// Day totals from a day's events — footer + folded tokens derive from this.
    static func summary(for events: [NutritionEventItem]) -> NutritionSummary
}
```

- `summary` rules: Σ per metric over food events; `kcalOut` = Σ exercise kcal ONLY (Clarification Q3); each Σ nil when no contributor.
- `hourlyFoodEvents` never emits an event with all-nil metrics.

## 3. Store — `SignalsStore` (EDIT, +3 methods)

```swift
@MainActor @Observable final class SignalsStore {
    // existing: fetch(dayStart:), upsert(dayStart:), fetchRange(from:to:), save()
    func fetchEvents(from startDay: Date, to endDay: Date) -> [NutritionEvent]   // date-range predicate only
    /// Replace-per-day dedup (research D6): deletes source==.healthKit && !isMockData
    /// rows for the day, inserts fresh DTOs. Mock + manual rows untouched.
    func replaceHealthKitEvents(dayStart: Date, with dtos: [NutritionEventDTO])
    func insertMockEvent(_ event: NutritionEvent)                                 // seeding path
}
```

## 4. Coordinator — `SignalSyncCoordinator` (EDIT)

- `sync(from:to:)` additionally calls `reader.readNutritionEvents(from:to:)` and `store.replaceHealthKitEvents(dayStart:with:)` per day, inside the same single `store.save()`.
- The existing once-per-day gate (`syncRecentIfNeeded(lastDays: 30)`) covers events — no second gate, no new coordinator.
- Provenance rule for events is replace-not-merge (unlike per-day groups): manual rows are excluded from deletion by predicate, so `canWrite` does not apply.

## 5. ViewModel — `MoodLibraryViewModel` (EDIT)

```swift
init(store: RecordingStore, signalsStore: SignalsStore, /* existing params */)
struct TimelineDay { /* existing */ ; let nutrition: DayNutrition? }
func loadNutrition()   // fetch month range once, group by SignalDayKey, apply real-wins-per-day (research D7)
```

- Respects `debugMockMode` exactly like `loadMedicationEvents()`.
- Called in `init` and after coordinator sync completes.

## 6. UI contracts (approved mockups are the visual source of truth)

### `FoldedDayCardHeader` (EDIT) — mockup V3
- `parts` appends ≤2 tokens after energy/focus/med: `fork.knife` + "N kcal" and `cup.and.saucer.fill` + "N mg", color `Palette.nutritionFood`, weight 600, only when the day summary has those values.
- Combined `accessibilityLabel` appends "N calories eaten, N milligrams caffeine" (FR-011).

### `NutritionEventRow` (NEW) — mockup variant A
- 28pt hollow bead (1.5pt stroke, 12% tint fill) on the shared 38pt rail; `fork.knife` (food, clay) / `flame.fill` (exercise, teal); name in lane color at 14pt weight 600; values SF Mono 11.5pt with muted unit suffixes; time SF Mono right of name; NO chevron, not tappable (FR-013 — plain content, no button traits).
- VoiceOver: single combined element — "Lunch, 13:05, 780 kilocalories, 34 grams protein".

### `DayNutritionFooter` (NEW)
- Hairline top border, indented to rail content edge (50pt) when rows exist above, full-width when nutrition-only day; 4 metrics (`fork.knife` kcal · "P" g · `cup.and.saucer.fill` mg · `flame.fill` kcal) with "—" placeholders; trailing provenance glyph `heart.fill` (Apple Health) / `pencil` (manual) with accessibility label.

### `DayCard` (EDIT)
- Expansion gate: `isExpanded && (!day.nodes.isEmpty || day.nutrition != nil)` (FR-005).
- Expanded body interleaves `TimelineRow` + `NutritionEventRow` by time (merge order from VM), footer last.

### `CalendarLibraryView` (EDIT)
- VM init gains `AppDependencies.signalsStore`.
- `.task`: `if didOfferHealthAccess { await coordinator.syncRecentIfNeeded(lastDays: 30); viewModel.loadNutrition() }` — never presents the primer (FR-010).

## 7. Design system — `SquirlDesignSystem` (EDIT)

- `Palette.nutritionFood`: clay `#B5674A` light / `#CB8266` dark.
- `Palette.nutritionExercise`: teal `#3E8E86` light / `#5FAEA5` dark.
- DESIGN.md Decisions Log entry (owner-approved 2026-07-05, mockup Pair 2). No new `GlyphSignal` case.

## 8. Copy / configuration

- `Info.plist` `NSHealthShareUsageDescription`: extend list with "nutrition and workouts".
- `HealthAccessPrimerView` copy: same extension.
- `MockDataGenerator.generate(context:)` calls new `seedNutritionEvents(context:)` (research D11).

## 9. Sync control & deletion (US4, added 2026-07-05 — FR-015–FR-017)

- **Gate**: `SignalSyncCoordinator.sync(lastDays:)` / `syncRecentIfNeeded` return early (distinct disabled result, reader never called) when `UserDefaults "healthSyncEnabled"` is false; default true. One guard covers calendar, Insights, and pull-to-refresh.
- **Deletion**: `SignalsStore.deleteImportedHealthData()` — deletes `NutritionEvent` rows where `source == .healthKit && isMockData == false` AND clears HealthKit-sourced groups on `DailySignals` (fields → nil, group source → `.none`); `.manual` groups, manual rows, and mock rows untouched; single save.
- **UI**: "Apple Health" section in `SettingsView` (native grouped chrome, DESIGN.md 2026-06-24 exemption; mockup `docs/superpowers/plans/2026-07-05-health-settings-mockup.html`): `@AppStorage("healthSyncEnabled")` toggle, "Last sync" row (coordinator's last completed sweep), destructive delete with `confirmationDialog`, same dialog offered on toggle-off (default Keep), posts `.nutritionEventsDidChange` after delete, footer points to the Health app for permission revocation.

## 10. Test contracts (RED-first, Swift Testing)

| Test file | Proves |
|-----------|--------|
| `NutritionEventTests` | defaults (source healthKit, isMockData false, nils), kind bridging |
| `NutritionEventGroupingTests` | hourly bucketing (boundaries, no empty events), summary Σ rules incl. kcalOut=workouts-only and nil placeholders |
| `SignalsStoreEventTests` | range fetch; replace-per-day deletes only real+healthKit rows (mock/manual survive); insert idempotence across re-seed |
| `SignalSyncCoordinatorTests` (+cases) | events written in sweep; unavailable-auth short-circuits; replace on second sync (no duplicates) |
| `MockDataGeneratorNutritionTests` | 30-day window, ~2 skip days, determinism (two runs identical), caffeine↓ on med days, isMockData true |
| `MoodLibraryViewModelNutritionTests` | day grouping via SignalDayKey (23:58 edge), real-wins-per-day matrix (mock on/off × real present/absent), TimelineDay.nutrition mapping, summary in tokens |
| `MockHealthDataReading` (+stub) | `setNutritionEvents(_:)`, records requested range |
| `SignalSyncCoordinatorTests` (+US4 cases) | sync-disabled gate: reader never called, distinct result; resumes on re-enable |
| `SignalsStoreEventTests` (+US4 cases) | `deleteImportedHealthData`: real healthKit events + HK day-signal groups cleared; manual/mock survive |
