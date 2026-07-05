import Testing
import Foundation
@testable import app_four

/// Pure value logic — no HealthKit, no SwiftData.
struct NutritionEventGroupingTests {

    private func food(kcal: Double? = nil, protein: Double? = nil, caffeine: Double? = nil,
                      source: SignalSource = .healthKit, at hour: Int = 12) -> NutritionEventItem {
        NutritionEventItem(
            kind: .food,
            startDate: Date(timeIntervalSince1970: TimeInterval(hour) * 3600),
            name: nil, kcal: kcal, proteinGrams: protein, caffeineMg: caffeine,
            durationMinutes: nil, source: source, isMockData: false
        )
    }

    private func workout(kcal: Double?, minutes: Double? = 30,
                         source: SignalSource = .healthKit) -> NutritionEventItem {
        NutritionEventItem(
            kind: .exercise,
            startDate: Date(timeIntervalSince1970: 18 * 3600),
            name: "Run", kcal: kcal, proteinGrams: nil, caffeineMg: nil,
            durationMinutes: minutes, source: source, isMockData: false
        )
    }

    // MARK: - summary(for:)

    @Test func summarySumsFoodMetricsPerMetric() {
        let summary = NutritionEventGrouping.summary(for: [
            food(kcal: 520, protein: 22, caffeine: 95),
            food(kcal: 780, protein: 34),
            food(caffeine: 125),
        ])
        #expect(summary.kcalIn == 1300)
        #expect(summary.proteinG == 56)
        #expect(summary.caffeineMg == 220)
    }

    @Test func kcalOutIsWorkoutSumOnly() {
        // Clarification Q3: energy out = Σ exercise kcal; food kcal never leaks into it.
        let summary = NutritionEventGrouping.summary(for: [
            food(kcal: 2000),
            workout(kcal: 310),
            workout(kcal: 100),
        ])
        #expect(summary.kcalOut == 410)
        #expect(summary.kcalIn == 2000)
    }

    @Test func exerciseKcalNeverContributesToKcalIn() {
        let summary = NutritionEventGrouping.summary(for: [workout(kcal: 310)])
        #expect(summary.kcalIn == nil)
        #expect(summary.kcalOut == 310)
    }

    @Test func missingMetricsAreNilNotZero() {
        // "—" placeholders in the footer come from nil, never 0 (FR-004).
        let summary = NutritionEventGrouping.summary(for: [food(kcal: 500)])
        #expect(summary.proteinG == nil)
        #expect(summary.caffeineMg == nil)
        #expect(summary.kcalOut == nil)
    }

    @Test func emptyEventsYieldAllNilSummary() {
        let summary = NutritionEventGrouping.summary(for: [])
        #expect(summary.kcalIn == nil)
        #expect(summary.proteinG == nil)
        #expect(summary.caffeineMg == nil)
        #expect(summary.kcalOut == nil)
    }

    // MARK: - hourlyFoodEvents(loose:)

    private let cal = Calendar(identifier: .gregorian)

    private func sample(_ h: Int, _ m: Int, kcal: Double? = nil, protein: Double? = nil,
                        caffeine: Double? = nil) -> LooseDietarySample {
        var comps = DateComponents(); comps.year = 2026; comps.month = 7; comps.day = 5
        comps.hour = h; comps.minute = m
        return LooseDietarySample(startDate: cal.date(from: comps)!, kcal: kcal,
                                  proteinGrams: protein, caffeineMg: caffeine)
    }

    @Test func loseSamplesInSameHourCollapseToOneEvent() {
        let events = NutritionEventGrouping.hourlyFoodEvents(loose: [
            sample(13, 5, kcal: 500, protein: 20),
            sample(13, 40, caffeine: 30),
        ], calendar: cal)
        #expect(events.count == 1)
        #expect(events[0].kcal == 500)
        #expect(events[0].proteinGrams == 20)
        #expect(events[0].caffeineMg == 30)
        #expect(events[0].kind == .food)
    }

    @Test func samplesInDifferentHoursSplit() {
        let events = NutritionEventGrouping.hourlyFoodEvents(loose: [
            sample(12, 59, kcal: 300),
            sample(13, 1, kcal: 400),
        ], calendar: cal)
        #expect(events.count == 2)
        #expect(Set(events.compactMap(\.kcal)) == [300, 400])
    }

    @Test func hourlyEventTimestampAnchorsToTheHour() {
        let events = NutritionEventGrouping.hourlyFoodEvents(loose: [sample(8, 45, kcal: 200)], calendar: cal)
        #expect(events.count == 1)
        #expect(cal.component(.hour, from: events[0].startDate) == 8)
    }

    @Test func hourlyGroupingNeverEmitsAnAllNilEvent() {
        let events = NutritionEventGrouping.hourlyFoodEvents(loose: [
            sample(9, 0),   // no metrics — must not produce an event
            sample(9, 30, kcal: 100),
        ], calendar: cal)
        #expect(events.count == 1)
        #expect(events[0].kcal == 100)
    }

    @Test func summarySourceIsManualWhenAnyContributorIsManual() {
        let mixed = NutritionEventGrouping.summary(for: [
            food(kcal: 500, source: .healthKit),
            food(kcal: 300, source: .manual),
        ])
        #expect(mixed.source == .manual)

        let allHealth = NutritionEventGrouping.summary(for: [food(kcal: 500)])
        #expect(allHealth.source == .healthKit)
    }
}
