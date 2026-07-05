import SwiftUI

/// Generic tag and status colors used outside the mood domain.
/// Mood colors live in `MoodLevel+Palette` (the app-wide mood SSOT); energy/focus
/// ramps live in `Palette+Signals`. Use these for medication and warning accents so
/// no raw `.orange`/`.purple` literals leak into models or views.
enum Palette {
    /// Medication purple — the single medication hue (bar fill, capsule glyph, tags).
    /// Paper & Pollen spec value; never `systemPurple`.
    static let medication = Color(lightHex: "#7E5CA8", darkHex: "#9277BE")
    /// Warning / caution accents and side-effect tags — a warm clay, not `systemOrange`.
    static let warning = Color(lightHex: "#C2772E", darkHex: "#D98A3E")
    /// Sleep — a cool indigo, bluer than medication purple so the two never read as one.
    /// Single, non-varying (the sleep 1→5 ramp is deferred).
    static let sleepIndigo = Color(hex: "#5566A6")
    /// Nutrition/food — clay for the day card's folded tokens, food rows, and totals.
    /// Knowingly shares the warm lane with mood-1/2 burnt orange (owner-accepted,
    /// spec 031 Pair 2 mockup); redder than `warning` so the two stay apart.
    static let nutritionFood = Color(lightHex: "#B5674A", darkHex: "#CB8266")
    /// Exercise — teal, the last clear cool gap between focus blue and meadow green.
    /// Flame glyph + workout rows + totals kcal-out (spec 031).
    static let nutritionExercise = Color(lightHex: "#3E8E86", darkHex: "#5FAEA5")
}
