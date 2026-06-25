import SwiftUI

/// Paper & Pollen typography — **Fraunces** (display/hero), **DM Sans** (body/UI),
/// **IBM Plex Mono** (data/time). Bundled via Info.plist `UIAppFonts`. Roles keep their
/// names so every call site is unchanged; each scales with Dynamic Type via `relativeTo:`.
enum Typography {
    private static let fraunces = "Fraunces"
    private static let dmSans = "DM Sans"
    private static let mono = "IBM Plex Mono"

    // MARK: Display (Fraunces)
    /// Serif display header — Insights section titles, the Check-in headline.
    static let display: Font = .custom(fraunces, size: 28, relativeTo: .title).weight(.medium)
    /// Screen hero — used sparingly.
    static let largeTitle: Font = .custom(fraunces, size: 34, relativeTo: .largeTitle).weight(.medium)
    /// Primary section title.
    static let title: Font = .custom(fraunces, size: 22, relativeTo: .title2).weight(.medium)
    /// Folded day-card weekday label.
    static let dayCardDate: Font = .custom(fraunces, size: 16, relativeTo: .subheadline).weight(.medium)

    // MARK: Content (DM Sans)
    /// Row / card headline.
    static let headline: Font = .custom(dmSans, size: 16, relativeTo: .headline).weight(.semibold)
    /// Group / section header label.
    static let subheadline: Font = .custom(dmSans, size: 14, relativeTo: .subheadline).weight(.medium)
    /// Primary body copy.
    static let body: Font = .custom(dmSans, size: 16, relativeTo: .body)
    /// Secondary body copy.
    static let callout: Font = .custom(dmSans, size: 15, relativeTo: .callout)

    // MARK: Metadata (DM Sans)
    /// Timestamps, labels, metadata.
    static let caption: Font = .custom(dmSans, size: 12, relativeTo: .caption)
    /// Uppercase section labels with tracking — call `.textCase(.uppercase)` separately.
    static let label: Font = .custom(dmSans, size: 12, relativeTo: .caption).weight(.medium)

    // MARK: Data / time (IBM Plex Mono)
    /// Timers and durations.
    static let timer: Font = .custom(mono, size: 22, relativeTo: .title2).weight(.medium)
    static let duration: Font = .custom(mono, size: 12, relativeTo: .caption)
    /// Generic mono for inline data (time labels, counts).
    static let mono12: Font = .custom(mono, size: 12, relativeTo: .caption)
}

// MARK: - View extensions for ergonomic usage

extension View {
    func typography(_ style: Font) -> some View {
        self.font(style)
    }
}

extension Font {
    /// A Fraunces font at an explicit size (for bespoke headline sizes that match the mockup).
    static func fraunces(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, weight: Font.Weight = .medium) -> Font {
        .custom("Fraunces", size: size, relativeTo: style).weight(weight)
    }
    /// IBM Plex Mono at an explicit size.
    static func plexMono(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("IBM Plex Mono", size: size, relativeTo: style)
    }
}
