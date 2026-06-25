import NaturalLanguage

/// Picks the extraction pack for a check-in. The language is detected from the
/// check-in text (constrained to the supported set with equal hints so short
/// notes still resolve). The Spanish variant (es-ES vs es-MX) comes from the
/// device region because `NLLanguageRecognizer` returns only `es` for both Spain
/// and Mexico Spanish.
enum LanguageDetector {
    /// Pack key: "en" | "pt-PT" | "es-ES" | "es-MX".
    static func packKey(for text: String, locale: Locale = .current) -> String {
        let rec = NLLanguageRecognizer()
        rec.languageConstraints = [.english, .portuguese, .spanish]
        rec.languageHints = [.english: 0.34, .portuguese: 0.33, .spanish: 0.33]
        rec.processString(text)
        switch rec.dominantLanguage {
        case .portuguese: return "pt-PT"
        case .spanish:    return (locale.region?.identifier == "MX") ? "es-MX" : "es-ES"
        default:          return "en"
        }
    }
}
