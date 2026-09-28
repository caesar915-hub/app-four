import SwiftUI

/// **Retired (spec 057).** New Look was the app-wide language of specs 032/033. Every member is
/// now an alias of the pen-derived token it maps to (DESIGN.md §4.2 "Today" column), so the 261
/// call sites keep compiling while screens migrate to `Surface` / `Ink` / `Accent` / `Stroke`.
/// UI-49 deletes this file once the last consumer has moved.
public enum NewLook {
    public static let screen = Surface.screen
    public static let card = Surface.card
    public static let inkPrimary = Ink.primary
    public static let onInk = Ink.onAccent
    /// Was `#8a8a8e` (3.4:1, a logged AA exception) — now grey-400, which passes.
    public static let inkSecondary = Ink.secondary
    public static let hairline = Stroke.chip
    public static let tintNeutral = Surface.track
    public static let selection = Accent.primaryFill
    public static let onSelection = Ink.onAccent
    public static let checkInGreen = Accent.primaryFill
    public static let checkInGreenSoft = Palette.green300
}

// MARK: - Card (alias of `.card(.large)`)

public extension View {
    /// Pre-057 card modifier — now the pen's large card (r 24, hairline, tinted shadow).
    func newLookCard(padding: CGFloat = Spacing.cardInset) -> some View {
        card(.large, padding: padding)
    }

    /// Pre-057 card shadow — now `Elevation.card`.
    func newLookCardShadow() -> some View {
        elevation(Elevation.card)
    }
}

// MARK: - Chip grammar (alias of `BillChip` styling; migrates in UI-10 consumers)

/// Which accent a selected chip fills with. The pen fills every selected chip green-600;
/// the medication role is kept as a name only until its call sites migrate.
public enum NewLookChipRole {
    case standard
    case medication
    case checkIn

    var selectedFill: Color { Accent.primaryFill }
}

public extension View {
    /// Pre-057 chip styling — now the Bill-shape chip's outline / solid states.
    func newLookChip(selected: Bool, role: NewLookChipRole = .standard) -> some View {
        self
            .font(Typography.chipLabel)
            .foregroundStyle(selected ? Ink.onAccent : Ink.chip)
            .padding(.horizontal, Spacing.cardInset)
            .padding(.vertical, 5)
            .background(selected ? role.selectedFill : Surface.card, in: .capsule)
            .overlay {
                Capsule().strokeBorder(selected ? role.selectedFill : Stroke.chip, lineWidth: Stroke.hairlineWidth)
            }
    }
}

// MARK: - Nav row (single consumer: the edit sheet, migrates in UI-28)

public struct NewLookNavBar<Leading: View, Trailing: View>: View {
    private let title: String
    private let leading: Leading
    private let trailing: Trailing

    public init(
        _ title: String,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            Text(title)
                .font(Typography.navTitle)
                .foregroundStyle(Ink.title)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)

            HStack {
                leading
                Spacer(minLength: Spacing.s)
                trailing
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
    }
}
