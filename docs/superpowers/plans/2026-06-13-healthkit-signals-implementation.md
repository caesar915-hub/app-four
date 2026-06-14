# HealthKit Signals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four passive health signals (sleep, activity, heart, menstrual cycle) sourced from Apple Health, mirrored into a day-keyed SwiftData model that the user can also edit by hand — including when HealthKit has no data.

**Architecture:** MVVM matching the existing app. HealthKit access is quarantined behind a `HealthDataReading` protocol implemented by one `actor` that returns Sendable DTOs. A `@MainActor SignalSyncCoordinator` applies a "HealthKit-wins-unless-edited" merge rule and upserts `DailySignals` rows. SwiftData is the source of truth; the UI never reads HealthKit directly.

**Tech Stack:** Swift 6.2 (strict concurrency), SwiftData, HealthKit, SwiftUI, Swift Testing (`@Test`/`#expect`), iOS 26.4 deployment target.

**Reference spec:** [2026-06-13-healthkit-signals-design.md](../specs/2026-06-13-healthkit-signals-design.md)

---

## Conventions (apply to every task)

- **Tests use Swift Testing**, not XCTest: `import Testing`, `@Test`, `#expect`, `@MainActor` on the test where it touches `ModelContext`. Match the existing `app-twoTests` suite if it already standardizes on one — check `app-twoTests/` before the first test and follow what's there. This plan assumes Swift Testing; if the suite is XCTest, translate `@Test func x()` → `func testX()` and `#expect(a == b)` → `XCTAssertEqual(a, b)`.
- **In-memory container for model/coordinator tests**: `ModelConfiguration(isStoredInMemoryOnly: true)`.
- **Never cross `ModelContext` or `@Model` instances across actors** (swiftdata-pro core rule). The HealthKit actor returns value-type DTOs only; the coordinator runs on `@MainActor` with the main context.
- **No `@unchecked Sendable`** (swift-concurrency-pro). DTOs are structs of value types → automatically `Sendable`.
- **Explicit `save()`** after mutations; do not check `hasChanges` first.
- **Enums stored in `@Model` conform to `Codable`** (and `Sendable`).
- **Commit after every green test.** Branch is `feat/healthkit-signals` (already created; spec already committed there).
- **Build/test command** (from memory `test-env-recovery`): the CLI needs `env -u GIT_CONFIG_*` and the erased simulator. Use:
  ```bash
  env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 \
    xcodebuild test -scheme app-two \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    -only-testing:app-twoTests/<SuiteName> 2>&1 | tail -40
  ```
  If the named simulator/scheme differs locally, list with `xcodebuild -list` and `xcrun simctl list devices available` and substitute. Real HealthKit reads are **device-only** (simulator has no Health data) — those are manual verification steps, flagged where they occur.

---

## File Structure

New files (grouped by feature, per project convention):

```
app-two/app-two/Models/
  DailySignals.swift              // @Model, source of truth (Task 1)
  SignalSource.swift              // enum (Task 1)
  MenstrualFlow.swift             // enum (Task 1)

app-two/app-two/Services/HealthKit/
  HealthSignalsDTO.swift          // Sendable DTOs + SignalDay key helper (Task 2)
  HealthDataReading.swift         // protocol (Task 3)
  HealthKitServiceImpl.swift      // actor, the ONLY HealthKit importer (Task 7)
  HealthKitSampleMapping.swift    // pure mapping funcs, unit-tested (Task 6)

app-two/app-two/Store/
  SignalsStore.swift              // upsert/fetch DailySignals by day (Task 4)
  SignalSyncCoordinator.swift     // provenance merge + sync orchestration (Task 5, 8)

app-two/app-two/ViewModels/
  DaySignalsEditorViewModel.swift // manual edit, flips source to .manual (Task 9)

app-two/app-two/Views/Signals/
  DaySignalsEditorSheet.swift     // editor UI (Task 11, after HTML mockup gate Task 10)
  DaySignalsSummaryView.swift     // compact read surface (Task 12)

app-twoTests/
  Mocks/MockHealthDataReading.swift   // canned DTOs (Task 3)
  DailySignalsTests.swift             // (Task 1)
  SignalDayKeyTests.swift             // timezone day-key (Task 2)
  SignalsStoreTests.swift             // (Task 4)
  SignalSyncCoordinatorTests.swift    // merge rule — the core risk (Task 5, 8)
  HealthKitSampleMappingTests.swift   // DTO mapping (Task 6)
  DaySignalsEditorViewModelTests.swift// (Task 9)
```

Modified files:
- `app-two/app-two/App/AppModelContainer.swift` — register `DailySignals.self` (Task 1).
- `app-two/app-two/Store/AppServices.swift` — add `healthService` (Task 3).
- `app-two/app-two/Store/AppDependencies.swift` — construct `HealthKitServiceImpl` + `SignalSyncCoordinator` (Task 7, 8).
- `app-twoTests/Mocks/MockAppServices.swift` — add `MockHealthDataReading` (Task 3).
- `app-two/app-two/Info.plist` — `NSHealthShareUsageDescription` (Task 7).
- `app-two/app-two.xcodeproj` — HealthKit capability + `.entitlements` (Task 7, manual Xcode step).

---

## Task 1: `DailySignals` model + value enums + schema registration

**Files:**
- Create: `app-two/app-two/Models/SignalSource.swift`
- Create: `app-two/app-two/Models/MenstrualFlow.swift`
- Create: `app-two/app-two/Models/DailySignals.swift`
- Modify: `app-two/app-two/App/AppModelContainer.swift` (two `Schema([...])` arrays)
- Test: `app-twoTests/DailySignalsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// app-twoTests/DailySignalsTests.swift
import Testing
import SwiftData
@testable import app_two

@MainActor
struct DailySignalsTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        return container.mainContext
    }

    @Test func newDayDefaultsToNoneSources() throws {
        let context = try makeContext()
        let day = DailySignals(dayStart: Date(timeIntervalSince1970: 0))
        context.insert(day)
        try context.save()

        #expect(day.sleepSource == .none)
        #expect(day.activitySource == .none)
        #expect(day.heartSource == .none)
        #expect(day.cycleSource == .none)
        #expect(day.sleepHours == nil)
    }

    @Test func dayStartIsUnique() throws {
        let context = try makeContext()
        let key = Date(timeIntervalSince1970: 86_400)
        context.insert(DailySignals(dayStart: key))
        context.insert(DailySignals(dayStart: key))
        // Unique constraint resolves to a single row on save (upsert semantics).
        try context.save()
        let count = try context.fetchCount(FetchDescriptor<DailySignals>())
        #expect(count == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the test command for `-only-testing:app-twoTests/DailySignalsTests`.
Expected: FAIL — `DailySignals`, `SignalSource` not found (compile error).

- [ ] **Step 3: Write the enums**

```swift
// app-two/app-two/Models/SignalSource.swift
import Foundation

/// Provenance of a signal group on a given day. Drives the merge rule in
/// `SignalSyncCoordinator`: HealthKit fills `.none`, re-syncs `.healthKit`,
/// and never overwrites `.manual`.
enum SignalSource: String, Codable, Sendable {
    case none
    case healthKit
    case manual
}
```

```swift
// app-two/app-two/Models/MenstrualFlow.swift
import Foundation

enum MenstrualFlow: String, Codable, Sendable, CaseIterable {
    case none
    case light
    case medium
    case heavy
    case spotting
}
```

- [ ] **Step 4: Write the model**

```swift
// app-two/app-two/Models/DailySignals.swift
import Foundation
import SwiftData

/// One row per local calendar day. Source of truth for the four health signals.
/// HealthKit mirrors into these fields; manual edits set the matching source to
/// `.manual` so subsequent syncs leave them untouched.
@Model
final class DailySignals {
    /// Start-of-day in the user's calendar/timezone — stable per-day identity.
    @Attribute(.unique) var dayStart: Date
    var updatedAt: Date

    // Sleep
    var sleepHours: Double?
    var sleepQuality: String?        // reuses existing poor|okay|good vocabulary
    var sleepSource: SignalSource

    // Activity
    var steps: Int?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Int?
    var activitySource: SignalSource

    // Heart
    var restingHeartRate: Double?    // bpm
    var hrvSDNN: Double?             // ms
    var heartSource: SignalSource

