import Testing
import SwiftUI
import UIKit
@testable import app_four

/// D14 (spec 057): WCAG AA is a hard floor — 4.5:1 for text, 3:1 for UI — in light AND dark.
/// Every text/fill pair the token files define is asserted here, so a retuned token fails a
/// test instead of being remembered.
@MainActor
struct TokenContrastTests {

    private static let appearances: [(UIUserInterfaceStyle, String)] = [(.light, "light"), (.dark, "dark")]

    @Test func inksClearAAOnSurfaces() {
        for (style, mode) in Self.appearances {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for (name, ink) in [("title", Ink.title), ("primary", Ink.primary), ("secondary", Ink.secondary),
                                ("tertiary", Ink.tertiary), ("chip", Ink.chip), ("destructive", Ink.destructive)] {
                for (surfaceName, surface) in [("screen", Surface.screen), ("card", Surface.card)] {
                    let ratio = Self.contrast(ink, surface, traits)
                    #expect(ratio >= 4.5, "Ink.\(name) on Surface.\(surfaceName) (\(mode)) = \(Self.fmt(ratio))")
                }
            }
        }
    }

    @Test func accentTextClearsAAOnCard() {
        for (style, mode) in Self.appearances {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for (name, ink) in [("primaryText", Accent.primaryText), ("energyText", Accent.energyText),
                                ("focusText", Accent.focusText), ("connection", Accent.connection),
                                ("violetText", Accent.violetText)] {
                let ratio = Self.contrast(ink, Surface.card, traits)
                #expect(ratio >= 4.5, "Accent.\(name) on card (\(mode)) = \(Self.fmt(ratio))")
            }
        }
    }

    @Test func labelsOnFilledControlsClearAA() {
        for (style, mode) in Self.appearances {
            let traits = UITraitCollection(userInterfaceStyle: style)
            #expect(Self.contrast(Ink.onAccent, Accent.primaryFill, traits) >= 4.5,
                    "onAccent on primaryFill (\(mode)) = \(Self.fmt(Self.contrast(Ink.onAccent, Accent.primaryFill, traits)))")
            #expect(Self.contrast(Ink.onAccent, Accent.pressed, traits) >= 4.5,
                    "onAccent on pressed (\(mode))")
        }
    }

    @Test func uiComponentsClearThreeToOne() {
        for (style, mode) in Self.appearances {
            let traits = UITraitCollection(userInterfaceStyle: style)
            #expect(Self.contrast(Ink.tabInactive, Surface.card, traits) >= 3.0, "tabInactive on card (\(mode))")
            #expect(Self.contrast(Accent.primary, Surface.card, traits) >= 3.0, "Accent.primary on card (\(mode))")
        }
    }

    @Test func moodWordsClearAAOnTheirTints() {
        for (style, mode) in Self.appearances {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for level in MoodLevel.allCases {
                #expect(Self.contrast(level.wordColor, level.avatarTint, traits) >= 4.5,
                        "\(level) word on avatar tint (\(mode)) = \(Self.fmt(Self.contrast(level.wordColor, level.avatarTint, traits)))")
                #expect(Self.contrast(level.wordColor, level.dayCardFill, traits) >= 4.5,
                        "\(level) word on day-card fill (\(mode))")
                #expect(Self.contrast(level.wordColor, Surface.card, traits) >= 4.5,
                        "\(level) word on card (\(mode))")
            }
        }
    }

    @Test func bubbleInkClearsAAOnBubbleFill() {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        for level in MoodLevel.allCases {
            let ratio = Self.contrast(level.bubbleInk, level.bubbleFill, traits)
            #expect(ratio >= 4.5, "\(level) bubble ink on bubble fill = \(Self.fmt(ratio))")
        }
    }

    // MARK: - WCAG helpers (sRGB)

    private static func rgb(_ color: Color, _ traits: UITraitCollection) -> (r: Double, g: Double, b: Double) {
        let ui = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private static func contrast(_ fg: Color, _ bg: Color, _ traits: UITraitCollection) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        func lum(_ c: (r: Double, g: Double, b: Double)) -> Double {
            0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
        }
        let la = lum(rgb(fg, traits)) + 0.05, lb = lum(rgb(bg, traits)) + 0.05
        return max(la, lb) / min(la, lb)
    }

    private static func fmt(_ ratio: Double) -> String { String(format: "%.2f:1", ratio) }
}
