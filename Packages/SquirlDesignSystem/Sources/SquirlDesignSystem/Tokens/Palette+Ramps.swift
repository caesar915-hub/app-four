import SwiftUI

/// The three primitive ramps of the pen design system (Frame 5 "Color palettes", spec 057).
/// Package-internal building blocks: views use the semantic roles in `Surface` / `Ink` /
/// `Accent` / `Stroke`, never a ramp step directly. Values are static across appearances;
/// the semantic roles pick different steps per appearance.
public extension Palette {
    // MARK: Violet
    public static let violet50  = Color(hex: "#f4f0fb")
    public static let violet100 = Color(hex: "#dbd0f1")
    public static let violet200 = Color(hex: "#cabaeb")
    public static let violet300 = Color(hex: "#b29ae2")
    public static let violet400 = Color(hex: "#a386dc")
    public static let violet500 = Color(hex: "#8c68d3")
    public static let violet600 = Color(hex: "#7f5fc0")
    public static let violet700 = Color(hex: "#634a96")
    public static let violet800 = Color(hex: "#4d3974")
    public static let violet900 = Color(hex: "#3b2c59")

    // MARK: Green
    public static let green50  = Color(hex: "#eaf4eb")
    public static let green100 = Color(hex: "#bdddc0")
    public static let green200 = Color(hex: "#9dcca2")
    public static let green300 = Color(hex: "#70b577")
    public static let green400 = Color(hex: "#55a75d")
    public static let green500 = Color(hex: "#2a9134")
    public static let green600 = Color(hex: "#26842f")
    public static let green700 = Color(hex: "#1e6725")
    public static let green800 = Color(hex: "#17501d")
    public static let green900 = Color(hex: "#123d16")

    // MARK: Neutral
    public static let grey50  = Color(hex: "#e9e9ea")
    public static let grey100 = Color(hex: "#babbbd")
    public static let grey200 = Color(hex: "#999b9d")
    public static let grey300 = Color(hex: "#6a6d70")
    public static let grey400 = Color(hex: "#4d5154")
    public static let grey500 = Color(hex: "#212529")
    public static let grey600 = Color(hex: "#1e2225")
    public static let grey700 = Color(hex: "#171a1d")
    public static let grey800 = Color(hex: "#121417")
    public static let grey900 = Color(hex: "#0e1011")
}
