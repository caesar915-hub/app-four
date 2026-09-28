import SwiftUI

/// The pen's date / time field (DESIGN.md §8.19): a 12/500 label above a 39 pt white field with a
/// leading icon and a 12/600 value. The picker itself is not designed (D-E3), so the field is a
/// button and the caller presents a picker from it.
public struct DateTimeField: View {
    public enum Kind {
        case date, time

        var icon: String {
            switch self {
            case .date: Icons.calendar
            case .time: Icons.clock
            }
        }
    }

    private let label: String
    private let kind: Kind
    private let value: String
    private let action: () -> Void

    public init(_ label: String, kind: Kind, value: String, action: @escaping () -> Void) {
        self.label = label
        self.kind = kind
        self.value = value
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(Typography.captionMedium)
                .foregroundStyle(Ink.primary)
            Button(action: action) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: kind.icon)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Ink.nav)
                    Text(value)
                        .font(Typography.status)
                        .foregroundStyle(Ink.chip)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 39)
                .background(Surface.card, in: .rect(cornerRadius: Radius.field))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.field)
                        .strokeBorder(Stroke.field, lineWidth: Stroke.hairlineWidth)
                }
                .elevation(Elevation.field)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .frame(minHeight: Metrics.minTapTarget)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityHint("Opens a picker")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

#Preview {
    HStack(spacing: Spacing.m) {
        DateTimeField("Date", kind: .date, value: "Jun 29") {}
        DateTimeField("Time", kind: .time, value: "9:15 AM") {}
    }
    .padding(Spacing.gutter)
    .background(Surface.screen)
}
