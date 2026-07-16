import Testing
import SwiftUI
import UIKit
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

    /// Design-review finding ①: the mood word must be a *deeper, legible* shade — not the raw
    /// saturated base (`deepFill`/`color`), which washed out to as low as 1.54:1 on its own tint.
    @Test func wordColourIsDistinctFromTheSaturatedBase() {
        for level in MoodLevel.allCases {
            #expect(level.wordColor != level.deepFill)
        }
    }

    /// The real requirement: the mood word clears WCAG AA (4.5:1 for normal text) against its
    /// own block tint (`color @ moodBlock` composited over the card surface), in light AND dark.
    /// This is the regression guard for finding ① — reverting `wordColor` to the base fails here.
    @Test func wordColourClearsAAOnItsBlockTint() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let mode = style == .light ? "light" : "dark"
            let surface = Self.rgb(NewLook.card, traits)
            for level in MoodLevel.allCases {
                let tint = Self.composite(Self.rgb(level.color, traits), over: surface, alpha: Opacity.moodBlock)
                let ratio = Self.contrast(Self.rgb(level.wordColor, traits), tint)
                #expect(ratio >= 4.5, "\(level) wordColor on its tint (\(mode)) = \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    /// Pin the tint/badge tokens so a swapped base colour or opacity wiring is caught.
    @Test func pinsRepresentativeMoodTokens() {
        #expect(MoodLevel.good.blockTint == Color(hex: "#5FB36E").opacity(Opacity.moodBlock))
        #expect(MoodLevel.great.badgeTint == Color(hex: "#2E8B57").opacity(Opacity.moodBadge))
    }

    // MARK: - WCAG helpers (sRGB; mirrors the contrast-audit mockup)

    private static func rgb(_ color: Color, _ traits: UITraitCollection) -> (r: Double, g: Double, b: Double) {
        let ui = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private static func composite(_ fg: (r: Double, g: Double, b: Double),
                                  over bg: (r: Double, g: Double, b: Double),
                                  alpha: Double) -> (r: Double, g: Double, b: Double) {
        (fg.r * alpha + bg.r * (1 - alpha),
         fg.g * alpha + bg.g * (1 - alpha),
         fg.b * alpha + bg.b * (1 - alpha))
    }

    private static func contrast(_ a: (r: Double, g: Double, b: Double),
                                 _ b: (r: Double, g: Double, b: Double)) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        func lum(_ c: (r: Double, g: Double, b: Double)) -> Double {
            0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
        }
        let la = lum(a) + 0.05, lb = lum(b) + 0.05
        return max(la, lb) / min(la, lb)
    }
}
