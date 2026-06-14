import Foundation
import Testing
import SwiftData
@testable import app_four

/// P2.3 — personal lexicon overlay built from the user's own corrections.
@MainActor
struct PersonalLexiconTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, RecordingTag.self, AppSettings.self,
            configurations: config
        )
    }

    @Test func buildsOverlayFromUserCorrectedTags() throws {
        // A user-corrected med + feeling, plus an NLP tag that must be ignored.
        context.insert(RecordingTag(name: "Wellbutrin XL", category: .medication, source: .userCorrected))
        context.insert(RecordingTag(name: "Hopeful", category: .feelings, source: .userCorrected))
        context.insert(RecordingTag(name: "Adderall", category: .medication, source: .nlp))
        try context.save()

        let overlay = PersonalLexiconBuilder.build(from: context)
        #expect(overlay != nil)
        #expect(overlay?.medications.contains("Wellbutrin XL") == true)
        #expect(overlay?.feelings.contains("hopeful") == true)
        // NLP-sourced tag is not personal vocabulary.
        #expect(overlay?.medications.contains("Adderall") != true)
    }

    @Test func noCorrectionsYieldsNilOverlay() throws {
        context.insert(RecordingTag(name: "Adderall", category: .medication, source: .nlp))
        try context.save()
        #expect(PersonalLexiconBuilder.build(from: context) == nil)
    }

    @Test func overlayExtendsExtractionVocabulary() {
        // A personal med name not in the base lexicon is recognised after overlay.
        let overlay = PersonalLexicon(medications: ["Zorblax"])
        let lexicon = LexiconLoader.loadBundled(overlay: overlay)
        let extractor = NLNoteExtractor(lexicon: lexicon)
        let result = extractor.extract(from: "I took my Zorblax this morning.")
        #expect(result.medications.contains { $0.name == "Zorblax" })
    }
}
