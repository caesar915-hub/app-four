import CoreFoundation

/// Opacity tokens for layered tints and de-emphasis, kept out of raw view code so
/// the same wash / de-emphasis reads consistently across the app.
enum Opacity {
    /// 0.16 — the day's average-mood colour washed over a card surface (Daylio-style).
    static let moodWash: Double = 0.16
    /// 0.34 — de-emphasis for calendar days more recent than the selected date.
    /// Always paired with a non-colour cue so it survives greyscale.
    static let deEmphasis: Double = 0.34
    /// 0.55 — soft tint of the mood-glyph circle in a folded day-card header.
    static let moodCircle: Double = 0.55
}
