import Foundation
import SwiftData

/// Fetch/upsert helper for `DailySignals`, keyed by normalized day. Mirrors
/// `RecordingStore`: holds the main context, exposes intent methods, never uses
/// `@Query` (that is view-only). Enforces one-row-per-day, since the schema carries no
/// `@Attribute(.unique)` (Constitution IX / CloudKit-compatible).
@Observable
@MainActor
final class SignalsStore {
    private let modelContext: ModelContext
    var context: ModelContext { modelContext }

    init(context: ModelContext) {
        self.modelContext = context
    }

    func fetch(dayStart: Date) -> DailySignals? {
        let key = SignalDayKey.dayStart(for: dayStart)
        var descriptor = FetchDescriptor<DailySignals>(
            predicate: #Predicate { $0.dayStart == key }
        )
        descriptor.fetchLimit = 1
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            // Distinguish a genuine fetch failure from "no row": a thrown error here that
            // returned nil would let `upsert` insert a duplicate day (no unique constraint).
            AppLogger.log("SignalsStore.fetch failed for \(key): \(error)")
            return nil
        }
    }

    /// Returns the row for `dayStart` (normalized to start-of-day), inserting one if
    /// absent. Idempotent: a second call for the same day returns the same row.
    @discardableResult
    func upsert(dayStart: Date) -> DailySignals {
        let key = SignalDayKey.dayStart(for: dayStart)
        if let existing = fetch(dayStart: key) { return existing }
        let row = DailySignals(dayStart: key)
        modelContext.insert(row)
        return row
    }

    /// All rows in the inclusive `[startDay, endDay]` range, newest first.
    func fetchRange(from startDay: Date, to endDay: Date) -> [DailySignals] {
        let start = SignalDayKey.dayStart(for: startDay)
        let end = SignalDayKey.dayStart(for: endDay)
        let descriptor = FetchDescriptor<DailySignals>(
            predicate: #Predicate { $0.dayStart >= start && $0.dayStart <= end },
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.log("SignalsStore.fetchRange failed [\(start)…\(end)]: \(error)")
            return []
        }
    }

    func save() throws {
        try modelContext.save()
    }

    // MARK: - Nutrition events (spec 031)

    /// All events whose `startDate` falls inside the inclusive `[startDay, endDay]` day
    /// range, oldest first. Returns BOTH mock and real rows — real-wins-per-day is the
    /// view-model's call and needs to see both partitions.
    func fetchEvents(from startDay: Date, to endDay: Date) -> [NutritionEvent] {
        let start = SignalDayKey.dayStart(for: startDay)
        let endDayStart = SignalDayKey.dayStart(for: endDay)
        guard let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: endDayStart) else { return [] }
        let descriptor = FetchDescriptor<NutritionEvent>(
            predicate: #Predicate { $0.startDate >= start && $0.startDate < endExclusive },
            sortBy: [SortDescriptor(\.startDate)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.log("SignalsStore.fetchEvents failed [\(start)…\(endExclusive)]: \(error)")
            return []
        }
    }

    /// Seeding path: forces the mock partition so a generator bug can never write a row
    /// that later blocks real HealthKit data (replace-per-day only touches real rows).
    func insertMockEvent(_ event: NutritionEvent) {
        event.isMockData = true
        modelContext.insert(event)
    }

    /// Replace-per-day dedup (spec 031): deletes the day's real HealthKit events and inserts
    /// the fresh DTOs. Mock rows and `.manual` rows are never touched, so re-syncing is
    /// idempotent without any unique constraint (Constitution IX). Caller saves.
    func replaceHealthKitEvents(dayStart: Date, with dtos: [NutritionEventDTO]) {
        let start = SignalDayKey.dayStart(for: dayStart)
        guard let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return }
        let hkRaw = SignalSource.healthKit.rawValue
        let descriptor = FetchDescriptor<NutritionEvent>(
            predicate: #Predicate {
                $0.startDate >= start && $0.startDate < endExclusive
                    && $0.sourceValue == hkRaw && $0.isMockData == false
            }
        )
        let stale = (try? modelContext.fetch(descriptor)) ?? []
        for event in stale { modelContext.delete(event) }
        for dto in dtos {
            let event = NutritionEvent(startDate: dto.startDate, kind: dto.kind)
            event.endDate = dto.endDate
            event.name = dto.name
            event.kcal = dto.kcal
            event.proteinGrams = dto.proteinGrams
            event.caffeineMg = dto.caffeineMg
            event.durationMinutes = dto.durationMinutes
            event.source = .healthKit
            event.isMockData = false
            modelContext.insert(event)
        }
    }
}
