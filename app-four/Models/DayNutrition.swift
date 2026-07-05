import Foundation

/// Immutable snapshot of a `NutritionEvent` for the view layer — no `@Model` reaches
/// the cards, and previews/tests build these directly (spec 031).
struct NutritionEventItem: Identifiable, Equatable, Sendable {
    let kind: NutritionEventKind
    let startDate: Date
    let name: String?
    let kcal: Double?
    let proteinGrams: Double?
    let caffeineMg: Double?
    let durationMinutes: Double?
    let source: SignalSource
    let isMockData: Bool

    /// Stable across recomputes (events are rebuilt each timeline pass), unique enough
    /// for one day's ForEach: two same-kind events never share a start instant + name.
    var id: String { "\(kind.rawValue)-\(startDate.timeIntervalSinceReferenceDate)-\(name ?? "")" }
}

extension NutritionEventItem {
    init(_ event: NutritionEvent) {
        self.init(
            kind: event.kind,
            startDate: event.startDate,
            name: event.name,
            kcal: event.kcal,
            proteinGrams: event.proteinGrams,
            caffeineMg: event.caffeineMg,
            durationMinutes: event.durationMinutes,
            source: event.source,
            isMockData: event.isMockData
        )
    }
}

/// Per-day totals for the folded tokens and the unfolded footer. Each Σ is nil when no
/// event carries that metric — "—" placeholders render from nil, never from 0 (FR-004).
struct NutritionSummary: Equatable, Sendable {
    let kcalIn: Double?
    let proteinG: Double?
    let caffeineMg: Double?
    let kcalOut: Double?
    let source: SignalSource
}

/// Everything the day card needs about one day's nutrition: the event list (newest
/// first, matching the timeline convention) and its derived totals.
struct DayNutrition: Equatable, Sendable {
    let events: [NutritionEventItem]
    let summary: NutritionSummary
}
