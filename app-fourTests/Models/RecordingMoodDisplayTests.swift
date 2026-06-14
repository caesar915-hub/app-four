import Testing
import SwiftUI
@testable import app_four

@MainActor
struct RecordingMoodDisplayTests {
    private func rec(mood: String?) -> Recording {
        Recording(audioFileName: "t.m4a", mood: mood)
    }

    // `moodColor` is the soft fill (M2 light partner) — paired with dark ink on beads/banners.
    @Test func moodColorUsesM2FillHexes() {
        #expect(rec(mood: "low").moodColor   == Color(hex: "#D4705F"))
        #expect(rec(mood: "flat").moodColor  == Color(hex: "#EA9D72"))
        #expect(rec(mood: "okay").moodColor  == Color(hex: "#EFD68C"))
        #expect(rec(mood: "good").moodColor  == Color(hex: "#AED68C"))
        #expect(rec(mood: "great").moodColor == Color(hex: "#6BC68A"))
    }

    @Test func moodColorUnknownIsSystemGray() {
        #expect(rec(mood: nil).moodColor == Color(.systemGray4))
        #expect(rec(mood: "alert").moodColor == Color(.systemGray4)) // energy word ≠ mood
    }

    // The saturated base (M2) lives on `color` / `deepFill` — the dark end of gradients.
    @Test func moodLevelBaseAndPartnerMatchM2() {
        #expect(MoodLevel.okay.color == Color(hex: "#E5C46A"))
        #expect(MoodLevel.okay.deepFill == Color(hex: "#E5C46A"))
        #expect(MoodLevel.okay.gradientPartner == Color(hex: "#EFD68C"))
        #expect(MoodLevel.okay.fill == Color(hex: "#EFD68C"))
        #expect(MoodLevel.low.color == Color(hex: "#C2503F"))
        #expect(MoodLevel.great.color == Color(hex: "#4CAF6E"))
    }

    @Test func moodLevelDisplayLabels() {
        #expect(MoodLevel.low.displayLabel == "Low")
        #expect(MoodLevel.great.displayLabel == "Great")
    }
}
