import Foundation
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

    var services: AppServices {
        AppServices(
            audioService: audio,
            storageService: storage,
            transcriptionService: transcription,
            aiModelService: aiModel,
            summarizationService: summarization,
            connectivity: connectivity
        )
    }
}
