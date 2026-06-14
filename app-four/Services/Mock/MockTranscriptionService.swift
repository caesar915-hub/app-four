import Foundation

/// Mock implementation of the transcription service for Phase 2.
final class MockTranscriptionService: TranscriptionService {
    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        AsyncStream { continuation in
            let task = Task {
                AppLogger.log("Starting mock transcription for \(url.lastPathComponent)")
                
                // Simulate processing delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                if Task.isCancelled {
                    continuation.finish()
                    return
                }
                
                let segment = TranscriptionSegmentDTO(
                    id: UUID(),
                    text: "[Transcription pending... Whisper model not installed]",
                    startTime: 0,
                    endTime: 0,
                    isFinal: true,
                    confidence: nil
                )
                
                continuation.yield(segment)
                continuation.finish()
                AppLogger.log("Mock transcription finished")
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    func cancelTranscription() async {
        AppLogger.log("Mock transcription cancelled")
    }
}
