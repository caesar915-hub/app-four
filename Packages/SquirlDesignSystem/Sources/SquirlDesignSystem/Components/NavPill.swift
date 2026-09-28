import SwiftUI

/// The pen's circular white pill with a green-700 icon: the back and `•••` pills (43 pt) and
/// the row-sized expand / more pills (24 pt). Always a 44 pt hit target.
public struct NavPill: View {
    public enum Kind {
        case back, more, chevronUp, chevronDown, chevronRight

        var symbol: String {
            switch self {
            case .back: Icons.back
            case .more: Icons.more
            case .chevronUp: Icons.chevronUp
            case .chevronDown: Icons.chevronDown
            case .chevronRight: Icons.chevronRight
            }
        }

        var label: String {
            switch self {
            case .back: "Back"
            case .more: "More"
            case .chevronUp: "Collapse"
            case .chevronDown: "Expand"
            case .chevronRight: "Open"
            }
        }
    }

    private let kind: Kind
    private let size: CGFloat
    private let action: () -> Void

    public init(_ kind: Kind, size: CGFloat = Metrics.navPill, action: @escaping () -> Void) {
        self.kind = kind
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(size < 30 ? Accent.primaryText : Accent.deepText)
                .frame(width: size, height: size)
                .background(Surface.card, in: .circle)
                .overlay { Circle().strokeBorder(Stroke.chip, lineWidth: Stroke.hairlineWidth) }
                .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.label)
    }
}

/// Nav header for pushed screens: back pill, optional title + subtitle, optional trailing pill.
public struct NavHeader<Trailing: View>: View {
    private let title: String?
    private let subtitle: String?
    private let onBack: () -> Void
    private let trailing: Trailing

    public init(title: String? = nil, subtitle: String? = nil, onBack: @escaping () -> Void,
                @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            NavPill(.back, action: onBack)
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.navTitle)
                        .foregroundStyle(Ink.title)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.navSubtitle)
                            .foregroundStyle(Ink.nav)
                    }
                }
            }
            Spacer(minLength: Spacing.s)
            trailing
        }
        .frame(minHeight: Metrics.navPill)
    }
}
