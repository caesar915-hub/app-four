import SwiftUI

/// One drop shadow, as the pen draws it (offset · blur · colour). SwiftUI's `shadow(radius:)`
/// is a Gaussian σ, so the pen's blur value is halved to match its rendered spread.
public struct ShadowSpec: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, blur: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = blur / 2
        self.x = x
        self.y = y
    }
}

/// Elevation tokens (DESIGN.md §6.3). One green-black tint (`#183c28`) at 0.06–0.16 carries the
/// system; the FAB and the ring use pure black.
public enum Elevation {
    private static let tint = "#183c28"

    /// Insights, settings, medication bar, day cards, connection cards.
    public static let card = ShadowSpec(color: Color(lightHex: tint, lightAlpha: 0.08, darkHex: "#000000", darkAlpha: 0.30), blur: 8, y: 3)
    /// Day-details cards, edit cards, the listening prompt card.
    public static let raised = ShadowSpec(color: Color(lightHex: tint, lightAlpha: 0.08, darkHex: "#000000", darkAlpha: 0.30), blur: 8, y: 4)
    /// Date / time fields.
    public static let field = ShadowSpec(color: Color(lightHex: tint, lightAlpha: 0.08, darkHex: "#000000", darkAlpha: 0.30), blur: 8, y: 2)
    /// Day-details emotion chips only.
    public static let chip = ShadowSpec(color: Color(lightHex: tint, lightAlpha: 0.06, darkHex: "#000000", darkAlpha: 0.25), blur: 6, y: 7)
    /// The floating tab bar.
    public static let tabBar = ShadowSpec(color: Color(lightHex: tint, lightAlpha: 0.16, darkHex: "#000000", darkAlpha: 0.45), blur: 24, y: 8)
    /// The Add button.
    public static let fab = ShadowSpec(color: Color(lightHex: "#000000", lightAlpha: 0.17, darkHex: "#000000", darkAlpha: 0.45), blur: 17, y: 7)
    /// The check-in ring.
    public static let ring = ShadowSpec(color: Color(lightHex: "#000000", lightAlpha: 0.08, darkHex: "#000000", darkAlpha: 0.35), blur: 18, y: 2)
    /// Month-selector thumb.
    public static let thumb = ShadowSpec(color: Color(lightHex: "#193024", lightAlpha: 0.07, darkHex: "#000000", darkAlpha: 0.30), blur: 3, y: 1)
}

public extension View {
    /// Applies one elevation token.
    func elevation(_ spec: ShadowSpec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
