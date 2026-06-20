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
}
