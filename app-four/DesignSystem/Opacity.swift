import CoreFoundation

/// Opacity tokens for layered tints and de-emphasis, kept out of raw view code so
/// the same wash / de-emphasis reads consistently across the app.
enum Opacity {
    /// 0.34 — de-emphasis for calendar days more recent than the selected date.
    /// Always paired with a non-colour cue so it survives greyscale.
    static let deEmphasis: Double = 0.34
    /// 0.16 — the day's representative-mood colour as an inset panel tint behind the folded header
    /// and the open-state strip (Paper & Pollen "#4 Divided · Cream disc"). Deliberately light, and
    /// inset within a cream frame, so the card reads as a mood-tinted panel — not a full-card stain —
    /// while the cream-disc badge stays the focal mood mark.
    static let moodBlock: Double = 0.16
    /// 0.50 — the cream-disc mood badge behind the mood glyph (folded header + check-in bead).
    static let moodBadge: Double = 0.50
}
