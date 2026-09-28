import SwiftUI
import Testing
import SquirlDesignSystem
@testable import app_four

struct RhythmTintTests {
    /// Dynamic colours are providers, not values — compare what they resolve to in each appearance.
    private func rgba(_ color: Color?, dark: Bool) -> [CGFloat]? {
        guard let color else { return nil }
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { ($0 * 1000).rounded() / 1000 }
    }

    @Test func tintIsTheMoodRampAvatarTintForTheOrdinal() {
        for (level, mood) in [(1, MoodLevel.low), (4, .good), (5, .great)] {
            for dark in [false, true] {
                #expect(rgba(RhythmTint.tint(level: level), dark: dark) == rgba(mood.avatarTint, dark: dark))
            }
        }
    }

    @Test func emptyOrOutOfRangeHasNoTint() {
        #expect(RhythmTint.tint(level: nil) == nil)
        #expect(RhythmTint.tint(level: 0) == nil)
        #expect(RhythmTint.tint(level: 9) == nil)
    }
}
