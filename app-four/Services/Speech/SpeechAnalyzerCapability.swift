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

    /// Whether the system-managed model asset for the chosen engine's resolved locale is
    /// already installed (so a recording can transcribe immediately vs. wait for download).
    /// Pure: the caller supplies `AssetInventory`-derived installed-locale lists. Used by
    /// the pending-transcription queue's readiness gate after the engine is wired in (T013).
    static func isModelInstalled(
        for choice: TranscriptionEngineChoice,
        installedSpeechLocales: [Locale],
        installedDictationLocales: [Locale]
    ) -> Bool {
        func contains(_ list: [Locale], _ locale: Locale) -> Bool {
            list.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }
        }
        switch choice {
        case .speechTranscriber(let locale): return contains(installedSpeechLocales, locale)
        case .dictation(let locale): return contains(installedDictationLocales, locale)
        case .unavailable: return false
        }
    }
}