    // Menstrual cycle
    var menstrualFlow: MenstrualFlow?
    var cycleSymptomsJSON: String?   // [String] encoded
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

extension DailySignals {
    var cycleSymptoms: [String] {
        get {
            guard let json = cycleSymptomsJSON,
                  let data = json.data(using: .utf8),
                  let tags = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return tags
        }
        set {
            guard !newValue.isEmpty,
                  let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                cycleSymptomsJSON = nil
                return
            }
            cycleSymptomsJSON = json
        }
    }
}
```

- [ ] **Step 5: Register in the schema (both arrays)**

In `app-two/app-two/App/AppModelContainer.swift`, add `DailySignals.self` to **both** `Schema([...])` literals (production container near line 9, preview container near line 63):

```swift
let schema = Schema([
    Recording.self,
    TranscriptionSegment.self,
    ModelMetadata.self,
    AppSettings.self,
    RecordingTag.self,
    MedicationEvent.self,
    DailySignals.self
])
```

- [ ] **Step 6: Run test to verify it passes**

Run `-only-testing:app-twoTests/DailySignalsTests`.
Expected: PASS (2 tests). The `#if DEBUG` wipe-on-schema-conflict path in AppModelContainer covers the dev store; no migration needed yet.

- [ ] **Step 7: Commit**

```bash
git add app-two/app-two/Models/DailySignals.swift app-two/app-two/Models/SignalSource.swift app-two/app-two/Models/MenstrualFlow.swift app-two/app-two/App/AppModelContainer.swift app-twoTests/DailySignalsTests.swift
git commit -m "feat(signals): DailySignals model + provenance enums, register in schema"
```

---

## Task 2: DTOs + timezone-safe day key

**Files:**
- Create: `app-two/app-two/Services/HealthKit/HealthSignalsDTO.swift`
- Test: `app-twoTests/SignalDayKeyTests.swift`

The DTOs are what crosses the actor boundary (Sendable value types). `SignalDayKey.dayStart(for:calendar:)` normalizes any instant to that day's start — the single source of day identity, unit-tested across timezones.

- [ ] **Step 1: Write the failing test**

```swift
// app-twoTests/SignalDayKeyTests.swift
import Testing
import Foundation
@testable import app_two

struct SignalDayKeyTests {
    @Test func dayStartZeroesTimeComponents() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        // 2026-06-13 15:30 in New York
        let comps = DateComponents(year: 2026, month: 6, day: 13, hour: 15, minute: 30)
        let instant = cal.date(from: comps)!

        let start = SignalDayKey.dayStart(for: instant, calendar: cal)
        let back = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)

        #expect(back.year == 2026)
        #expect(back.month == 6)
        #expect(back.day == 13)
        #expect(back.hour == 0)
        #expect(back.minute == 0)
        #expect(back.second == 0)
    }

    @Test func sameDayDifferentTimesProduceSameKey() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let morning = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 1))!
        let night = cal.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 23))!
        #expect(SignalDayKey.dayStart(for: morning, calendar: cal) == SignalDayKey.dayStart(for: night, calendar: cal))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run `-only-testing:app-twoTests/SignalDayKeyTests`.
Expected: FAIL — `SignalDayKey` not found.

- [ ] **Step 3: Write the DTOs + day key**

```swift
// app-two/app-two/Services/HealthKit/HealthSignalsDTO.swift
import Foundation

/// The single source of day identity. Normalizes any instant to the start of its
/// local day so HealthKit reads and SwiftData rows agree on "which day."
enum SignalDayKey {
    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
}

/// Sendable value types returned by `HealthDataReading`. No `HKObject` ever
/// escapes the HealthKit actor — only these.
struct SleepDTO: Sendable, Equatable {
    var hours: Double
    var quality: String?   // poor|okay|good, derived; nil if not computed
}

struct ActivityDTO: Sendable, Equatable {
    var steps: Int?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Int?
}

struct HeartDTO: Sendable, Equatable {
    var restingHeartRate: Double?
    var hrvSDNN: Double?
}

struct CycleDTO: Sendable, Equatable {
    var flow: MenstrualFlow?
    var symptoms: [String]
}

/// One day's worth of whatever HealthKit returned. Any field may be nil when
/// HealthKit has no sample for it that day.
struct DaySignalsDTO: Sendable, Equatable {
    var dayStart: Date
    var sleep: SleepDTO?
    var activity: ActivityDTO?
    var heart: HeartDTO?
    var cycle: CycleDTO?
}
```

- [ ] **Step 4: Run test to verify it passes**

Run `-only-testing:app-twoTests/SignalDayKeyTests`.
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app-two/app-two/Services/HealthKit/HealthSignalsDTO.swift app-twoTests/SignalDayKeyTests.swift
git commit -m "feat(signals): Sendable health DTOs + timezone-safe day key"
```

---

## Task 3: `HealthDataReading` protocol + mock + DI wiring

**Files:**
- Create: `app-two/app-two/Services/HealthKit/HealthDataReading.swift`
- Create: `app-twoTests/Mocks/MockHealthDataReading.swift`
- Modify: `app-two/app-two/Store/AppServices.swift`
- Modify: `app-twoTests/Mocks/MockAppServices.swift`

No new behavior to test here directly; this defines the seam and keeps the build green with the mock wired in. Verification is "the test target compiles and existing tests still pass."

- [ ] **Step 1: Write the protocol**

```swift
// app-two/app-two/Services/HealthKit/HealthDataReading.swift
import Foundation

/// Authorization status we care about, decoupled from HKAuthorizationStatus so
/// callers never import HealthKit.
enum HealthAuthorizationState: Sendable {
    case notDetermined
    case denied
    case authorized
    case unavailable   // HealthKit not available on this device
}

/// The only seam to Apple Health. Implemented by an actor that imports HealthKit;
/// mocked in tests. Returns Sendable DTOs only — never HKObjects.
protocol HealthDataReading: Sendable {
    func authorizationState() async -> HealthAuthorizationState
    /// Requests read access for all signal types. Returns the resulting state.
    /// Note: HealthKit deliberately reports `.authorized` even when the user
    /// denied read access (denial is indistinguishable from "no data").
    func requestAuthorization() async throws -> HealthAuthorizationState
    /// Reads all four signals for each day in `[startDay, endDay]` inclusive.
    /// Days with no samples are omitted or returned with nil fields.
    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO]
}
```

- [ ] **Step 2: Write the mock**

```swift
// app-twoTests/Mocks/MockHealthDataReading.swift
import Foundation
@testable import app_two

final class MockHealthDataReading: HealthDataReading, @unchecked Sendable {
    // @unchecked is acceptable here ONLY because this is a test double whose
    // mutation happens before use on a single test actor. (swift-concurrency-pro
    // exception: provably single-threaded test helper.)
    var stubbedState: HealthAuthorizationState = .authorized
    var stubbedSignals: [DaySignalsDTO] = []
    var readCallCount = 0

    func authorizationState() async -> HealthAuthorizationState { stubbedState }
    func requestAuthorization() async throws -> HealthAuthorizationState { stubbedState }
    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO] {
        readCallCount += 1
        return stubbedSignals
    }
}
```

> Note: this is the one sanctioned `@unchecked Sendable` — a single-threaded test double. Production code must not use it (swift-concurrency-pro rule).

- [ ] **Step 3: Add `healthService` to `AppServices`**

In `app-two/app-two/Store/AppServices.swift`, add the stored property, the init parameter, and the assignment:

```swift
// add to stored properties
let healthService: HealthDataReading

// add to init signature (after summarizationService)
        healthService: HealthDataReading,

// add to init body
        self.healthService = healthService
```

- [ ] **Step 4: Wire the mock into `MockAppServices`**

In `app-twoTests/Mocks/MockAppServices.swift`, add the mock and pass it into the `AppServices(...)` construction:

```swift
let health = MockHealthDataReading()

// inside the `services` computed property's AppServices(...) call, add:
            healthService: health,
```

- [ ] **Step 5: Verify the test target compiles and existing tests pass**

