import Foundation
import Speech
import AVFoundation

/// On-device transcription via Apple's iOS 26 `SpeechAnalyzer` + `SpeechTranscriber`
/// (spec 045). This is the primary engine: it conforms to the existing file-based
/// `TranscriptionService` (used for the deferred/pending path and as the drop-in
/// replacement for the WhisperKit engine at the `AppDependencies` seam). Live/streaming
/// capture and the `DictationTranscriber` fallback module are separate, later phases
/// (tasks T007–T013); this service uses the shared `SpeechAnalyzerCapability` ladder to
/// decide whether `SpeechTranscriber` can serve the current device/locale and, if not,
/// surfaces an honest error segment while the caller preserves the audio.
///
/// Modelled on the verified on-device probe (`Probes/SpeechTranscriberProbe`) and the
/// `speech-recognition` skill's analyzer patterns. The model asset is system-managed via
/// `AssetInventory` — nothing is bundled or app-downloaded (SC-001). Logs are
/// counts/status only, never transcript text (Principle VI).
actor SpeechAnalyzerTranscriptionService: TranscriptionService {
    private var activeTranscriptionTask: Task<Void, Never>?

    // MARK: - Pure, testable mapping helpers

    /// Collapse any run of whitespace to a single space and trim the ends.
    nonisolated static func cleanText(_ s: String) -> String {
        s.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Build the committed transcript segment; an empty result is surfaced as
    /// "(no speech detected)" rather than an error.
    nonisolated static func makeFinalSegment(text: String, start: TimeInterval, end: TimeInterval) -> TranscriptionSegmentDTO {
        let cleaned = cleanText(text)
        return TranscriptionSegmentDTO(
            text: cleaned.isEmpty ? "(no speech detected)" : cleaned,
            startTime: start, endTime: end, isFinal: true, confidence: nil, isError: false)
    }

    /// A non-final progress line for the UI while the model prepares/transcribes.
    nonisolated static func progressSegment(_ message: String) -> TranscriptionSegmentDTO {
        TranscriptionSegmentDTO(text: message, startTime: 0, endTime: 0, isFinal: false, confidence: nil, isError: false)
    }

    /// A terminal error segment; the caller keeps the audio for retry.
    nonisolated static func errorSegment(_ message: String) -> TranscriptionSegmentDTO {
        TranscriptionSegmentDTO(text: "Transcription error: \(message)", startTime: 0, endTime: 0, isFinal: true, confidence: nil, isError: true)
    }

    // MARK: - Asset installation

    /// Installs the system-managed model asset for the resolved locale, if needed.
    func loadModel() async throws {
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else { return }
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            AppLogger.log("SpeechAnalyzer: installing model asset…")
            try await request.downloadAndInstall()
        }
    }

    // MARK: - File-based transcription

    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        let (stream, continuation) = AsyncStream<TranscriptionSegmentDTO>.makeStream()

        activeTranscriptionTask?.cancel()
        let task = Task {
            do {
                let resolvedSpeech = SpeechTranscriber.isAvailable
                    ? await SpeechTranscriber.supportedLocale(equivalentTo: .current)
                    : nil
                let choice = SpeechAnalyzerCapability.resolve(
                    isAvailable: SpeechTranscriber.isAvailable,
                    resolvedSpeechLocale: resolvedSpeech,
                    resolvedDictationLocale: nil)   // DictationTranscriber module lands in T012

                guard case let .speechTranscriber(locale) = choice else {
                    AppLogger.log("SpeechAnalyzer: SpeechTranscriber unavailable for this device/locale")
                    continuation.yield(Self.errorSegment("on-device transcription is unavailable on this device"))
                    continuation.finish()
                    return
                }

                continuation.yield(Self.progressSegment("Transcribing…"))

                let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    continuation.yield(Self.progressSegment("Preparing on-device model…"))
                    try await request.downloadAndInstall()
                }

                let analyzer = SpeechAnalyzer(modules: [transcriber], options: nil)
                let audioFile = try AVAudioFile(forReading: url)

                async let collected = transcriber.results.reduce(into: AttributedString()) { acc, result in
                    if result.isFinal { acc.append(result.text) }
                }

                if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                    try await analyzer.finalizeAndFinish(through: lastSample)
                } else {
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                }

                let text = String(try await collected.characters)
                let duration = AudioConverter.getDuration(url: url)
                continuation.yield(Self.makeFinalSegment(text: text, start: 0, end: duration))
                continuation.finish()
                AppLogger.log("SpeechAnalyzer: transcription finished (\(text.count) chars)")
            } catch {
                AppLogger.log("SpeechAnalyzer error: \(error)")
                continuation.yield(Self.errorSegment(error.localizedDescription))
                continuation.finish()
            }
        }
        activeTranscriptionTask = task

        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.cancelTranscription() }
        }
        return stream
    }

    func cancelTranscription() async {
        activeTranscriptionTask?.cancel()
        activeTranscriptionTask = nil
        AppLogger.log("SpeechAnalyzer transcription cancelled")
    }
}
