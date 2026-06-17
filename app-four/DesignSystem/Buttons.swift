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
            .background(Theme.meadowGradient, in: .rect(cornerRadius: Radius.button))
            .shadow(color: Theme.meadowAmber.opacity(0.34), radius: 12, y: 5)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

/// Ghost secondary action — ink text on the surface with a hairline border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Spacing.l)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
