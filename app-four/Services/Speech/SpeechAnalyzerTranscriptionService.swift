import Foundation
import Speech
import AVFoundation

/// On-device transcription via Apple's iOS 26 `SpeechAnalyzer` (spec 045). Primary engine
/// `SpeechTranscriber`, automatic fallback to `DictationTranscriber` for devices/locales
/// where `SpeechTranscriber` is unavailable (the ladder in `SpeechAnalyzerCapability`).
/// Conforms to the existing file-based `TranscriptionService` (deferred/pending path and
/// the drop-in replacement for the WhisperKit engine at the `AppDependencies` seam).
/// Live/streaming capture and the `AppDependencies` swap are later phases (T007–T011).
///
/// Model assets are system-managed via `AssetInventory` — nothing is bundled or
/// app-downloaded (SC-001). Logs are counts/status only, never transcript text (Principle VI).
/// Modelled on the verified on-device probe and the `speech-recognition` skill patterns.
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

    // MARK: - Engine selection (the fallback ladder)

    /// Resolves the `SpeechTranscriber → DictationTranscriber` ladder for the current locale.
    private func resolveChoice() async -> TranscriptionEngineChoice {
        let isAvailable = SpeechTranscriber.isAvailable
        let speechLocale = isAvailable ? await SpeechTranscriber.supportedLocale(equivalentTo: .current) : nil
        let dictationLocale = await DictationTranscriber.supportedLocale(equivalentTo: .current)
        return SpeechAnalyzerCapability.resolve(
            isAvailable: isAvailable,
            resolvedSpeechLocale: speechLocale,
            resolvedDictationLocale: dictationLocale)
    }

    // MARK: - Asset installation

    /// Installs the system-managed model asset for the resolved engine/locale, if needed.
    func loadModel() async throws {
        switch await resolveChoice() {
        case .speechTranscriber(let locale):
            try await Self.installAssets(for: SpeechTranscriber(locale: locale, preset: .transcription))
        case .dictation(let locale):
            try await Self.installAssets(for: DictationTranscriber(locale: locale, preset: .longDictation))
        case .unavailable:
            break
        }
    }

    private static func installAssets(for module: any SpeechModule) async throws {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            AppLogger.log("SpeechAnalyzer: installing model asset…")
            try await request.downloadAndInstall()
        }
    }

    /// The system model asset is installed for the resolved engine/locale, so a
    /// recording can transcribe immediately (vs. queueing until the asset lands).
    func isModelReady() async -> Bool {
        switch await resolveChoice() {
        case .speechTranscriber(let locale):
            return SpeechAnalyzerCapability.isModelInstalled(
                for: .speechTranscriber(locale),
                installedSpeechLocales: await SpeechTranscriber.installedLocales,
                installedDictationLocales: [])
        case .dictation(let locale):
            return SpeechAnalyzerCapability.isModelInstalled(
                for: .dictation(locale),
                installedSpeechLocales: [],
                installedDictationLocales: await DictationTranscriber.installedLocales)
        case .unavailable:
            return false
        }
    }

    // MARK: - File-based transcription

    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        let (stream, continuation) = AsyncStream<TranscriptionSegmentDTO>.makeStream()

        activeTranscriptionTask?.cancel()
        let task = Task {
            do {
                let choice = await resolveChoice()
                let duration = AudioConverter.getDuration(url: url)

                switch choice {
                case .speechTranscriber(let locale):
                    continuation.yield(Self.progressSegment("Transcribing…"))
                    let text = try await Self.runSpeechTranscriber(locale: locale, url: url)
                    continuation.yield(Self.makeFinalSegment(text: text, start: 0, end: duration))
                case .dictation(let locale):
                    continuation.yield(Self.progressSegment("Transcribing…"))
                    let text = try await Self.runDictation(locale: locale, url: url)
                    continuation.yield(Self.makeFinalSegment(text: text, start: 0, end: duration))
                case .unavailable:
                    AppLogger.log("SpeechAnalyzer: no engine available for this device/locale")
                    continuation.yield(Self.errorSegment("on-device transcription is unavailable on this device"))
                }
                continuation.finish()
                AppLogger.log("SpeechAnalyzer: transcription finished")
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

    // MARK: - Per-engine file analysis

    private static func runSpeechTranscriber(locale: Locale, url: URL) async throws -> String {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        try await installAssets(for: transcriber)
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: nil)
        let audioFile = try AVAudioFile(forReading: url)
        async let collected = transcriber.results.reduce(into: AttributedString()) { acc, result in
            if result.isFinal { acc.append(result.text) }
        }
        try await Self.finish(analyzer, file: audioFile)
        return String(try await collected.characters)
    }

    private static func runDictation(locale: Locale, url: URL) async throws -> String {
        let transcriber = DictationTranscriber(locale: locale, preset: .longDictation)
        try await installAssets(for: transcriber)
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: nil)
        let audioFile = try AVAudioFile(forReading: url)
        async let collected = transcriber.results.reduce(into: AttributedString()) { acc, result in
            if result.isFinal { acc.append(result.text) }
        }
        try await Self.finish(analyzer, file: audioFile)
        return String(try await collected.characters)
    }

    /// Analyze the whole file then explicitly finish the session (ending the input does
    /// not finish the analyzer — a documented trap).
    private static func finish(_ analyzer: SpeechAnalyzer, file: AVAudioFile) async throws {
        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        }
    }

    func cancelTranscription() async {
        activeTranscriptionTask?.cancel()
        activeTranscriptionTask = nil
        AppLogger.log("SpeechAnalyzer transcription cancelled")
    }
}
