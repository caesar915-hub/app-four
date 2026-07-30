import Foundation
import Testing
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct InsightsViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recording.self, MedicationEvent.self, AppSettings.self, configurations: config)
    }()

    let context: ModelContext
    let store: RecordingStore
    /// Fixed month (June 2025) so tests are deterministic.
    let month = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!

    init() throws {
        TestSupport.useRealData()
        context = Self.container.mainContext
        try context.delete(model: Recording.self)
        try context.delete(model: MedicationEvent.self)
        try context.delete(model: AppSettings.self)
        store = RecordingStore(context: context)
    }

    @discardableResult
    private func add(day: Int = 1, hour: Int = 10, mood: String? = nil, energy: String? = nil,
                     focus: String? = nil, sleepQuality: String? = nil, med: String? = nil) -> Recording {
        let date = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: day, hour: hour))!
        let r = Recording(createdAt: date, audioFileName: "r.m4a",
                          energyLevel: energy, focusLevel: focus, mood: mood, sleepQuality: sleepQuality)
        context.insert(r)
        if let med {
            let e = MedicationEvent(name: med, takenAt: date, taken: true, source: .manual)
            context.insert(e); e.recording = r
        }
        try? context.save(); store.loadRecordings()
        return r
    }

    private func vm() -> InsightsViewModel {
        let v = InsightsViewModel(store: store); v.currentMonth = month; return v
    }

    // MARK: - moodShares

    @Test func moodSharesCountsOnlyMoodPresent() {
        add(mood: "okay"); add(mood: "okay"); add(mood: "good"); add(energy: "alert") // no mood
        let shares = vm().moodShares
        #expect(shares.reduce(0) { $0 + $1.count } == 3)
        let okay = shares.first { $0.level == .okay }
        #expect(okay?.count == 2)
        #expect(abs((okay?.fraction ?? 0) - 2.0 / 3.0) < 0.0001)
    }

    @Test func moodSharesEmptyWhenNoMood() {
        add(energy: "alert")
        #expect(vm().moodShares.isEmpty)
    }

    // MARK: - signalStrips

    @Test func signalStripsAreChronologicalWithEmptyBeads() {
        add(day: 2, mood: "good"); add(day: 1, mood: "okay"); add(day: 3, energy: "alert") // day3 has no mood
        let mood = vm().signalStrips.first { $0.kind == .mood }!
        #expect(mood.beads.count == 3)
        #expect((mood.beads[0].level as? MoodLevel) == .okay) // day 1 first
        #expect((mood.beads[1].level as? MoodLevel) == .good) // day 2
        #expect(mood.beads[2].level == nil)                   // day 3 no mood → empty
    }

    @Test func stripSummaryIsModalLabel() {
        add(mood: "okay"); add(mood: "okay"); add(mood: "great")
        #expect(vm().signalStrips.first { $0.kind == .mood }!.summary == "mostly Okay")
    }

    @Test func stripSummaryNoDataWhenSignalAbsent() {
        add(mood: "okay")
        #expect(vm().signalStrips.first { $0.kind == .focus }!.summary == "no data")
    }

    // MARK: - signalAverages

    @Test func averageHalfStepGetsPlusLabel() {
        add(mood: "okay"); add(mood: "good") // avg 3.5 → "Okay+", "between Okay & Good", 0.7
        let a = vm().signalAverages.first { $0.kind == .mood }!
        #expect(a.fillLabel == "Okay+")
        #expect(a.caption == "between Okay & Good")
        #expect(abs(a.fraction - 0.7) < 0.0001)
    }

    @Test func averageWholeStepUsesWord() {
        add(energy: "steady"); add(energy: "steady")
        let a = vm().signalAverages.first { $0.kind == .energy }!
        #expect(a.fillLabel == "Steady")
        #expect(a.caption == "Steady on average")
    }

    @Test func averageEmptyWhenNoData() {
        add(mood: "okay")
        let f = vm().signalAverages.first { $0.kind == .focus }!
        #expect(f.isEmpty)
        #expect(f.fillLabel == "—")
    }

    // spec-036 FR-010: the view must never re-derive the ordinal from `fraction` —
    // the VM ships the level explicitly so fill/glyph and fillLabel cannot disagree.
    @Test func averageLevelMatchesLabelOrdinal() {
        add(mood: "okay"); add(mood: "good"); add(mood: "okay")   // avg 3.33… → "Okay+"
        let a = vm().signalAverages.first { $0.kind == .mood }!
        #expect(a.level == 3)
        #expect(a.fillLabel.hasPrefix("Okay"))
        let empty = vm().signalAverages.first { $0.kind == .focus }!
        #expect(empty.level == 0)
    }

    // MARK: - rhythmMatrix

    @Test func rhythmDominantPerBucket() {
        add(hour: 8, mood: "okay"); add(hour: 9, mood: "okay"); add(hour: 9, mood: "great") // morning okay×2
        add(hour: 14, mood: "good") // afternoon
        let mood = vm().rhythmMatrix.first { $0.kind == .mood }!
        #expect((mood.cells[0].dominant as? MoodLevel) == .okay)  // morning
        #expect((mood.cells[1].dominant as? MoodLevel) == .good)  // afternoon
        #expect(mood.cells[2].dominant == nil)                    // evening empty
        #expect(mood.cells[3].dominant == nil)                    // late empty
    }

    @Test func rhythmTieBreaksToHigherLevel() {
        add(hour: 8, mood: "okay"); add(hour: 8, mood: "great") // 1–1 tie → higher (great)
        #expect((vm().rhythmMatrix.first { $0.kind == .mood }!.cells[0].dominant as? MoodLevel) == .great)
    }

    @Test func rhythmLateBucketIncludesPostMidnight() {
        add(hour: 2, mood: "low") // 02:00 → Late, not dropped
        #expect((vm().rhythmMatrix.first { $0.kind == .mood }!.cells[3].dominant as? MoodLevel) == .low)
    }

    // MARK: - connections (gating boundaries are the critical cases)

    @Test func medFocusGatedBelowFourDays() {
        for d in 1...3 { add(day: d, focus: "sharp", med: "Concerta") }
        guard case .gated = vm().connections[0].state else { Issue.record("expected gated med×focus"); return }
    }

    @Test func medFocusUnlocksAtFourDays() {
        for d in 1...4 { add(day: d, hour: 14, focus: "sharp", med: "Concerta") }
        guard case .unlocked(_, let frac, _, _, _) = vm().connections[0].state else {
            Issue.record("expected unlocked med×focus"); return
        }
        #expect(abs(frac - 1.0) < 0.0001) // 4/4 sharp-or-better
    }

    @Test func energyMoodGatesUnderFiveHighEnergy() {
        for d in 1...4 { add(day: d, mood: "good", energy: "alert") }
        guard case .gated = vm().connections[1].state else { Issue.record("expected gated energy×mood"); return }
    }

    @Test func energyMoodUnlocksAtFive() {
        for d in 1...5 { add(day: d, mood: "good", energy: "alert") }
        guard case .unlocked(_, let frac, _, _, _) = vm().connections[1].state else {
            Issue.record("expected unlocked energy×mood"); return
        }
        #expect(abs(frac - 1.0) < 0.0001)
    }

    @Test func sleepMoodGatesWithoutThreeEachSide() {
        for d in 1...3 { add(day: d, mood: "good", sleepQuality: "good") } // only good-sleep side
        guard case .gated = vm().connections[2].state else { Issue.record("expected gated sleep×mood"); return }
    }

    @Test func sleepMoodUnlocksWithThreeEachSide() {
        for d in 1...3 { add(day: d, mood: "great", sleepQuality: "good") }
        for d in 4...6 { add(day: d, mood: "low", sleepQuality: "poor") }
        guard case .unlocked = vm().connections[2].state else { Issue.record("expected unlocked sleep×mood"); return }
    }

    @Test func gatedCopyCountsRemainingDays() {
        add(day: 1, focus: "sharp", med: "Concerta") // 1 med day → need 3 more
        guard case let .gated(copy) = vm().connections[0].state else {
            Issue.record("expected gated med×focus"); return
        }
        #expect(copy == "Log medication on 3 more days to unlock this connection.")
    }

    @Test func gatedCopySingularDay() {
        for d in 1...4 { add(day: d, energy: "alert") } // 4 high-energy days → need 1 more
        guard case let .gated(copy) = vm().connections[1].state else {
            Issue.record("expected gated energy×mood"); return
        }
        #expect(copy == "Log high energy on 1 more day to unlock this connection.")
    }

    @Test func gatedSleepCopyMentionsBothSidesShort() {
        add(day: 1, mood: "good", sleepQuality: "good") // 1 good, 0 poor
        guard case let .gated(copy) = vm().connections[2].state else {
            Issue.record("expected gated sleep×mood"); return
        }
        #expect(copy == "Note 2 more good-sleep days and 3 more poor-sleep days to unlock this connection.")
    }

    @Test func connectionsAlwaysThreeInOrder() {
        let c = vm().connections
        #expect(c.count == 3)
        #expect(c[0].title == "Medication × focus")
        #expect(c[1].title == "Energy × mood")
        #expect(c[2].title == "Sleep × mood")
    }

    // MARK: - weekdaySignalStrips

    // June 2 2025 = Monday (weekday 2), June 4 = Wednesday (4), June 6 = Friday (6)

    @Test func weekdayStrips_groupsByWeekday() {
        add(day: 2, mood: "good") // Monday only
        let mood = vm().weekdaySignalStrips.first { $0.kind == .mood }!
        #expect(mood.beads.count == 7)
        let mo = mood.beads.first { $0.weekdayLabel == "Mo" }!
        #expect((mo.level as? MoodLevel) == .good)
        for bead in mood.beads where bead.weekdayLabel != "Mo" {
            #expect(bead.level == nil)
        }
    }

    @Test func weekdayStrips_averagesRoundUp() {
        // okay(3) + good(4) on Wednesday → avg 3.5 → Int(3.5.rounded()) = 4 → good
        add(day: 4, mood: "okay")
        add(day: 4, mood: "good")
        let we = vm().weekdaySignalStrips.first { $0.kind == .mood }!
            .beads.first { $0.weekdayLabel == "We" }!
        #expect((we.level as? MoodLevel) == .good)
    }

    @Test func weekdayStrips_averagesHalfRounds() {
        // flat(2) + okay(3) on Friday → avg 2.5 → Int(2.5.rounded()) = 3 → okay
        add(day: 6, mood: "flat")
        add(day: 6, mood: "okay")
        let fr = vm().weekdaySignalStrips.first { $0.kind == .mood }!
            .beads.first { $0.weekdayLabel == "Fr" }!
        #expect((fr.level as? MoodLevel) == .okay)
    }

    @Test func weekdayStrips_emptyMonthAllNil() {
        let mood = vm().weekdaySignalStrips.first { $0.kind == .mood }!
        #expect(mood.beads.allSatisfy { $0.level == nil })
    }

    @Test func weekdayStrips_slotOrder() {
        add(day: 1, mood: "okay")
        let mood = vm().weekdaySignalStrips.first { $0.kind == .mood }!
        #expect(mood.beads.first?.weekdayLabel == "Mo")
        #expect(mood.beads.last?.weekdayLabel == "Su")
    }

    @Test func weekdayStrips_allThreeKinds() {
        add(day: 2, mood: "good", energy: "alert", focus: "sharp")
        let strips = vm().weekdaySignalStrips
        #expect(strips.count == 3)
        #expect(strips.map(\.kind).contains(.mood))
        #expect(strips.map(\.kind).contains(.energy))
        #expect(strips.map(\.kind).contains(.focus))
    }
}
