import Foundation

/// A dietary sample not contained in any `.food` correlation — the HealthKit-free value the
/// service extracts so the hourly-bucketing rule can be unit-tested without importing HealthKit.
struct LooseDietarySample: Sendable, Equatable {
    let startDate: Date
    let kcal: Double?
    let proteinGrams: Double?
    let caffeineMg: Double?
}

/// Pure value logic for turning nutrition events into display aggregates. HealthKit-free
/// so the rules stay unit-testable (pattern: `HealthKitSampleMapping`).
enum NutritionEventGrouping {

    /// Buckets loose dietary samples into one food event per clock hour (spec 031, clarify Q1).
    /// A bucket with no metric at all is dropped — never emit an empty event.
    static func hourlyFoodEvents(loose: [LooseDietarySample], calendar: Calendar) -> [NutritionEventDTO] {
        let byHour = Dictionary(grouping: loose) { sample in
            calendar.dateInterval(of: .hour, for: sample.startDate)?.start ?? sample.startDate
        }
        func sum(_ values: [Double?]) -> Double? {
            let present = values.compactMap { $0 }
            return present.isEmpty ? nil : present.reduce(0, +)
        }
        return byHour.keys.sorted().compactMap { hour in
            let samples = byHour[hour] ?? []
            let kcal = sum(samples.map(\.kcal))
            let protein = sum(samples.map(\.proteinGrams))
            let caffeine = sum(samples.map(\.caffeineMg))
            guard kcal != nil || protein != nil || caffeine != nil else { return nil }
            return NutritionEventDTO(kind: .food, startDate: hour, endDate: nil, name: nil,
                                     kcal: kcal, proteinGrams: protein, caffeineMg: caffeine,
                                     durationMinutes: nil)
        }
    }

    /// Day totals. `kcalOut` sums exercise events ONLY (spec 031 clarification Q3): the
    /// footer must reconcile with the visible timeline, never with all-day active energy.
    static func summary(for events: [NutritionEventItem]) -> NutritionSummary {
        func total(_ values: [Double?]) -> Double? {
            let present = values.compactMap { $0 }
            return present.isEmpty ? nil : present.reduce(0, +)
        }
        let food = events.filter { $0.kind == .food }
        let workouts = events.filter { $0.kind == .exercise }
        return NutritionSummary(
            kcalIn: total(food.map(\.kcal)),
            proteinG: total(food.map(\.proteinGrams)),
            caffeineMg: total(food.map(\.caffeineMg)),
            kcalOut: total(workouts.map(\.kcal)),
            source: events.contains { $0.source == .manual } ? .manual : .healthKit
        )
    }
}
