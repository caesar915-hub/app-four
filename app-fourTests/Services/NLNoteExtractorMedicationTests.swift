import Testing
@testable import app_four

/// P0.3 — medication de-duplication and per-med attribute scoping.
struct NLNoteExtractorMedicationTests {

    let extractor = NLNoteExtractor()

    // "Concerta XL" must not also produce a bare "Concerta" event.
    @Test func longestNameWinsNoDuplicate() {
        let result = extractor.extract(from: "I took my Concerta XL 36mg this morning.")
        #expect(result.medications.count == 1)
        #expect(result.medications.first?.name == "Concerta XL")
        #expect(result.medications.first?.dose == "36mg")
    }

    // Two meds in one sentence get their own nearest dose.
    @Test func twoMedsGetDistinctDoses() {
        let result = extractor.extract(from: "I took Concerta 36mg and Strattera 40mg.")
        let concerta = result.medications.first { $0.name == "Concerta" }
        let strattera = result.medications.first { $0.name == "Strattera" }
        #expect(result.medications.count == 2)
        #expect(concerta?.dose == "36mg")
        #expect(strattera?.dose == "40mg")
    }

    // "finished the report" is not a med change for Vyvanse.
    @Test func finishedReportIsNotMedChange() {
        let result = extractor.extract(from: "I took Vyvanse and finished the report.")
        let vyvanse = result.medications.first { $0.name == "Vyvanse" }
        #expect(vyvanse != nil)
        #expect(vyvanse?.change == nil)
    }

    // A real stop verb still registers a med change.
    @Test func stoppedStillRegistersChange() {
        let result = extractor.extract(from: "I stopped taking my Strattera.")
        let strattera = result.medications.first { $0.name == "Strattera" }
        #expect(strattera?.change == .stopped)
    }

    @Test func asrTypoMatchesCanonicalMed() {
        let r = extractor.extract(from: "Took my Conserta 36mg at 8 this morning.")
        #expect(r.medications.contains { $0.name == "Concerta" })
    }
    @Test func vyvanseTypoMatches() {
        let r = extractor.extract(from: "I skipped my Vyvance today.")
        #expect(r.medications.contains { $0.name == "Vyvanse" && $0.taken == false })
    }
    @Test func concertIsNotConcerta() {
        let r = extractor.extract(from: "I took my kids to a concert last night.")
        #expect(r.medications.isEmpty)
    }
    @Test func noMedContextNoFuzzyMatch() {
        let r = extractor.extract(from: "Conserta sounds like a furniture brand.")
        #expect(r.medications.isEmpty)
    }
    @Test func asrTypoWithMilligramsContextMatches() {
        let r = extractor.extract(from: "I bumped my Conserta up to 54 milligrams this week on the doctor's advice.")
        #expect(r.medications.contains { $0.name == "Concerta" })
    }
}
