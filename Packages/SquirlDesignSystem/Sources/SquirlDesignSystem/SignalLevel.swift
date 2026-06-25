import SwiftUI
import UIKit

// MARK: - Dynamic colour + contrast helpers

public extension Color {
    /// Black or white — whichever reads on `fill` in the given scheme. Resolves dynamic
    /// colours first, so it is correct even for the inverting focus ramp.
    ///
    /// Sanctioned use of literal black/white: text-on-coloured-fill contrast only
    /// (bubble %, gauge label, connection bar). Never use raw black/white elsewhere in views.
    public static func contrastingInk(for fill: Color, in scheme: ColorScheme) -> Color {
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let resolved = UIColor(fill).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var white: CGFloat = 0
        resolved.getWhite(&white, alpha: nil)
        return white > 0.6 ? .black : .white
    }
}

// MARK: - SignalLevel: one shared grammar for mood / energy / focus

/// The three Insights signals share a 5-step ordinal grammar so a single bead, blob, or
/// gauge can render any of them. `MoodLevel`, `EnergyLevel`, and `FocusLevel` conform.
public protocol SignalLevel {
    /// 1…5, low→high.
    var numericValue: Int { get }
    /// Human label shown beside the colour (colour is never the only signal).
    var displayLabel: String { get }
    /// Base (saturated / dark end of the fill).
    var color: Color { get }
    /// Lighter gradient partner (light end of the fill).
    var gradientPartner: Color { get }
}

public extension SignalLevel {
    /// Standard filled-element gradient: partner (top-leading) → base (bottom-trailing).
    /// The one shared fill helper — do not hand-roll gradients per view.
    public var fillGradient: LinearGradient {
        LinearGradient(colors: [gradientPartner, color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Radial fill for the bubble chart (highlight at 32% / 28%).
    public var bubbleFill: RadialGradient {
        RadialGradient(colors: [gradientPartner, color],
                       center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: 110)
    }
}

// `MoodLevel.color` / `.gradientPartner` / `.displayLabel` live in `Recording+MoodDisplay`
// (the app-wide mood SSOT). Energy/focus read the ramps in `Palette+Signals`.
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
