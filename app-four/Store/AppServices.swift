import Foundation
import Observation

/// Observable bundle of application-level service singletons.
/// Injected via SwiftUI `@Environment(AppServices.self)` so that
/// ViewModels never reference `AppDependencies` directly.
@Observable
@MainActor
final class AppServices {
    let audioService: AudioRecordingService
    let storageService: AudioFileStorageService
    let transcriptionService: TranscriptionService
    let aiModelService: AIModelService
    let summarizationService: SummarizationService
    let connectivity: Connectivity
    let pendingTranscriptionService: PendingTranscriptionService
    let exportService: ExportService
    /// 037 — the process-level coordinator the check-in view model delegates finalize /
    /// pause / resume to, so a Lock-Screen intent reaches the same recording pipeline.
    let recordingSessionController: RecordingSessionController

    init(
        audioService: AudioRecordingService,
        storageService: AudioFileStorageService,
        transcriptionService: TranscriptionService,
        aiModelService: AIModelService,
        summarizationService: SummarizationService,
        connectivity: Connectivity,
        pendingTranscriptionService: PendingTranscriptionService,
        exportService: ExportService,
        recordingSessionController: RecordingSessionController
    ) {
        self.audioService = audioService
        self.storageService = storageService
        self.transcriptionService = transcriptionService
        self.aiModelService = aiModelService
        self.summarizationService = summarizationService
        self.connectivity = connectivity
        self.pendingTranscriptionService = pendingTranscriptionService
        self.exportService = exportService
        self.recordingSessionController = recordingSessionController
    }
}
