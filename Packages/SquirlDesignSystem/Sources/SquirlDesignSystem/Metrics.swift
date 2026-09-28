import CoreFoundation

/// Layout metrics that aren't spacing or radius: tap targets, content width limits and the
/// fixed-point sizes of imagery (glyphs, rings, chrome) — never Dynamic-Type copy.
///
/// Named `Metrics` (not `Layout`) to avoid shadowing the SwiftUI `Layout` protocol.
public enum Metrics {
    /// Minimum interactive target per Apple HIG
    public static let minTapTarget: CGFloat = 44
    /// Maximum readable content width (used to inset content on iPad)
    public static let maxContentWidth: CGFloat = 600

    // MARK: Chrome (spec 057)
    /// Floating tab bar height and pill radius (60 high, r 75).
    public static let tabBarHeight: CGFloat = 60
    /// Compact tab bar width (icon-only active pill, shares the row with the FAB).
    public static let tabBarCompactWidth: CGFloat = 274
    /// Active tab pill (icon-only).
    public static let tabPillWidth: CGFloat = 64
    public static let tabPillHeight: CGFloat = 44
    /// Tab-bar icon size.
    public static let tabIcon: CGFloat = 24
    /// Add button diameter.
    public static let fab: CGFloat = 50
    /// Back / more nav pill diameter, and its row-sized variant.
    public static let navPill: CGFloat = 43
    public static let navPillSmall: CGFloat = 24
    /// Bottom inset, above the home-indicator safe area, that keeps content clear of the floating
    /// chrome: bar 60 + its 4 pt bottom gap + 8 pt breathing room.
    public static let floatingChromeInset: CGFloat = 72

    // MARK: Glyphs (spec 057 — Frame 12 placed sizes)
    /// Level-picker tiles, weekday rows, rhythm tiles, avatars.
    public static let glyphTile: CGFloat = 33.55
    /// Inline signal words on cards.
    public static let glyphInline: CGFloat = 24
    /// Journal rows.
    public static let glyphRow: CGFloat = 18
    /// Section-header identity icons.
    public static let glyphHeader: CGFloat = 16
    /// Level tile side.
    public static let levelTile: CGFloat = 56
    /// Mood avatar diameter.
    public static let avatar: CGFloat = 44
    /// Medication badge diameter.
    public static let medicationBadge: CGFloat = 26
    /// Bill-shape chip height.
    public static let chipHeight: CGFloat = 27

    // MARK: Day card (spec 034 — migrates in UI-25)
    /// Base size for the folded-card summary's inline signal glyph.
    public static let summarySignal: CGFloat = 15
    /// Check-in row signal-glyph size.
    public static let rowSignal: CGFloat = 12
    /// Diameter of the day-header's inline mood glyph.
    public static let dayHeaderGlyph: CGFloat = 40
    /// Unfolded entry-row mood disc.
    public static let rowMoodDisc: CGFloat = 43
    /// Mood sprout size inside the entry-row disc.
    public static let rowMoodGlyph: CGFloat = 28
    /// Outlined "more" affordance circle on an entry row.
    public static let moreAffordance: CGFloat = 21

    /// Fixed-point dimensions of the check-in capture surface.
    public enum CheckIn {
        /// Ring diameter at 402 pt — callers clamp to `min(width − 2·gutter, ringDiameter)`.
        public static let ringDiameter: CGFloat = 347
        /// Ring diameter on the saved screen.
        public static let ringSavedDiameter: CGFloat = 211
        /// Ring track / arc width, idle-listening and saved.
        public static let ringStroke: CGFloat = 21.33
        public static let ringSavedStroke: CGFloat = 12.97
        /// The saved-screen check tile side.
        public static let checkTile: CGFloat = 97
        /// Prompt-progress dot diameter.
        public static let promptDot: CGFloat = 7.25
        /// Stop glyph inside the Stop & Save button.
        public static let stopGlyph: CGFloat = 16
        public static let stopGlyphRadius: CGFloat = 4

        // Pre-057 (aliases until UI-21/22/23 migrate; UI-49 deletes)
        public static let crescentDiameter: CGFloat = 300
        public static let promptBarHeight: CGFloat = 4
        public static let savedDisc: CGFloat = 78
        public static let savedCheck: CGFloat = 32
    }
}
