import SwiftUI

/// Generic tag and status colors used outside the mood domain.
/// Mood colors live in `MoodLevel+Palette` (the app-wide mood SSOT); energy/focus
/// ramps live in `Palette+Signals`. Use these for medication and warning accents so
/// no raw `.orange`/`.purple` literals leak into models or views.
public enum Palette {
    /// Medication purple — the single medication hue (bar fill, capsule glyph, tags).
    /// Paper & Pollen spec value; never `systemPurple`.
    public static let medication = Color(lightHex: "#7E5CA8", darkHex: "#9277BE")
    /// End-stop of the medication progress-track gradient (a01, node 308:1933). Figma's own
    /// `#AF99C3` is an unbound literal even in the source file; dark value is derived (no
    /// Figma dark variant exists) by lightening `medication`'s dark pairing the same way the
    /// light pair lightens — verify on device.
    public static let medicationFillEnd = Color(lightHex: "#AF99C3", darkHex: "#B3A1D6")
    /// Warning / caution accents and side-effect tags — a warm clay, not `systemOrange`.
    public static let warning = Color(lightHex: "#C2772E", darkHex: "#D98A3E")
    /// Sleep — a cool indigo, bluer than medication purple so the two never read as one.
    /// Single, non-varying (the sleep 1→5 ramp is deferred).
    public static let sleepIndigo = Color(hex: "#5566A6")
}
