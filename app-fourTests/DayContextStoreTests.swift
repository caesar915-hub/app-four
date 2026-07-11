import Testing
import Foundation
import SwiftData
@testable import app_four

@MainActor
struct DayContextStoreTests {
    var store: DayContextStore
    var container: ModelContainer

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: DayCalendarContext.self, configurations: config)
        store = DayContextStore(context: container.mainContext)
    }

    // MARK: - Helpers

    private func makePayload(title: String) -> CapturedDayEvents {
        CapturedDayEvents(events: [
            CapturedEvent(
                title: title,
                start: Date(timeIntervalSince1970: 1_000_000),
                end: Date(timeIntervalSince1970: 1_003_600),
                isAllDay: false,
                attendeeCount: 1,
                availability: "busy"
            )
        ])
    }

    private func dayKey(offsetDays: Int = 0) -> Date {
        let base = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_750_000_000))
        return Calendar.current.date(byAdding: .day, value: offsetDays, to: base)!
    }

    private func rowCount() throws -> Int {
        let desc = FetchDescriptor<DayCalendarContext>()
        return try container.mainContext.fetch(desc).count
    }

    // MARK: - upsert: insert

    @Test func upsertInserts() throws {
        let day = dayKey()
        let payload = makePayload(title: "Standup")
        store.upsert(dayKey: day, payload: payload, titlesIncluded: true)

        #expect(try rowCount() == 1)
        #expect(store.context(for: day) == payload)
    }

    // MARK: - upsert: replace (idempotent; one row remains)

    @Test func upsertSecondCallReplaces() throws {
        let day = dayKey()
        store.upsert(dayKey: day, payload: makePayload(title: "First"), titlesIncluded: true)
        let payloadV2 = makePayload(title: "Second")
        store.upsert(dayKey: day, payload: payloadV2, titlesIncluded: false)

        #expect(try rowCount() == 1)
        #expect(store.context(for: day) == payloadV2)
    }

    // MARK: - dedupe guard: pre-existing duplicate rows → survivor is newest

    @Test func dedupeGuardKeepsNewest() throws {
        let day = dayKey()
        let ctx = container.mainContext

        // Insert two rows directly with different capturedAt values.
        let older = DayCalendarContext(dayKey: day, capturedAt: Date(timeIntervalSince1970: 100), isMockData: false)
        older.encodeEvents(makePayload(title: "Older"))
        let newer = DayCalendarContext(dayKey: day, capturedAt: Date(timeIntervalSince1970: 200), isMockData: false)
        newer.encodeEvents(makePayload(title: "Newer"))
        ctx.insert(older)
        ctx.insert(newer)
        try ctx.save()

        // upsert must detect 2 rows, keep the newest, delete the rest, and apply the new payload.
        let fresh = makePayload(title: "Fresh")
        store.upsert(dayKey: day, payload: fresh, titlesIncluded: true)

        #expect(try rowCount() == 1)
        #expect(store.context(for: day) == fresh)
    }

    // MARK: - daysLackingContext

    @Test func daysLackingContextReturnsOnlyMissingDays() throws {
        let covered = dayKey(offsetDays: 0)
        let missing1 = dayKey(offsetDays: 1)
        let missing2 = dayKey(offsetDays: 2)

        store.upsert(dayKey: covered, payload: makePayload(title: "Covered"), titlesIncluded: true)

        let lacking = store.daysLackingContext(checkInDays: [covered, missing1, missing2])
        #expect(!lacking.contains(covered))
        #expect(lacking.contains(missing1))
        #expect(lacking.contains(missing2))
        #expect(lacking.count == 2)
    }

    // MARK: - purgeAll

    @Test func purgeAllEmptiesStoreAndCache() throws {
        store.upsert(dayKey: dayKey(offsetDays: 0), payload: makePayload(title: "A"), titlesIncluded: true)
        store.upsert(dayKey: dayKey(offsetDays: 1), payload: makePayload(title: "B"), titlesIncluded: true)

        store.purgeAll()

        #expect(try rowCount() == 0)
        #expect(store.contextsByDay.isEmpty)
    }

    // MARK: - deleteContext

    @Test func deleteContextRemovesOnlyThatDay() throws {
        let day0 = dayKey(offsetDays: 0)
        let day1 = dayKey(offsetDays: 1)
        store.upsert(dayKey: day0, payload: makePayload(title: "Day0"), titlesIncluded: true)
        store.upsert(dayKey: day1, payload: makePayload(title: "Day1"), titlesIncluded: true)

        store.deleteContext(for: day0)

        #expect(try rowCount() == 1)
        #expect(store.context(for: day0) == nil)
        #expect(store.context(for: day1) != nil)
    }

    // MARK: - partition isolation

    @Test func partitionIsolationRealStoreIgnoresMockRows() throws {
        let day = dayKey()
        let ctx = container.mainContext

        // Insert a row flagged isMockData = true directly.
        let mockRow = DayCalendarContext(dayKey: day, capturedAt: Date(), isMockData: true)
        mockRow.encodeEvents(makePayload(title: "MockEvent"))
        ctx.insert(mockRow)
        try ctx.save()

        // The store is in real (non-mock) mode; it must not see the mock row.
        store.reload()
        #expect(store.context(for: day) == nil)
        #expect(store.contextsByDay.isEmpty)
    }
}
