import Foundation
import Testing
@testable import app_four

/// 045 / T002 — the SpeechTranscriber → DictationTranscriber fallback ladder.
/// Pure resolution logic: the async locale lookups happen in the service and are
/// passed in, so the ladder is unit-testable without the Speech SDK (which reports
/// `isAvailable == false` on the Simulator).
@Suite struct SpeechAnalyzerCapabilityTests {
    let enUS = Locale(identifier: "en-US")
    let enGB = Locale(identifier: "en-GB")

    @Test func availableWithSpeechLocaleChoosesSpeechTranscriber() {
        let choice = SpeechAnalyzerCapability.resolve(
            isAvailable: true, resolvedSpeechLocale: enUS, resolvedDictationLocale: enGB)
        #expect(choice == .speechTranscriber(enUS))
    }

    @Test func unavailableFallsBackToDictation() {
        let choice = SpeechAnalyzerCapability.resolve(
            isAvailable: false, resolvedSpeechLocale: enUS, resolvedDictationLocale: enGB)
        #expect(choice == .dictation(enGB))
    }

    @Test func availableButNoSupportedSpeechLocaleUsesDictation() {
        let choice = SpeechAnalyzerCapability.resolve(
            isAvailable: true, resolvedSpeechLocale: nil, resolvedDictationLocale: enGB)
        #expect(choice == .dictation(enGB))
    }

    @Test func nothingSupportedIsUnavailable() {
        let choice = SpeechAnalyzerCapability.resolve(
            isAvailable: true, resolvedSpeechLocale: nil, resolvedDictationLocale: nil)
        #expect(choice == .unavailable)
    }

    // T013 — pure model-installed readiness (consumed by the pending queue post-swap).

    @Test func speechModelInstalledWhenResolvedLocaleIsInstalled() {
        #expect(SpeechAnalyzerCapability.isModelInstalled(
            for: .speechTranscriber(enUS), installedSpeechLocales: [enUS], installedDictationLocales: []))
    }

    @Test func speechModelNotInstalledWhenLocaleMissing() {
        #expect(!SpeechAnalyzerCapability.isModelInstalled(
            for: .speechTranscriber(enUS), installedSpeechLocales: [enGB], installedDictationLocales: []))
    }

    @Test func dictationReadinessChecksDictationLocalesOnly() {
        #expect(SpeechAnalyzerCapability.isModelInstalled(
            for: .dictation(enGB), installedSpeechLocales: [], installedDictationLocales: [enGB]))
        #expect(!SpeechAnalyzerCapability.isModelInstalled(
            for: .dictation(enGB), installedSpeechLocales: [enGB], installedDictationLocales: []))
    }

    @Test func unavailableIsNeverInstalled() {
        #expect(!SpeechAnalyzerCapability.isModelInstalled(
            for: .unavailable, installedSpeechLocales: [enUS], installedDictationLocales: [enGB]))
    }
}
