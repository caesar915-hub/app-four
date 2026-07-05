# Data Model: Nutrition & Exercise Signals on the Day Card (Demo)

## New: `NutritionEvent` (SwiftData `@Model`)

One row per food or exercise event. Standalone — no relationships; days are joined by date range using the existing `SignalDayKey` convention. CloudKit-compatible per Constitution IX: every attribute optional or defaulted, no `@Attribute(.unique)`.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `startDate` | `Date` | `.distantPast` | Event time; drives timeline position and day membership |
| `endDate` | `Date?` | `nil` | Workouts only (duration display derives from it or `durationMinutes`) |
| `kindValue` | `String` | `"food"` | Raw of `NutritionEventKind` (`food` \| `exercise`) — string-raw enum bridged via computed property, same pattern as `DailySignals.sleepLevelValue` |
| `name` | `String?` | `nil` | Meal name from `HKMetadataKeyFoodType` / workout activity name; `nil` → UI shows "Food" / "Workout" |
| `kcal` | `Double?` | `nil` | Food: dietary energy consumed. Exercise: active energy burned (from `statistics(for:)`) |
| `proteinGrams` | `Double?` | `nil` | Food only |
| `caffeineMg` | `Double?` | `nil` | Food only |
| `durationMinutes` | `Double?` | `nil` | Exercise only |
| `sourceValue` | `String` | `SignalSource.healthKit.rawValue` | Reuses existing `SignalSource` enum (`healthKit` \| `manual`; `none` unused here) |
| `isMockData` | `Bool` | `false` | Existing partition convention (Constitution IX) |
| `updatedAt` | `Date` | `Date()` | Sync bookkeeping |

**Validation rules** (enforced in code, not schema):
- A food event SHOULD have at least one of `kcal` / `proteinGrams` / `caffeineMg`; the grouping mapper never emits an empty event.
- An exercise event SHOULD have `durationMinutes` and/or `kcal`.
- `startDate` determines day membership via `SignalDayKey.dayStart(for:calendar:)` — an event at 23:58 belongs to that day (spec edge case).

**Lifecycle / state transitions**:
- **Created** by sync (`source == .healthKit, isMockData == false`) or by mock seeding (`source == .healthKit, isMockData == true`).
- **Replaced** on re-sync: per day, all `source == .healthKit && isMockData == false` rows are deleted and re-inserted (research D6). Mock rows are only deleted by the generator's own re-seed path.
- **Never edited** in this feature (read-only surface, FR-013). `source == .manual` is reserved for the deferred editor.

## Unchanged: `DailySignals`

No new fields. Explicitly NOT the source for the totals footer (research D5): `activeEnergyKcal` in the Activity group remains a per-day aggregate for the 009 Insights surface only.

## Derived (in-memory, not persisted)

### `NutritionEventKind`
`enum NutritionEventKind: String, Codable, Sendable { case food, exercise }` — lives beside the model, mirrors `SignalSource` conventions.

### `NutritionEventDTO` (Sendable, service boundary)
`{ kind, startDate, endDate?, name?, kcal?, proteinGrams?, caffeineMg?, durationMinutes? }` — produced by `HealthKitServiceImpl`, consumed by `SignalSyncCoordinator`. No SwiftData or HealthKit types cross the seam (existing 009 rule).

### `DayNutrition` (VM value type)
`{ events: [NutritionEventItem], summary: NutritionSummary }` where `NutritionEventItem` is a plain value snapshot of a `NutritionEvent` (no `@Model` in views) and:

```
NutritionSummary {
  kcalIn:     Double?   // Σ food.kcal
  proteinG:   Double?   // Σ food.proteinGrams
  caffeineMg: Double?   // Σ food.caffeineMg
  kcalOut:    Double?   // Σ exercise.kcal  ← workouts only (Clarification Q3)
  source:     SignalSource  // .healthKit unless any contributing event is .manual
}
```
Each Σ is `nil` (renders "—") when no contributing event carries that metric.

### `TimelineDay` extension
`MoodLibraryViewModel.TimelineDay` gains `let nutrition: DayNutrition?`. Interleaving rule: food/exercise items merge-sort with `nodes` by time using the existing row ordering convention; rendering stays in the view layer.

## Real-wins-per-day resolution (research D7)

Given a day key `d` with fetched events `E(d)`:
- mock mode OFF → use `E(d).filter { !$0.isMockData }`
- mock mode ON → if any real event exists in `E(d)` → real events only; else mock events only

Never mixed within a day.
