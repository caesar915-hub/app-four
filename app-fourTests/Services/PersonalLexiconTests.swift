import Foundation
import Testing
import SwiftData
@testable import app_four

/// P2.3 — personal lexicon overlay built from the user's own corrections.
@Suite(.serialized)
@MainActor
struct PersonalLexiconTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Recording.self, MedicationEvent.self, RecordingTag.self, AppSettings.self,
            configurations: config
        )
    }()

    var context: ModelContext { Self.container.mainContext }

    init() throws {
        try context.delete(model: Recording.self)
        try context.delete(model: MedicationEvent.self)
        try context.delete(model: RecordingTag.self)
        try context.delete(model: AppSettings.self)
    }

    @Test func buildsOverlayFromUserCorrectedTags() throws {
        // A user-corrected med + emotion, plus an NLP tag that must be ignored.
        context.insert(RecordingTag(name: "Wellbutrin XL", category: .medication, source: .userCorrected))
        context.insert(RecordingTag(name: "Hopeful", category: .emotions, source: .userCorrected))
        context.insert(RecordingTag(name: "Adderall", category: .medication, source: .llm))
        try context.save()

        let overlay = PersonalLexiconBuilder.build(from: context)
        #expect(overlay != nil)
        #expect(overlay?.medications.contains("Wellbutrin XL") == true)
        #expect(overlay?.emotions.contains("hopeful") == true)
        // NLP-sourced tag is not personal vocabulary.
        #expect(overlay?.medications.contains("Adderall") != true)
    }

    @Test func noCorrectionsYieldsNilOverlay() throws {
        context.insert(RecordingTag(name: "Adderall", category: .medication, source: .llm))
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
