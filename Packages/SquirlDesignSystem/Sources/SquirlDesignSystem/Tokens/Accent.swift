import SwiftUI

/// Accents (DESIGN.md §4.2). One brand green — green-500 for non-text uses (ring arc, dots,
/// icons, bars) and green-600 for every text-carrying fill (D14: white on green-500 measures
/// 4.04:1, white on green-600 4.75:1). Violet is the second accent: the Add button, the
/// medication family, the AI sparkle, connection tiles, the sleep moon.
public enum Accent {
    /// Non-text green: ring arc, active dots, glyph accents, the mood-row bar.
    public static let primary = Color(lightHex: "#2a9134", darkHex: "#55a75d")
    /// Text-carrying green fills: filled buttons, selected chips, toggles, the active tab pill.
    public static let primaryFill = Color(lightHex: "#26842f", darkHex: "#26842f")
    /// Green text on a light surface: outlined/underline labels, chevrons, status words.
    public static let primaryText = Color(lightHex: "#26842f", darkHex: "#70b577")
    /// Pressed fill for filled controls (the pen's "Hovered" green-700).
    public static let pressed = Color(lightHex: "#1e6725", darkHex: "#1e6725")
    /// Green-700 as text/icon: back chevrons, ellipsis dots, selected segment labels.
    public static let deepText = Color(lightHex: "#1e6725", darkHex: "#9dcca2")
    /// Deep green (the pen's "Focused" fill).
    public static let deep = Color(lightHex: "#17501d", darkHex: "#123d16")

    /// Violet-500 — Add button, play button, played waveform, medication bar fill, moon fill.
    public static let violet = Color(lightHex: "#8c68d3", darkHex: "#a386dc")
    /// Violet-800 — the capsule inside its tile, the unlock icon.
    public static let violetDeep = Color(lightHex: "#4d3974", darkHex: "#dbd0f1")
    /// Violet-600 — connection eyebrows, lock icon, AI sparkle.
    public static let connection = Color(lightHex: "#7f5fc0", darkHex: "#b29ae2")
    /// Violet-700 — the "Log Medications" outlined-button label.
    /// Calendar strip "has check-ins" dot — green-400 (the pen's `#55a75d`).
    public static let calendarDot = Color(lightHex: "#55a75d", darkHex: "#70b577")
    public static let violetText = Color(lightHex: "#634a96", darkHex: "#cabaeb")
    /// Start of the medication-bar / connection-bar gradient (drawn only by `ProgressTrack`).
    public static let medicationBarStart = Color(lightHex: "#8061bf", darkHex: "#8c68d3")

    /// Focus glyph blue and its value text.
    public static let focusBlue = Color(lightHex: "#4278a8", darkHex: "#8ab8d6")
    public static let focusText = Color(lightHex: "#447097", darkHex: "#8ab8d6")
    public static let focusRing = Color(lightHex: "#d6e5f0", darkHex: "#2f3f4c")
    public static let focusDisc = Color(lightHex: "#8ab8d6", darkHex: "#5f8fb0")

    /// Energy bolt amber family — decorative only.
    public static let energyAmber = Color(lightHex: "#eda94a", darkHex: "#eda94a")
    public static let energyDark = Color(lightHex: "#d98232", darkHex: "#d98232")
    public static let energyPale = Color(lightHex: "#f8e4c7", darkHex: "#4a3d24")
    /// The only amber allowed to carry text (5.1:1 on white); the pen's `#e38400` is 2.8:1.
    public static let energyText = Color(lightHex: "#a85a00", darkHex: "#f0cf9e")

    /// Sleep moon family.
    public static let sleepMoonBase = Color(lightHex: "#e3d7f3", darkHex: "#3a3050")
    public static let sleepMoonHighlight = Color(lightHex: "#bca5e8", darkHex: "#cabaeb")

    /// Check-in ring arc gradient — green-600 → bright → green-600, anchored at 3 o'clock.
    public static var ringGradient: AngularGradient {
        AngularGradient(
            colors: [Color(hex: "#26842f"), Color(hex: "#3fbb4b"), Color(hex: "#25832e")],
            center: .center, startAngle: .degrees(0), endAngle: .degrees(360))
    }

    /// Medication bar / connection bar fill.
    public static var medicationBarGradient: LinearGradient {
        LinearGradient(colors: [medicationBarStart, violet], startPoint: .leading, endPoint: .trailing)
    }
}
