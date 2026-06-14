import Testing
@testable import app_four

/// P0 exit smoke: a realistic multi-signal transcript should produce coherent
/// headline outputs across all the hardened paths at once.
struct NLNoteExtractorSmokeTests {

    let extractor = NLNoteExtractor()

    @Test func multiSignalTranscript() {
        let transcript = """
        I took my Concerta XL 36mg at 8am and skipped my Strattera. \
        This morning I was a mess but right now I feel good. \
        I only slept 5 hours and felt a bit of a headache. \
        I nailed the big presentation.
        """
        let result = extractor.extract(from: transcript)

        // Present-tense mood wins the headline.
        #expect(result.mood == "good")

        // Med de-dup: Concerta XL (not bare Concerta) + Strattera, distinct.
        let names = Set(result.medications.map(\.name))
        #expect(names.contains("Concerta XL"))
        #expect(!names.contains("Concerta"))      // suppressed by the longer name
        #expect(names.contains("Strattera"))

        // Per-med taken state: Concerta taken, Strattera skipped.
        #expect(result.medications.first { $0.name == "Concerta XL" }?.taken == true)
        #expect(result.medications.first { $0.name == "Strattera" }?.taken == false)

        // Concerta dose scoped to its own clause.
        #expect(result.medications.first { $0.name == "Concerta XL" }?.dose == "36mg")

        // Sleep duration extracted from a real sleep phrase.
        #expect(result.sleepHours == 5)

        // The win is still recorded (no false negation from "skipped").
        #expect(!result.wins.isEmpty)
    }
}
