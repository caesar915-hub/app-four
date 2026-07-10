import Foundation
import SwiftData

/// Applies the "HealthKit-wins-unless-edited" rule and orchestrates syncs. Holds zero
/// HealthKit knowledge (takes DTOs). Runs on `@MainActor` with the main context, so no
/// `@Model`/`ModelContext` ever crosses an actor boundary.
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

    /// A HealthKit read may write a group only when it is untouched or already HK-sourced;
    /// a `.manual` group is sticky.
    private func canWrite(_ source: SignalSource) -> Bool { source != .manual }

    func merge(_ dto: SleepDTO, into row: DailySignals) {
        guard canWrite(row.sleepSource) else { return }
        row.sleepHours = dto.hours
        row.sleepLevel = dto.level
        row.sleepSource = .healthKit
        row.updatedAt = Date()
    }

    func merge(_ dto: ActivityDTO, into row: DailySignals) {
        guard canWrite(row.activitySource) else { return }
        row.steps = dto.steps
        row.activeEnergyKcal = dto.activeEnergyKcal
        row.exerciseMinutes = dto.exerciseMinutes
        row.activitySource = .healthKit
        row.updatedAt = Date()
    }

    func merge(_ dto: HeartDTO, into row: DailySignals) {
        guard canWrite(row.heartSource) else { return }
        row.restingHeartRate = dto.restingHeartRate
        row.hrvSDNN = dto.hrvSDNN
        row.heartSource = .healthKit
        row.updatedAt = Date()
    }

    func merge(_ dto: CycleDTO, into row: DailySignals) {
        guard canWrite(row.cycleSource) else { return }
        row.menstrualFlow = dto.flow
        row.cycleSymptoms = dto.symptoms
        row.cycleSource = .healthKit
        row.updatedAt = Date()
    }

    // MARK: - Orchestration

    enum SyncResult: Sendable, Equatable { case completed(daysWritten: Int), unavailable, disabled }

    /// Reads HealthKit for the inclusive day range and merges into SwiftData, honoring
    /// per-group provenance. Saves once at the end.
    @discardableResult
    func sync(from startDay: Date, to endDay: Date) async throws -> SyncResult {
        // User pause switch (spec 031 US4 / FR-015): the single gate for every sync path —
        // calendar, Insights, and pull-to-refresh all route through here. Default on.
        guard UserDefaults.standard.object(forKey: "healthSyncEnabled") as? Bool ?? true else { return .disabled }
        // Short-circuit when HealthKit isn't available, so a missing-HealthKit device is
        // distinguishable from "synced, no data" (FR-014 / SyncResult.unavailable).
        guard await reader.authorizationState() != .unavailable else { return .unavailable }
        let start = SignalDayKey.dayStart(for: startDay, calendar: calendar)
        let end = SignalDayKey.dayStart(for: endDay, calendar: calendar)
        let dtos = try await reader.readSignals(from: start, to: end)
        for dto in dtos {
            let row = store.upsert(dayStart: dto.dayStart)
            if let sleep = dto.sleep { merge(sleep, into: row) }
            if let activity = dto.activity { merge(activity, into: row) }
            if let heart = dto.heart { merge(heart, into: row) }
            if let cycle = dto.cycle { merge(cycle, into: row) }
        }

        // Nutrition/exercise events (spec 031): grouped per day, replace-per-day so a
        // re-sync never duplicates. Same window, same single save below.
        let events = try await reader.readNutritionEvents(from: start, to: end)
        let eventsByDay = Dictionary(grouping: events) { SignalDayKey.dayStart(for: $0.startDate, calendar: calendar) }
        var cursor = start
        while cursor <= end {
            store.replaceHealthKitEvents(dayStart: cursor, with: eventsByDay[cursor] ?? [])
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        try store.save()
        UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate, forKey: "healthLastSyncAt")
        return .completed(daysWritten: dtos.count)
    }

    /// Convenience: sync the last `days` days ending today (first-grant backfill = 30).
    @discardableResult
    func sync(lastDays days: Int) async throws -> SyncResult {
        let today = SignalDayKey.dayStart(for: Date(), calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
        return try await sync(from: start, to: today)
    }

    private var lastFullSyncDay: Date?

    /// Runs the `lastDays` sync at most once per calendar day (in-memory), so opening the
    /// day surface repeatedly doesn't repeat the full sweep. Pull-to-refresh should call
    /// `sync(lastDays:)` directly to force a re-read.
    @discardableResult
    func syncRecentIfNeeded(lastDays days: Int = 30) async throws -> SyncResult {
        let today = SignalDayKey.dayStart(for: Date(), calendar: calendar)
        if lastFullSyncDay == today { return .completed(daysWritten: 0) }
        let result = try await sync(lastDays: days)
        if case .completed = result { lastFullSyncDay = today }
        return result
    }

    /// Clears the once-per-day throttle so the next `syncRecentIfNeeded` re-runs the full
    /// sweep. The Settings switch calls this when "Sync from Apple Health" is turned back on:
    /// the in-memory throttle would otherwise block the re-import until relaunch/next day,
    /// breaking US4's "re-enable → next surface visit re-imports" (Scenario 4 / SC-007).
    func resetSyncThrottle() { lastFullSyncDay = nil }
}
