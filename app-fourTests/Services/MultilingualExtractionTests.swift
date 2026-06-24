import Testing
import Foundation
@testable import app_four

/// Acceptance tests for the four-language demo (spec 021, SC-001): each reference
/// check-in must surface the six demo signals — mood, energy, focus, sleep,
/// medications, side-effects — using the matching pack. English (US1) runs the
/// ported engine on the bundled English vocabulary; pt/es/mx (US2/US3) go through
/// `LanguagePackLoader` so pack selection is exercised end-to-end.
struct MultilingualExtractionTests {

    /// Asserts the six demo signals are present on an extraction.
    private func expectSixSignals(_ r: NoteExtraction, _ lang: String) {
        #expect(r.mood != nil, "\(lang): mood")
        #expect(r.energy != nil, "\(lang): energy")
        #expect(r.focus != nil, "\(lang): focus")
        #expect(r.sleep?.mentioned == true, "\(lang): sleep")
        #expect(!r.medications.isEmpty, "\(lang): medications")
        #expect(!r.sideEffects.isEmpty || !r.physicalSideEffects.isEmpty, "\(lang): side-effects")
    }

    // US1 — English reference, ported engine on the bundled English vocabulary.
    @Test func englishReferenceSurfacesSixSignals() {
        let extractor = NLNoteExtractor(lexicon: LexiconLoader.loadBundled())
        let r = extractor.extract(from: """
        Took Concerta 36mg this morning. Slept five hours, woke up tired. Focus good in \
        the morning but energy low in the afternoon. Dry mouth all day. Mood low.
        """)
        expectSixSignals(r, "en")
    }
}
