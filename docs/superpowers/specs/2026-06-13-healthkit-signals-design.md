# HealthKit Signals — Design Spec

**Date:** 2026-06-13 · *Daylio competitive review folded in 2026-06-25 (see §12).*
**Status:** Design approved (architecture + scope confirmed); detailed decisions made autonomously — see **Assumptions** for anything to veto. Non-Goals re-examined against Daylio research — see §1 and §12.
**Scope:** Read sleep, activity, heart, and menstrual-cycle data from Apple Health, mirror it into a new day-keyed SwiftData model, and let the user view and manually edit every signal — including when HealthKit has no data.

---

## 1. Goal & Non-Goals

### Goal
Give app-four four passive health **signals** — sleep, activity, heart, menstrual cycle — sourced from Apple Health when available and editable by hand when not, so they can later be correlated with mood/energy/focus in Insights.

### Non-Goals (explicitly out of scope for this spec)
Each non-goal now carries a rationale line cross-checked against Daylio (the market-leading mood tracker with an Apple Health integration — see §12).

- **HKStateOfMind / mood import.** Deferred. Mood stays exact-match lexicon + check-in. *Rationale (validated):* Daylio does **not** import mood from Health either — it keeps its own scale. Confirms our posture. A future *write* of our mood → `HKStateOfMind` is a separate opportunity (see "Future opt-in writes" below), not a v1 import.
- **Background delivery / `HKObserverQuery` / `BGProcessingTask`.** v1 reads on-open and on manual refresh only. Background sync is a named follow-up. *Rationale (validated):* Daylio also syncs on-open/import-pull; our on-open + pull-to-refresh matches the market norm.
- **Writing back to HealthKit.** v1 is read + local manual entry. We do not push manual values into Apple Health (revisit for menstrual flow later). *Rationale (validated):* even Daylio does **not** meaningfully write back — secondary sources claiming it does conflate Daylio with Apple's own Journal app (see §12 cross-check). So broad write-back is not table-stakes; the two narrow Apple-native writes worth considering are listed below.
- **Correlation analytics / new Insights charts.** This spec lands the data + entry + a minimal day view. Wiring signals into the Insights correlation cards is a separate spec. *Rationale + priority bump:* this is **Daylio's single biggest differentiator** ("Influence on Mood" — see §12). It is the highest-value follow-up and should be the **next spec** (see §11).
- **Widgets, notifications, server sync.** None. Health data never leaves the device. *Rationale (validated):* matches Daylio's on-device, never-shared-with-advertisers stance.

#### Future opt-in writes (Apple-native) — out of scope here, named for the roadmap
These are the *only* write candidates the Daylio research surfaced as worthwhile. Both are **opt-in**, on-device, and sequenced **after** the Insights-correlation spec — not part of any near-term release:
- **Check-in → Mindful Minutes** (`HKCategoryType(.mindfulSession)`). The Apple Journal pattern: log time spent on a check-in as a mindful session. Small, privacy-safe, high familiarity.
- **Mood → `HKStateOfMind`.** Write the user's logged mood to Apple Health so iOS's *own* State-of-Mind correlations (exercise, sleep, daylight, mindful minutes) light up. This is the Apple-native counterpart to the import we're declining.

Either would add `NSHealthUpdateUsageDescription` and the corresponding share/write entitlement — neither exists today (v1 is read-only).

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

> **Reconciled to shipped code 2026-06-25.** No `@Attribute(.unique)`; every attribute is optional or defaulted (CloudKit-compatible, Constitution IX). One-row-per-day is enforced by `SignalsStore.upsert` (fetch-by-day then insert), **not** by the schema. Sleep stores `sleepLevelValue` (raw `SleepLevel`, the 5-step restless…deep scale), not a `sleepQuality` string.

