import CoreFoundation

/// Base-4/base-8 spacing grid. All padding and spacing values must come from here.
/// Never use arbitrary numbers like 14, 18, 26, 34.
enum Spacing {
    /// 4pt — tight gaps between sibling elements (icon + label, dot + text)
    static let xs: CGFloat = 4
    /// 8pt — gaps within a component (chip padding, avatar-to-text gap)
    static let s: CGFloat = 8
    /// 12pt — internal card padding (vertical), compact sections
    static let m: CGFloat = 12
    /// 16pt — standard outer content margin, card horizontal padding
    static let l: CGFloat = 16
    /// 20pt — slightly wider outer margin (legacy — prefer .l)
    static let xl: CGFloat = 20
    /// 24pt — between major sections within a screen
    static let xxl: CGFloat = 24
    /// 32pt — between top-level page sections, generous breathe room
    static let section: CGFloat = 32
    /// 40pt — large spacers (bottom safe-area padding, hero spacing)
    static let hero: CGFloat = 40
}
