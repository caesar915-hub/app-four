import SwiftUI

/// Semantic typography roles mapped to Dynamic Type text styles.
/// Use these instead of `.font(.system(size:))` — they scale automatically
/// with the user's preferred text size and require no maintenance.
///
/// Justified exception: timers / durations use `.monospacedDigit()` on top of
/// a text style (e.g. `Font.body.monospacedDigit()`) for digit alignment,
/// but never a full `.monospaced` design.
enum Typography {
    // MARK: Display
    /// Serif display header — Insights section titles and the Check-in headline. New York, left-aligned,
    /// scales with Dynamic Type.
    static let display: Font = .system(.title, design: .serif, weight: .bold)
    /// Screen hero — used sparingly, typically one per screen
    static let largeTitle: Font = .largeTitle
    /// Primary section title
    static let title: Font = .title2
    // MARK: Content
    /// Row / card headline — the most prominent text in a list row
    static let headline: Font = .headline
    /// Group or section header label
    static let subheadline: Font = .subheadline
    /// Primary body copy
    static let body: Font = .body
    /// Secondary body copy, supporting text
    static let callout: Font = .callout
    // MARK: Metadata
    /// Timestamps, labels, metadata — smallest legible size
    static let caption: Font = .caption
    /// Uppercase section labels with tracking — call `.textCase(.uppercase)` separately
    static let label: Font = .caption.weight(.medium)

    // MARK: - Monospaced Digit Variants
    /// Timers and durations — preserves Dynamic Type scaling with stable digit widths
    static let timer: Font = Font.title2.monospacedDigit().bold()
    static let duration: Font = Font.caption.monospacedDigit()
}

// MARK: - View extensions for ergonomic usage

extension View {
    func typography(_ style: Font) -> some View {
        self.font(style)
    }
}