Run a broad test (e.g. `-only-testing:app-twoTests/DailySignalsTests` plus one existing suite).
Expected: PASS — no behavior changed; the seam compiles. (Production `AppDependencies` still doesn't construct `healthService` yet → app target won't compile until Task 7. That's fine; tests use `MockAppServices`. If your setup compiles the app target during `xcodebuild test`, jump to Task 7 Step for the production wiring before running, then return here.)

- [ ] **Step 6: Commit**

```bash
git add app-two/app-two/Services/HealthKit/HealthDataReading.swift app-twoTests/Mocks/MockHealthDataReading.swift app-two/app-two/Store/AppServices.swift app-twoTests/Mocks/MockAppServices.swift
git commit -m "feat(signals): HealthDataReading protocol + mock + AppServices seam"
```

---

## Task 4: `SignalsStore` (upsert/fetch by day)

**Files:**
- Create: `app-two/app-two/Store/SignalsStore.swift`
- Test: `app-twoTests/SignalsStoreTests.swift`

Mirrors the existing `RecordingStore` pattern: a `@MainActor` class holding a `ModelContext`, no `@Query` (that's view-only per swiftdata-pro).

- [ ] **Step 1: Write the failing test**

```swift
// app-twoTests/SignalsStoreTests.swift
import Testing
import SwiftData
import Foundation
@testable import app_two

@MainActor
struct SignalsStoreTests {
    private func makeStore() throws -> (SignalsStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        let context = container.mainContext
        return (SignalsStore(context: context), context)
    }

    @Test func upsertCreatesThenReturnsSameRow() throws {
        let (store, context) = try makeStore()
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000))

        let first = store.upsert(dayStart: day)
        first.steps = 5000
        try context.save()

        let second = store.upsert(dayStart: day)
        #expect(second.steps == 5000)             // same row, not a new one
        #expect(try context.fetchCount(FetchDescriptor<DailySignals>()) == 1)
    }

    @Test func fetchReturnsNilForMissingDay() throws {
        let (store, _) = try makeStore()
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 2_000_000))
        #expect(store.fetch(dayStart: day) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run `-only-testing:app-twoTests/SignalsStoreTests`.
Expected: FAIL — `SignalsStore` not found.

- [ ] **Step 3: Write the store**

```swift
// app-two/app-two/Store/SignalsStore.swift
import Foundation
import SwiftData

/// Fetch/upsert helper for `DailySignals`, keyed by `dayStart`. Mirrors
/// `RecordingStore`: holds the main context, exposes intent methods, never uses
/// `@Query` (that is view-only).
@MainActor
final class SignalsStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch(dayStart: Date) -> DailySignals? {
        var descriptor = FetchDescriptor<DailySignals>(
            predicate: #Predicate { $0.dayStart == dayStart }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Returns the row for `dayStart`, creating and inserting one if absent.
    @discardableResult
    func upsert(dayStart: Date) -> DailySignals {
        if let existing = fetch(dayStart: dayStart) { return existing }
        let row = DailySignals(dayStart: dayStart)
        context.insert(row)
        return row
    }

    func save() throws {
        try context.save()
    }

    /// Fetches all rows in `[startDay, endDay]`, newest first.
    func fetchRange(from startDay: Date, to endDay: Date) -> [DailySignals] {
        let descriptor = FetchDescriptor<DailySignals>(
            predicate: #Predicate { $0.dayStart >= startDay && $0.dayStart <= endDay },
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run `-only-testing:app-twoTests/SignalsStoreTests`.
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add app-two/app-two/Store/SignalsStore.swift app-twoTests/SignalsStoreTests.swift
git commit -m "feat(signals): SignalsStore upsert/fetch by day key"
```

---

## Task 5: `SignalSyncCoordinator` — the provenance merge rule (core risk)

**Files:**
- Create: `app-two/app-two/Store/SignalSyncCoordinator.swift`
- Test: `app-twoTests/SignalSyncCoordinatorTests.swift`

This is the highest-risk unit. We test the merge function in isolation first (Task 5), then the full sync orchestration with the mock reader (Task 8). The merge applies per signal group: `.none` → fill+`.healthKit`; `.healthKit` → overwrite+`.healthKit`; `.manual` → untouched.

- [ ] **Step 1: Write the failing tests (table-driven over source states)**

```swift
// app-twoTests/SignalSyncCoordinatorTests.swift
import Testing
import SwiftData
import Foundation
@testable import app_two

@MainActor
struct SignalSyncCoordinatorTests {
    private func makeFixture() throws -> (SignalSyncCoordinator, SignalsStore, ModelContext, MockHealthDataReading) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        let context = container.mainContext
        let store = SignalsStore(context: context)
        let reader = MockHealthDataReading()
        let coordinator = SignalSyncCoordinator(reader: reader, store: store)
        return (coordinator, store, context, reader)
    }

    private let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 3_000_000))

    // .none -> fills from HealthKit, marks .healthKit
    @Test func noneSourceFilledByHealthKit() throws {
        let (coordinator, store, _, _) = try makeFixture()
        let row = store.upsert(dayStart: day)   // sleepSource == .none

        coordinator.merge(SleepDTO(hours: 7.5, quality: "good"), into: row)

        #expect(row.sleepHours == 7.5)
        #expect(row.sleepQuality == "good")
        #expect(row.sleepSource == .healthKit)
    }

    // .healthKit -> overwritten by a fresh HealthKit read
    @Test func healthKitSourceReSyncs() throws {
        let (coordinator, store, _, _) = try makeFixture()
        let row = store.upsert(dayStart: day)
        coordinator.merge(SleepDTO(hours: 6.0, quality: "okay"), into: row)   // now .healthKit

        coordinator.merge(SleepDTO(hours: 8.0, quality: "good"), into: row)

        #expect(row.sleepHours == 8.0)
        #expect(row.sleepSource == .healthKit)
    }

    // .manual -> NEVER overwritten
    @Test func manualSourceIsSticky() throws {
        let (coordinator, store, _, _) = try makeFixture()
        let row = store.upsert(dayStart: day)
        row.sleepHours = 5.0
        row.sleepQuality = "poor"
        row.sleepSource = .manual

        coordinator.merge(SleepDTO(hours: 9.0, quality: "good"), into: row)

        #expect(row.sleepHours == 5.0)            // untouched
        #expect(row.sleepSource == .manual)
    }

    @Test func activityAndHeartMergeIndependently() throws {
        let (coordinator, store, _, _) = try makeFixture()
        let row = store.upsert(dayStart: day)
        row.restingHeartRate = 58
        row.heartSource = .manual                 // heart is sticky

        coordinator.merge(ActivityDTO(steps: 8000, activeEnergyKcal: 400, exerciseMinutes: 30), into: row)
        coordinator.merge(HeartDTO(restingHeartRate: 70, hrvSDNN: 40), into: row)

        #expect(row.steps == 8000)                // activity filled
        #expect(row.activitySource == .healthKit)
        #expect(row.restingHeartRate == 58)       // heart untouched
        #expect(row.heartSource == .manual)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run `-only-testing:app-twoTests/SignalSyncCoordinatorTests`.
Expected: FAIL — `SignalSyncCoordinator` not found.

- [ ] **Step 3: Write the coordinator (merge functions only for now)**

```swift
// app-two/app-two/Store/SignalSyncCoordinator.swift
import Foundation
import SwiftData

/// Applies the "HealthKit-wins-unless-edited" rule and orchestrates syncs.
/// Holds zero HealthKit knowledge — takes DTOs in. Runs on @MainActor with the
/// main context, so no model/context ever crosses an actor boundary.
@MainActor
final class SignalSyncCoordinator {
    private let reader: HealthDataReading
    private let store: SignalsStore
    private let calendar: Calendar

    init(reader: HealthDataReading, store: SignalsStore, calendar: Calendar = .current) {
        self.reader = reader
        self.store = store
        self.calendar = calendar
    }

    // MARK: - Merge (per signal group)

    /// True when a HealthKit read may write this group: untouched or already HK-sourced.
    private func canWrite(_ source: SignalSource) -> Bool {
        source != .manual
    }

    func merge(_ dto: SleepDTO, into row: DailySignals) {
        guard canWrite(row.sleepSource) else { return }
        row.sleepHours = dto.hours
        row.sleepQuality = dto.quality
        row.sleepSource = .healthKit
        row.updatedAt = .now
    }

    func merge(_ dto: ActivityDTO, into row: DailySignals) {
        guard canWrite(row.activitySource) else { return }
        row.steps = dto.steps
        row.activeEnergyKcal = dto.activeEnergyKcal
        row.exerciseMinutes = dto.exerciseMinutes
        row.activitySource = .healthKit
        row.updatedAt = .now
    }

    func merge(_ dto: HeartDTO, into row: DailySignals) {
        guard canWrite(row.heartSource) else { return }
        row.restingHeartRate = dto.restingHeartRate
        row.hrvSDNN = dto.hrvSDNN
        row.heartSource = .healthKit
        row.updatedAt = .now
    }

    func merge(_ dto: CycleDTO, into row: DailySignals) {
        guard canWrite(row.cycleSource) else { return }
        row.menstrualFlow = dto.flow
        row.cycleSymptoms = dto.symptoms
        row.cycleSource = .healthKit
        row.updatedAt = .now
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run `-only-testing:app-twoTests/SignalSyncCoordinatorTests`.
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app-two/app-two/Store/SignalSyncCoordinator.swift app-twoTests/SignalSyncCoordinatorTests.swift
git commit -m "feat(signals): SignalSyncCoordinator merge rule (HealthKit-wins-unless-edited)"
```

---

## Task 6: HealthKit sample mapping (pure functions)

**Files:**
- Create: `app-two/app-two/Services/HealthKit/HealthKitSampleMapping.swift`
- Test: `app-twoTests/HealthKitSampleMappingTests.swift`

Pull the value-mapping logic out of the actor so it's testable without an `HKHealthStore`. These functions take primitive inputs (the numbers HealthKit yields) and produce DTOs — no HealthKit types in their signatures, so they import nothing health-specific.

- [ ] **Step 1: Write the failing test**

```swift
// app-twoTests/HealthKitSampleMappingTests.swift
import Testing
import Foundation
@testable import app_two

struct HealthKitSampleMappingTests {
    @Test func sleepQualityHeuristicBuckets() {
        // efficiency = asleep / inBed; >0.9 good, >0.75 okay, else poor
        #expect(HealthKitSampleMapping.sleepQuality(asleepHours: 7.2, inBedHours: 7.5) == "good")
        #expect(HealthKitSampleMapping.sleepQuality(asleepHours: 6.0, inBedHours: 7.5) == "okay")
        #expect(HealthKitSampleMapping.sleepQuality(asleepHours: 4.0, inBedHours: 8.0) == "poor")
    }

    @Test func sleepQualityNilWhenNoInBedReference() {
        #expect(HealthKitSampleMapping.sleepQuality(asleepHours: 7.0, inBedHours: 0) == nil)
    }

    @Test func flowMappingCoversAllRawValues() {
        #expect(HealthKitSampleMapping.flow(fromHKValue: 1) == MenstrualFlow.none)   // HKCategoryValueMenstrualFlow.unspecified handled as .none upstream; 1 = .none? -> see note
        #expect(HealthKitSampleMapping.flow(fromHKValue: 2) == .light)
        #expect(HealthKitSampleMapping.flow(fromHKValue: 3) == .medium)
        #expect(HealthKitSampleMapping.flow(fromHKValue: 4) == .heavy)
        #expect(HealthKitSampleMapping.flow(fromHKValue: 5) == .spotting)
        #expect(HealthKitSampleMapping.flow(fromHKValue: 99) == nil)   // unknown -> nil
    }
}
```

> Note on HK raw values: `HKCategoryValueMenstrualFlow` is `unspecified=1, light=2, medium=3, heavy=4, none=5` historically, with `.none` deprecated. The mapping below uses the **documented current enum**; if the SDK on the target OS differs, adjust the integer cases in the mapping AND this test together so they stay in sync. The test exists precisely to lock whatever mapping you commit to.

- [ ] **Step 2: Run test to verify it fails**

Run `-only-testing:app-twoTests/HealthKitSampleMappingTests`.
Expected: FAIL — `HealthKitSampleMapping` not found.

- [ ] **Step 3: Write the mapping**

```swift
// app-two/app-two/Services/HealthKit/HealthKitSampleMapping.swift
import Foundation

/// Pure value mapping for HealthKit reads. Deliberately imports no HealthKit
/// types so it is unit-testable; the actor converts HKSamples to these inputs.
enum HealthKitSampleMapping {
    /// Coarse sleep-quality bucket from sleep efficiency. Returns nil when there
    /// is no in-bed reference to compute efficiency (Assumption A3 fallback).
    static func sleepQuality(asleepHours: Double, inBedHours: Double) -> String? {
        guard inBedHours > 0 else { return nil }
        let efficiency = asleepHours / inBedHours
        switch efficiency {
        case 0.9...: return "good"
        case 0.75..<0.9: return "okay"
        default: return "poor"
        }
    }

    /// Maps the integer rawValue of HKCategoryValueMenstrualFlow to our enum.
    /// Returns nil for unrecognized values so we never write garbage.
    static func flow(fromHKValue raw: Int) -> MenstrualFlow? {
        switch raw {
        case 1: return MenstrualFlow.none   // unspecified treated as none
        case 2: return .light
        case 3: return .medium
        case 4: return .heavy
        case 5: return .spotting
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run `-only-testing:app-twoTests/HealthKitSampleMappingTests`.
Expected: PASS (3 tests). If `flowMappingCoversAllRawValues` fails because the target SDK numbers differ, update both the `switch` and the test's expected pairs together, then re-run to green.

- [ ] **Step 5: Commit**

```bash
git add app-two/app-two/Services/HealthKit/HealthKitSampleMapping.swift app-twoTests/HealthKitSampleMappingTests.swift
git commit -m "feat(signals): pure HealthKit sample-mapping helpers (sleep quality, flow)"
```

---

## Task 7: `HealthKitServiceImpl` actor + entitlement + Info.plist + production DI

**Files:**
- Create: `app-two/app-two/Services/HealthKit/HealthKitServiceImpl.swift`
- Modify: `app-two/app-two/Info.plist`
- Modify: `app-two/app-two/Store/AppDependencies.swift`
- Xcode (manual): add HealthKit capability → generates `app-two.entitlements`

This is the only file importing HealthKit. It is **device-verified**, not unit-tested (simulator lacks Health data). The pure mapping it relies on is already covered (Task 6).

- [ ] **Step 1: Add the HealthKit capability in Xcode (manual)**

In Xcode: select the `app-two` target → Signing & Capabilities → **+ Capability** → **HealthKit**. This creates `app-two/app-two/app-two.entitlements` with `com.apple.developer.healthkit = true`. Do **not** enable "Clinical Health Records" or background delivery (out of scope for v1).

- [ ] **Step 2: Add the read usage description to Info.plist**

In `app-two/app-two/Info.plist`, inside the top `<dict>`, add:

```xml
<key>NSHealthShareUsageDescription</key>
<string>app-two reads your sleep, activity, heart, and cycle data from Apple Health so you can see them alongside your check-ins. This stays on your device.</string>
```

(No `NSHealthUpdateUsageDescription` — v1 does not write to Health.)

- [ ] **Step 3: Write the actor**

```swift
// app-two/app-two/Services/HealthKit/HealthKitServiceImpl.swift
import Foundation
import HealthKit

/// The ONLY type that imports HealthKit. Reads samples, maps to Sendable DTOs.
/// An actor: serializes access to the shared HKHealthStore. Never returns HKObjects.
actor HealthKitServiceImpl: HealthDataReading {
    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.menstrualFlow)
        ]
        // Add the symptom category types we surface; ignore any unavailable on-OS.
        let symptomIdentifiers: [HKCategoryTypeIdentifier] = [
            .abdominalCramps, .headache, .moodChanges, .fatigue, .lowerBackPain
        ]
        for id in symptomIdentifiers {
            types.insert(HKCategoryType(id))
        }
        return types
    }

    func authorizationState() async -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        // Read authorization can't be reliably introspected (privacy), so we
        // report .authorized once available and let reads simply return empty.
        return .authorized
    }

    func requestAuthorization() async throws -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        return .authorized
    }

    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        // Build the list of day buckets to fill.
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: startDay)
        let last = calendar.startOfDay(for: endDay)
        while cursor <= last {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Read each signal per day concurrently with a bounded task group
        // (structured concurrency, swift-concurrency-pro). Each child reads one
        // day and returns a DTO; cancellation propagates automatically.
        return try await withThrowingTaskGroup(of: DaySignalsDTO.self) { group in
            for day in days {
                group.addTask { [self] in
                    try Task.checkCancellation()
                    async let sleep = self.readSleep(on: day)
                    async let activity = self.readActivity(on: day)
                    async let heart = self.readHeart(on: day)
                    async let cycle = self.readCycle(on: day)
                    return DaySignalsDTO(
                        dayStart: day,
                        sleep: try await sleep,
                        activity: try await activity,
                        heart: try await heart,
                        cycle: try await cycle
                    )
                }
            }
            var results: [DaySignalsDTO] = []
            for try await dto in group { results.append(dto) }
            return results
        }
    }

    // MARK: - Per-signal reads (return nil when no samples)

    private func dayInterval(_ day: Date) -> (start: Date, end: Date) {
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return (day, end)
    }

    private func readSleep(on day: Date) async throws -> SleepDTO? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        guard !samples.isEmpty else { return nil }

        var asleep: TimeInterval = 0
        var inBed: TimeInterval = 0
        for s in samples {
            let dur = s.endDate.timeIntervalSince(s.startDate)
            switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
            case .inBed: inBed += dur
            case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified: asleep += dur
            default: break
            }
        }
        let asleepHours = asleep / 3600
        let inBedHours = inBed / 3600
        guard asleepHours > 0 else { return nil }
        let quality = HealthKitSampleMapping.sleepQuality(asleepHours: asleepHours, inBedHours: inBedHours)
        return SleepDTO(hours: (asleepHours * 10).rounded() / 10, quality: quality)
    }

    private func sumQuantity(_ type: HKQuantityType, unit: HKUnit, day: Date) async throws -> Double? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let stats = try await descriptor.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: unit)
    }

    private func averageQuantity(_ type: HKQuantityType, unit: HKUnit, day: Date) async throws -> Double? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .discreteAverage
        )
        let stats = try await descriptor.result(for: store)
        return stats?.averageQuantity()?.doubleValue(for: unit)
    }

    private func readActivity(on day: Date) async throws -> ActivityDTO? {
        let steps = try await sumQuantity(HKQuantityType(.stepCount), unit: .count(), day: day)
        let energy = try await sumQuantity(HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), day: day)
        let exercise = try await sumQuantity(HKQuantityType(.appleExerciseTime), unit: .minute(), day: day)
        if steps == nil && energy == nil && exercise == nil { return nil }
        return ActivityDTO(
            steps: steps.map { Int($0.rounded()) },
            activeEnergyKcal: energy.map { ($0 * 10).rounded() / 10 },
            exerciseMinutes: exercise.map { Int($0.rounded()) }
        )
    }

    private func readHeart(on day: Date) async throws -> HeartDTO? {
        let resting = try await averageQuantity(HKQuantityType(.restingHeartRate), unit: HKUnit.count().unitDivided(by: .minute()), day: day)
        let hrv = try await averageQuantity(HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli), day: day)
        if resting == nil && hrv == nil { return nil }
        return HeartDTO(
            restingHeartRate: resting.map { ($0 * 10).rounded() / 10 },
            hrvSDNN: hrv.map { ($0 * 10).rounded() / 10 }
        )
    }

    private func readCycle(on day: Date) async throws -> CycleDTO? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let flowDescriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.menstrualFlow), predicate: predicate)],
            sortDescriptors: []
        )
        let flowSamples = try await flowDescriptor.result(for: store)
        let flow = flowSamples.last.flatMap { HealthKitSampleMapping.flow(fromHKValue: $0.value) }

        // Symptoms: presence of a category sample that day = the symptom tag.
        let symptomMap: [(HKCategoryTypeIdentifier, String)] = [
            (.abdominalCramps, "cramps"),
            (.headache, "headache"),
            (.moodChanges, "mood changes"),
            (.fatigue, "fatigue"),
            (.lowerBackPain, "back pain")
        ]
        var symptoms: [String] = []
        for (id, label) in symptomMap {
            let d = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: HKCategoryType(id), predicate: predicate)],
                sortDescriptors: []
            )
            if let samples = try? await d.result(for: store), !samples.isEmpty {
                symptoms.append(label)
            }
        }
        if flow == nil && symptoms.isEmpty { return nil }
        return CycleDTO(flow: flow, symptoms: symptoms)
    }
}
```

> If any `HKCategoryTypeIdentifier`/`HKQuantityTypeIdentifier` or `HKCategoryValueSleepAnalysis` case in the snippet isn't available on the iOS 26.4 SDK as written, fix the identifier to the SDK's spelling — the compiler will pinpoint it. The structure (one read per signal per day, sums for activity, averages for heart, last-sample for flow) stays.

- [ ] **Step 4: Wire production DI in `AppDependencies`**

In `app-two/app-two/Store/AppDependencies.swift`, add the service and coordinator, and pass `healthService` into the `services` bundle:

```swift
    static let healthService: HealthDataReading = HealthKitServiceImpl()
    static let signalsStore = SignalsStore(context: AppModelContainer.container.mainContext)
    static let signalSyncCoordinator = SignalSyncCoordinator(reader: healthService, store: signalsStore)

    // add to the AppServices(...) call:
        healthService: healthService
