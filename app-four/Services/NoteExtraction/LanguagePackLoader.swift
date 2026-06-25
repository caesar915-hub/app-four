import Foundation

/// Builds the `NLNoteExtractor` for a check-in by selecting a language pack.
/// `"en"` reuses the bundled English vocabulary (`LexiconLoader.loadBundled`) and the
/// in-code `LanguageConfig.english`; `"pt-PT"`/`"es-ES"`/`"es-MX"` load their bundled
/// `lexicon.<key>.json` + `config.<key>.json`. The personalization overlay (P2.3) is
/// threaded through unchanged. A missing or malformed pack degrades to English (FR-008).
enum LanguagePackLoader {
    static func lexicon(_ key: String, overlay: PersonalLexicon? = nil) -> Lexicon {
        guard key != "en",
              let url = Bundle.main.url(forResource: "lexicon.\(key)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(LexiconData.self, from: data)
        else { return LexiconLoader.loadBundled(overlay: overlay) }
        return decoded.toLexicon(personalOverlay: overlay)
    }

    static func config(_ key: String) -> LanguageConfig {
        guard key != "en",
              let url = Bundle.main.url(forResource: "config.\(key)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(LanguageConfig.self, from: data)
        else { return .english }
        return cfg
    }

    static func extractor(for text: String,
                          locale: Locale = .current,
                          overlay: PersonalLexicon? = nil) -> NLNoteExtractor {
        let key = LanguageDetector.packKey(for: text, locale: locale)
        return NLNoteExtractor(lexicon: lexicon(key, overlay: overlay), config: config(key))
    }
}
