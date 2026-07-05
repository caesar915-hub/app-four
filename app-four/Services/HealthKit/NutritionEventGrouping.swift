import Foundation

/// Pure value logic for turning nutrition events into display aggregates. HealthKit-free
/// so the rules stay unit-testable (pattern: `HealthKitSampleMapping`).
enum NutritionEventGrouping {
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
