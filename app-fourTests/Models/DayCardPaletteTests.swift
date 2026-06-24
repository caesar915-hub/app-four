import Testing
import SwiftUI
@testable import app_four

/// The day-card mood-block palette (spec 019, "#4 Divided · Cream disc"): the representative-mood
/// accessors that drive the folded block, the cream-disc badge, and the mood word. Pure value
/// mapping on `MoodLevel` — the only new logic in an otherwise view-only redesign (Constitution X).
@MainActor
struct DayCardPaletteTests {

    @Test func blockTintIsBaseColourAtBlockOpacity() {
        for level in MoodLevel.allCases {
            #expect(level.blockTint == level.color.opacity(Opacity.moodBlock))
        }
    }

    @Test func badgeTintIsBaseColourAtBadgeOpacity() {
        for level in MoodLevel.allCases {
            #expect(level.badgeTint == level.color.opacity(Opacity.moodBadge))
        }
    }

    @Test func wordColourIsTheDeepLegibleShade() {
        for level in MoodLevel.allCases {
            #expect(level.wordColor == level.deepFill)
        }
    }

    /// Pin the actual tokens so a swapped base colour or opacity wiring is caught (not just a re-expression).
    @Test func pinsRepresentativeMoodTokens() {
        #expect(MoodLevel.good.wordColor == Color(hex: "#5FB36E"))
        #expect(MoodLevel.good.blockTint == Color(hex: "#5FB36E").opacity(Opacity.moodBlock))
        #expect(MoodLevel.great.badgeTint == Color(hex: "#2E8B57").opacity(Opacity.moodBadge))
    }
}
