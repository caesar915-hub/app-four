import SwiftUI

/// **New Look** — a cool **sage** ground with white, borderless, generously-rounded cards and
/// iOS-ink text. As of spec 033, New Look is the app-wide default. `Theme` (Paper & Pollen) is
/// retained only for the semantic-color exceptions documented in DESIGN.md (accent, meadow,
/// status, danger, medication).
///
/// Values map 1:1 to the Figma "Tiimo Colors" variables (file Squil-Design); dark values are
/// derived per iOS convention (cool-dark surfaces, light ink) and validated at device QA.
/// Medication is NOT redefined here — it reuses `Palette.medication`.
public enum NewLook {
    /// Screen ground — cool sage.
    public static let screen = Color(lightHex: "#EFF2EB", darkHex: "#12140F")
    /// Card surface — raised, borderless.
    public static let card = Color(lightHex: "#FFFFFF", darkHex: "#1C1E19")
    /// Primary text.
    public static let inkPrimary = Color(lightHex: "#1C1B1F", darkHex: "#F2F3EE")
    /// Secondary text — labels, captions, unselected chip glyphs.
    /// Known limitation: the light value `#8A8A8E` is below WCAG AA (3.0:1 on `screen`, 3.4:1 on
    /// `card`) for normal-size body text — kept 1:1 with Figma by owner decision (2026-07-12, see
    /// DESIGN.md Decisions Log). Do not darken without approval. Dark mode passes (~7:1).
    public static let inkSecondary = Color(lightHex: "#8A8A8E", darkHex: "#9BA09A")
    /// Hairline — chip / field borders (never a card border in New Look).
    public static let hairline = Color(lightHex: "#DBDDDE", darkHex: "#33362F")
    /// Neutral tint — grooves, tracks, segmented-control fills (never a card background).
    public static let tintNeutral = Color(lightHex: "#ECEAE6", darkHex: "#272A22")
    /// Selection accent — filled selected chips (non-medication).
    public static let selection = Color(lightHex: "#54B492", darkHex: "#5FC49F")
}

// MARK: - Card

public extension View {
    /// New Look card: white surface, radius 20, soft shadow, **no border**. Spec 033 makes New
    /// Look the app-wide look; `.card()` / `Theme` are retained only for the semantic-color set
    /// (accent/meadow/status/danger). `RecordingRow` and `MedicationBarView` are no longer
    /// permanent `.card()` consumers — they migrate to `.newLookCard()` under spec-033.
    func newLookCard(padding: CGFloat = Spacing.l) -> some View {
        self
            .padding(padding)
            .background(NewLook.card, in: .rect(cornerRadius: Radius.newLookCard))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Chip grammar

/// Which accent a selected chip fills with. Medication chips are always purple; everything else
/// uses the selection green (contract C7/C8).
public enum NewLookChipRole {
    case standard
    case medication

    var selectedFill: Color {
        switch self {
        case .standard:   NewLook.selection
        case .medication: Palette.medication
        }
    }
}

public extension View {
    /// New Look pill/chip styling applied to a chip's label content: unselected = white fill +
    /// hairline border + primary ink; selected = solid role fill + white label. Shape is a capsule
    /// (matches a03's 26pt pills). Pair with the caller's own `Button` + accessibility traits.
    func newLookChip(selected: Bool, role: NewLookChipRole = .standard) -> some View {
        self
            .font(Typography.caption)
            .fontWeight(.medium)
            .foregroundStyle(selected ? .white : NewLook.inkPrimary)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(selected ? role.selectedFill : NewLook.card, in: .capsule)
            .overlay {
                if !selected {
                    Capsule().strokeBorder(NewLook.hairline, lineWidth: 1)
                }
            }
    }
}

// MARK: - Nav row

/// New Look navigation row: a leading pill and a trailing pill at the edges with the title
/// **mathematically centered on the screen axis** (a `ZStack` so the centering is independent of
/// pill widths — a03's fix for the off-center title). Used in place of the system nav bar on the
/// re-skinned sheets.
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
                .font(Typography.text(24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(NewLook.inkPrimary)
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