```swift
@Model
final class DailySignals {
    /// Start-of-day in the user's calendar — the logical per-day key (non-unique).
    var dayStart: Date = Date.distantPast
    var updatedAt: Date = Date()

    // --- Sleep ---
    var sleepHours: Double? = nil
    var sleepLevelValue: String? = nil   // raw value of SleepLevel (restless…deep)
    var sleepSource: SignalSource = SignalSource.none

    // --- Activity ---
    var steps: Int? = nil
    var activeEnergyKcal: Double? = nil
    var exerciseMinutes: Int? = nil
    var activitySource: SignalSource = SignalSource.none

    // --- Heart ---
    var restingHeartRate: Double? = nil  // bpm
    var hrvSDNN: Double? = nil           // ms (stress proxy)
    var heartSource: SignalSource = SignalSource.none

    // --- Menstrual cycle ---
    var menstrualFlow: MenstrualFlow? = nil
    var cycleSymptomsJSON: String? = nil // [String] encoded; symptom tags
    var cycleSource: SignalSource = SignalSource.none

    var isMockData: Bool = false

    init(dayStart: Date) { self.dayStart = dayStart; self.updatedAt = Date() }
}

extension DailySignals {
    // Bridges over the stored raw values — used by views/coordinator.
    var sleepLevel: SleepLevel? { get { … } set { … } }   // ↔ sleepLevelValue
    var cycleSymptoms: [String] { get { … } set { … } }   // ↔ cycleSymptomsJSON
}
```

**No unique constraint by design.** SwiftData `@Attribute(.unique)` is incompatible with CloudKit sync (Constitution IX), so `dayStart` is a plain (defaulted) attribute and idempotency lives in `SignalsStore.upsert`. All attributes are defaulted for the same CloudKit reason.

