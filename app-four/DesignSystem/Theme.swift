import SwiftUI

/// Semantic color roles. Thin wrappers over UIKit adaptive system colors
/// so every color adapts automatically to light/dark mode and accessibility.
///
/// Never use hardcoded `Color.white`, `Color.black`, or `Color.white.opacity(...)` in views.
/// The only accepted opacity usage is:
///   - `.opacity(0.15)` for subtle background strokes
///   - `.opacity(0.3)` for separator lines
enum Theme {
    // MARK: - Backgrounds
    /// Main screen background (white / near-black)
    static let background = Color(.systemBackground)
    /// Card, group, and row backgrounds (light gray / dark gray)
    static let cardBackground = Color(.secondarySystemBackground)
    /// Elevated card background (used for cards on top of secondarySystemBackground)
    static let elevatedBackground = Color(.tertiarySystemBackground)

    // MARK: - Text
    /// Full-weight primary text
    static let textPrimary = Color.primary
    /// Secondary / supporting text
    static let textSecondary = Color.secondary

    // MARK: - Separators
    /// System-standard divider color
    static let separator = Color(.separator)

    // MARK: - Accent
    /// Single accent color — set via AccentColor in the asset catalog
    static let accent = Color.accentColor

    // MARK: - Status
    /// Done / completed states
    static let statusDone = Color.green
    /// In-progress / pending states
    static let statusInProgress = Color.orange

    // MARK: - Stroke helper
    /// Subtle card border — use at 0.15 opacity max
    static let cardStroke = Color(.separator)
}
