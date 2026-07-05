import Testing
import SwiftData
import Foundation
@testable import app_four

@MainActor
struct NutritionEventTests {
    // Held for the lifetime of each test so the context stays valid.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: NutritionEvent.self, configurations: config)
    }

    @Test func newEventDefaultsToHealthKitRealFoodWithNilMetrics() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = NutritionEvent(startDate: Date(timeIntervalSince1970: 0), kind: .food)
        context.insert(event)
        try context.save()

        #expect(event.kind == .food)
        #expect(event.source == .healthKit)
        #expect(event.isMockData == false)
        #expect(event.name == nil)
        #expect(event.kcal == nil)
        #expect(event.proteinGrams == nil)
        #expect(event.caffeineMg == nil)
        #expect(event.durationMinutes == nil)
        #expect(event.endDate == nil)
    }

    @Test func kindBridgesRawValueBothDirections() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = NutritionEvent(startDate: Date(timeIntervalSince1970: 0), kind: .exercise)
        context.insert(event)

        #expect(event.kindValue == "exercise")
        event.kind = .food
        #expect(event.kindValue == "food")
        event.kindValue = "exercise"
        #expect(event.kind == .exercise)
    }

    @Test func sourceBridgesRawValueBothDirections() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = NutritionEvent(startDate: Date(timeIntervalSince1970: 0), kind: .food)
        context.insert(event)

        event.source = .manual
        #expect(event.sourceValue == "manual")
        event.sourceValue = "healthKit"
        #expect(event.source == .healthKit)
    }
}
