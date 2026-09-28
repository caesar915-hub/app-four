import SwiftUI

/// One tint rule for every rhythm cell (DESIGN.md §8.16, D-I4): a level's pastel is the mood
/// ramp's avatar tint for that ordinal whatever the signal — energy and focus share the mood
/// ramp (`Palette+Signals`). `nil` for an empty cell or an out-of-range level.
enum RhythmTint {
    static func tint(level: Int?) -> Color? {
        guard let level, let mood = MoodLevel.allCases.first(where: { $0.numericValue == level }) else { return nil }
        return mood.avatarTint
    }
}
