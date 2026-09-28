import Testing
import SwiftUI
@testable import app_four

@MainActor
struct RecordingMoodDisplayTests {
    private func rec(mood: String?) -> Recording {
        Recording(audioFileName: "t.m4a", mood: mood)
    }

    // `moodColor` is the soft fill (the pen ramp's light partner) — paired with dark ink on beads/banners.
    @Test func moodColorUsesPenRampPartnerHexes() {
        #expect(rec(mood: "low").moodColor   == Color(hex: "#E7A975"))
        #expect(rec(mood: "flat").moodColor  == Color(hex: "#F3C789"))
        #expect(rec(mood: "okay").moodColor  == Color(hex: "#BFDEC3"))
        #expect(rec(mood: "good").moodColor  == Color(hex: "#90C696"))
        #expect(rec(mood: "great").moodColor == Color(hex: "#75B87B"))
    }

    @Test func moodColorUnknownIsSystemGray() {
        #expect(rec(mood: nil).moodColor == Color(.systemGray4))
        #expect(rec(mood: "alert").moodColor == Color(.systemGray4)) // energy word ≠ mood
    }

    // The chart ramp (pen Frame 5 / bubble chart) lives on `color` / `deepFill` — the dark end of gradients.
    @Test func moodLevelBaseAndPartnerMatchPenRamp() {
        #expect(MoodLevel.okay.color == Color(hex: "#9DCCA2"))
        #expect(MoodLevel.okay.deepFill == Color(hex: "#9DCCA2"))
        #expect(MoodLevel.okay.gradientPartner == Color(hex: "#BFDEC3"))
        #expect(MoodLevel.okay.fill == Color(hex: "#BFDEC3"))
        #expect(MoodLevel.low.color == Color(hex: "#DA7A2A"))
        #expect(MoodLevel.flat.color == Color(hex: "#EDA94A"))
        #expect(MoodLevel.good.color == Color(hex: "#55A75D"))
        #expect(MoodLevel.great.color == Color(hex: "#2A9134"))
    }

    @Test func moodLevelDisplayLabels() {
        #expect(MoodLevel.low.displayLabel == "Low")
        #expect(MoodLevel.great.displayLabel == "Great")
    }

    // MARK: - DayCard redesign (spec 023): line-4 caps + line-3 sleep

    private func rec(emotions: [String] = [], sideEffects: [String] = [], sleepHours: Double? = nil) -> Recording {
        let r = Recording(audioFileName: "t.m4a", mood: nil)
        let enc = JSONEncoder()
        if !emotions.isEmpty { r.emotionsJSON = String(data: try! enc.encode(emotions), encoding: .utf8) }
        if !sideEffects.isEmpty { r.sideEffectsJSON = String(data: try! enc.encode(sideEffects), encoding: .utf8) }
        r.sleepHours = sleepHours
        return r
    }

    @Test func feelingsCapAtFourWithOverflowAndCapitalize() {
        #expect(rec(emotions: []).feelings().shown.isEmpty)
        #expect(rec(emotions: []).feelings().overflow == 0)

        let four = ["calm", "focused", "bright", "steady"]
        #expect(rec(emotions: four).feelings().shown.count == 4)
        #expect(rec(emotions: four).feelings().overflow == 0)

        let seven = four + ["tense", "restless", "foggy"]
        let f = rec(emotions: seven).feelings()
        #expect(f.shown.count == 4)
        #expect(f.overflow == 3)
        #expect(f.shown.first == "Calm")   // capitalized for display
    }

    @Test func sideEffectsCapAtFourWithOverflow() {
        let six = ["nausea", "jitters", "headache", "dizziness", "dry mouth", "insomnia"]
        let s = rec(sideEffects: six).sideEffects()
        #expect(s.shown.count == 4)
        #expect(s.overflow == 2)
        #expect(s.shown.first == "Nausea")
        #expect(rec(sideEffects: []).sideEffects().overflow == 0)
    }

    @Test func sleepLabelFormatsHoursOrNil() {
        #expect(rec(sleepHours: nil).sleepLabel == nil)
        #expect(rec(sleepHours: 5).sleepLabel == "5h sleep")
    }
}