```

- [ ] **Step 5: Build the app target + run the existing test suite**

Build the app (`xcodebuild build -scheme app-two -destination '...simulator...'`) to confirm the actor compiles, the entitlement resolves, and DI wires. Then run a known existing suite to confirm nothing regressed.
Expected: BUILD SUCCEEDED; existing tests PASS.

- [ ] **Step 6: Manual device verification (HealthKit reads)**

On a physical device with Health data: run the app, trigger `requestAuthorization()`, grant access, and confirm `readSignals(from:to:)` returns non-empty DTOs for days that have data. (Cannot be automated — simulator has no Health samples.) Record the result in the PR description.

- [ ] **Step 7: Commit**

```bash
git add app-two/app-two/Services/HealthKit/HealthKitServiceImpl.swift app-two/app-two/Info.plist app-two/app-two/Store/AppDependencies.swift app-two/app-two/app-two.entitlements
git commit -m "feat(signals): HealthKitServiceImpl actor + entitlement + Info.plist + DI"
```

---

## Task 8: `SignalSyncCoordinator.sync(...)` orchestration (with mock reader)

**Files:**
- Modify: `app-two/app-two/Store/SignalSyncCoordinator.swift`
- Modify: `app-twoTests/SignalSyncCoordinatorTests.swift`

Now wire the merge functions into a full sync: request days, upsert rows, merge each DTO group, save once. Tested end-to-end with `MockHealthDataReading` — no real HealthKit.

- [ ] **Step 1: Add failing orchestration tests**

Append to `SignalSyncCoordinatorTests`:

```swift
    @Test func syncFillsRowsFromReader() async throws {
        let (coordinator, store, context, reader) = try makeFixture()
        let d0 = day
        reader.stubbedSignals = [
            DaySignalsDTO(dayStart: d0,
                          sleep: SleepDTO(hours: 7.0, quality: "good"),
                          activity: ActivityDTO(steps: 9000, activeEnergyKcal: 500, exerciseMinutes: 25),
                          heart: HeartDTO(restingHeartRate: 60, hrvSDNN: 45),
                          cycle: nil)
        ]

        try await coordinator.sync(from: d0, to: d0)

        let row = try #require(store.fetch(dayStart: d0))
        #expect(row.sleepHours == 7.0)
        #expect(row.steps == 9000)
        #expect(row.restingHeartRate == 60)
        #expect(row.sleepSource == .healthKit)
        #expect(try context.fetchCount(FetchDescriptor<DailySignals>()) == 1)
        #expect(reader.readCallCount == 1)
    }

    @Test func syncPreservesManualEdits() async throws {
        let (coordinator, store, _, reader) = try makeFixture()
        let d0 = day
        let row = store.upsert(dayStart: d0)
        row.sleepHours = 5.5
        row.sleepSource = .manual
        try store.save()

        reader.stubbedSignals = [
            DaySignalsDTO(dayStart: d0, sleep: SleepDTO(hours: 8.0, quality: "good"),
                          activity: nil, heart: nil, cycle: nil)
        ]
        try await coordinator.sync(from: d0, to: d0)

        let updated = try #require(store.fetch(dayStart: d0))
        #expect(updated.sleepHours == 5.5)          // manual sticks
        #expect(updated.sleepSource == .manual)
    }
