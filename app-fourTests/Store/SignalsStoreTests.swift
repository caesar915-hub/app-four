import Testing
import SwiftData
import Foundation
@testable import app_four

@MainActor
struct SignalsStoreTests {
    // Returns a store plus the container that must be retained for the test's lifetime.
    private func makeStore() throws -> (SignalsStore, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        return (SignalsStore(context: container.mainContext), container)
    }

    @Test func upsertCreatesThenReturnsSameRow() throws {
        let (store, container) = try makeStore()
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000))

        let first = store.upsert(dayStart: day)
        first.steps = 5000
        try store.save()

        let second = store.upsert(dayStart: day)
        #expect(second.steps == 5000)                                                    // same row
        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailySignals>()) == 1)
    }

    @Test func upsertNormalizesInstantToStartOfDay() throws {
        let (store, container) = try makeStore()
        let key = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000))   // local midnight
        let laterSameDay = key.addingTimeInterval(3_600)                               // 1h later, same local day

        _ = store.upsert(dayStart: key)
        _ = store.upsert(dayStart: laterSameDay)        // un-normalized instant → must hit the same row
        try store.save()

        #expect(try container.mainContext.fetchCount(FetchDescriptor<DailySignals>()) == 1)
    }

    @Test func fetchReturnsNilForMissingDay() throws {
        let (store, _container) = try makeStore()
        _ = _container
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 2_000_000))
        #expect(store.fetch(dayStart: day) == nil)
    }

    @Test func fetchRangeReturnsDaysNewestFirst() throws {
        let (store, _container) = try makeStore()
        _ = _container
        let d1 = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000))
        let d2 = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000 + 86_400))
        _ = store.upsert(dayStart: d1)
        _ = store.upsert(dayStart: d2)
        try store.save()

        let range = store.fetchRange(from: d1, to: d2)
        #expect(range.count == 2)
        #expect(range.first?.dayStart == d2)            // newest first
    }

    @Test func fetchRangeBoundariesAreInclusiveExclusive() throws {
        let (store, container) = try makeStore(); _ = container
        let start = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 5_000_000))
        let end = SignalDayKey.dayStart(for: start.addingTimeInterval(86_400 * 2))   // start + 2 days
        let before = SignalDayKey.dayStart(for: start.addingTimeInterval(-86_400))   // out (below)
        let after = SignalDayKey.dayStart(for: start.addingTimeInterval(86_400 * 3)) // out (above)
        _ = store.upsert(dayStart: before)
        _ = store.upsert(dayStart: start)   // on lower boundary
        _ = store.upsert(dayStart: end)     // on upper boundary
        _ = store.upsert(dayStart: after)
        try store.save()

        let range = store.fetchRange(from: start, to: end)
        #expect(range.count == 2)                              // both boundaries included, others excluded
        #expect(range.contains { $0.dayStart == start })
        #expect(range.contains { $0.dayStart == end })
        #expect(!range.contains { $0.dayStart == before })
        #expect(!range.contains { $0.dayStart == after })
    }

    @Test func fetchRangeEmptyWhenNoRows() throws {
        let (store, container) = try makeStore(); _ = container
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 9_000_000))
        #expect(store.fetchRange(from: day, to: day).isEmpty)
    }
}
