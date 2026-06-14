import SwiftUI

/// Filled primary action button — one accent-tinted style for the main action
/// on a screen. Honors the 44pt minimum tap target.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Spacing.l)
            .background(Theme.accent, in: .rect(cornerRadius: Radius.control))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Tinted secondary action — accent text on a subtle fill.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Spacing.l)
            .background(Theme.accent.opacity(0.15), in: .rect(cornerRadius: Radius.control))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