```

- [ ] **Step 2: Run to verify failure**

Run `-only-testing:app-twoTests/SignalSyncCoordinatorTests`.
Expected: FAIL — `sync(from:to:)` not found.

- [ ] **Step 3: Add `sync` to the coordinator**

Append inside `SignalSyncCoordinator`:

```swift
    // MARK: - Orchestration

    enum SyncResult: Sendable, Equatable { case completed(daysWritten: Int), unavailable }

    /// Reads HealthKit for the inclusive day range and merges into SwiftData,
    /// honoring per-group provenance. Saves once at the end.
    @discardableResult
    func sync(from startDay: Date, to endDay: Date) async throws -> SyncResult {
        let s = calendar.startOfDay(for: startDay)
        let e = calendar.startOfDay(for: endDay)
        let dtos = try await reader.readSignals(from: s, to: e)
        guard !dtos.isEmpty else { return .completed(daysWritten: 0) }

        for dto in dtos {
            let row = store.upsert(dayStart: SignalDayKey.dayStart(for: dto.dayStart, calendar: calendar))
            if let sleep = dto.sleep { merge(sleep, into: row) }
            if let activity = dto.activity { merge(activity, into: row) }
            if let heart = dto.heart { merge(heart, into: row) }
            if let cycle = dto.cycle { merge(cycle, into: row) }
        }
        try store.save()
        return .completed(daysWritten: dtos.count)
    }

    /// Convenience: sync the last `days` days ending today.
    @discardableResult
    func sync(lastDays days: Int) async throws -> SyncResult {
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
        return try await sync(from: start, to: today)
    }
