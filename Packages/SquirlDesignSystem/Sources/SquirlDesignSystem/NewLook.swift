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
