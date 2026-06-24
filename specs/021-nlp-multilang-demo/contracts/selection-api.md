# Contract: Pack Selection API

Two stateless helpers in `app-four/Services/NoteExtraction/`. Not DI services (Constitution IV/VIII
— they construct the existing engine, reached through the `NLSummarizationService` seam).

## `LanguageDetector`

```swift
enum LanguageDetector {
    /// Pack key: "en" | "pt-PT" | "es-ES" | "es-MX".
    /// Language from text (NLLanguageRecognizer constrained to en/pt/es + equal hints);
    /// Spanish VARIANT from device locale region (recognizer returns only "es").
    static func packKey(for text: String, locale: Locale = .current) -> String
}
```

Contract:

| Input | `locale.region` | Result |
|---|---|---|
| dominant English text | any | `"en"` |
| dominant Portuguese text | any | `"pt-PT"` |
| dominant Spanish text | `"MX"` | `"es-MX"` |
| dominant Spanish text | not `"MX"` (or nil) | `"es-ES"` |
| undetectable / unsupported | any | `"en"` (best-effort fallback) |

## `LanguagePackLoader`

```swift
enum LanguagePackLoader {
    static func lexicon(_ key: String, overlay: PersonalLexicon? = nil) -> Lexicon
    static func config(_ key: String) -> LanguageConfig                 // key=="en" → .english
    static func extractor(for text: String,
                          locale: Locale = .current,
                          overlay: PersonalLexicon? = nil) -> NLNoteExtractor
}
```

Contract:

- `lexicon(key, overlay)` loads `lexicon.<key>.json` → `LexiconData.toLexicon(personalOverlay: overlay)`;
  on missing/malformed resource returns `Lexicon()` (code defaults) — graceful degradation (FR-008).
  **The overlay is always threaded** (FR-007/SC-005).
- `config(key)` returns `.english` for `"en"`; else decodes `config.<key>.json`; on missing/malformed
  returns `.english` (FR-008).
- `extractor(for:locale:overlay:)` = `NLNoteExtractor(lexicon: lexicon(key, overlay), config: config(key))`
  where `key = LanguageDetector.packKey(for: text, locale: locale)`.

## Acceptance (tests — written RED first, Constitution X)

`LanguageDetectorTests`:
- English/Portuguese/Spanish reference sentences map to `en`/`pt-PT`/`es-ES`.
- Same Spanish sentence: region `MX` → `es-MX`; region `ES` → `es-ES`.

`LanguagePackLoaderTests`:
- `config("pt-PT")`/`config("es-ES")`/`config("es-MX")` each decode to a NON-`.english` config
  (proves the pack is complete — guards D5's silent-fallback trap).
- `config("en") == .english`; `config("zz")` (missing) → `.english`.
- `lexicon(key, overlay:)` applies a sentinel overlay term (overlay threaded, not dropped).
