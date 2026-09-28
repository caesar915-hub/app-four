import SwiftUI
import UIKit

// MARK: - Dynamic colour + contrast helpers

public extension Color {
    /// Black or white — whichever reads on `fill` in the given scheme. Resolves dynamic
    /// colours first, so it is correct for adaptive fills.
    ///
    /// Sanctioned use of literal black/white: text-on-coloured-fill contrast only
    /// (bubble %, connection bar). Never use raw black/white elsewhere in views.
    public static func contrastingInk(for fill: Color, in scheme: ColorScheme) -> Color {
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let resolved = UIColor(fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var white: CGFloat = 0
        resolved.getWhite(&white, alpha: nil)
        return white > 0.6 ? .black : .white
    }
}

// MARK: - SignalLevel: one shared grammar for mood / energy / focus / sleep

/// The ramped signals share a 5-step ordinal grammar so a single tile, bubble or bar can
/// render any of them. `MoodLevel`, `EnergyLevel`, `FocusLevel` and `SleepLevel` conform.
public protocol SignalLevel {
    /// 1…5, low→high.
    var numericValue: Int { get }
    /// Human label shown beside the colour (colour is never the only signal).
    var displayLabel: String { get }
    /// Chart colour — the mood ramp for every signal (DESIGN.md §4.4).
    var color: Color { get }
    /// Lighter gradient partner (light end of the fill).
    var gradientPartner: Color { get }
}

public extension SignalLevel {
    /// Standard filled-element gradient: partner (top-leading) → base (bottom-trailing).
    public var fillGradient: LinearGradient {
        LinearGradient(colors: [gradientPartner, color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Radial fill for the bubble chart (highlight at 32% / 28%).
    public var bubbleFill: RadialGradient {
        RadialGradient(colors: [gradientPartner, color],
                       center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: 110)
    }
}

extension MoodLevel: SignalLevel {}

extension EnergyLevel: SignalLevel {
    public var color: Color { Palette.energyRamp[numericValue - 1] }
    public var gradientPartner: Color { Palette.energyRampPartner[numericValue - 1] }
    public var displayLabel: String { rawValue.capitalized }
}

extension FocusLevel: SignalLevel {
    public var color: Color { Palette.focusRamp[numericValue - 1] }
    public var gradientPartner: Color { Palette.focusRampPartner[numericValue - 1] }
    // `displayLabel` ("Foggy"…"Locked In") already defined on FocusLevel.
}

extension SleepLevel: SignalLevel {
    public var color: Color { MoodLevel.allCases[numericValue - 1].color }
    public var gradientPartner: Color { MoodLevel.allCases[numericValue - 1].gradientPartner }
    public var displayLabel: String {
        switch self {
        case .restless: "Restless"
        case .light: "Light"
        case .okay: "Okay"
        case .good: "Good"
        case .deep: "Deep"
        }
    }
}
