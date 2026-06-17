import SwiftUI

/// Paper & Pollen semantic colours. Warm **paper** in light, warm **loam** in dark —
/// never system white/black. Every value is an adaptive light/dark token, matching the
/// design-system `:root` (and dark) variables.
enum Theme {
    // MARK: - Backgrounds
    /// Main screen background — paper / loam.
    static let background = Color(lightHex: "#F6F1E7", darkHex: "#14130F")
    /// Card / row background.
    static let cardBackground = Color(lightHex: "#FCF8EF", darkHex: "#1E1C16")
    /// Inset / second surface (segmented fills, tracks, chips).
    static let surface2 = Color(lightHex: "#EFE8D8", darkHex: "#272419")
    /// Elevated card background.
    static let elevatedBackground = Color(lightHex: "#FCF8EF", darkHex: "#272419")

    // MARK: - Text
    static let textPrimary = Color(lightHex: "#221E16", darkHex: "#F3EEE0")
    static let textSecondary = Color(lightHex: "#7A7361", darkHex: "#9A917C")

    // MARK: - Separators
    /// Hairline rules and card borders.
    static let separator = Color(lightHex: "#E3DAC7", darkHex: "#322E22")
    static let cardStroke = Color(lightHex: "#E3DAC7", darkHex: "#322E22")

    // MARK: - Accent + Meadow
    /// Bronze accent — links, focus, the "current" ring.
    static let accent = Color(lightHex: "#B8842A", darkHex: "#D4A24A")
    static let meadowGreen = Color(lightHex: "#5F8A4C", darkHex: "#6E9A58")
    static let meadowAmber = Color(lightHex: "#E0A33A", darkHex: "#E8B255")

    // MARK: - Status (no raw system green/orange)
    static let statusDone = meadowGreen
    static let statusInProgress = meadowAmber
    /// Quiet danger — failed transcription, a "stopped" med. Warm clay, never raw red.
    static let danger = Color(lightHex: "#B5503A", darkHex: "#CF6A52")

    // MARK: - The signature gradient
    /// Green → amber (~120°) — primary actions, the crescent, active states.
    static var meadowGradient: LinearGradient {
        LinearGradient(colors: [meadowGreen, meadowAmber],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
