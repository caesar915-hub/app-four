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

    /// Diameter of the time-bead circle (wrapped by the medication-phase ring) in a check-in row.
    /// Matches `headerMoodBadge` so the row ring never out-sizes the header badge (spec 019 / "#5 Balanced").
    public static let timeBead: CGFloat = 42
    /// Diameter of the cream-disc mood badge in the day-card header (folded block + open strip)
    public static let headerMoodBadge: CGFloat = 42
    /// Base size for the folded-card summary's inline signal glyph (fixed-point, decorative) and
    /// its mood text (scales with Dynamic Type) — the two align at the default text size.
    public static let summarySignal: CGFloat = 15
    /// Check-in row type ("#5 Balanced"): the mood word (Fraunces, scales), the inline time (mono),
    /// and the energy/focus signal glyph — kept below the folded-summary sizes so the rows read as
    /// detail beneath the header, not peers of it.
    public static let rowMoodText: CGFloat = 14
    public static let rowTime: CGFloat = 11
    public static let rowSignal: CGFloat = 13

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
        /// Idle-hub ambient crescent diameter.
        public static let idleCrescent: CGFloat = 200
        /// Recording-stage crescent diameter (the larger, active ring).
        public static let recordingCrescent: CGFloat = 260
        /// Side of the rounded "stop" square glyph inside the Stop & save button.
        public static let stopGlyph: CGFloat = 11
        /// Corner radius of that stop-square glyph.
        public static let stopGlyphRadius: CGFloat = 3
        /// Diameter of a single prompt-progress dot, and the gap between dots.
        public static let promptDot: CGFloat = 6
        /// Height of the thin prompt-progress bar at the top of the recording stage.
        public static let promptBarHeight: CGFloat = 3
        /// Saved-state confirmation disc diameter.
        public static let savedDisc: CGFloat = 78
        /// Saved-state checkmark glyph point size.
        public static let savedCheck: CGFloat = 32
    }
}
