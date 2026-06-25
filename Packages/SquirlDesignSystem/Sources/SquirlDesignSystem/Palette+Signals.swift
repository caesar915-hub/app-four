import SwiftUI

/// Energy and focus colour ramps for the Meadow Insights system.
/// Mood colours live in `Recording+MoodDisplay` (the app-wide mood SSOT).
/// Each ramp is indexed by `numericValue - 1` (0 = lowest level, 4 = highest).
public extension Palette {

    // MARK: - Energy ("Lemon") — sluggish→charged, static across modes

    public static let energyRamp: [Color] = [
        Color(hex: "#7C6E2E"), // sluggish
        Color(hex: "#A89236"), // tired
        Color(hex: "#D2BB40"), // steady
        Color(hex: "#EEDA4C"), // alert
        Color(hex: "#FCEE64"), // charged
    ]
    public static let energyRampPartner: [Color] = [
        Color(hex: "#8C7F44"),
        Color(hex: "#B8A450"),
        Color(hex: "#E2CD5F"),
        Color(hex: "#FEEC6E"),
        Color(hex: "#FFF482"),
    ]

    // MARK: - Focus ("Voltage" blue) — foggy→lockedIn, static across modes

    public static let focusRamp: [Color] = [
        Color(hex: "#44546E"), // foggy
        Color(hex: "#4E6F94"), // distracted
        Color(hex: "#5889BA"), // present
        Color(hex: "#63A4E0"), // sharp
        Color(hex: "#79C4FF"), // lockedIn
    ]
    public static let focusRampPartner: [Color] = [
        Color(hex: "#5C697E"),
        Color(hex: "#6985A4"),
        Color(hex: "#77A0CA"),
        Color(hex: "#85BDF0"),
        Color(hex: "#96D1FF"),
    ]
}
