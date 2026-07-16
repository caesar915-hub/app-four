import CoreFoundation

/// Layout metrics that aren't spacing or radius: tap targets, content width
/// limits, and standard decorative icon sizes.
///
/// Named `Metrics` (not `Layout`) to avoid shadowing the SwiftUI `Layout`
/// protocol, which is conformed to by `FlowLayout` in `TagFlowView`.
public enum Metrics {
    /// Minimum interactive target per Apple HIG
    public static let minTapTarget: CGFloat = 44
    /// Maximum readable content width (used to inset content on iPad)
    public static let maxContentWidth: CGFloat = 600
    /// Standard minimum row height
    public static let rowMinHeight: CGFloat = 44

    /// Diameter of the cream-disc mood badge in the day-card header (folded block + open strip)
    public static let headerMoodBadge: CGFloat = 42
    /// Base size for the folded-card summary's inline signal glyph (fixed-point, decorative) and
    /// its mood text (scales with Dynamic Type) — the two align at the default text size.
    public static let summarySignal: CGFloat = 15
    /// Check-in row signal-glyph size — the energy/focus chip glyphs in the expanded entry row.
    public static let rowSignal: CGFloat = 12
    /// Diameter of the no-disc day-header's inline mood glyph, folded + expanded (spec 023).
    public static let dayHeaderGlyph: CGFloat = 40

    // MARK: - DayCard a01 (spec 034)
    /// Unfolded entry-row mood disc (a01 node 308:1957 — 43pt), tinted with the row's own
    /// mood at `Opacity.moodBadge`.
    public static let rowMoodDisc: CGFloat = 43
    /// Mood sprout size inside the entry-row disc — a badge glyph with a visible tint ring
    /// (smaller than the disc so the disc reads as an avatar, matching the app's bead proportions).
    public static let rowMoodGlyph: CGFloat = 28
    /// Outlined "more" (⋯) affordance circle on an unfolded entry row (a01 — 30pt).
    public static let moreAffordance: CGFloat = 30

    /// Decorative SF Symbol sizes (large hero glyphs, not Dynamic Type text).
    /// These use a fixed point size intentionally because they are imagery, not copy.
    public enum IconSize {
        /// Inline control glyphs (play/pause, close)
        public static let control: CGFloat = 32
        /// Empty-state / section illustration glyph
        public static let illustration: CGFloat = 48
        /// Onboarding hero glyph
        public static let hero: CGFloat = 72
    }

    /// Fixed-point dimensions of the Check-in capture surface — imagery and hand-rolled
    /// control glyphs, not Dynamic-Type copy, so they are intentionally point-sized.
    /// Named here (rather than scattered as literals) so the capture screen reads from
    /// one place; tap targets still use `minTapTarget`.
    public enum CheckIn {
        /// Check-in ring diameter — same in idle and recording states (spec 025).
        public static let crescentDiameter: CGFloat = 300
        /// Side of the rounded "stop" square glyph inside the Stop & save button.
        public static let stopGlyph: CGFloat = 11
        /// Corner radius of that stop-square glyph.
        public static let stopGlyphRadius: CGFloat = 3
        /// Diameter of a single prompt-progress dot, and the gap between dots.
        public static let promptDot: CGFloat = 6
        /// Height of the thin prompt-progress bar at the top of the recording stage
        /// (4pt per Figma a05, spec 036 — was 3 pre-New-Look).
        public static let promptBarHeight: CGFloat = 4
        /// Saved-state confirmation disc diameter.
        public static let savedDisc: CGFloat = 78
        /// Saved-state checkmark glyph point size.
        public static let savedCheck: CGFloat = 32
    }
}
