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