```

- [ ] **Step 4: Run to verify pass**

Run `-only-testing:app-twoTests/SignalSyncCoordinatorTests`.
Expected: PASS (6 tests total).

- [ ] **Step 5: Commit**

```bash
git add app-two/app-two/Store/SignalSyncCoordinator.swift app-twoTests/SignalSyncCoordinatorTests.swift
git commit -m "feat(signals): SignalSyncCoordinator.sync orchestration (range + lastDays)"
```

---

## Task 9: `DaySignalsEditorViewModel` (manual edit flips source to .manual)

**Files:**
- Create: `app-two/app-two/ViewModels/DaySignalsEditorViewModel.swift`
- Test: `app-twoTests/DaySignalsEditorViewModelTests.swift`

`@Observable @MainActor` view model matching the existing VM convention (`CheckInViewModel`). Loads a day's row, exposes editable fields, and on save writes them back, setting the relevant source to `.manual` for any group the user changed. Clearing a field to nil resets that group to `.none` (Assumption A5) so HealthKit can refill it.

- [ ] **Step 1: Write the failing test**

```swift
// app-twoTests/DaySignalsEditorViewModelTests.swift
import Testing
import SwiftData
import Foundation
@testable import app_two

@MainActor
struct DaySignalsEditorViewModelTests {
    private func makeVM(day: Date) throws -> (DaySignalsEditorViewModel, SignalsStore) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        let store = SignalsStore(context: container.mainContext)
        let vm = DaySignalsEditorViewModel(dayStart: day, store: store)
        return (vm, store)
    }

    private let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 4_000_000))

    @Test func editingSleepFlipsSourceToManual() throws {
        let (vm, store) = try makeVM(day: day)
        vm.sleepHours = 6.5
        vm.sleepQuality = "okay"
        try vm.save()

        let row = try #require(store.fetch(dayStart: day))
        #expect(row.sleepHours == 6.5)
        #expect(row.sleepSource == .manual)
    }

    @Test func clearingManualFieldResetsToNone() throws {
        let (vm, store) = try makeVM(day: day)
        // seed a manual value
        let row = store.upsert(dayStart: day)
        row.sleepHours = 7
        row.sleepSource = .manual
        try store.save()

        vm.load()                 // pull existing into the VM
        vm.sleepHours = nil       // user clears it
        vm.sleepQuality = nil
        try vm.save()

        let updated = try #require(store.fetch(dayStart: day))
        #expect(updated.sleepHours == nil)
        #expect(updated.sleepSource == .none)   // eligible for HealthKit again
    }

    @Test func untouchedGroupsKeepTheirSource() throws {
        let (vm, store) = try makeVM(day: day)
        let row = store.upsert(dayStart: day)
        row.steps = 8000
        row.activitySource = .healthKit
        try store.save()

        vm.load()
        vm.sleepHours = 8         // only sleep edited
        try vm.save()

        let updated = try #require(store.fetch(dayStart: day))
        #expect(updated.activitySource == .healthKit)   // untouched
        #expect(updated.sleepSource == .manual)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run `-only-testing:app-twoTests/DaySignalsEditorViewModelTests`.
Expected: FAIL — `DaySignalsEditorViewModel` not found.

- [ ] **Step 3: Write the view model**

```swift
// app-two/app-two/ViewModels/DaySignalsEditorViewModel.swift
import Foundation
import Observation

/// Manual view/edit of one day's signals. Editing a group flips it to `.manual`
/// (sticky against future HealthKit syncs); clearing all of a group's values
/// resets it to `.none` so HealthKit may refill it.
@Observable
@MainActor
final class DaySignalsEditorViewModel {
    let dayStart: Date
    @ObservationIgnored private let store: SignalsStore

    // Sleep
    var sleepHours: Double?
    var sleepQuality: String?
    private(set) var sleepSource: SignalSource = .none

    // Activity
    var steps: Int?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Int?
    private(set) var activitySource: SignalSource = .none

    // Heart
    var restingHeartRate: Double?
    var hrvSDNN: Double?
    private(set) var heartSource: SignalSource = .none

    // Cycle
    var menstrualFlow: MenstrualFlow?
    var cycleSymptoms: [String] = []
    private(set) var cycleSource: SignalSource = .none

    init(dayStart: Date, store: SignalsStore) {
        self.dayStart = dayStart
        self.store = store
        load()
    }

    func load() {
        guard let row = store.fetch(dayStart: dayStart) else { return }
        sleepHours = row.sleepHours
        sleepQuality = row.sleepQuality
        sleepSource = row.sleepSource
        steps = row.steps
        activeEnergyKcal = row.activeEnergyKcal
        exerciseMinutes = row.exerciseMinutes
        activitySource = row.activitySource
        restingHeartRate = row.restingHeartRate
        hrvSDNN = row.hrvSDNN
        heartSource = row.heartSource
        menstrualFlow = row.menstrualFlow
        cycleSymptoms = row.cycleSymptoms
        cycleSource = row.cycleSource
    }

    /// Writes the VM's values onto the day row. For each group, set `.manual`
    /// when it has any value, `.none` when fully cleared.
    func save() throws {
        let row = store.upsert(dayStart: dayStart)

        row.sleepHours = sleepHours
        row.sleepQuality = sleepQuality
        row.sleepSource = (sleepHours == nil && sleepQuality == nil) ? .none : .manual

        row.steps = steps
        row.activeEnergyKcal = activeEnergyKcal
        row.exerciseMinutes = exerciseMinutes
        row.activitySource = (steps == nil && activeEnergyKcal == nil && exerciseMinutes == nil) ? .none : .manual

        row.restingHeartRate = restingHeartRate
        row.hrvSDNN = hrvSDNN
        row.heartSource = (restingHeartRate == nil && hrvSDNN == nil) ? .none : .manual

        row.menstrualFlow = menstrualFlow
        row.cycleSymptoms = cycleSymptoms
        row.cycleSource = (menstrualFlow == nil && cycleSymptoms.isEmpty) ? .none : .manual

        row.updatedAt = .now
        try store.save()
    }
}
```

> Design note: this "set source by whether the group has any value on save" rule means re-saving a HealthKit-sourced day **without changing it** would flip it to `.manual`. That is acceptable and intentional — opening the editor and pressing Save is a user assertion of the values. If you want "only flip groups the user actually touched," that requires dirty-tracking per group; deferred as a refinement (not needed for v1 correctness, and the merge rule still protects data). The tests above encode the save-asserts-manual behavior.

- [ ] **Step 4: Run to verify pass**

Run `-only-testing:app-twoTests/DaySignalsEditorViewModelTests`.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add app-two/app-two/ViewModels/DaySignalsEditorViewModel.swift app-twoTests/DaySignalsEditorViewModelTests.swift
git commit -m "feat(signals): DaySignalsEditorViewModel (manual edit sets provenance)"
```

---

## Task 10: HTML mockups for the editor + summary (CLAUDE.md gate)

**Files:**
- Create: `docs/superpowers/plans/2026-06-13-signals-editor-mockup.html`
- Create: `docs/superpowers/plans/2026-06-13-signals-summary-mockup.html`

CLAUDE.md and memory `feedback-html-mockup-first`: **any new SwiftUI view requires an HTML mockup approved before the SwiftUI is written.** Tasks 11–12 are blocked until the user approves these. Match the Liquid Glass look (memory `project-liquid-glass-ui`): floating `.glassEffect` capsule styling, iOS 26 aesthetic.

- [ ] **Step 1: Build the editor mockup**

Create `2026-06-13-signals-editor-mockup.html`: a sheet with four sections (Sleep, Activity, Heart, Cycle). Each field shows its value, a source pill ("From Apple Health" / "Added by you"), and an edit control. Sleep section shows the existing poor/okay/good chips + an hours field. Use the app's existing palette/spacing tokens as CSS approximations.

- [ ] **Step 2: Build the summary mockup**

Create `2026-06-13-signals-summary-mockup.html`: a compact per-day card showing the four groups with values + a small source glyph, matching the Insights bead/gauge visual language.

- [ ] **Step 3: Present to user and STOP for approval**

Show both mockups. Do **not** proceed to Task 11/12 until the user approves the visual design. (This is the only hard human gate in the plan.)

- [ ] **Step 4: Commit the approved mockups**

```bash
git add docs/superpowers/plans/2026-06-13-signals-editor-mockup.html docs/superpowers/plans/2026-06-13-signals-summary-mockup.html
git commit -m "docs(signals): HTML mockups for Day Signals editor + summary"
```

---

## Task 11: `DaySignalsEditorSheet` (SwiftUI, after mockup approval)

**Files:**
- Create: `app-two/app-two/Views/Signals/DaySignalsEditorSheet.swift`

No unit test (SwiftUI view); verify via Preview + manual run. Follows swiftui-pro: small focused view, `@State` for the VM, no business logic in the view.

- [ ] **Step 1: Write the view (structure mirrors approved mockup)**

```swift
// app-two/app-two/Views/Signals/DaySignalsEditorSheet.swift
import SwiftUI

struct DaySignalsEditorSheet: View {
    @State private var viewModel: DaySignalsEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: DaySignalsEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                sleepSection
                activitySection
                heartSection
                cycleSection
            }
            .navigationTitle("Day Signals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? viewModel.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func sourcePill(_ source: SignalSource) -> some View {
        Group {
            switch source {
            case .healthKit: Label("From Apple Health", systemImage: "heart.fill")
            case .manual: Label("Added by you", systemImage: "pencil")
            case .none: Label("Not set", systemImage: "minus.circle")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var sleepSection: some View {
        Section {
            HStack {
                Text("Hours")
                Spacer()
                TextField("—", value: $viewModel.sleepHours, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            Picker("Quality", selection: $viewModel.sleepQuality) {
                Text("—").tag(String?.none)
                ForEach(["poor", "okay", "good"], id: \.self) { q in
                    Text(q.capitalized).tag(String?.some(q))
                }
            }
        } header: {
            HStack { Text("Sleep"); Spacer(); sourcePill(viewModel.sleepSource) }
        }
    }

    private var activitySection: some View {
        Section {
            numberRow("Steps", value: $viewModel.steps)
            decimalRow("Active energy (kcal)", value: $viewModel.activeEnergyKcal)
            numberRow("Exercise (min)", value: $viewModel.exerciseMinutes)
        } header: {
            HStack { Text("Activity"); Spacer(); sourcePill(viewModel.activitySource) }
        }
    }

    private var heartSection: some View {
        Section {
            decimalRow("Resting HR (bpm)", value: $viewModel.restingHeartRate)
            decimalRow("HRV SDNN (ms)", value: $viewModel.hrvSDNN)
        } header: {
            HStack { Text("Heart"); Spacer(); sourcePill(viewModel.heartSource) }
        }
    }

    private var cycleSection: some View {
        Section {
            Picker("Flow", selection: $viewModel.menstrualFlow) {
                Text("—").tag(MenstrualFlow?.none)
                ForEach(MenstrualFlow.allCases, id: \.self) { f in
                    Text(f.rawValue.capitalized).tag(MenstrualFlow?.some(f))
                }
            }
        } header: {
            HStack { Text("Cycle"); Spacer(); sourcePill(viewModel.cycleSource) }
        }
    }

    private func numberRow(_ title: String, value: Binding<Int?>) -> some View {
        HStack {
            Text(title); Spacer()
            TextField("—", value: value, format: .number)
                .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90)
        }
    }

    private func decimalRow(_ title: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(title); Spacer()
            TextField("—", value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
        }
    }
}
```

- [ ] **Step 2: Add a Preview using the preview container**

```swift
#Preview {
    let store = SignalsStore(context: AppModelContainer.previewContainer.mainContext)
    let day = SignalDayKey.dayStart(for: .now)
    return DaySignalsEditorSheet(viewModel: DaySignalsEditorViewModel(dayStart: day, store: store))
}
```

- [ ] **Step 3: Build + visually verify in Preview/simulator**

Build the app target and open the Preview.
Expected: BUILD SUCCEEDED; sheet renders four sections with source pills; editing a value and tapping Save persists (confirm by reopening).

- [ ] **Step 4: Commit**

```bash
git add app-two/app-two/Views/Signals/DaySignalsEditorSheet.swift
git commit -m "feat(signals): DaySignalsEditorSheet UI"
```

---

## Task 12: `DaySignalsSummaryView` + sync trigger on appear

**Files:**
- Create: `app-two/app-two/Views/Signals/DaySignalsSummaryView.swift`

Compact read surface for one day. Reads `DailySignals` via the store (passed in), shows values + source glyphs, opens the editor on tap, and kicks the sync coordinator on appear (read-on-open, v1).

- [ ] **Step 1: Write the view**

```swift
// app-two/app-two/Views/Signals/DaySignalsSummaryView.swift
import SwiftUI

struct DaySignalsSummaryView: View {
    let dayStart: Date
    let store: SignalsStore
    let coordinator: SignalSyncCoordinator

    @State private var row: DailySignals?
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Signals").font(.headline)
                Spacer()
                Button { showingEditor = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Edit day signals")
            }
            signalRow("Sleep", value: sleepText, source: row?.sleepSource ?? .none)
            signalRow("Activity", value: activityText, source: row?.activitySource ?? .none)
            signalRow("Heart", value: heartText, source: row?.heartSource ?? .none)
            signalRow("Cycle", value: cycleText, source: row?.cycleSource ?? .none)
        }
        .padding()
        .task { await refresh() }
        .refreshable { await refresh() }
        .sheet(isPresented: $showingEditor, onDismiss: { row = store.fetch(dayStart: dayStart) }) {
            DaySignalsEditorSheet(
                viewModel: DaySignalsEditorViewModel(dayStart: dayStart, store: store)
            )
        }
    }

    private func refresh() async {
        // Read-on-open: pull last 30 days from HealthKit, then re-read this day.
        try? await coordinator.sync(lastDays: 30)
        row = store.fetch(dayStart: dayStart)
    }

    private func signalRow(_ title: String, value: String, source: SignalSource) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
            sourceGlyph(source)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(sourceA11y(source))")
    }

    private func sourceGlyph(_ s: SignalSource) -> some View {
        Group {
            switch s {
            case .healthKit: Image(systemName: "heart.fill").foregroundStyle(.pink)
            case .manual: Image(systemName: "pencil").foregroundStyle(.secondary)
            case .none: Image(systemName: "minus").foregroundStyle(.tertiary)
            }
        }
        .font(.caption2)
        .accessibilityHidden(true)
    }

    private func sourceA11y(_ s: SignalSource) -> String {
        switch s {
        case .healthKit: "from Apple Health"
        case .manual: "added by you"
        case .none: "not set"
        }
    }

    private var sleepText: String {
        guard let h = row?.sleepHours else { return "—" }
        let q = row?.sleepQuality.map { " · \($0.capitalized)" } ?? ""
        return String(format: "%.1f h%@", h, q)
    }
    private var activityText: String {
        guard let s = row?.steps else { return "—" }
        return "\(s) steps"
    }
    private var heartText: String {
        guard let hr = row?.restingHeartRate else { return "—" }
        return String(format: "%.0f bpm", hr)
    }
    private var cycleText: String {
        guard let f = row?.menstrualFlow, f != .none else { return "—" }
        return f.rawValue.capitalized
    }
}
```

- [ ] **Step 2: Build + visually verify**

Build the app. On simulator (no Health data), the sync returns nothing and the view shows "—" with the edit affordance — confirming the **manual-only fallback path works without HealthKit** (the spec's core requirement). Edit a value, save, confirm it shows with the "added by you" glyph.
Expected: BUILD SUCCEEDED; manual path works with zero HealthKit data.

- [ ] **Step 3: Manual device verification (full path)**

On a device with Health data: open a day, grant authorization when prompted, confirm HealthKit values appear with the Apple Health glyph, edit one, confirm it switches to "added by you" and survives a pull-to-refresh.

- [ ] **Step 4: Commit**

```bash
git add app-two/app-two/Views/Signals/DaySignalsSummaryView.swift
git commit -m "feat(signals): DaySignalsSummaryView read surface + read-on-open sync"
```

---

## Task 13: Optional note→day sleep bridge (Assumption A2)

**Files:**
- Modify: `app-two/app-two/Store/RecordingStore.swift` (or wherever `createCheckInNote`/`applySummary` is finalized)
- Test: `app-twoTests/SignalSyncCoordinatorTests.swift` (add a bridge test) or a new `NoteSleepBridgeTests.swift`

When a check-in note produces a sleep value for a day whose `DailySignals.sleepSource == .none`, seed the day's sleep and mark it `.manual`. Never overwrites HealthKit/manual. This preserves "add sleep as implemented today" while `DailySignals` is the dashboard truth. **If the user vetoed A2, skip this task entirely.**

- [ ] **Step 1: Write the failing test**

```swift
// app-twoTests/NoteSleepBridgeTests.swift
import Testing
import SwiftData
import Foundation
@testable import app_two

