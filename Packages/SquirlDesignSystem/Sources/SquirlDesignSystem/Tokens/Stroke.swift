import SwiftUI

/// Hairlines (DESIGN.md §6.4). Light values are the pen's; dark pairs are white washes so a
/// hairline stays a hairline on the dark card.
public enum Stroke {
    /// Card border — 0.5 pt.
    public static let card = Color(lightHex: "#000000", lightAlpha: 0.10, darkHex: "#ffffff", darkAlpha: 0.12)
    public static let cardWidth: CGFloat = 0.5
    /// In-card row divider — 1 pt.
    public static let separator = Color(lightHex: "#000000", lightAlpha: 0.10, darkHex: "#ffffff", darkAlpha: 0.12)
    /// Chips, nav pills, expand pills, the edit "How did you feel?" card.
    public static let chip = Color(lightHex: "#e4ece4", darkHex: "#33362f")
    /// Unselected level tile.
    public static let tile = Color(lightHex: "#e5f7e5", darkHex: "#2f4f32")
    /// Outlined buttons (Frame 3).
    public static let outlinedButton = Color(lightHex: "#cbd5e1", darkHex: "#44484c")
    /// Date / time fields.
    public static let field = Color(lightHex: "#1c1b1f", lightAlpha: 0.10, darkHex: "#ffffff", darkAlpha: 0.12)
    /// Empty rhythm tile / empty weekday circle.
    public static let empty = Color(lightHex: "#dbddde", darkHex: "#3a3d3f")
    /// Segmented-control track.
    public static let segmentTrack = Color(lightHex: "#000000", lightAlpha: 0.04, darkHex: "#ffffff", darkAlpha: 0.06)
    public static let hairlineWidth: CGFloat = 1
}
