import Testing
import SwiftData
import Foundation
@testable import app_four

@MainActor
struct DailySignalsTests {
    // Held for the lifetime of each test so the context stays valid.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: DailySignals.self, configurations: config)
    }

    @Test func newDayDefaultsToNoneSourcesAndNilFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let day = DailySignals(dayStart: Date(timeIntervalSince1970: 0))
        context.insert(day)
        try context.save()

        #expect(day.sleepSource == .none)
        #expect(day.activitySource == .none)
        #expect(day.heartSource == .none)
        #expect(day.cycleSource == .none)
        #expect(day.sleepHours == nil)
        #expect(day.steps == nil)
        #expect(day.menstrualFlow == nil)
        #expect(day.isMockData == false)
    }

    @Test func cycleSymptomsRoundTripThroughJSON() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let day = DailySignals(dayStart: Date(timeIntervalSince1970: 0))
        context.insert(day)
        day.cycleSymptoms = ["cramps", "headache"]
        try context.save()

        #expect(day.cycleSymptoms == ["cramps", "headache"])

        day.cycleSymptoms = []
        #expect(day.cycleSymptomsJSON == nil)
        #expect(day.cycleSymptoms.isEmpty)
    }

    @Test func sleepLevelBridgesRawValue() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let day = DailySignals(dayStart: Date(timeIntervalSince1970: 0))
        context.insert(day)
        day.sleepLevel = .good
        #expect(day.sleepLevelValue == "good")
        #expect(day.sleepLevel == .good)
        day.sleepLevel = nil
        #expect(day.sleepLevelValue == nil)
    }
}
