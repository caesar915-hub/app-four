import Foundation

/// The set of day-cards currently expanded in the calendar list, as a small value type so
/// the expand / selection rules are pure and unit-testable (Constitution Principle X). The
/// view holds it as `@State` and replaces it wholesale on each change. Keys are normalised
/// to start-of-day so a card is identified by its calendar day regardless of check-in time.
struct ExpandedDayCards: Equatable {
    private var dates: Set<Date>

    init(_ dates: Set<Date> = []) {
        let cal = Calendar.current
        self.dates = Set(dates.map { cal.startOfDay(for: $0) })
    }

    /// Is the card for `date` expanded?
    func contains(_ date: Date) -> Bool {
        dates.contains(Calendar.current.startOfDay(for: date))
    }

    /// Toggle one card independently — every other card is untouched (FR-005). Multiple
    /// cards may be open at once.
    func toggling(_ date: Date) -> ExpandedDayCards {
        let key = Calendar.current.startOfDay(for: date)
        var next = dates
        if next.contains(key) { next.remove(key) } else { next.insert(key) }
        return ExpandedDayCards(next)
    }

    /// Select a date: collapse every open card, then open only `date` when `autoExpand` is
    /// on (FR-009, FR-019). Idempotent when `date` is already the sole open card.
    func selecting(_ date: Date, autoExpand: Bool) -> ExpandedDayCards {
        autoExpand ? ExpandedDayCards([date]) : ExpandedDayCards()
    }

    /// Whether the card for `date` should render expanded: the "Always expand cards" setting
    /// (FR-008) opens every card, otherwise the per-card open set decides. Pure value-logic so
    /// the calendar's effective-expansion rule is unit-testable without a SwiftUI host.
    func shouldExpand(_ date: Date, alwaysExpand: Bool) -> Bool {
        alwaysExpand || contains(date)
    }
}
