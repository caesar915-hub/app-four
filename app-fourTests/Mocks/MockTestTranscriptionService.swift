import Foundation
@testable import app_four

actor MockTestTranscriptionService: TranscriptionService {
    var shouldThrowError = false
    var mockTranscriptText = "This is a mock transcript."
    var loadModelHangs = false
    private(set) var loadModelCallCount = 0
    var modelReady = true

    func setLoadModelHangs(_ v: Bool) { loadModelHangs = v }
    func setModelReady(_ v: Bool) { modelReady = v }
    func isModelReady() async -> Bool { modelReady }

    func loadModel() async throws {
        loadModelCallCount += 1
        if loadModelHangs {
            while !Task.isCancelled { await Task.yield() }
        }
    }

    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        
        return AsyncStream { continuation in
            continuation.yield(TranscriptionSegmentDTO(
                id: UUID(),
                text: mockTranscriptText,
                startTime: 0,
                endTime: 10,
                isFinal: true,
                confidence: 0.99
            ))
            continuation.finish()
        }
    }
    
    func cancelTranscription() async {}
}
