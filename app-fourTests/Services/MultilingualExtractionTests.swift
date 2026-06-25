import Testing
import Foundation
@testable import app_four

/// Acceptance tests for the four-language demo (spec 021, SC-001): each reference
/// check-in must surface the six demo signals — mood, energy, focus, sleep,
/// medications, side-effects — through the full `LanguagePackLoader` selection
/// path (detect language + region → load pack → extract).
struct MultilingualExtractionTests {
    static let en = "Took Concerta 36mg this morning. Slept five hours, woke up tired. Focus good in the morning but energy low in the afternoon. Dry mouth all day. Mood low."
    static let pt = "Tomei Concerta 36mg de manhã. Dormi cinco horas, acordei cansado. Concentração boa de manhã mas energia em baixo à tarde. Boca seca o dia todo. Humor em baixo."
    static let es = "Tomé Concerta 36mg por la mañana. Dormí cinco horas, me desperté cansado. Concentración bien por la mañana pero energía baja por la tarde. Boca seca todo el día. Humor por los suelos."
    static let mx = "Tomé Concerta 36mg en la mañana. Dormí cinco horas, me desperté cansado. Concentración bien en la mañana pero energía baja en la tarde. Boca seca todo el día. Ando agüitado."

    /// Asserts the six demo signals are present on an extraction.
    private func expectSixSignals(_ r: NoteExtraction, _ lang: String) {
        #expect(r.mood != nil, "\(lang): mood")
        #expect(r.energy != nil, "\(lang): energy")
        #expect(r.focus != nil, "\(lang): focus")
        #expect(r.sleep?.mentioned == true, "\(lang): sleep")
        #expect(!r.medications.isEmpty, "\(lang): medications")
        #expect(!r.sideEffects.isEmpty || !r.physicalSideEffects.isEmpty, "\(lang): side-effects")
    }

    private func extract(_ text: String, _ region: String) -> NoteExtraction {
        LanguagePackLoader.extractor(for: text, locale: Locale(identifier: region)).extract(from: text)
    }

    @Test func englishReferenceSurfacesSixSignals() {
        expectSixSignals(extract(Self.en, "en_US"), "en")
    }
    @Test func portugueseReferenceSurfacesSixSignals() {
        expectSixSignals(extract(Self.pt, "pt_PT"), "pt-PT")
    }
    @Test func spanishSpainReferenceSurfacesSixSignals() {
        expectSixSignals(extract(Self.es, "es_ES"), "es-ES")
    }
    @Test func mexicanReferenceSurfacesSixSignals() {
        expectSixSignals(extract(Self.mx, "es_MX"), "es-MX")
    }
}
