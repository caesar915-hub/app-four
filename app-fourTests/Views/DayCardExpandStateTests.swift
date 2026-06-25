import Testing
import Foundation
@testable import app_four

/// Test-first (Constitution Principle X) for the pure expand/selection state machine
/// behind the daily-card redesign (FR-005, FR-009, FR-019). `ExpandedDayCards` is a value
/// type so these rules are verifiable without a SwiftUI host.
@Suite struct DayCardExpandStateTests {

    private let cal = Calendar.current
    /// A fixed calendar day, `offset` days from a stable anchor (no `Date()` → deterministic).
    private func day(_ offset: Int) -> Date {
        let anchor = cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        return cal.date(byAdding: .day, value: offset, to: anchor)!
    }

    // MARK: - FR-005: independent header toggle

    @Test func togglingAddsThenRemoves() {
        let d = day(0)
        var s = ExpandedDayCards()
        #expect(!s.contains(d))
        s = s.toggling(d)
        #expect(s.contains(d))
        s = s.toggling(d)
        #expect(!s.contains(d))
    }

    @Test func togglingIsIndependentAcrossCards() {
        let a = day(0), b = day(1)
        let s = ExpandedDayCards().toggling(a).toggling(b)
        #expect(s.contains(a))
        #expect(s.contains(b))            // multiple open at once (FR-005)
        let afterA = s.toggling(a)
        #expect(!afterA.contains(a))
        #expect(afterA.contains(b))       // toggling A left B untouched
    }

    @Test func membershipIsKeyedByCalendarDay() {
        let base = day(0)
        let sameDayLater = base.addingTimeInterval(13 * 3600)   // +13h, same calendar day
        let s = ExpandedDayCards().toggling(base)
        #expect(s.contains(sameDayLater))
    }

    // MARK: - FR-009 / FR-019: selection collapses others, opens only selected

    @Test func selectingAutoExpandOpensOnlySelected() {
        let a = day(0), b = day(1)
        let s = ExpandedDayCards().toggling(a).toggling(b)
        let sel = s.selecting(b, autoExpand: true)
        #expect(sel.contains(b))
        #expect(!sel.contains(a))         // collapse-all then open selected (FR-009)
    }

    @Test func selectingWithoutAutoExpandClosesEverything() {
        let a = day(0)
        let s = ExpandedDayCards().toggling(a)
        let sel = s.selecting(a, autoExpand: false)
        #expect(!sel.contains(a))         // auto-expand OFF ⇒ nothing opens (FR-019)
    }

    @Test func reselectingSameDateIsIdempotent() {
        let a = day(0)
        let once = ExpandedDayCards().selecting(a, autoExpand: true)
        let twice = once.selecting(a, autoExpand: true)
        #expect(once == twice)            // FR-009 idempotent re-selection
        #expect(twice.contains(a))
    }
}
