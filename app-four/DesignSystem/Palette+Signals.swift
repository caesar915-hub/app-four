import SwiftUI

/// Energy and focus colour ramps for the Meadow Insights system.
/// Mood colours live in `Recording+MoodDisplay` (the app-wide mood SSOT).
/// Each ramp is indexed by `numericValue - 1` (0 = lowest level, 4 = highest).
extension Palette {

    // MARK: - Energy (E2 "Voltage") — sluggish→charged, static across modes

    static let energyRamp: [Color] = [
        Color(hex: "#44546E"), // sluggish
        Color(hex: "#4E6F94"), // tired
        Color(hex: "#5889BA"), // steady
        Color(hex: "#63A4E0"), // alert
        Color(hex: "#79C4FF"), // charged
    ]
    static let energyRampPartner: [Color] = [
        Color(hex: "#5F6F8A"),
        Color(hex: "#6B8BAE"),
        Color(hex: "#74A3D2"),
        Color(hex: "#82BCF0"),
        Color(hex: "#9CD6FF"),
    ]

    // MARK: - Focus (F2 "Graphite") — foggy→lockedIn, dynamic (inverts in light mode)

    static let focusRamp: [Color] = [
        Color(lightHex: "#D8D8DE", darkHex: "#3A3A3E"), // foggy
        Color(lightHex: "#B4B4BC", darkHex: "#58585E"), // distracted
        Color(lightHex: "#8A8A94", darkHex: "#7E7E86"), // present
        Color(lightHex: "#5A5A64", darkHex: "#ABABB5"), // sharp
        Color(lightHex: "#26262C", darkHex: "#ECECF4"), // lockedIn
    ]
    static let focusRampPartner: [Color] = [
        Color(lightHex: "#E6E6EA", darkHex: "#4A4A50"),
        Color(lightHex: "#C6C6CE", darkHex: "#6A6A72"),
        Color(lightHex: "#9C9CA6", darkHex: "#92929C"),
        Color(lightHex: "#6E6E78", darkHex: "#C2C2CC"),
        Color(lightHex: "#3A3A42", darkHex: "#FFFFFF"),
    ]
}
