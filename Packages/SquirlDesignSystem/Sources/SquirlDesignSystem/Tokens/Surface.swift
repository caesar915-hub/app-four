import SwiftUI

/// Surfaces — grounds, cards, tracks and tints (DESIGN.md §4.2). Light values are the pen's;
/// dark values are derived: a green-black ground, the Figma `surface/card` dark `#1c1e19`,
/// and level tints mixed 78 % into that card so they stay a whisper, not a stain.
public enum Surface {
    /// Every screen's ground — the faintly green white of the pen (`BG_Color`).
    public static let screen = Color(lightHex: "#fbfffc", darkHex: "#101311")
    /// Cards, the tab bar, pills, outline chips.
    public static let card = Color(lightHex: "#ffffff", darkHex: "#1c1e19")
    /// Segmented-control tracks and progress tracks.
    public static let track = Color(lightHex: "#fafafa", darkHex: "#23262a")
    /// Header band of the expanded day card — a fixed mint for every mood.
    public static let bandMint = Color(lightHex: "#e6f5ee", darkHex: "#1f371f")
    /// Check-in ring disc.
    public static let ringDisc = Color(lightHex: "#ebf8ee", darkHex: "#1f371f")
    /// Check-in ring track (green-100 in light).
    public static let ringTrack = Color(lightHex: "#bdddc0", darkHex: "#2f4f32")
    /// Date / time fields.
    public static let field = card
    /// Medication capsule tile, locked connection tile, confirmation preview row (violet-50).
    public static let medicationTint = Color(lightHex: "#f4f0fb", darkHex: "#352e42")
    /// Unlocked connection tile.
    public static let connectionUnlocked = Color(lightHex: "#e3d8f9", darkHex: "#4e3f6d")
    /// Mini-bar track on the day-details signal summary (grey-50).
    public static let miniTrack = Color(lightHex: "#e9e9ea", darkHex: "#2c2f33")
}
