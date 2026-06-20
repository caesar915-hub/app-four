# Phase 1 Contracts: HealthKit Signals

**Feature**: 009-healthkit-signals | **Date**: 2026-06-20

This is a mobile app feature; the "contracts" are the internal seams (Swift protocols / type APIs) other layers depend on, plus the platform/permission contract. Implementation bodies live in tasks/implement.

## C1 — `HealthDataReading` (service seam, Constitution VIII)

The only seam to Apple Health. Implemented by an `actor` that imports HealthKit; mocked in tests. Returns Sendable DTOs only.

```
enum HealthAuthorizationState: Sendable { case notDetermined, denied, authorized, unavailable }

protocol HealthDataReading: Sendable {
    func authorizationState() async -> HealthAuthorizationState
    func requestAuthorization() async throws -> HealthAuthorizationState
    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO]
}
```

**Contract notes**
- `requestAuthorization` requests read for: sleep analysis; step count, active energy, exercise time; resting HR, HRV SDNN; menstrual flow + symptom categories. `toShare: []` (read-only).
- Read authorization status is **not introspectable**: `authorizationState()` returns `.authorized` whenever `isHealthDataAvailable()`, else `.unavailable`. Denied is indistinguishable from no-data (D3).
- `readSignals` is inclusive of both day bounds; days with no samples are omitted or returned with `nil` fields. Never throws for "no data."

## C2 — `SignalSyncCoordinator` (merge + orchestration, `@MainActor`)

Holds zero HealthKit knowledge (takes DTOs). The single home of the merge rule.

```
@MainActor final class SignalSyncCoordinator {
    init(reader: HealthDataReading, store: SignalsStore, calendar: Calendar = .current)

    // merge one group into a row, honoring provenance (FR-009/010/011)
    func merge(_ dto: SleepDTO,    into row: DailySignals)
    func merge(_ dto: ActivityDTO, into row: DailySignals)
    func merge(_ dto: HeartDTO,    into row: DailySignals)
    func merge(_ dto: CycleDTO,    into row: DailySignals)

    enum SyncResult: Sendable, Equatable { case completed(daysWritten: Int), unavailable }
    @discardableResult func sync(from startDay: Date, to endDay: Date) async throws -> SyncResult
    @discardableResult func sync(lastDays days: Int) async throws -> SyncResult   // backfill window; first grant = 30 (FR-007/A4)
}
```

**Contract notes**
- `merge` writes only when the group's source is `.none` or `.healthKit`; `.manual` is untouched.
- `sync` reads the range, upserts one row per returned day, merges each present group, saves **once**.

## C3 — `SignalsStore` API

See data-model.md "Store contract". Consumed by the coordinator and the editor view model; never exposes `ModelContext` to views.

## C4 — Platform / permission contract

- Entitlement: `com.apple.developer.healthkit = true` (no Clinical Records, no background delivery).
- Info.plist: `NSHealthShareUsageDescription` (read rationale, on-device). No `NSHealthUpdateUsageDescription` (read-only, FR-017).
- Privacy (Constitution VI / FR-016): no health value leaves the device; SwiftData store stays excluded from iCloud backup; logs record counts/durations only.

## C5 — UI surfaces (verified by build + simulator run; HTML mockup gate first, Constitution I)

- **`DaySignalsEditorSheet`** (+ `DaySignalsEditorViewModel`, `@Observable @MainActor`): four sections (sleep/activity/heart/cycle); each shows value(s), a **source indicator** ("From Apple Health" / "Added by you" / "Not set"), and edit controls; sleep uses a 5-step `SleepLevel` picker (A6/D5). Editing a group → `.manual`; clearing it → `.none`.
- **`DaySignalsSummaryView`**: compact per-day read surface; sleep rendered as 5-step beads (`SignalLevel`), activity/heart/cycle as plain values + a source glyph; opens the editor; triggers read-on-open sync (last 30 days) + pull-to-refresh.
- **`HealthAccessPrimerView`**: one-time plain-language primer before the system HealthKit sheet (FR-005); "Not now" leaves the manual path fully usable.

**Mockup gate**: `DaySignalsEditorSheet` and `DaySignalsSummaryView` are new views → require an approved HTML mockup before SwiftUI (Constitution I). This is the one human gate in the build.
