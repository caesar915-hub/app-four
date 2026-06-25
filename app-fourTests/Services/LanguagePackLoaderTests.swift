import Testing
import Foundation
@testable import app_four

/// Pack loading + graceful fallback + overlay threading (spec 021, FR-007/FR-008, research D5).
struct LanguagePackLoaderTests {

    // A non-English config must decode to a NON-.english config. This guards the
    // synthesized-Codable trap: a missing required key would throw and silently
    // fall back to .english (research D5), which this would catch.
    @Test func portugueseConfigDecodesNonEnglish() {
        #expect(LanguagePackLoader.config("pt-PT").presentMarkers != LanguageConfig.english.presentMarkers)
    }
    @Test func spanishESConfigDecodesNonEnglish() {
        #expect(LanguagePackLoader.config("es-ES").presentMarkers != LanguageConfig.english.presentMarkers)
    }
    @Test func englishConfigIsEnglish() {
        #expect(LanguagePackLoader.config("en").presentMarkers == LanguageConfig.english.presentMarkers)
    }
    @Test func missingConfigFallsBackToEnglish() {
        #expect(LanguagePackLoader.config("zz").presentMarkers == LanguageConfig.english.presentMarkers)
    }

    // A non-English lexicon pack decodes to a localized, non-empty vocabulary
    // (not the English fallback).
    @Test func portugueseLexiconDecodesLocalized() {
        let lex = LanguagePackLoader.lexicon("pt-PT")
        #expect(!lex.emotions.isEmpty)
        #expect(lex.emotions != LexiconLoader.loadBundled().emotions)
    }
    @Test func missingLexiconFallsBackToEnglish() {
        #expect(LanguagePackLoader.lexicon("zz").emotions == LexiconLoader.loadBundled().emotions)
    }

    // The personalization overlay (P2.3) is threaded through both the English path
    // and a loaded pack — it must not be dropped by the rewire (FR-007).
    @Test func overlayThreadedForEnglish() {
        let lex = LanguagePackLoader.lexicon("en", overlay: PersonalLexicon(medications: ["zzsentinelmed"]))
        #expect(lex.medications.contains("zzsentinelmed"))
    }
    @Test func overlayThreadedForPack() {
        let lex = LanguagePackLoader.lexicon("pt-PT", overlay: PersonalLexicon(medications: ["zzsentinelmed"]))
        #expect(lex.medications.contains("zzsentinelmed"))
    }
}
