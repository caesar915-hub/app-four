import SwiftUI

/// Generic tag and status colors used outside the mood domain.
/// Mood colors live in `MoodLevel+Palette` (the app-wide mood SSOT); energy/focus
/// ramps live in `Palette+Signals`. Use these for medication and warning accents so
/// no raw `.orange`/`.purple` literals leak into models or views.
enum Palette {
    /// Medication-related tags
    static let medication = Color(.systemPurple)
    /// Warning / caution accents and side-effect tags (no longer shared with energy)
    static let warning = Color(.systemOrange)
}
