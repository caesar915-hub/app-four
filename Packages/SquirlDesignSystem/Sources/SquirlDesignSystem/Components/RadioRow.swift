import SwiftUI

/// A radio row (Dose Guard): title 14/600 + subtitle 12/500, a 20 pt radio on the right;
/// the whole row is the target and announces `.isSelected`.
public struct RadioRow: View {
    private let title: String
    private let subtitle: String?
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.rowTitle)
                        .foregroundStyle(Ink.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.captionMedium)
                            .foregroundStyle(Ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Spacing.s)
                radio
            }
            .frame(minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var radio: some View {
        ZStack {
            if isSelected {
                Circle().fill(Accent.primaryFill)
                Circle().fill(Ink.onAccent).frame(width: 8, height: 8)
            } else {
                Circle().strokeBorder(Stroke.separator, lineWidth: Stroke.hairlineWidth)
            }
        }
        .frame(width: 20, height: 20)
        .animation(Motion.snappy, value: isSelected)
        .accessibilityHidden(true)
    }
}
