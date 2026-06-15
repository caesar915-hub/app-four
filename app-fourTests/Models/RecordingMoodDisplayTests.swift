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
}
