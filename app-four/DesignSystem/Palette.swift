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
}
