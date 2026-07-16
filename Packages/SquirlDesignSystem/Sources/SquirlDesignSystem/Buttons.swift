import SwiftUI

/// Filled primary action button — one accent-tinted style for the main action
/// on a screen. Honors the 44pt minimum tap target.
public struct PrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
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

/// Capture-flow primary action — the check-in green (`checkInGreen`) as a soft green-only
/// gradient (no amber), for the capture surfaces (onboarding "Start", text composer). Mirrors
/// `PrimaryButtonStyle`'s metrics; scoped so the shared meadow primary stays untouched.
public struct CheckInPrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(NewLook.onSelection)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Spacing.l)
            .background(
                LinearGradient(colors: [NewLook.checkInGreen, NewLook.checkInGreenSoft],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: Radius.button)
            )
            .shadow(color: NewLook.checkInGreen.opacity(0.3), radius: 12, y: 5)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

/// Ghost secondary action — ink text on the surface with a hairline border.
public struct SecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(NewLook.inkPrimary)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Spacing.l)
            .background(NewLook.card, in: .rect(cornerRadius: Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .strokeBorder(NewLook.hairline, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    public static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == CheckInPrimaryButtonStyle {
    public static var checkInPrimary: CheckInPrimaryButtonStyle { CheckInPrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    public static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
