import CoreFoundation

/// Layout metrics that aren't spacing or radius: tap targets, content width
/// limits, and standard decorative icon sizes.
///
/// Named `Metrics` (not `Layout`) to avoid shadowing the SwiftUI `Layout`
/// protocol, which is conformed to by `FlowLayout` in `TagFlowView`.
enum Metrics {
    /// Minimum interactive target per Apple HIG
    static let minTapTarget: CGFloat = 44
    /// Maximum readable content width (used to inset content on iPad)
    static let maxContentWidth: CGFloat = 600
    /// Standard minimum row height
    static let rowMinHeight: CGFloat = 44

    /// Decorative SF Symbol sizes (large hero glyphs, not Dynamic Type text).
    /// These use a fixed point size intentionally because they are imagery, not copy.
    enum IconSize {
        /// Inline control glyphs (play/pause, close)
        static let control: CGFloat = 32
        /// Empty-state / section illustration glyph
        static let illustration: CGFloat = 48
        /// Onboarding hero glyph
        static let hero: CGFloat = 72
    }
}
