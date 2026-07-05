import Testing
import SwiftData
import Foundation
@testable import app_four

@MainActor
struct MockDataGeneratorNutritionTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: NutritionEvent.self, configurations: config)
    }

    /// Fixed anchor so both runs of a determinism check see identical day boundaries.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let calendar = Calendar.current

    private func seededEventsByDay(_ container: ModelContainer) throws -> [Date: [NutritionEvent]] {
        let context = container.mainContext
        MockDataGenerator.seedNutritionEvents(context: context, calendar: calendar, now: now)
        let all = try context.fetch(FetchDescriptor<NutritionEvent>())
        return Dictionary(grouping: all) { calendar.startOfDay(for: $0.startDate) }
    }

    @Test func seedsRoughlyTwentyEightOfThirtyDays() throws {
        let byDay = try seededEventsByDay(try makeContainer())
        #expect(byDay.count == 28)   // 30-day window minus ~2 skip days

        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -29, to: today)!
        #expect(byDay.keys.allSatisfy { $0 >= windowStart && $0 <= today })
    }

    @Test func everyEventIsMockAndHealthKitSourced() throws {
        let byDay = try seededEventsByDay(try makeContainer())
        let all = byDay.values.flatMap { $0 }
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { $0.isMockData })
        #expect(all.allSatisfy { $0.source == .healthKit })
    }

    @Test func dailyShapeIsThreeToFourMealsAndAtMostOneWorkout() throws {
        let byDay = try seededEventsByDay(try makeContainer())
        for (_, events) in byDay {
            let meals = events.filter { $0.kind == .food }
            let workouts = events.filter { $0.kind == .exercise }
            #expect((3...4).contains(meals.count))
            #expect(workouts.count <= 1)
            // Realistic hours: nothing before 06:00 or after 23:00.
            #expect(events.allSatisfy { (6...23).contains(calendar.component(.hour, from: $0.startDate)) })
            // Meals carry at least one metric; workouts carry duration + kcal.
            #expect(meals.allSatisfy { $0.kcal != nil || $0.proteinGrams != nil || $0.caffeineMg != nil })
            #expect(workouts.allSatisfy { $0.durationMinutes != nil && $0.kcal != nil })
        }
    }

    @Test func caffeineIsLowerOnMedDaysThanOffDays() throws {
        // generate() always logs a morning dose on offsets 0..<10, so those are the
        // "medicated" days; the seed correlates caffeine inversely with them.
        let byDay = try seededEventsByDay(try makeContainer())
        let today = calendar.startOfDay(for: now)

        func caffeineTotal(_ events: [NutritionEvent]) -> Double {
            events.compactMap(\.caffeineMg).reduce(0, +)
        }
        var medDayTotals: [Double] = []
        var offDayTotals: [Double] = []
        for (day, events) in byDay {
            let offset = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            if offset < 10 {
                medDayTotals.append(caffeineTotal(events))
            } else {
                offDayTotals.append(caffeineTotal(events))
            }
        }
        let maxMed = try #require(medDayTotals.max())
        let minOff = try #require(offDayTotals.min())
        #expect(maxMed < minOff)
    }

    @Test func reseedingIsDeterministic() throws {
        func fingerprint(_ byDay: [Date: [NutritionEvent]]) -> [String] {
            byDay.values.flatMap { $0 }
                .map { "\($0.startDate.timeIntervalSince1970)|\($0.kindValue)|\($0.name ?? "")|\($0.kcal ?? -1)|\($0.proteinGrams ?? -1)|\($0.caffeineMg ?? -1)|\($0.durationMinutes ?? -1)" }
                .sorted()
        }
        let first = fingerprint(try seededEventsByDay(try makeContainer()))
        let second = fingerprint(try seededEventsByDay(try makeContainer()))
        #expect(first == second)
        #expect(!first.isEmpty)
    }
}
