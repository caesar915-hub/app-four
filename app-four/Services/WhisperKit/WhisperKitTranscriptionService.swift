import Foundation
import WhisperKit
import CoreML
import AVFoundation
import UIKit

actor WhisperKitTranscriptionService: TranscriptionService {
    private var whisperKit: WhisperKit?
    private var modelLoadingTask: Task<Void, Error>?
    private var activeTranscriptionTask: Task<Void, Never>?
    private let modelName = "openai_whisper-small"
    private let diagnosticsStore: DiagnosticsStore

    init(diagnosticsStore: DiagnosticsStore = DiagnosticsStore()) {
        self.diagnosticsStore = diagnosticsStore
    }
    
    /// Prompt that biases WhisperKit toward ADHD medication and journal vocabulary.
    /// Leads with a representative check-in sentence so the prompt (which Whisper treats
    /// as the text spoken just before the clip) matches the register of an actual entry,
    /// rather than reading like a drug leaflet and dragging the output off-topic.
    private func getADHDPrompt() -> String {
        "Daily ADHD check-in journal. Today I woke up fine, slept 6 hours, good mood, energy more or less ok but I feel focused. Took the medication two hours ago, Concerta 36mg. Other meds: Vyvanse, Elvanse, Adderall XR, Ritalin, Strattera, Focalin, Dexedrine, Wellbutrin, Modafinil, methylphenidate, lisdexamfetamine, dextroamphetamine, atomoxetine. Hyperfocused, brain fog, executive dysfunction, task paralysis, initiation paralysis, stimming, body doubling, rebound, wearing off, afternoon crash, flat affect, appetite loss, dry mouth."
    }
    
    /// Tokenizes the prompt string using the model's tokenizer.
    private func getPromptTokens(for text: String) -> [Int]? {
        guard let kit = whisperKit else { return nil }
        // WhisperTokenizer encode returns [Int] non-throwing
        return kit.tokenizer?.encode(text: text)
    }

    /// Whisper labels silent / non-speech regions with literal markers like
    /// `[BLANK_AUDIO]`, `[MUSIC]`, `(inaudible)` — almost always the quiet tail of a
    /// clip after the user stops talking. They're artifacts, never spoken content, so
    /// strip them and collapse the whitespace they leave behind. The regex only matches
    /// a bracket/paren containing *just* the marker word, so real parentheticals such
    /// as "[sound of rain]" are left untouched.
    private static let nonSpeechMarker = /[\[(]\s*(?:BLANK[ _]AUDIO|SILENCE|NO[ _]SPEECH|MUSIC|INAUDIBLE|NOISE|SOUND|PAUSE|APPLAUSE|LAUGHS?|LAUGHTER|BEEP|STATIC|CLICKING)\s*[\])]/.ignoresCase()

    private static func cleanTranscript(_ text: String) -> String {
        text
            .replacing(nonSpeechMarker, with: " ")
            .replacing(/\s{2,}/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Preloads the model. Call this on app launch or first use.
    func loadModel() async throws {
        if let loadingTask = modelLoadingTask {
            _ = try await loadingTask.value
            return
        }
        
        guard whisperKit == nil else { return }

        let task = Task {
            AppLogger.log("Loading WhisperKit model...")
            
            let computeOptions = await ModelComputeOptions(
                audioEncoderCompute: ComputeEnvironment.preferredUnits,
                textDecoderCompute: ComputeEnvironment.preferredUnits
            )
            
            let kit = try await WhisperKit(
                model: modelName,
                downloadBase: ModelConstants.whisperDownloadBase,
                computeOptions: computeOptions,
                verbose: true,
                logLevel: .debug
            )
            
            self.whisperKit = kit
            AppLogger.log("WhisperKit model initialized successfully")
        }
        
        modelLoadingTask = task
        
        defer { modelLoadingTask = nil }
        try await task.value
    }
    
    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        let (stream, continuation) = AsyncStream<TranscriptionSegmentDTO>.makeStream()

        // Estimate tokens from audio duration
        let audioDuration = AudioConverter.getDuration(url: url)
        let tokenEstimate = Int(audioDuration * 100) // ~100 tokens/sec for whisper-small

        let startTime = Date()
        await diagnosticsStore.record(SessionSnapshot(
            whisperDurationMs: 0,
            transcriptionTokenEstimate: tokenEstimate,
            screenName: "transcription-start"
        ))

        activeTranscriptionTask?.cancel()
        let task = Task {
            do {
                // Ensure model is loaded
                if whisperKit == nil {
                    // Yield progress so the user knows why they are waiting on the first run.
                    // Plain language, no internal model name or byte wall (FR-022).
                    continuation.yield(TranscriptionSegmentDTO(
                        id: UUID(),
                        text: "Setting up on-device transcription…",
                        startTime: 0,
                        endTime: 0,
                        isFinal: false,
                        confidence: nil
                    ))

                    try await loadModel()
                }

                guard let kit = whisperKit else {
                    throw AudioConverterError.conversionFailed("Transcription engine not initialized")
                }

                // Yield progress
                continuation.yield(TranscriptionSegmentDTO(
                    id: UUID(),
                    text: "Transcribing…",
                    startTime: 0,
                    endTime: 0,
                    isFinal: false,
                    confidence: nil
                ))

                // Run transcription with DecodingOptions. The medical-context prompt is
                // opt-out via Settings → Accessibility; when off we pass no prompt so a
                // non-medical clip can't be dragged toward medication vocabulary.
                let language = "en"
                let promptTokens = UserDefaults.standard.medicalPromptEnabled
                    ? getPromptTokens(for: getADHDPrompt())
                    : nil

                let options = DecodingOptions(
                    language: language,
                    promptTokens: promptTokens
                )

                // Keep the app alive while CoreML/Metal runs so the OS doesn't
                // suspend us mid-transcription (which causes GPU background errors).
                // Ends exactly once — via the OS expiration handler OR the defer, never both.
                // Built on the main actor (the token is MainActor-isolated); the reference is
                // Sendable, so the off-main body can hold it and end it back on the main actor.
                let bgToken = await MainActor.run { () -> BackgroundTaskToken in
                    let token = BackgroundTaskToken()
                    token.begin("WhisperTranscription")
                    return token
                }
                defer {
                    Task { @MainActor in bgToken.end() }
                }

                let results: [TranscriptionResult] = try await kit.transcribe(audioPath: url.path, decodeOptions: options)

                let transcription = await Self.cleanTranscript(results.map { $0.text }.joined(separator: " "))

                guard !transcription.isEmpty else {
                    throw AudioConverterError.conversionFailed("No transcription result")
                }

                // Yield final result
                continuation.yield(TranscriptionSegmentDTO(
                    id: UUID(),
                    text: transcription,
                    startTime: 0,
                    endTime: AudioConverter.getDuration(url: url),
                    isFinal: true,
                    confidence: nil
                ))

                // RAM management: fully release Whisper BEFORE signaling completion,
                // so its Metal/CoreML buffers are freed the moment transcription ends
                // rather than lingering while downstream NL extraction runs.
                await unloadModel()

                continuation.finish()

                let durationMs = Date().timeIntervalSince(startTime) * 1000
                await diagnosticsStore.record(SessionSnapshot(
                    whisperDurationMs: durationMs,
                    transcriptionTokenEstimate: tokenEstimate,
                    screenName: "transcription-end"
                ))

            } catch {
                AppLogger.log("WhisperKit error: \(error)")
                continuation.yield(TranscriptionSegmentDTO(
                    id: UUID(),
                    text: "Transcription error: \(error.localizedDescription)",
                    startTime: 0,
                    endTime: 0,
                    isFinal: true,
                    confidence: nil,
                    isError: true
                ))

                // RAM management: release Whisper before handing off (see success path).
                await unloadModel()

                continuation.finish()

                let durationMs = Date().timeIntervalSince(startTime) * 1000
                await diagnosticsStore.record(SessionSnapshot(
                    whisperDurationMs: durationMs,
                    transcriptionTokenEstimate: tokenEstimate,
                    screenName: "transcription-error"
                ))
            }
        }
        activeTranscriptionTask = task

        return stream
    }
    
    func unloadModel() async {
        whisperKit = nil
        AppLogger.log("WhisperKit model unloaded")
    }
    
    func cancelTranscription() async {
        AppLogger.log("WhisperKit transcription cancellation requested")
        activeTranscriptionTask?.cancel()
        activeTranscriptionTask = nil
    }
}

/// Owns a UIKit background-task identifier and ends it exactly once, whether the OS
/// expiration handler fires or the caller's defer runs first — avoiding the double-end /
/// identifier-reuse footgun of ending the same id twice.
@MainActor
private final class BackgroundTaskToken {
    private var id: UIBackgroundTaskIdentifier = .invalid

    func begin(_ name: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
