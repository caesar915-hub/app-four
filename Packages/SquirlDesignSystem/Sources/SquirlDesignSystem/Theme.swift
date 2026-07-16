import SwiftUI

/// Retained from the retired Paper & Pollen system: semantic colours with no New Look
/// equivalent (spec-033).
public enum Theme {
    // MARK: - Accent + Meadow
    /// Bronze accent — links, focus, the "current" ring.
    public static let accent = Color(lightHex: "#B8842A", darkHex: "#D4A24A")
    public static let meadowGreen = Color(lightHex: "#5F8A4C", darkHex: "#6E9A58")
    public static let meadowAmber = Color(lightHex: "#E0A33A", darkHex: "#E8B255")

    // MARK: - Status (no raw system green/orange)
    public static let statusDone = meadowGreen
    public static let statusInProgress = meadowAmber
    /// Quiet danger — failed transcription, a "stopped" med. Warm clay, never raw red.
    public static let danger = Color(lightHex: "#B5503A", darkHex: "#CF6A52")

    // MARK: - The signature gradient
    /// Green → amber (~120°) — primary actions, the crescent, active states.
    public static var meadowGradient: LinearGradient {
        LinearGradient(colors: [meadowGreen, meadowAmber],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
