import Testing
import SwiftUI
@testable import app_four

@MainActor
struct RecordingMoodDisplayTests {
    private func rec(mood: String?) -> Recording {
        Recording(audioFileName: "t.m4a", mood: mood)
    }

    // `moodColor` is the soft fill (Meadow·Burnt light partner) — paired with dark ink on beads/banners.
    @Test func moodColorUsesMeadowBurntFillHexes() {
        #expect(rec(mood: "low").moodColor   == Color(hex: "#EA9248"))
        #expect(rec(mood: "flat").moodColor  == Color(hex: "#FDC06C"))
        #expect(rec(mood: "okay").moodColor  == Color(hex: "#B9DB9C"))
        #expect(rec(mood: "good").moodColor  == Color(hex: "#7EC38A"))
        #expect(rec(mood: "great").moodColor == Color(hex: "#459B6B"))
    }

    @Test func moodColorUnknownIsSystemGray() {
        #expect(rec(mood: nil).moodColor == Color(.systemGray4))
        #expect(rec(mood: "alert").moodColor == Color(.systemGray4)) // energy word ≠ mood
    }

    // The saturated base (Meadow·Burnt) lives on `color` / `deepFill` — the dark end of gradients.
    @Test func moodLevelBaseAndPartnerMatchMeadowBurnt() {
        #expect(MoodLevel.okay.color == Color(hex: "#9FCB79"))
        #expect(MoodLevel.okay.deepFill == Color(hex: "#9FCB79"))
        #expect(MoodLevel.okay.gradientPartner == Color(hex: "#B9DB9C"))
        #expect(MoodLevel.okay.fill == Color(hex: "#B9DB9C"))
        #expect(MoodLevel.low.color == Color(hex: "#DA7A2A"))
        #expect(MoodLevel.flat.color == Color(hex: "#EDA94A")) // the chosen amber (was #F0B85C "light amber")
        #expect(MoodLevel.great.color == Color(hex: "#2E8B57"))
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

    @Test func sleepLineUsesSleepIndigoOrNil() {
        #expect(rec(sleepHours: nil).sleepLine == nil)
        let line = rec(sleepHours: 5).sleepLine
        #expect(line?.label == "5h sleep")
        #expect(line?.color == Palette.sleepIndigo)
    }
}
