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
        return try? modelContext.fetch(descriptor).first
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
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save() throws {
        try modelContext.save()
    }
}
