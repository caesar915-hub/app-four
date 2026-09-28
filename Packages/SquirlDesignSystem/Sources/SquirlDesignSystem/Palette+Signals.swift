import SwiftUI

/// Chart ramps for energy and focus. The pen draws every chart, range bar and legend in the
/// mood ramp regardless of signal (DESIGN.md §4.4), so both ramps are the mood ramp; the
/// signals are told apart by their glyphs, never by a second hue family.
public extension Palette {
    public static let energyRamp: [Color] = MoodLevel.allCases.map(\.color)
    public static let energyRampPartner: [Color] = MoodLevel.allCases.map(\.gradientPartner)
    public static let focusRamp: [Color] = MoodLevel.allCases.map(\.color)
    public static let focusRampPartner: [Color] = MoodLevel.allCases.map(\.gradientPartner)
}
