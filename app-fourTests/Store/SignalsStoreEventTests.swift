import Testing
import SwiftData
import Foundation
@testable import app_four

@MainActor
struct SignalsStoreEventTests {
    // Returns a store plus the container that must be retained for the test's lifetime.
    private func makeStore() throws -> (SignalsStore, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DailySignals.self, NutritionEvent.self, configurations: config
        )
        return (SignalsStore(context: container.mainContext), container)
    }

    private func insert(_ store: SignalsStore, kind: NutritionEventKind = .food,
                        at date: Date, mock: Bool = false) throws -> NutritionEvent {
        let event = NutritionEvent(startDate: date, kind: kind)
        event.kcal = 100
        event.isMockData = mock
        store.context.insert(event)
        try store.save()
        return event
    }

    @Test func fetchEventsCoversInclusiveRangeIncludingLateEvening() throws {
        let (store, _) = try makeStore()
        let calendar = Calendar.current
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000))
        // 23:58 on the end day belongs to that day (spec edge case).
        let lateEvening = calendar.date(bySettingHour: 23, minute: 58, second: 0, of: day)!
        let dayBefore = calendar.date(byAdding: .day, value: -1, to: day)!
        let dayAfter = calendar.date(byAdding: .day, value: 1, to: day)!

        _ = try insert(store, at: lateEvening)
        _ = try insert(store, at: dayBefore)
        _ = try insert(store, at: dayAfter)

        let events = store.fetchEvents(from: day, to: day)
        #expect(events.count == 1)
        #expect(events.first?.startDate == lateEvening)
    }

    @Test func fetchEventsReturnsBothMockAndRealRows() throws {
        // Partitioning is the VM's job (real-wins-per-day needs both); the store is raw.
        let (store, _) = try makeStore()
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000))

        _ = try insert(store, at: day.addingTimeInterval(3600), mock: false)
        _ = try insert(store, at: day.addingTimeInterval(7200), mock: true)

        let events = store.fetchEvents(from: day, to: day)
        #expect(events.count == 2)
    }

    @Test func insertMockEventPersistsWithMockFlag() throws {
        let (store, container) = try makeStore()
        let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 1_000_000))

        let event = NutritionEvent(startDate: day.addingTimeInterval(8 * 3600), kind: .food)
        event.kcal = 520
        event.isMockData = true
        store.insertMockEvent(event)
        try store.save()

        let fetched = try container.mainContext.fetch(FetchDescriptor<NutritionEvent>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.isMockData == true)
        #expect(fetched.first?.kcal == 520)
    }
}
