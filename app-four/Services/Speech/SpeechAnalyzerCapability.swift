import Foundation

/// The resolved transcription-engine choice for a recording — the outcome of the
/// `SpeechTranscriber → DictationTranscriber` fallback ladder (spec 045, FR-003/FR-004).
enum TranscriptionEngineChoice: Sendable, Equatable {
    case speechTranscriber(Locale)
    case dictation(Locale)
    case unavailable
}

/// Pure, testable resolution of the fallback ladder. The async locale lookups
/// (`supportedLocale(equivalentTo:)`) are performed by the caller against the Speech
/// SDK and passed in, so the branch logic is unit-testable without the SDK — which is
/// unavailable on the Simulator (`SpeechTranscriber.isAvailable == false`). Callers MUST
/// resolve locales via `supportedLocale(equivalentTo:)`, never `supportedLocales.contains(.current)`,
/// so regional variants (e.g. `en-PT` → `en-GB`) are not wrongly treated as unsupported.
struct SpeechAnalyzerCapability: Sendable {
    static func resolve(
        isAvailable: Bool,
        resolvedSpeechLocale: Locale?,
        resolvedDictationLocale: Locale?
    ) -> TranscriptionEngineChoice {
        if isAvailable, let locale = resolvedSpeechLocale {
            return .speechTranscriber(locale)
        }
        if let locale = resolvedDictationLocale {
            return .dictation(locale)
        }
        return .unavailable
    }
}