**Provenance is per *signal group*, not per scalar field.** Sleep is one provenance unit (`sleepSource`), activity another, etc. Rationale: a signal group is filled or edited as a unit (you don't import steps from Health but active-energy by hand). Four source fields instead of nine keeps the merge rule legible. Documented as **Assumption A1** — easy to split later if a field needs independent provenance.

### 3.2 Value types

```swift
enum SignalSource: String, Codable, Sendable {
    case none        // never populated
    case healthKit   // mirrored from Apple Health
    case manual      // user entered/edited — HealthKit will not overwrite
}

enum MenstrualFlow: String, Codable, Sendable, CaseIterable {
    case light, medium, heavy, spotting
    // No `.none` case — "no flow" is represented by `menstrualFlow == nil`.
    // Maps to/from HKCategoryValueVaginalBleeding (light/medium/heavy) in
    // HealthKitServiceImpl only; `spotting` is a manual-entry value with no
    // distinct HealthKit case.
}
```

Cycle symptoms are stored as a JSON `[String]` (`cycleSymptomsJSON`) following the codebase's existing `*JSON` convention (e.g. `sleepEventJSON`, `feelingsJSON`) rather than a relationship — symptoms are a small unordered tag set, never queried independently.

### 3.3 Schema registration

`DailySignals.self` is registered in both `Schema([...])` arrays (production + preview) in [AppModelContainer.swift](app-four/App/AppModelContainer.swift#L9-L16) ✅. The existing wipe-on-schema-conflict path covers dev. **No production migration is needed yet** (no shipped store). A lightweight migration must be authored before first App Store ship — noted as a follow-up, not a v1 task.

### 3.4 Relationship to existing sleep on `Recording`

`Recording.sleepHours / sleepQuality / sleepLevelValue / sleepEventJSON` **stay as they are.** They represent "sleep mentioned in this note." `DailySignals` is the day's truth.

**One-way, optional bridge (Assumption A2) — NOT YET IMPLEMENTED (deferred follow-up, plan task T034):** when a check-in note for a given day produces a sleep value and that day's `DailySignals.sleepSource == .none`, seed the day's `sleepHours`/`sleepLevel` from the note and set `sleepSource = .manual`. The note never overwrites a day that already has HealthKit or manual sleep. This would keep today's manual sleep-entry behavior working end-to-end while `DailySignals` becomes the dashboard's source. Shipped v1 does **not** include this bridge; it can be added later without affecting the rest of the design.

---

## 4. Authorization & Read Flow

### 4.1 Types requested (read-only)

| Signal | HealthKit types |
|--------|-----------------|
| Sleep | `HKCategoryType(.sleepAnalysis)` |
| Activity | `HKQuantityType(.stepCount)`, `.activeEnergyBurned`, `.appleExerciseTime` |
| Heart | `HKQuantityType(.restingHeartRate)`, `.heartRateVariabilitySDNN` |
| Cycle | `HKCategoryType(.menstrualFlow)` + a small fixed set of symptom category types (cramps, headache, mood changes, etc.) |

### 4.2 Entitlement & Info.plist (done in v1)
- **HealthKit** capability added → `app-four.entitlements` with `com.apple.developer.healthkit` ✅.
- `NSHealthShareUsageDescription` added to [Info.plist](app-four/Info.plist) (read) ✅. No `NSHealthUpdateUsageDescription` in v1 (no writes) — it would be added only if a "Future opt-in write" (§1) ships.

### 4.3 Read mechanics
- Modern async queries: `HKSampleQueryDescriptor` / `HKStatisticsQueryDescriptor` with `.result(for: store)`.
- Sleep: sum `asleep*` + `inBed` category samples per day into hours; derive a coarse `sleepLevel` (5-step `SleepLevel`) from **sleep efficiency = asleepHours / inBedHours** via fixed buckets in `HealthKitSampleMapping.sleepLevel` (`<0.70` restless · `<0.80` light · `<0.88` okay · `<0.94` good · else deep). Returns nil when there's no in-bed reference (Assumption A3 fallback).
- Activity/heart: daily statistics (sum for steps/energy/exercise; average for resting HR/HRV).
- Cycle: `menstrualFlow` mapped via `HealthKitSampleMapping.flow` from `HKCategoryValueVaginalBleeding` (only graded light/medium/heavy; unspecified/none → nil) + a fixed symptom set (cramps, headache, mood changes, fatigue, back pain).

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
- Sleep section uses the named 5-step `SleepLevel` scale (restless/light/okay/good/deep) plus an hours stepper/field — this is where today's manual sleep entry moves to, preserving the current capability.
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
- **A2** — Optional one-way bridge: a check-in note's sleep can seed a day with no existing sleep (sets `.manual`); never overwrites HK/manual. *(Deferred — not in shipped v1; plan task T034.)*
- **A3** — `sleepLevel` (5-step) is derived from a **sleep-efficiency** heuristic (asleepHours / inBedHours); fallback is import-without-level when there's no in-bed reference.
- **A4** — First-grant backfill window = 30 days.
- **A5** — Clearing a `.manual` field to empty resets it to `.none`, re-enabling HealthKit fill.
- **A6** — Only sleep renders through the existing 5-step `SignalLevel` bead grammar in v1; activity/heart/cycle render as plain values.
- **A7** — No write-back to HealthKit in v1 (read + local manual only). *Reaffirmed by Daylio research (§12); two Apple-native opt-in writes are named for the roadmap under §1 "Future opt-in writes."*
- **A8** — All four signals are built end-to-end (read + manual + minimal display) in this spec, per scope confirmation.

---

## 11. Out-of-spec follow-ups (named, not built)
*Ordered by priority after the Daylio review (§12). #1 is the recommended next spec.*
1. **Insights correlation cards consuming `DailySignals`** — Daylio's flagship value. Adopt the "Influence on Mood" pattern: a **confidence level** (Low/Medium/High by data richness) plus **same-day / previous-day / next-day** comparisons. `DailySignals` already stores the per-day data this needs. **Recommended next spec.**
2. Production SwiftData migration before first App Store ship.
3. Background delivery (`HKObserverQuery` + background entitlement + `BGProcessingTask`).
4. **Apple-native opt-in writes** (after #1): check-in → Mindful Minutes; mood → `HKStateOfMind`. See §1 "Future opt-in writes."
5. Write-back of manual signals to HealthKit (esp. menstrual flow) — lower priority; not a Daylio behavior.
6. Signal data in PDF/CSV export (Daylio offers this; minor).

---

## 12. Competitive analysis: Daylio (added 2026-06-25)

Daylio is the market-leading mood tracker with an Apple Health integration. We reviewed it to pressure-test our scope. **Net: the research mostly *validates* our existing choices and sharpens the follow-up priority order — it did not move us to widen v1.**

### 12.1 How Daylio connects
- **Opt-in HealthKit**, connected from Daylio's settings; standard iOS permission sheet. Privacy policy: *"If you grant the app access to Apple Health, the app will import your data from Apple Health into the Application."*
- The integration is an **import/pull** into Daylio's local store. (Daylio's permission prompt requests read **and** write, but the write side appears vestigial — see the cross-check in §12.4.)

### 12.2 What data Daylio uses
- Reads exactly **three** signals: **steps, sleep, exercise time** — Daylio's own words: *"It pulls in your steps, sleep, and exercise time to help you see how they influence your mood."*
- Core model is **manual**: 5-point mood + tagged activities (≈2-tap entry), plus newer **Scales** (sliders for sleep, stress, energy, pain). Health data is layered on as objective context to correlate against mood.
- **Where app-four already leads:** we read **four** groups (sleep, activity, heart **+ HRV**, **menstrual cycle**) and carry a **provenance/merge model** (`SignalSource.none/healthKit/manual`) Daylio doesn't expose. Our read+mirror+manual-edit foundation is already richer than Daylio's read side.

### 12.3 How Daylio displays it — the differentiator
- **"Influence on Mood"** is the flagship stat: a **confidence level** (Low/Medium/High, by data richness) plus four comparisons — *with vs. without* the activity, *Previous Day*, *Same Day*, *Next Day*.
- Plus mood-colored **frequency charts**, **Year in Pixels**, **Mood Count**, **Related Activities** (%), **Occurrence During Week**, **Longest Period**.
- Health data is also addable to filterable **PDF/CSV exports**.
- **Takeaway:** Daylio's entire value lives in the **correlation layer**, which for us is the deferred *Insights correlation* work. That is the single highest-value thing to adopt → promoted to the **recommended next spec** (§11.1).

### 12.4 Cross-check note (don't re-derive this)
Several secondary sources claim Daylio **writes** mood / "mindful minutes" / "State of Mind" to Apple Health. **This is a conflation with Apple's own Journal app and is not supported by any first-party Daylio source.** Evidence:
- Daylio's own messaging and privacy policy describe the integration purely as **import/pull** ("pulls in," "import your data from Apple Health"). Nothing first-party says Daylio writes.
- The "mindful minutes" / "State of Mind" language traces to **Apple Support docs for Apple's Journal and Health apps**, not Daylio — search engines merged the two.
- The "read **and** write permission" troubleshooting note is **generic HealthKit behavior**: iOS doesn't expose read-authorization status, so apps request broadly and tell users to flip every toggle. Not evidence of active write-back.

**Consequence:** the "reconsider write-back" question reframes to "should *we* adopt the **Apple Journal** write pattern?" — captured as the two opt-in, post-Insights candidates in §1, not as v1 scope.

### 12.5 Privacy parity
Daylio: imported health data *"stored only locally… all calculations are done on your device,"* and *"never shared with third parties… or advertisers."* This matches app-four's on-device, no-server, no-ads posture (§9) — no gap to close.

### Sources
- Daylio on Apple Health (steps/sleep/exercise): https://x.com/hellodaylio/status/1939796586399141963
- Daylio FAQ / Apple Health troubleshooting: https://faq.daylio.net/article/103-apple-health-troubleshooting · https://daylio.net/faq/docs/daylio-faq/
- Activity & Mood Statistics: https://daylio.net/faq/docs/daylio-faq/about/activity-and-mood-statistics/
- Daylio Privacy Policy: https://daylio.net/faq/privacy-policy/
- App Store listing: https://apps.apple.com/us/app/daylio-journal-mood-tracker/id1194023242
- Apple (basis for the §12.4 conflation cross-check): https://support.apple.com/guide/iphone/log-your-state-of-mind-iph6a6decb13/ios · https://support.apple.com/guide/iphone/journal-for-your-wellbeing-iph7b79617d5/ios
