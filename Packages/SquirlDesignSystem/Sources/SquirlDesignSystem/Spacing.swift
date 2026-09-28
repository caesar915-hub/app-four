import CoreFoundation

/// Base-4 spacing grid plus the handful of pen-specific metrics (DESIGN.md §6.1).
public enum Spacing {
    /// 4pt — icon + label, dot + text
    public static let xs: CGFloat = 4
    /// 8pt — gaps within a component, button stacks
    public static let s: CGFloat = 8
    /// 12pt — section heading → card
    public static let m: CGFloat = 12
    /// 16pt — inner padding on the signal-summary card, chip padding
    public static let l: CGFloat = 16
    /// 20pt
    public static let xl: CGFloat = 20
    /// 24pt — card/section stacks on every scroll screen
    public static let xxl: CGFloat = 24
    /// 32pt
    public static let section: CGFloat = 32
    /// 40pt
    public static let hero: CGFloat = 40

    // MARK: Pen metrics (spec 057)
    /// Screen gutter — one token; cards fill the column (D16).
    public static let gutter: CGFloat = 28
    /// Inner padding of insights / edit / settings cards.
    public static let cardInset: CGFloat = 15
    /// Inner padding of day-details cards, the medication bar and journal rows.
    public static let rowInset: CGFloat = 11
    /// Gap between chips in a display-only row.
    public static let chipGap: CGFloat = 6
    /// Gap between cards in a stack.
    public static let cardGap: CGFloat = 24
    /// Level-tile pitch (56 tile + 8 gap).
    public static let tilePitch: CGFloat = 64
    /// Minimum row pitch for interactive chip rows so 44-pt hit frames never overlap (D-K6).
    public static let chipRowPitch: CGFloat = 44
}
