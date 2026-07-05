import Testing
import SwiftData
import Foundation
@testable import app_four

@MainActor
struct SignalSyncCoordinatorTests {
    private func makeFixture() throws -> (SignalSyncCoordinator, SignalsStore, ModelContainer, MockHealthDataReading) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, configurations: config)
        let store = SignalsStore(context: container.mainContext)
        let reader = MockHealthDataReading()
        let coordinator = SignalSyncCoordinator(reader: reader, store: store)
        return (coordinator, store, container, reader)
    }

    private let day = SignalDayKey.dayStart(for: Date(timeIntervalSince1970: 3_000_000))

    // MARK: Merge rule

    @Test func noneSourceFilledByHealthKit() throws {
        let (coordinator, store, container, _) = try makeFixture(); _ = container
        let row = store.upsert(dayStart: day)
        coordinator.merge(SleepDTO(hours: 7.5, level: .good), into: row)
        #expect(row.sleepHours == 7.5)
        #expect(row.sleepLevel == .good)
        #expect(row.sleepSource == .healthKit)
    }

    @Test func healthKitSourceReSyncs() throws {
        let (coordinator, store, container, _) = try makeFixture(); _ = container
        let row = store.upsert(dayStart: day)
        coordinator.merge(SleepDTO(hours: 6, level: .okay), into: row)
        coordinator.merge(SleepDTO(hours: 8, level: .good), into: row)
        #expect(row.sleepHours == 8)
        #expect(row.sleepSource == .healthKit)
    }

    @Test func manualSourceIsSticky() throws {
        let (coordinator, store, container, _) = try makeFixture(); _ = container
        let row = store.upsert(dayStart: day)
        row.sleepHours = 5
        row.sleepLevel = .restless
        row.sleepSource = .manual
        coordinator.merge(SleepDTO(hours: 9, level: .deep), into: row)
        #expect(row.sleepHours == 5)              // untouched
        #expect(row.sleepSource == .manual)
    }

    @Test func activityAndHeartMergeIndependently() throws {
        let (coordinator, store, container, _) = try makeFixture(); _ = container
        let row = store.upsert(dayStart: day)
        row.restingHeartRate = 58
        row.heartSource = .manual                 // heart sticky
        coordinator.merge(ActivityDTO(steps: 8000, activeEnergyKcal: 400, exerciseMinutes: 30), into: row)
        coordinator.merge(HeartDTO(restingHeartRate: 70, hrvSDNN: 40), into: row)
        #expect(row.steps == 8000)                // activity filled
        #expect(row.activitySource == .healthKit)
        #expect(row.restingHeartRate == 58)       // heart untouched
        #expect(row.heartSource == .manual)
    }

    // MARK: Orchestration

    @Test func syncFillsRowsFromReader() async throws {
        let (coordinator, store, container, reader) = try makeFixture(); _ = container
        await reader.setSignals([
            DaySignalsDTO(dayStart: day,
                          sleep: SleepDTO(hours: 7, level: .good),
                          activity: ActivityDTO(steps: 9000, activeEnergyKcal: 500, exerciseMinutes: 25),
                          heart: HeartDTO(restingHeartRate: 60, hrvSDNN: 45),
                          cycle: nil)
        ])
        try await coordinator.sync(from: day, to: day)

        let row = try #require(store.fetch(dayStart: day))
        #expect(row.sleepHours == 7)
        #expect(row.steps == 9000)
        #expect(row.restingHeartRate == 60)
        #expect(row.sleepSource == .healthKit)
        let count = await reader.readCallCount
        #expect(count == 1)
    }

    @Test func syncPreservesManualEdits() async throws {
        let (coordinator, store, container, reader) = try makeFixture(); _ = container
        let seeded = store.upsert(dayStart: day)
        seeded.sleepHours = 5.5
        seeded.sleepSource = .manual
        try store.save()

        await reader.setSignals([
            DaySignalsDTO(dayStart: day, sleep: SleepDTO(hours: 8, level: .good),
                          activity: nil, heart: nil, cycle: nil)
        ])
        try await coordinator.sync(from: day, to: day)

        let updated = try #require(store.fetch(dayStart: day))
        #expect(updated.sleepHours == 5.5)        // manual sticks
        #expect(updated.sleepSource == .manual)
    }

    // MARK: US3 — mixed-provenance round-trip (T031)

    @Test func mixedProvenanceRoundTrip() async throws {
        let (coordinator, store, container, reader) = try makeFixture(); _ = container
        let seeded = store.upsert(dayStart: day)
        seeded.sleepHours = 6; seeded.sleepSource = .manual          // manual → must survive
        seeded.restingHeartRate = 55; seeded.heartSource = .healthKit // HK → must refresh
        // activity left .none → must fill
        try store.save()

        await reader.setSignals([
            DaySignalsDTO(dayStart: day,
                          sleep: SleepDTO(hours: 9, level: .deep),
                          activity: ActivityDTO(steps: 7000, activeEnergyKcal: 300, exerciseMinutes: 20),
                          heart: HeartDTO(restingHeartRate: 62, hrvSDNN: 50),
                          cycle: nil)
        ])
        try await coordinator.sync(from: day, to: day)

        let updated = try #require(store.fetch(dayStart: day))
        #expect(updated.sleepHours == 6)                 // manual preserved
        #expect(updated.sleepSource == .manual)
        #expect(updated.steps == 7000)                   // none → filled
        #expect(updated.activitySource == .healthKit)
        #expect(updated.restingHeartRate == 62)          // healthKit → refreshed
        #expect(updated.heartSource == .healthKit)
    }

    // MARK: Cycle merge (was only ever exercised with cycle: nil)

    @Test func cycleMergeWritesFlowAndSymptoms() throws {
        let (coordinator, store, container, _) = try makeFixture(); _ = container
        let row = store.upsert(dayStart: day)
        coordinator.merge(CycleDTO(flow: .medium, symptoms: ["cramps", "headache"]), into: row)
        #expect(row.menstrualFlow == .medium)
        #expect(row.cycleSymptoms == ["cramps", "headache"])
        #expect(row.cycleSource == .healthKit)
    }

    // MARK: Auth-aware sync

    @Test func syncReturnsUnavailableWhenHealthKitUnavailable() async throws {
        let (coordinator, _, container, reader) = try makeFixture(); _ = container
        await reader.setState(.unavailable)
        let result = try await coordinator.sync(from: day, to: day)
        #expect(result == .unavailable)
        let count = await reader.readCallCount
        #expect(count == 0)                              // short-circuits before reading
    }

    // MARK: sync(lastDays:) window math

    @Test func syncLastDaysRequestsInclusiveWindowEndingToday() async throws {
        let (coordinator, _, container, reader) = try makeFixture(); _ = container
        let cal = Calendar.current

        try await coordinator.sync(lastDays: 30)
        let r30 = try #require(await reader.lastRequestedRange)
        #expect(cal.dateComponents([.day], from: r30.start, to: r30.end).day == 29)  // 30 days inclusive
        #expect(cal.isDateInToday(r30.end))

        try await coordinator.sync(lastDays: 1)
        let r1 = try #require(await reader.lastRequestedRange)
        #expect(cal.dateComponents([.day], from: r1.start, to: r1.end).day == 0)     // today only

        try await coordinator.sync(lastDays: 0)
        let r0 = try #require(await reader.lastRequestedRange)
        #expect(cal.dateComponents([.day], from: r0.start, to: r0.end).day == 0)     // clamped to 1
    }

    // MARK: Multi-day assembly

    @Test func syncFillsEachDayInMultiDayPayload() async throws {
        let (coordinator, store, container, reader) = try makeFixture(); _ = container
        let d0 = day
        let d1 = SignalDayKey.dayStart(for: day.addingTimeInterval(86_400))
        await reader.setSignals([
            DaySignalsDTO(dayStart: d0, sleep: SleepDTO(hours: 7, level: .good), activity: nil, heart: nil, cycle: nil),
            DaySignalsDTO(dayStart: d1, sleep: nil,
                          activity: ActivityDTO(steps: 5000, activeEnergyKcal: nil, exerciseMinutes: nil),
                          heart: nil, cycle: nil)
        ])
        let result = try await coordinator.sync(from: d0, to: d1)
        #expect(result == .completed(daysWritten: 2))
        #expect(store.fetch(dayStart: d0)?.sleepHours == 7)
        #expect(store.fetch(dayStart: d1)?.steps == 5000)
    }

    // MARK: US3 — nutrition-event sweep

    private func makeNutritionFixture() throws -> (SignalSyncCoordinator, SignalsStore, ModelContainer, MockHealthDataReading) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailySignals.self, NutritionEvent.self, configurations: config)
        let store = SignalsStore(context: container.mainContext)
        let reader = MockHealthDataReading()
        return (SignalSyncCoordinator(reader: reader, store: store), store, container, reader)
    }

    private func foodDTO(on day: Date, hour: Int, kcal: Double) -> NutritionEventDTO {
        NutritionEventDTO(kind: .food, startDate: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!,
                          endDate: nil, name: "Meal", kcal: kcal, proteinGrams: nil, caffeineMg: nil, durationMinutes: nil)
    }

    @Test func syncWritesNutritionEvents() async throws {
        let (coordinator, store, container, reader) = try makeNutritionFixture(); _ = container
        await reader.setNutritionEvents([foodDTO(on: day, hour: 8, kcal: 500), foodDTO(on: day, hour: 13, kcal: 700)])
        try await coordinator.sync(from: day, to: day)
        let events = store.fetchEvents(from: day, to: day)
        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.source == .healthKit && !$0.isMockData })
    }

    @Test func reSyncReplacesNutritionWithoutDuplicating() async throws {
        let (coordinator, store, container, reader) = try makeNutritionFixture(); _ = container
        await reader.setNutritionEvents([foodDTO(on: day, hour: 8, kcal: 500)])
        try await coordinator.sync(from: day, to: day)
        try await coordinator.sync(from: day, to: day)   // same window again
        #expect(store.fetchEvents(from: day, to: day).count == 1)   // replaced, not doubled
    }

    @Test func nutritionSweepShortCircuitsWhenUnavailable() async throws {
        let (coordinator, store, container, reader) = try makeNutritionFixture(); _ = container
        await reader.setState(.unavailable)
        await reader.setNutritionEvents([foodDTO(on: day, hour: 8, kcal: 500)])
        _ = try await coordinator.sync(from: day, to: day)
        #expect(store.fetchEvents(from: day, to: day).isEmpty)
        let count = await reader.nutritionReadCallCount
        #expect(count == 0)
    }
}
