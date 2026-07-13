import Foundation
import SwiftData

@Observable
@MainActor
final class DayContextStore {
    private(set) var contextsByDay: [Date: CapturedDayEvents] = [:]
    private let modelContext: ModelContext

    /// Re-read every access, never frozen at init — matches RecordingStore /
    /// MedicationBarViewModel so a live Mock-Mode toggle repartitions this store too
    /// (Constitution IX). Callers must `reload()` after a toggle to refresh the cache.
    private var isMockData: Bool { UserDefaults.standard.bool(forKey: "debugMockMode") }

    init(context: ModelContext) {
        self.modelContext = context
        reload()
    }

    func context(for dayKey: Date) -> CapturedDayEvents? {
        contextsByDay[DayKey.make(for: dayKey)]
    }

    /// Day keys that currently hold a captured context (in-memory cache) — the
    /// coordinator's orphan-reconciliation source.
    func contextDays() -> Set<Date> {
        Set(contextsByDay.keys)
    }

    func upsert(dayKey: Date, payload: CapturedDayEvents, titlesIncluded: Bool) {
        let key = DayKey.make(for: dayKey)
        let partition = isMockData
        do {
            let descriptor = FetchDescriptor<DayCalendarContext>(
                predicate: #Predicate { $0.dayKey == key && $0.isMockData == partition }
            )
            let rows = try modelContext.fetch(descriptor)

            switch rows.count {
            case 0:
                let ctx = DayCalendarContext(
                    dayKey: key,
                    capturedAt: Date(),
                    titlesIncluded: titlesIncluded,
                    isMockData: partition
                )
                ctx.encodeEvents(payload)
                modelContext.insert(ctx)

            case 1:
                let ctx = rows[0]
                ctx.encodeEvents(payload)
                ctx.capturedAt = Date()
                ctx.titlesIncluded = titlesIncluded

            default:
                let sorted = rows.sorted { $0.capturedAt > $1.capturedAt }
                let survivor = sorted[0]
                survivor.encodeEvents(payload)
                survivor.capturedAt = Date()
                survivor.titlesIncluded = titlesIncluded
                for stale in sorted.dropFirst() {
                    modelContext.delete(stale)
                }
            }

            // Persist BEFORE mutating the cache: a thrown save jumps to `catch`, so the
            // UI-facing cache is never told a write succeeded when it did not (the row
            // would otherwise vanish on the next reload with no error surfaced).
            try modelContext.save()
            contextsByDay[key] = payload
        } catch {
            AppLogger.log("DayContextStore.upsert failed: \(error)")
        }
    }

    func deleteContext(for dayKey: Date) {
        let key = DayKey.make(for: dayKey)
        let partition = isMockData
        do {
            let descriptor = FetchDescriptor<DayCalendarContext>(
                predicate: #Predicate { $0.dayKey == key && $0.isMockData == partition }
            )
            let rows = try modelContext.fetch(descriptor)
            for row in rows { modelContext.delete(row) }
            try modelContext.save()
            contextsByDay.removeValue(forKey: key)
        } catch {
            AppLogger.log("DayContextStore.deleteContext failed: \(error)")
        }
    }

    func purgeAll() {
        let partition = isMockData
        do {
            let descriptor = FetchDescriptor<DayCalendarContext>(
                predicate: #Predicate { $0.isMockData == partition }
            )
            let rows = try modelContext.fetch(descriptor)
            for row in rows { modelContext.delete(row) }
            try modelContext.save()
            contextsByDay.removeAll()
        } catch {
            AppLogger.log("DayContextStore.purgeAll failed: \(error)")
        }
    }

    func daysLackingContext(checkInDays: Set<Date>) -> Set<Date> {
        let normalized = Set(checkInDays.map { DayKey.make(for: $0) })
        return normalized.subtracting(Set(contextsByDay.keys))
    }

    func reload() {
        let partition = isMockData
        do {
            let descriptor = FetchDescriptor<DayCalendarContext>(
                predicate: #Predicate { $0.isMockData == partition }
            )
            let rows = try modelContext.fetch(descriptor)
            // Group by normalized dayKey; pick the row with the newest capturedAt.
            var byKey: [Date: DayCalendarContext] = [:]
            for row in rows {
                let key = DayKey.make(for: row.dayKey)
                if let current = byKey[key] {
                    if row.capturedAt > current.capturedAt { byKey[key] = row }
                } else {
                    byKey[key] = row
                }
            }
            var cache: [Date: CapturedDayEvents] = [:]
            for (key, row) in byKey {
                if let events = row.decodedEvents { cache[key] = events }
            }
            contextsByDay = cache
        } catch {
            AppLogger.log("DayContextStore.reload failed: \(error)")
        }
    }
}
