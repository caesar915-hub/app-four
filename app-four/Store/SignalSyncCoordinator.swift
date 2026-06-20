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

    enum SyncResult: Sendable, Equatable { case completed(daysWritten: Int), unavailable }

    /// Reads HealthKit for the inclusive day range and merges into SwiftData, honoring
    /// per-group provenance. Saves once at the end.
    @discardableResult
    func sync(from startDay: Date, to endDay: Date) async throws -> SyncResult {
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
        try store.save()
        return .completed(daysWritten: dtos.count)
    }

    /// Convenience: sync the last `days` days ending today (first-grant backfill = 30).
    @discardableResult
    func sync(lastDays days: Int) async throws -> SyncResult {
        let today = SignalDayKey.dayStart(for: Date(), calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) ?? today
        return try await sync(from: start, to: today)
    }
}
