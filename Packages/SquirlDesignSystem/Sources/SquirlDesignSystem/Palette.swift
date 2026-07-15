import SwiftUI

/// Generic tag and status colors used outside the mood domain.
/// Mood colors live in `MoodLevel+Palette` (the app-wide mood SSOT); energy/focus
/// ramps live in `Palette+Signals`. Use these for medication and warning accents so
/// no raw `.orange`/`.purple` literals leak into models or views.
public enum Palette {
    /// Medication purple — the single medication hue (bar fill, capsule glyph, tags).
    /// Paper & Pollen spec value; never `systemPurple`. Dark value nudged `#9277BE` → `#957BC1`
    /// (2026-07-16) so 12pt purple text clears WCAG AA on the dark card (was 4.49:1, now ~4.7:1);
    /// imperceptible hue shift, derived value — not Figma-locked.
    public static let medication = Color(lightHex: "#7E5CA8", darkHex: "#957BC1")
    /// End-stop of the medication progress-track gradient (a01, node 308:1933). Figma's own
    /// `#AF99C3` is an unbound literal even in the source file; dark value is derived (no
    /// Figma dark variant exists) by lightening `medication`'s dark pairing the same way the
    /// light pair lightens — verify on device.
    public static let medicationFillEnd = Color(lightHex: "#AF99C3", darkHex: "#B3A1D6")
    /// Warning / caution accents and side-effect tags — a warm clay, not `systemOrange`.
    public static let warning = Color(lightHex: "#C2772E", darkHex: "#D98A3E")
    /// Sleep — a cool indigo, bluer than medication purple so the two never read as one.
    /// Single, non-varying (the sleep 1→5 ramp is deferred). The dark value is lightened to a
    /// periwinkle so the sleep chip clears WCAG AA (~6.3:1) on the dark card; the base `#5566A6`
    /// alone measured ≈3.15:1 there (spec-034 owner decision, 2026-07-15).
    public static let sleepIndigo = Color(lightHex: "#5566A6", darkHex: "#8E9BD4")
}