@MainActor
struct NoteSleepBridgeTests {
    private func makeFixture() throws -> (SignalsStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        return (SignalsStore(context: container.mainContext), container.mainContext)
    }

    @Test func noteSeedsEmptyDay() throws {
        let (store, _) = try makeFixture()
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 5_000_000))

        SignalSyncCoordinator.bridgeNoteSleep(hours: 7.0, quality: "good", day: day, store: store)

        let row = try #require(store.fetch(dayStart: day))
        #expect(row.sleepHours == 7.0)
        #expect(row.sleepSource == .manual)
    }

    @Test func noteDoesNotOverwriteHealthKit() throws {
        let (store, _) = try makeFixture()
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 6_000_000))
        let row = store.upsert(dayStart: day)
        row.sleepHours = 8.0
        row.sleepSource = .healthKit
        try store.save()

        SignalSyncCoordinator.bridgeNoteSleep(hours: 5.0, quality: "poor", day: day, store: store)

        let updated = try #require(store.fetch(dayStart: day))
        #expect(updated.sleepHours == 8.0)       // HealthKit untouched
        #expect(updated.sleepSource == .healthKit)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run `-only-testing:app-twoTests/NoteSleepBridgeTests`.
Expected: FAIL — `bridgeNoteSleep` not found.

