import CoreFoundation

/// Opacity tokens for layered tints and de-emphasis, kept out of raw view code so
/// the same wash / de-emphasis reads consistently across the app.
public enum Opacity {
    /// 0.16 — the day's representative-mood colour as an inset panel tint behind the folded header
    /// and the open-state strip (Paper & Pollen "#4 Divided · Cream disc"). Deliberately light, and
    /// inset within a cream frame, so the card reads as a mood-tinted panel — not a full-card stain —
    /// while the cream-disc badge stays the focal mood mark.
    public static let moodBlock: Double = 0.24
    /// 0.50 — the cream-disc mood badge behind the mood glyph (folded header + check-in bead).
    public static let moodBadge: Double = 0.50
}
