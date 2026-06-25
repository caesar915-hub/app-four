import Testing
import Foundation
@testable import app_four

/// Test-first (Constitution Principle X) for the folded day-card summary derivation
/// (FR-002, FR-003, FR-004). Exercises the pure `DayCardSummary` type, not the SwiftUI view.
@MainActor
@Suite struct FoldedDayCardHeaderTests {

    private let cal = Calendar.current
    private func at(_ hour: Int) -> Date {
        let base = cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private func rec(_ mood: String?, _ energy: String? = nil, _ focus: String? = nil) -> Recording {
        let r = Recording(audioFileName: "a.m4a", duration: 0, title: "t", mood: mood)
        r.energyLevel = energy
        r.focusLevel = focus
        return r
    }
    private func med(_ name: String) -> MedicationEvent {
        MedicationEvent(name: name, dose: "18mg", takenAt: Date(), taken: true, durationHours: 8, source: .manual)
    }
    private func node(_ time: Date, rec: Recording? = nil, doses: [MedicationEvent] = []) -> DayTimeline.Node {
        DayTimeline.Node(id: "\(time.timeIntervalSince1970)", time: time, recording: rec, intakeDoses: doses, rings: [])
    }
    private func summary(_ nodes: [DayTimeline.Node]) -> DayCardSummary {
        DayCardSummary(day: .init(date: cal.startOfDay(for: at(0)), label: "L", nodes: nodes))
    }

    // FR-002 — unlogged signals omitted, never zeroed/blanked
    @Test func omitsUnloggedSignals() {
        let s = summary([node(at(16), rec: rec("Great"))])
        #expect(s.mood == "Great")
        #expect(s.energy == nil)
        #expect(s.focus == nil)
    }

    // FR-003 — multi-medication day shows the most-recent check-in's med name only
    @Test func multiMedDayShowsMostRecentMedOnly() {
        let nodes = [
            node(at(16), rec: rec("Good", "Charged", "Present"), doses: [med("Vyvanse")]),  // newest
            node(at(9),  rec: rec("Okay"),                       doses: [med("Concerta")]),
        ]
        #expect(summary(nodes).mostRecentMedicationName == "Vyvanse")
    }

    @Test func signalsComeFromLatestRecording() {
        let nodes = [
            node(at(16), rec: rec("Good", "Charged", "Present")),   // newest → wins
            node(at(9),  rec: rec("Low", "Tired", "Foggy")),
        ]
        let s = summary(nodes)
        #expect(s.mood == "Good")
        #expect(s.energy == "Charged")
        #expect(s.focus == "Present")
    }

    @Test func noMedicationDayYieldsNil() {
        #expect(summary([node(at(10), rec: rec("Okay"))]).mostRecentMedicationName == nil)
    }

    // FR-004 — empty day reads the calm copy, exactly
    @Test func emptyDayFlagAndCopy() {
        let s = summary([])
        #expect(s.isEmpty)
        #expect(DayCardSummary.emptyCopy == "No check-ins this day. That's alright.")
    }
}
