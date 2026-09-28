import CoreFoundation

/// Corner radii (DESIGN.md §6.2). Circular shapes use `Circle()`; pills use `Capsule()`.
public enum Radius {
    /// 24 — large cards (insights, settings groups, edit sections, the AI card)
    public static let cardL: CGFloat = 24
    /// 18 — medium cards (connection cards, the listening prompt card)
    public static let cardM: CGFloat = 18
    /// 12 — small cards, day cards, the medication bar, row cards
    public static let cardS: CGFloat = 12
    /// 20 — level-picker tile
    public static let tile: CGFloat = 20
    /// 15 — Bill-shape chip (pill on 27 high)
    public static let chip: CGFloat = 15
    /// 12 — date / time fields, the confirmation preview row
    public static let field: CGFloat = 12
    /// 11 — connection icon tile
    public static let iconTile: CGFloat = 11
    /// 19 / 15 — segmented month picker track / thumb
    public static let segmentTrack: CGFloat = 19
    public static let segmentThumb: CGFloat = 15
    /// 999 — every button, toggle and bar
    public static let pill: CGFloat = 999

    // MARK: Pre-057 (aliases until their consumers migrate; UI-49 deletes)
    /// 16 → large card
    public static let card: CGFloat = cardL
    /// 10 → small card
    public static let control: CGFloat = cardS
    /// 16 → pill
    public static let button: CGFloat = pill
    /// 20 → large card
    public static let newLookCard: CGFloat = cardL
}
