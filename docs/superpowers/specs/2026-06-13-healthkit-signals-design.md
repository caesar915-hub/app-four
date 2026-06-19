# HealthKit Signals — Design Spec

**Date:** 2026-06-13
**Status:** Design approved (architecture + scope confirmed); detailed decisions made autonomously — see **Assumptions** for anything to veto.
**Scope:** Read sleep, activity, heart, and menstrual-cycle data from Apple Health, mirror it into a new day-keyed SwiftData model, and let the user view and manually edit every signal — including when HealthKit has no data.

---

## 1. Goal & Non-Goals

### Goal
Give app-four four passive health **signals** — sleep, activity, heart, menstrual cycle — sourced from Apple Health when available and editable by hand when not, so they can later be correlated with mood/energy/focus in Insights.

### Non-Goals (explicitly out of scope for this spec)
- **HKStateOfMind / mood import.** Deferred. Mood stays exact-match lexicon + check-in.
- **Background delivery / `HKObserverQuery` / `BGProcessingTask`.** v1 reads on-open and on manual refresh only. Background sync is a named follow-up.
- **Writing back to HealthKit.** v1 is read + local manual entry. We do not push manual values into Apple Health (revisit for menstrual flow later).
- **Correlation analytics / new Insights charts.** This spec lands the data + entry + a minimal day view. Wiring signals into the Insights correlation cards is a separate spec.
- **Widgets, notifications, server sync.** None. Health data never leaves the device.

---

## 2. Architecture

HealthKit is a **source**, never the source of truth. SwiftData (`DailySignals`) is the source of truth. Exactly one type imports `HealthKit`.

```
Apple Health ──(read)──▶ HealthKitService ──DTOs──▶ SignalSyncCoordinator ──merge──▶ DailySignals (SwiftData)
   (HKHealthStore)        (actor, only HK            (@MainActor, provenance        (one row / calendar day,
                           importer)                  merge rule)                    source of truth)
                                                            ▲                              │
 Day Signals Editor (manual) ───────────────────────────────┘                              ▼
   (sheet + view model)                                                       Day / Insights read views
```

### Components (each independently testable)

1. **`HealthKitService`** — `actor`, conforms to `HealthDataReading`. The only file that imports HealthKit. Responsibilities: authorization request, availability check, per-signal reads returning **DTOs** (no `HKSample` escapes). Mockable via the protocol exactly like the existing service protocols.
2. **`SignalSyncCoordinator`** — `@MainActor`. Takes DTOs (never `HKObject`), applies the provenance merge rule, upserts `DailySignals` rows via `ModelContext`. Holds zero HealthKit knowledge → fully unit-testable without HealthKit or a simulator.
3. **`DailySignals`** — `@Model`, one row per calendar day. Source of truth. Per-field value + per-field source enum.
4. **`DaySignalsEditorViewModel` + `DaySignalsEditorSheet`** — manual view/edit/override of one day's signals.
5. **`SignalsStore`** (thin) — fetch/upsert helper around `ModelContext` for `DailySignals`, mirroring the existing `RecordingStore` pattern, so views/VMs don't touch `ModelContext` directly.

