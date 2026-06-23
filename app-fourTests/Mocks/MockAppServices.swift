import Foundation
import SwiftData
@testable import app_four

/// Bundles the existing service mocks into an AppServices for view-model tests.
@MainActor
struct MockAppServices {
    let audio = MockAudioRecordingService()
    let storage = MockAudioFileStorageService()
    let transcription = MockTestTranscriptionService()
    let aiModel = MockAIModelService()
    let summarization = MockSummarizationService()
    let connectivity = MockConnectivity()
    let pendingTranscription = MockPendingTranscriptionService()

    var services: AppServices {
        AppServices(
            audioService: audio,
            storageService: storage,
            transcriptionService: transcription,
            aiModelService: aiModel,
            summarizationService: summarization,
            connectivity: connectivity,
            pendingTranscriptionService: pendingTranscription
        )
    }
}

/// No-op queue mock for view-model tests. The draining behavior itself is exercised
/// directly against `PendingTranscriptionServiceImpl` in `PendingTranscriptionServiceTests`;
/// here it only needs to satisfy the `AppServices` dependency. Records drive calls so a
/// test can assert the wiring fired.
actor MockPendingTranscriptionService: PendingTranscriptionService {
    private(set) var drainCallCount = 0
    private(set) var enqueuedIDs: [PersistentIdentifier] = []

    func enqueue(_ recordingID: PersistentIdentifier) async {
        enqueuedIDs.append(recordingID)
    }

    func drainIfModelReady() async {
        drainCallCount += 1
    }
}
