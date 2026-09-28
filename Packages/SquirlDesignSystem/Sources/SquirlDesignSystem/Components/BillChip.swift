import SwiftUI

/// The pen's "Bill-shape" chip (Frame 15): a 27 pt pill, 12/500 label, outline or solid green.
public enum BillChipStyle: Equatable {
    /// White, `Stroke.chip` hairline, green-black label.
    case outline
    /// Green-600 fill, white label — the selected state.
    case solid
    /// Outline with a leading 8 pt dot (Insights legend).
    case withDot(Color)
    /// Solid with a leading white disc + green check (Settings "2h").
    case solidWithCheck

    var isSolid: Bool {
        switch self {
        case .solid, .solidWithCheck: true
        case .outline, .withDot: false
        }
    }

    public static func == (lhs: BillChipStyle, rhs: BillChipStyle) -> Bool {
        switch (lhs, rhs) {
        case (.outline, .outline), (.solid, .solid), (.solidWithCheck, .solidWithCheck): true
        case (.withDot, .withDot): true
        default: false
        }
    }
}

public struct BillChip: View {
    private let text: String
    private let style: BillChipStyle
    private let large: Bool

    /// - Parameter large: the day-details emotion chip (29 pt, 14/500, raised shadow).
    public init(_ text: String, style: BillChipStyle = .outline, large: Bool = false) {
        self.text = text
        self.style = style
        self.large = large
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            leading
            Text(text)
                .font(large ? Typography.rowLabel : Typography.chipLabel)
                .lineLimit(1)
        }
        .foregroundStyle(style.isSolid ? Ink.onAccent : Ink.chip)
        .padding(.horizontal, Spacing.cardInset)
        .padding(.vertical, large ? 6 : 5)
        .frame(minHeight: large ? 29 : Metrics.chipHeight)
        .background(style.isSolid ? Accent.primaryFill : Surface.card, in: .capsule)
        .overlay {
            Capsule().strokeBorder(style.isSolid ? Accent.primaryFill : Stroke.chip, lineWidth: Stroke.hairlineWidth)
        }
        .elevation(large ? Elevation.chip : ShadowSpec(color: .clear, blur: 0, y: 0))
    }

    @ViewBuilder private var leading: some View {
        switch style {
        case .withDot(let color):
            Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
        case .solidWithCheck:
            ZStack {
                Circle().fill(Ink.onAccent).frame(width: 15, height: 15)
                Image(systemName: Icons.check)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Accent.primaryFill)
            }
            .accessibilityHidden(true)
        case .outline, .solid:
            EmptyView()
        }
    }
}

/// A wrapping row of chips. Display rows sit on a 6/6 grid; interactive rows take a ≥ 44 pt
/// row pitch so each chip's 44 pt hit frame is unambiguous (D-K6: chip 27 + gap 17).
public struct ChipRow<Content: View>: View {
    private let interactive: Bool
    private let content: Content

    public init(interactive: Bool = false, @ViewBuilder content: () -> Content) {
        self.interactive = interactive
        self.content = content()
    }

    public var body: some View {
        FlowLayout(spacing: Spacing.chipGap,
                   rowSpacing: interactive ? Spacing.chipRowPitch - Metrics.chipHeight : Spacing.chipGap) {
            content
        }
    }
}

/// A tappable chip — the chip drawn at 27 pt with a 44 pt hit frame and `.isSelected`.
public struct ChipButton: View {
    private let text: String
    private let selected: Bool
    private let action: () -> Void

    public init(_ text: String, selected: Bool, action: @escaping () -> Void) {
        self.text = text
        self.selected = selected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            BillChip(text, style: selected ? .solid : .outline)
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

#Preview("Chips") {
    VStack(alignment: .leading, spacing: Spacing.xxl) {
        ChipRow {
            BillChip("Proud")
            BillChip("Excited", style: .solid)
            BillChip("Low (2)", style: .withDot(MoodLevel.low.color))
            BillChip("2h", style: .solidWithCheck)
            BillChip("Proud", large: true)
            BillChip("Excited", style: .solid, large: true)
        }
        ChipRow(interactive: true) {
            ForEach(["Excited", "Joyful", "Proud", "Serene", "Thrilled", "Inspired", "Content", "Grateful", "Peaceful", "Secure"], id: \.self) { word in
                ChipButton(word, selected: word == "Excited") {}
            }
        }
    }
    .padding(Spacing.gutter)
    .background(Surface.screen)
}
