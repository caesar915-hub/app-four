import Testing
import Foundation
@testable import app_four

/// Test-first (Constitution Principle X) for the folded day-card summary derivation
/// (FR-002, FR-003, FR-004). Exercises the pure `DayCardSummary` type, not the SwiftUI view.
/// Mood, energy and focus are rounded-up averages across the day's check-ins.
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
    private func recSleep(_ mood: String?, hours: Double?) -> Recording {
        let r = rec(mood)
        r.sleepHours = hours
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

    // Mood, energy and focus are now rounded-up averages across the day.
    @Test func signalsAreAveragedAcrossRecordings() {
        let nodes = [
            node(at(16), rec: rec("Good", "Charged", "Present")),
            node(at(9),  rec: rec("Okay", "Tired", "Foggy")),
        ]
        let s = summary(nodes)
        // mood:  (4 + 3) / 2 = 3.5 → 4 = Good
        // energy: (5 + 2) / 2 = 3.5 → 4 = Alert
        // focus:  (3 + 1) / 2 = 2.0 → 2 = Distracted
        #expect(s.mood == "Good")
        #expect(s.energy == "Alert")
        #expect(s.focus == "Distracted")
    }

    @Test func moodAveragesRoundUp() {
        let great = summary([
            node(at(16), rec: rec("Good")),
            node(at(9),  rec: rec("Great")),
        ])
        #expect(great.mood == "Great") // 4.5 → 5

        let good = summary([
            node(at(16), rec: rec("Okay")),
            node(at(9),  rec: rec("Great")),
        ])
        #expect(good.mood == "Good") // 4.0 → 4
    }

    @Test func energyAveragesRoundUp() {
        let charged = summary([
            node(at(16), rec: rec(nil, "Alert")),
            node(at(9),  rec: rec(nil, "Charged")),
        ])
        #expect(charged.energy == "Charged") // 4.5 → 5

        let alert = summary([
            node(at(16), rec: rec(nil, "Steady")),
            node(at(9),  rec: rec(nil, "Alert")),
        ])
        #expect(alert.energy == "Alert") // 3.5 → 4
    }

    @Test func focusAveragesRoundUp() {
        let sharp = summary([
            node(at(16), rec: rec(nil, nil, "Present")),
            node(at(9),  rec: rec(nil, nil, "Sharp")),
        ])
        #expect(sharp.focus == "Sharp") // 3.5 → 4

        let distracted = summary([
            node(at(16), rec: rec(nil, nil, "Foggy")),
            node(at(9),  rec: rec(nil, nil, "Distracted")),
        ])
        #expect(distracted.focus == "Distracted") // 1.5 → 2
    }

    @Test func signalMissingFromSomeRecordingsIsAveragedOnlyFromThoseThatHaveIt() {
        let nodes = [
            node(at(16), rec: rec("Great", nil, "Sharp")),       // energy missing
            node(at(9),  rec: rec("Good", "Charged", "Foggy")),
        ]
        let s = summary(nodes)
        #expect(s.mood == "Great")     // (5 + 4) / 2 = 4.5 → 5
        #expect(s.energy == "Charged") // only one value
        #expect(s.focus == "Present")  // (4 + 1) / 2 = 2.5 → 3
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

    // MARK: - spec 034 FR-003: sleep summary derivation (most recent captured sleep)

    @Test func sleepComesFromMostRecentRecording() {
        let nodes = [
            node(at(16), rec: recSleep("Good", hours: 6)),   // newest → wins
            node(at(9),  rec: recSleep("Okay", hours: 8)),
        ]
        #expect(summary(nodes).sleep == "6h sleep")
    }

    @Test func sleepFallsBackToOlderNodeWhenNewestHasNone() {
        let nodes = [
            node(at(16), rec: rec("Good")),                  // newest, no sleep
            node(at(9),  rec: recSleep("Okay", hours: 7)),
        ]
        #expect(summary(nodes).sleep == "7h sleep")
    }

    @Test func noSleepAnywhereYieldsNil() {
        #expect(summary([node(at(10), rec: rec("Okay"))]).sleep == nil)
    }

    @Test func sleepHoursFormatsWithoutDecimalWhenWhole() {
        #expect(summary([node(at(10), rec: recSleep("Okay", hours: 7))]).sleep == "7h sleep")
    }
}
