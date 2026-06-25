import Foundation
import SwiftData
import CryptoKit
@testable import app_four

/// Bundles the existing service mocks into an AppServices for view-model tests.
@MainActor
struct MockAppServices {
    let audio = MockAudioRecordingService()
    let storage = MockAudioFileStorageService()
    let transcription = MockTestTranscriptionService()
    let aiModel = MockAIModelService()
    let summarization = MockSummarizationService()
    let health = MockHealthDataReading()
    let connectivity = MockConnectivity()
    let pendingTranscription = MockPendingTranscriptionService()
    let export = MockExportService()

    var services: AppServices {
        AppServices(
            audioService: audio,
            storageService: storage,
            transcriptionService: transcription,
            aiModelService: aiModel,
            summarizationService: summarization,
            healthService: health,
            connectivity: connectivity,
            pendingTranscriptionService: pendingTranscription,
            exportService: export
        )
    }
}

/// Deterministic export mock for view-model tests. Seals a tiny fixed archive under a
/// fresh key (no real graph read) so a consumer still round-trips, and can be forced to
/// throw. The crypto round-trip itself is covered by `ExportServiceTests`.
final class MockExportService: ExportService, @unchecked Sendable {
    var errorToThrow: Error?
    private(set) var exportCallCount = 0

    @MainActor
    func export(from context: ModelContext) async throws -> ExportResult {
        exportCallCount += 1
        if let errorToThrow { throw errorToThrow }
        let archive = JournalArchive(
            formatVersion: JournalArchive.currentFormatVersion,
            exportedAt: .now,
            recordings: []
        )
        let key = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(try JSONEncoder().encode(archive), using: key)
        return ExportResult(data: sealed.combined ?? Data(), key: key)
    }
}

/// No-op queue mock for view-model tests. The draining behavior itself is exercised
/// directly against `PendingTranscriptionServiceImpl` in `PendingTranscriptionServiceTests`;
/// here it only needs to satisfy the `AppServices` dependency. Records drive calls so a
/// test can assert the wiring fired.
actor MockPendingTranscriptionService: PendingTranscriptionService {
    private(set) var drainCallCount = 0

    func drainIfModelReady() async {
        drainCallCount += 1
    }
}
