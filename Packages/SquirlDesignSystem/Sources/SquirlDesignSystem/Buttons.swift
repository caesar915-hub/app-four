import SwiftUI

/// The pen's three button sizes (Frame 3): height · horizontal padding · gap · font · icon.
public enum ButtonSize: Sendable {
    case small, medium, large

    var height: CGFloat {
        switch self { case .small: 36; case .medium: 44; case .large: 52 }
    }
    var paddingX: CGFloat {
        switch self { case .small: 14; case .medium: 18; case .large: 24 }
    }
    var font: Font {
        switch self { case .small: Typography.buttonSmall; case .medium: Typography.buttonMedium; case .large: Typography.buttonLarge }
    }
}

/// Which accent an outlined button's label takes.
public enum ButtonTint: Sendable {
    case green, violet
}

/// Filled pill — green-600 (text-carrying fill, D14), green-700 when pressed, grey when disabled.
public struct FilledButtonStyle: ButtonStyle {
    public var size: ButtonSize = .medium
    public var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    public init(size: ButtonSize = .medium, fullWidth: Bool = false) {
        self.size = size
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(isEnabled ? Ink.onAccent : Ink.disabled)
            .padding(.horizontal, size.paddingX)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size.height)
            .background(fill(pressed: configuration.isPressed), in: .capsule)
            .contentShape(.capsule)
            .animation(Motion.snappy, value: configuration.isPressed)
    }

    private func fill(pressed: Bool) -> Color {
        guard isEnabled else { return Surface.disabledFill }
        return pressed ? Accent.pressed : Accent.primaryFill
    }
}

/// Outlined pill — white with a slate hairline, green (or violet) label; the stroke turns green
/// when pressed.
public struct OutlinedButtonStyle: ButtonStyle {
    public var size: ButtonSize = .medium
    public var fullWidth = false
    public var tint: ButtonTint = .green
    @Environment(\.isEnabled) private var isEnabled

    public init(size: ButtonSize = .medium, fullWidth: Bool = false, tint: ButtonTint = .green) {
        self.size = size
        self.fullWidth = fullWidth
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(labelColor)
            .padding(.horizontal, size.paddingX)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size.height)
            .background(isEnabled ? (configuration.isPressed ? Surface.pressedOutlined : Surface.card) : Surface.disabledOutlined, in: .capsule)
            .overlay {
                Capsule().strokeBorder(strokeColor(pressed: configuration.isPressed), lineWidth: Stroke.hairlineWidth)
            }
            .contentShape(.capsule)
            .animation(Motion.snappy, value: configuration.isPressed)
    }

    private var labelColor: Color {
        guard isEnabled else { return Ink.disabled }
        return tint == .violet ? Accent.violetText : Accent.primaryText
    }

    private func strokeColor(pressed: Bool) -> Color {
        guard isEnabled else { return Stroke.disabledOutlined }
        return pressed ? Accent.primary : Stroke.outlinedButton
    }
}

/// Text-only button — green label, darker when pressed; keeps a 44 pt hit height.
public struct UnderlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.buttonMedium)
            .foregroundStyle(isEnabled ? (configuration.isPressed ? Accent.pressed : Accent.primaryText) : Ink.disabled)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
    }
}

public extension ButtonStyle where Self == FilledButtonStyle {
    static var filled: FilledButtonStyle { FilledButtonStyle() }
    static func filled(_ size: ButtonSize = .medium, fullWidth: Bool = false) -> FilledButtonStyle {
        FilledButtonStyle(size: size, fullWidth: fullWidth)
    }
}

public extension ButtonStyle where Self == OutlinedButtonStyle {
    static var outlined: OutlinedButtonStyle { OutlinedButtonStyle() }
    static func outlined(_ size: ButtonSize = .medium, fullWidth: Bool = false, tint: ButtonTint = .green) -> OutlinedButtonStyle {
        OutlinedButtonStyle(size: size, fullWidth: fullWidth, tint: tint)
    }
}

public extension ButtonStyle where Self == UnderlineButtonStyle {
    static var underline: UnderlineButtonStyle { UnderlineButtonStyle() }
}

#Preview("Buttons") {
    VStack(spacing: Spacing.l) {
        ForEach([ButtonSize.small, .medium, .large], id: \.self) { size in
            HStack(spacing: Spacing.s) {
                Button("Button", systemImage: Icons.mic) {}.buttonStyle(.filled(size))
                Button("Button") {}.buttonStyle(.outlined(size))
                Button("Button") {}.buttonStyle(.outlined(size, tint: .violet))
                Button("Button") {}.buttonStyle(.filled(size)).disabled(true)
            }
        }
        Button("Save changes") {}.buttonStyle(.filled(fullWidth: true))
        Button("Cancel") {}.buttonStyle(.underline)
    }
    .padding(Spacing.gutter)
    .background(Surface.screen)
}
