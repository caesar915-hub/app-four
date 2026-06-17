import Testing
@testable import app_four

/// Pure-helper coverage for the Paper & Pollen signal glyphs (Constitution Principle X).
/// The glyph `View`s themselves are exempt (verified by build + simulator render).
struct SignalGlyphTests {

    // MARK: clampedSignalLevel

    @Test func clampPassesNilThrough() {
        #expect(clampedSignalLevel(nil) == nil)
    }

    @Test func clampSnapsOutOfRange() {
        #expect(clampedSignalLevel(0) == 1)
        #expect(clampedSignalLevel(-3) == 1)
        #expect(clampedSignalLevel(6) == 5)
        #expect(clampedSignalLevel(99) == 5)
    }

    @Test func clampKeepsValidLevels() {
        #expect(clampedSignalLevel(1) == 1)
        #expect(clampedSignalLevel(3) == 3)
        #expect(clampedSignalLevel(5) == 5)
    }

    // MARK: signalName (reuses MoodLevel/EnergyLevel/FocusLevel SSOT)

    @Test func nameUsesLevelEnums() {
        #expect(signalName(.mood, level: 1) == "Low")
        #expect(signalName(.mood, level: 5) == "Great")
        #expect(signalName(.energy, level: 4) == "Alert")
        #expect(signalName(.focus, level: 1) == "Foggy")
        #expect(signalName(.focus, level: 5) == "Locked In")
    }

    @Test func nameNilForNonLevelSignals() {
        #expect(signalName(.sleep, level: 3) == nil)
        #expect(signalName(.medication, level: 3) == nil)
    }

    // MARK: signalSynonym

    @Test func synonymUsesEnumSubtitles() {
        #expect(signalSynonym(.mood, level: 5) == "bright, thriving")
        #expect(signalSynonym(.energy, level: 1) == "slow, heavy")
        #expect(signalSynonym(.focus, level: 1) == "hazy, drifting")
    }

    // MARK: signalAccessibilityLabel

    @Test func a11yLabelForSelfStateSignals() {
        #expect(signalAccessibilityLabel(.energy, level: 4) == "Energy: Alert, 4 of 5")
        #expect(signalAccessibilityLabel(.focus, level: 5) == "Focus: Locked In, 5 of 5")
    }

    @Test func a11yLabelClampsOutOfRange() {
        #expect(signalAccessibilityLabel(.energy, level: 9) == "Energy: Charged, 5 of 5")
    }

    @Test func a11yLabelTitleOnlyForSingleOrAbsent() {
        #expect(signalAccessibilityLabel(.sleep, level: nil) == "Sleep")
        #expect(signalAccessibilityLabel(.medication, level: 3) == "Medication")
        #expect(signalAccessibilityLabel(.mood, level: nil) == "Mood")
    }
}