- [ ] **Step 3: Add the static bridge helper**

Append inside `SignalSyncCoordinator` (static so the note-save path can call it without holding a coordinator instance):

```swift
    /// One-way bridge: a check-in note's sleep seeds a day that has no sleep yet.
    /// Never overwrites `.healthKit` or `.manual`. (Spec Assumption A2.)
    @MainActor
    static func bridgeNoteSleep(hours: Double?, quality: String?, day: Date, store: SignalsStore) {
        guard hours != nil || quality != nil else { return }
        let row = store.upsert(dayStart: SignalDayKey.dayStart(for: day))
        guard row.sleepSource == .none else { return }
        row.sleepHours = hours
        row.sleepQuality = quality
        row.sleepSource = .manual
        row.updatedAt = .now
        try? store.save()
    }
```

- [ ] **Step 4: Call it from the note-save path**

In the check-in note creation path (`RecordingStore.createCheckInNote` or the VM that finalizes a check-in's sleep — find where `recording.sleepHours`/`sleepQuality` are set on save), after the recording is saved, call:

```swift
SignalSyncCoordinator.bridgeNoteSleep(
    hours: recording.sleepHours,
    quality: recording.sleepQuality,
    day: recording.createdAt,
    store: AppDependencies.signalsStore
)
```

(Use the injected `SignalsStore` if the call site has one; otherwise `AppDependencies.signalsStore`.)

- [ ] **Step 5: Run to verify pass**

Run `-only-testing:app-twoTests/NoteSleepBridgeTests`.
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add app-two/app-two/Store/SignalSyncCoordinator.swift app-two/app-two/Store/RecordingStore.swift app-twoTests/NoteSleepBridgeTests.swift
git commit -m "feat(signals): one-way note->day sleep bridge (does not overwrite HK/manual)"
```

---

## Task 14: Permission primer + authorization trigger

**Files:**
- Create: `app-two/app-two/Views/Signals/HealthAccessPrimerView.swift`
- (Optional) Modify wherever Signals first becomes visible to present the primer once.

A lightweight one-time primer before the system HealthKit sheet (App Review + UX best practice): explain what's read and that it stays on-device, then call `requestAuthorization()`. If denied/unavailable, the editor/manual path still works — no broken state.

- [ ] **Step 1: Write the primer view**

```swift
// app-two/app-two/Views/Signals/HealthAccessPrimerView.swift
import SwiftUI

struct HealthAccessPrimerView: View {
    let health: HealthDataReading
    var onFinished: (HealthAuthorizationState) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var requesting = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 56)).foregroundStyle(.pink)
            Text("Connect Apple Health")
                .font(.title2.bold())
            Text("app-two can show your sleep, activity, heart, and cycle data next to your check-ins. It's read-only and stays on your device — nothing is uploaded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button {
                Task { await request() }
            } label: {
                Text(requesting ? "Requesting…" : "Connect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(requesting)
            Button("Not now") { onFinished(.notDetermined); dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func request() async {
        requesting = true
        let state = (try? await health.requestAuthorization()) ?? .denied
        requesting = false
        onFinished(state)
        dismiss()
    }
}
```

- [ ] **Step 2: Build + visually verify**

Build and preview. On a device, "Connect" presents the system HealthKit sheet; "Not now" dismisses and the manual path remains usable.
Expected: BUILD SUCCEEDED; both buttons behave; no crash when HealthKit unavailable.

- [ ] **Step 3: Commit**

```bash
git add app-two/app-two/Views/Signals/HealthAccessPrimerView.swift
git commit -m "feat(signals): one-time Apple Health access primer"
```

---

## Task 15: Final verification + branch wrap-up

- [ ] **Step 1: Run the full test suite**

Run the entire `app-twoTests` target (drop `-only-testing`).
Expected: ALL PASS, including the pre-existing suites (no regressions). Record the count.

- [ ] **Step 2: Build the app target clean**

```bash
env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 \
  xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED, no new warnings (the repo tracks actor-isolation warnings at zero — keep it there).

- [ ] **Step 3: Manual device pass (the only thing tests can't cover)**

On a physical device with Health data, walk the full path: primer → grant → values appear with Apple Health glyph → edit one → becomes "added by you" → pull-to-refresh keeps the edit. Note results in the PR.

- [ ] **Step 4: Update the backlog (Plan → In code)**

Move the "HealthKit signals" row in `docs/BACKLOG.md` from 📐 Plan to 🔨 In code, with branch `feat/healthkit-signals` and a link to this plan.

- [ ] **Step 5: Commit + open PR**

```bash
git add docs/BACKLOG.md
git commit -m "docs(backlog): HealthKit signals -> In code"
git push -u origin feat/healthkit-signals
gh pr create --title "HealthKit signals (sleep, activity, heart, cycle)" --body "Implements the day-keyed DailySignals model with HealthKit mirroring + manual entry. See docs/superpowers/plans/2026-06-13-healthkit-signals-implementation.md. Manual device verification: <fill in>."
```

---

## Self-Review Notes (completed by plan author)

**Spec coverage:** §2 Architecture → Tasks 3,5,7,8. §3 Data model → Task 1,2. §4 Auth/read → Task 7,14. §5 Merge rule → Task 5,8. §6 UI → Tasks 10,11,12,14. §7 DI → Tasks 3,7. §8 Testing → embedded per task. §10 Assumptions: A1 (Task 1), A2 (Task 13), A3 (Task 6), A4 (Task 12 uses 30), A5 (Task 9), A6 (Task 12 plain values), A7 (no write types in Task 7), A8 (all four signals across Tasks 1–12). All covered.

**Placeholder scan:** No TBD/TODO in code steps; every code step shows full code. The only intentional human gate is Task 10 Step 3 (mockup approval) and device-only verification steps (Tasks 7,12,15) — these are inherent to HealthKit, not placeholders.

**Type consistency:** `SignalSource` (.none/.healthKit/.manual), `DailySignals` field names, `DaySignalsDTO`/`SleepDTO`/`ActivityDTO`/`HeartDTO`/`CycleDTO`, `SignalsStore.upsert/fetch/save/fetchRange`, `SignalSyncCoordinator.merge(_:into:)`/`sync(from:to:)`/`sync(lastDays:)`/`bridgeNoteSleep`, `SignalDayKey.dayStart(for:calendar:)` are used identically across all tasks. `HealthDataReading.authorizationState/requestAuthorization/readSignals` consistent across protocol, mock, actor, and primer.
