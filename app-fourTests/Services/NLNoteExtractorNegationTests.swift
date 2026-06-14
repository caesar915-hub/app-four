import Testing
@testable import app_four

/// P0.2 — negation scoping. "forgot / missed / skipped" must NOT act as generic
/// negation (they negated unrelated cues before). They survive only as a
/// medication-specific "not taken" signal, scoped to the med's own clause.
struct NLNoteExtractorNegationTests {

    let extractor = NLNoteExtractor()

    // "skipped lunch" must not mark the separately-taken Concerta as not-taken.
    @Test func skippedLunchDoesNotNegateMed() {
        let result = extractor.extract(from: "I skipped lunch and took my Concerta.")
        let concerta = result.medications.first { $0.name == "Concerta" }
        #expect(concerta != nil)
        #expect(concerta?.taken == true)
    }

    // "forgot my Concerta" is a med-clause not-taken signal.
    @Test func forgotMedMarksNotTaken() {
        let result = extractor.extract(from: "I forgot my Concerta this morning.")
        let concerta = result.medications.first { $0.name == "Concerta" }
        #expect(concerta != nil)
        #expect(concerta?.taken == false)
    }

    // Generic "not" negation on mood is unchanged.
    @Test func notHappyStillNegatesMood() {
        let result = extractor.extract(from: "I'm not happy today.")
        #expect(result.mood == "low")
    }

    // "missed" no longer negates a win cue that is unrelated to it.
    @Test func missedDoesNotNegateUnrelatedCue() {
        // "missed the bus" should not suppress the "win" recorded for nailing the report.
        let result = extractor.extract(from: "I missed the bus but I nailed the presentation.")
        #expect(!result.wins.isEmpty)
    }

    // "skipped" scoped to a different med clause does not negate this med.
    @Test func skippedOtherMedDoesNotNegateThisMed() {
        let result = extractor.extract(from: "I skipped my Strattera but took my Concerta.")
        let concerta = result.medications.first { $0.name == "Concerta" }
        let strattera = result.medications.first { $0.name == "Strattera" }
        #expect(concerta?.taken == true)
        #expect(strattera?.taken == false)
    }
}
