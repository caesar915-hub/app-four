import CoreFoundation

/// Base-4/base-8 spacing grid. All padding and spacing values must come from here.
/// Never use arbitrary numbers like 14, 18, 26, 34.
public enum Spacing {
    /// 4pt — tight gaps between sibling elements (icon + label, dot + text)
    public static let xs: CGFloat = 4
    /// 8pt — gaps within a component (chip padding, avatar-to-text gap)
    public static let s: CGFloat = 8
    /// 12pt — internal card padding (vertical), compact sections
    public static let m: CGFloat = 12
    /// 16pt — standard outer content margin, card horizontal padding
    public static let l: CGFloat = 16
    /// 20pt — slightly wider outer margin (legacy — prefer .l)
    public static let xl: CGFloat = 20
    /// 24pt — between major sections within a screen
    public static let xxl: CGFloat = 24
    /// 32pt — between top-level page sections, generous breathe room
    public static let section: CGFloat = 32
    /// 40pt — large spacers (bottom safe-area padding, hero spacing)
    public static let hero: CGFloat = 40

    /// 3.3pt — stroke width of the medication-phase ring around a check-in time bead
    public static let ringStroke: CGFloat = 3.3
}
