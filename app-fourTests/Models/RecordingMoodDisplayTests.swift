import Testing
import SwiftUI
@testable import app_four

@MainActor
struct RecordingMoodDisplayTests {
    private func rec(mood: String?) -> Recording {
        Recording(audioFileName: "t.m4a", mood: mood)
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

    // MARK: - Sleep label (day cards, day details)

    private func rec(sleepHours: Double?) -> Recording {
        let r = Recording(audioFileName: "t.m4a", mood: nil)
        r.sleepHours = sleepHours
        return r
    }

    @Test func sleepLabelFormatsHoursOrNil() {
        #expect(rec(sleepHours: nil).sleepLabel == nil)
        #expect(rec(sleepHours: 5).sleepLabel == "5h sleep")
    }
}