### Why this boundary
- Quarantining the `import HealthKit` in one actor means components 2–5 test with plain values — no `HKHealthStore`, no "simulator has no Health data" problem.
- It slots into the existing DI (`protocol → impl → AppDependencies → AppServices → @Environment`) with **zero refactor**. `HealthKitService` is added to `AppServices`; a `MockHealthDataReading` is added to `MockAppServices`.
- The dashboard reads SwiftData only, so HealthKit permission state never gates rendering. Denied permission is indistinguishable from "no data" (Apple's design) and we treat both as "show manual entry."

---

## 3. Data Model

### 3.1 `DailySignals` (`@Model`)

One row per local calendar day, identified by a normalized day key.

```swift
@Model
final class DailySignals {
    // `dayStart` is the start-of-day in the user's current calendar/timezone,
    // used as the stable identity. @Attribute(.unique) prevents duplicate rows per day.
    @Attribute(.unique) var dayStart: Date
    var updatedAt: Date

    // --- Sleep ---
    var sleepHours: Double?
    var sleepQuality: String?          // reuses existing poor|okay|good vocabulary
    var sleepSource: SignalSource

    // --- Activity ---
    var steps: Int?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Int?
    var activitySource: SignalSource

    // --- Heart ---
    var restingHeartRate: Double?      // bpm
    var hrvSDNN: Double?               // ms (stress proxy)
    var heartSource: SignalSource

    // --- Menstrual cycle ---
    var menstrualFlow: MenstrualFlow?
    var cycleSymptomsJSON: String?     // [String] encoded; symptom tags
    var cycleSource: SignalSource

    var isMockData: Bool = false

    init(dayStart: Date, updatedAt: Date = .now) {
        self.dayStart = dayStart
        self.updatedAt = updatedAt
        self.sleepSource = .none
        self.activitySource = .none
        self.heartSource = .none
        self.cycleSource = .none
    }
}
```

**Provenance is per *signal group*, not per scalar field.** Sleep is one provenance unit (`sleepSource`), activity another, etc. Rationale: a signal group is filled or edited as a unit (you don't import steps from Health but active-energy by hand). Four source fields instead of nine keeps the merge rule legible. Documented as **Assumption A1** — easy to split later if a field needs independent provenance.

### 3.2 Value types

```swift
enum SignalSource: String, Codable, Sendable {
    case none        // never populated
    case healthKit   // mirrored from Apple Health
    case manual      // user entered/edited — HealthKit will not overwrite
}

enum MenstrualFlow: String, Codable, Sendable, CaseIterable {
    case none, light, medium, heavy, spotting
    // maps to/from HKCategoryValueMenstrualFlow in HealthKitService only
}
```

Cycle symptoms are stored as a JSON `[String]` (`cycleSymptomsJSON`) following the codebase's existing `*JSON` convention (e.g. `sleepEventJSON`, `feelingsJSON`) rather than a relationship — symptoms are a small unordered tag set, never queried independently.

### 3.3 Schema registration

Add `DailySignals.self` to both `Schema([...])` arrays in [AppModelContainer.swift](app-four/App/AppModelContainer.swift#L9-L16). The existing `#if DEBUG` wipe-on-schema-conflict path covers dev. **No production migration is needed yet** (no shipped store). A lightweight migration must be authored before first App Store ship — noted as a follow-up, not a v1 task.

### 3.4 Relationship to existing sleep on `Recording`

`Recording.sleepHours / sleepQuality / sleepLevelValue / sleepEventJSON` **stay as they are.** They represent "sleep mentioned in this note." `DailySignals` is the day's truth.

**One-way, optional bridge (Assumption A2):** when a check-in note for a given day produces a sleep value and that day's `DailySignals.sleepSource == .none`, seed the day's `sleepHours/sleepQuality` from the note and set `sleepSource = .manual`. The note never overwrites a day that already has HealthKit or manual sleep. This keeps today's manual sleep-entry behavior working end-to-end ("add it still as is implemented today") while `DailySignals` becomes the dashboard's source. If this bridge feels like scope creep, it can be dropped without affecting the rest of the design.

---

## 4. Authorization & Read Flow

### 4.1 Types requested (read-only)

| Signal | HealthKit types |
|--------|-----------------|
| Sleep | `HKCategoryType(.sleepAnalysis)` |
| Activity | `HKQuantityType(.stepCount)`, `.activeEnergyBurned`, `.appleExerciseTime` |
| Heart | `HKQuantityType(.restingHeartRate)`, `.heartRateVariabilitySDNN` |
| Cycle | `HKCategoryType(.menstrualFlow)` + a small fixed set of symptom category types (cramps, headache, mood changes, etc.) |

### 4.2 Entitlement & Info.plist (greenfield — none exist today)
- Add **HealthKit** capability → creates `app-four.entitlements` with `com.apple.developer.healthkit`.
- Add `NSHealthShareUsageDescription` to [Info.plist](app-four/Info.plist) (read). No `NSHealthUpdateUsageDescription` in v1 (no writes).

### 4.3 Read mechanics
- Modern async queries: `HKSampleQueryDescriptor` / `HKStatisticsQueryDescriptor` with `.result(for: store)`.
- Sleep: sum `asleep*` category samples per day into hours; derive a coarse `sleepQuality` heuristic from stage mix / fragmentation (Assumption A3 — heuristic, documented; can be "imported, no quality" if preferred).
- Activity/heart: daily statistics (sum for steps/energy/exercise; average for resting HR/HRV).
- Cycle: category samples mapped to `MenstrualFlow` + symptom tags.

### 4.4 Sync trigger (v1: read-on-open + manual refresh)
- On dashboard `task`/`onAppear`: `SignalSyncCoordinator.sync(lastNDays:)`.
- Pull-to-refresh re-runs the same sync.
- First grant backfills last **30 days** (Assumption A4).
- No background delivery, no BGTask.

---

## 5. Provenance Merge Rule (HealthKit-wins-unless-edited)

For each signal group on a day, when sync brings a HealthKit DTO:

```
switch existing source:
  .none      → write HK values, set source = .healthKit
  .healthKit → overwrite with fresh HK values (re-sync), keep source = .healthKit
  .manual    → DO NOT TOUCH (user edit is sticky)
```

Manual entry always sets `source = .manual`. A manual field thus survives every subsequent sync. The user can re-clear a field; clearing a `.manual` field back to empty sets it to `.none`, which makes it eligible for HealthKit fill again on the next sync (Assumption A5).

This is the single place the rule lives — `SignalSyncCoordinator`. It is the most heavily unit-tested unit (table-driven over the three source states × has/has-no HK value × has/has-no manual value).

---

## 6. UI

> Per CLAUDE.md, any **new** SwiftUI view requires an HTML mockup for approval **before** the SwiftUI is written. The mockups are a gate inside the implementation plan, not this spec. This section defines behavior and structure only.

### 6.1 Day Signals Editor (new sheet)
- Opened from a day (tap) or an "Add / edit signals" affordance.
- One sheet, four sections (Sleep, Activity, Heart, Cycle). Each field shows its value and a **source indicator**: "From Apple Health" vs "Added by you," with an edit/override control. Editing any field flips that group to `.manual`.
- Sleep section reuses the existing poor/okay/good chip vocabulary plus an hours stepper/field — this is where today's manual sleep entry moves to, preserving the current capability.
- Heart fields are effectively read-only in practice (no one hand-logs resting HR) but remain editable for completeness; the UI de-emphasizes manual heart entry.

### 6.2 Read surface (minimal in v1)
- A compact per-day signals summary (the four groups with values + source glyphs), shown where a day is viewed. Full Insights correlation rendering is a later spec.
- Sleep can render through the existing `SignalLevel` 5-step bead grammar (via `SleepLevel`). Activity/heart/cycle do **not** force-fit the 5-step ordinal in v1; they render as plain values/labels (Assumption A6).

### 6.3 Permission UX
- A one-time, contextual primer before the system HealthKit sheet (explain what's read and that it's on-device only), then the standard authorization sheet.
- If denied or no data: the editor simply shows empty, manually-fillable fields. No nag, no broken state. Core app flows never gate on HealthKit.

---

## 7. Dependency Injection wiring

- New protocol `HealthDataReading: Sendable` (authorization + per-signal reads returning DTOs).
- `HealthKitServiceImpl: HealthDataReading` (`actor`, imports HealthKit).
- Add `healthService: HealthDataReading` to [AppServices](app-four/Store/AppServices.swift) and construct it in [AppDependencies](app-four/Store/AppDependencies.swift).
- `SignalSyncCoordinator` constructed at the composition root with the `mainContext` (mirrors `RecordingStore`/`MedicationBarViewModel`).
- Add `MockHealthDataReading` to `MockAppServices` returning canned DTOs.

---

## 8. Testing Strategy

| Unit | What's tested | How |
|------|---------------|-----|
| `SignalSyncCoordinator` | Provenance merge rule (the core risk) | Table-driven unit tests over source × HK × manual; in-memory `ModelContainer`. No HealthKit. |
| `DailySignals` + `SignalsStore` | Upsert-by-day, uniqueness, JSON round-trips | In-memory container. |
| DTO ↔ model mapping | `MenstrualFlow`/symptom encode/decode, day-key normalization across timezones | Pure value tests. |
| `HealthKitServiceImpl` | Auth request shape, type set, DTO mapping from sample fixtures | Thin; `HKHealthStore` not unit-tested (integration/manual on device). The mapping functions are pulled out as pure funcs and tested with synthetic samples. |
| `DaySignalsEditorViewModel` | Edit flips source to `.manual`; clearing resets to `.none`; save persists | `MockHealthDataReading` + in-memory container. |

`HKHealthStore` itself is not unit-testable; real reads are verified by **manual device testing** (simulator lacks Health data) — called out in the plan's verification steps.

---

## 9. Risks & Mitigations
- **Simulator has no Health data** → all automated tests use mocks/DTOs; device test is a manual verification step.
- **Spurious correlations with small n** → not a v1 concern (no correlation UI ships here); flagged for the future Insights spec.
- **Sleep-quality heuristic may be wrong** → A3 isolates it; can degrade to "no quality from HealthKit."
- **Timezone/day-boundary bugs** → `dayStart` normalization is centralized and unit-tested across timezones.
- **App Review (Health data)** → no ads/marketing use, no off-device transmission; usage string is explicit. Store excluded from iCloud backup already (existing behavior in AppModelContainer).

---

## 10. Assumptions (made autonomously — veto any)

- **A1** — Provenance tracked per signal *group* (4 sources), not per scalar field.
- **A2** — Optional one-way bridge: a check-in note's sleep can seed a day with no existing sleep (sets `.manual`); never overwrites HK/manual.
- **A3** — `sleepQuality` is derived from a stage/fragmentation heuristic; fallback is import-without-quality.
- **A4** — First-grant backfill window = 30 days.
- **A5** — Clearing a `.manual` field to empty resets it to `.none`, re-enabling HealthKit fill.
- **A6** — Only sleep renders through the existing 5-step `SignalLevel` bead grammar in v1; activity/heart/cycle render as plain values.
- **A7** — No write-back to HealthKit in v1 (read + local manual only).
- **A8** — All four signals are built end-to-end (read + manual + minimal display) in this spec, per scope confirmation.

---

## 11. Out-of-spec follow-ups (named, not built)
1. Background delivery (`HKObserverQuery` + background entitlement + `BGProcessingTask`).
2. Insights correlation cards consuming `DailySignals`.
3. Write-back to HealthKit (esp. menstrual flow).
4. Production SwiftData migration before first App Store ship.
5. HKStateOfMind / mood import (separate track).
