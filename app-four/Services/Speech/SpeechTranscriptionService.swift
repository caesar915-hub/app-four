import Foundation
import Speech

/// Service implementation for transcribing audio using Apple's SFSpeechRecognizer.
actor SpeechTranscriptionService: TranscriptionService {
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        let authorized = await requestAuthorization()
        
        return AsyncStream { continuation in
            guard authorized, let recognizer = speechRecognizer, recognizer.isAvailable else {
                AppLogger.log("Speech recognition not authorized or unavailable.")
                let segment = TranscriptionSegmentDTO(
                    id: UUID(),
                    text: "Speech recognition not authorized or unavailable. Enable in Settings.",
                    startTime: 0,
                    endTime: 0,
                    isFinal: true,
                    confidence: nil
                )
                continuation.yield(segment)
                continuation.finish()
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            
            AppLogger.log("Speech recognition started for \(url.lastPathComponent)")
            
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                var textToYield = ""
                var isFinal = false
                
                if let result = result {
                    textToYield = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                    
                    // Fallback: If SFSpeechRecognizer returns an empty string on the final
                    // callback (a known bug with on-device dictation on short files),
                    // we do not want to overwrite good partials with an empty string.
                    if isFinal && textToYield.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        AppLogger.log("Final result was empty, ignoring to preserve partials.")
                        continuation.finish()
                        return
                    }
                }
                
                if let error = error {
                    AppLogger.log("Speech recognition error: \(error.localizedDescription)")
                    // Don't yield an error segment if we already have partial text,
                    // just finish the stream. SFSpeechRecognizer often throws an error 
                    // at the end of a successful recognition if it hits silence.
                    continuation.finish()
                    return
                }
                
                if isFinal {
                    AppLogger.log("Final result: \(textToYield.count) chars")
                } else {
                    AppLogger.log("Partial result: \(textToYield.count) chars")
                }
                
                let segment = TranscriptionSegmentDTO(
                    id: UUID(),
                    text: textToYield,
                    startTime: 0,
                    endTime: 0, // Using 0 for timestamps in Phase 2 for simplicity
                    isFinal: isFinal,
                    confidence: nil
                )
                
                continuation.yield(segment)
                
                if isFinal {
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.cancelTranscription() }
            }
        }
    }
    
    func cancelTranscription() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        AppLogger.log("Speech recognition cancelled")
    }
    
    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
