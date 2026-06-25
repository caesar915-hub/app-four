import Testing
import Foundation
@testable import app_four

/// Pack selection from the check-in text + device region (spec 021, FR-001/FR-002).
struct LanguageDetectorTests {
    static let en = "Took Concerta 36mg this morning. Slept five hours, woke up tired. Focus good in the morning but energy low in the afternoon. Dry mouth all day. Mood low."
    static let pt = "Tomei Concerta 36mg de manhã. Dormi cinco horas, acordei cansado. Concentração boa de manhã mas energia em baixo à tarde. Boca seca o dia todo. Humor em baixo."
    static let es = "Tomé Concerta 36mg por la mañana. Dormí cinco horas, me desperté cansado. Concentración bien por la mañana pero energía baja por la tarde. Boca seca todo el día. Humor por los suelos."
    static let mx = "Tomé Concerta 36mg en la mañana. Dormí cinco horas, me desperté cansado. Concentración bien en la mañana pero energía baja en la tarde. Boca seca todo el día. Ando agüitado."

    @Test func detectsEnglish() {
        #expect(LanguageDetector.packKey(for: Self.en, locale: Locale(identifier: "en_US")) == "en")
    }
    @Test func detectsPortuguese() {
        #expect(LanguageDetector.packKey(for: Self.pt, locale: Locale(identifier: "pt_PT")) == "pt-PT")
    }
    // US2: Spanish resolves to es-ES (Spain or any non-MX region).
    @Test func detectsSpanishSpain() {
        #expect(LanguageDetector.packKey(for: Self.es, locale: Locale(identifier: "es_ES")) == "es-ES")
    }
    // US3: the device region disambiguates the Spanish variant. The SAME Spanish
    // text yields es-MX under region Mexico and es-ES otherwise (FR-002, SC-004).
    @Test func detectsMexicanSpanishByRegion() {
        #expect(LanguageDetector.packKey(for: Self.es, locale: Locale(identifier: "es_MX")) == "es-MX")
    }
    @Test func detectsMexicanReference() {
        #expect(LanguageDetector.packKey(for: Self.mx, locale: Locale(identifier: "es_MX")) == "es-MX")
    }
}
