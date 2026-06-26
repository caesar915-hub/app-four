import SwiftUI
import UIKit

/// Squirl typography — **Apple SF**: SF Pro (text/display) and SF Mono (data/time).
/// Every role scales with Dynamic Type via `UIFontMetrics` (relative to a text style),
/// so custom point sizes still respond to the user's text-size setting. Roles keep their
/// names so every call site is unchanged; only the underlying face changed (Fraunces +
/// DM Sans + IBM Plex Mono → SF), with weight carrying the hierarchy the serif gave by style.
public enum Typography {

    /// SF Pro / SF Mono at an explicit point size, scaled relative to `style` for Dynamic Type.
    private static func sf(_ size: CGFloat, _ weight: UIFont.Weight, _ style: UIFont.TextStyle, mono: Bool = false) -> Font {
        let base = mono
            ? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    // MARK: Display (SF Pro)
    /// Serif-replacement display header — Insights section titles, the Check-in headline.
    public static let display: Font = sf(28, .semibold, .title1)
    /// Screen hero — used sparingly.
    public static let largeTitle: Font = sf(34, .bold, .largeTitle)
    /// Primary section title.
    public static let title: Font = sf(22, .semibold, .title2)
    /// Folded day-card weekday label.
    public static let dayCardDate: Font = sf(16, .semibold, .subheadline)

    // MARK: Content (SF Pro)
    /// Row / card headline.
    public static let headline: Font = sf(16, .semibold, .headline)
    /// Group / section header label.
    public static let subheadline: Font = sf(14, .medium, .subheadline)
    /// Primary body copy.
    public static let body: Font = sf(16, .regular, .body)
    /// Secondary body copy.
    public static let callout: Font = sf(15, .regular, .callout)

    // MARK: Metadata (SF Pro)
    /// Timestamps, labels, metadata.
    public static let caption: Font = sf(12, .regular, .caption1)
    /// Uppercase section labels with tracking — call `.textCase(.uppercase)` separately.
    public static let label: Font = sf(12, .medium, .caption1)

    // MARK: Data / time (SF Mono)
    /// Timers and durations.
    public static let timer: Font = sf(22, .medium, .title2, mono: true)
    public static let duration: Font = sf(12, .regular, .caption1, mono: true)
    /// Generic mono for inline data (time labels, counts).
    public static let mono12: Font = sf(12, .regular, .caption1, mono: true)

    // MARK: Bespoke sizes (explicit point size + Dynamic Type scaling)

    /// SF Pro text at an explicit size (for call sites that need a specific point size — e.g. the
    /// check-in row's mood word). Scales relative to `style`.
    public static func text(_ size: CGFloat, weight: UIFont.Weight = .regular, relativeTo style: UIFont.TextStyle = .body) -> Font {
        sf(size, weight, style)
    }
    /// SF Mono at an explicit size (inline time/data). Scales relative to `style`.
    public static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular, relativeTo style: UIFont.TextStyle = .caption1) -> Font {
        sf(size, weight, style, mono: true)
    }
}

// MARK: - View extensions for ergonomic usage

public extension View {
    func typography(_ style: Font) -> some View {
        self.font(style)
    }
}
