import Testing
import SwiftUI
import UIKit
@testable import app_four

/// The day-card mood palette: the mood word must stay legible on the tints the cards paint it on.
/// Pure value mapping on `MoodLevel`.
@MainActor
struct DayCardPaletteTests {

    /// Design-review finding ①: the mood word must be a *deeper, legible* shade — not the raw
    /// saturated base (`deepFill`/`color`), which washed out to as low as 1.54:1 on its own tint.
    @Test func wordColourIsDistinctFromTheSaturatedBase() {
        for level in MoodLevel.allCases {
            #expect(level.wordColor != level.deepFill)
        }
    }

    /// The real requirement: the mood word clears WCAG AA (4.5:1 for normal text) against the
    /// day-card fill it sits on (spec 057 `dayCardFill`), in light AND dark. Reverting `wordColor`
    /// to the saturated base fails here.
    @Test func wordColourClearsAAOnItsDayCardFill() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let mode = style == .light ? "light" : "dark"
            for level in MoodLevel.allCases {
                let ratio = Self.contrast(Self.rgb(level.wordColor, traits), Self.rgb(level.dayCardFill, traits))
                #expect(ratio >= 4.5, "\(level) wordColor on its day-card fill (\(mode)) = \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    // MARK: - WCAG helpers (sRGB; mirrors the contrast-audit mockup)

    private static func rgb(_ color: Color, _ traits: UITraitCollection) -> (r: Double, g: Double, b: Double) {
        let ui = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
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
