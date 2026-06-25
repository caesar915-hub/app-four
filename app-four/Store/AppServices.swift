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
    let healthService: HealthDataReading
    let connectivity: Connectivity
    let pendingTranscriptionService: PendingTranscriptionService
    let exportService: ExportService

    init(
        audioService: AudioRecordingService,
        storageService: AudioFileStorageService,
        transcriptionService: TranscriptionService,
        aiModelService: AIModelService,
        summarizationService: SummarizationService,
        healthService: HealthDataReading,
        connectivity: Connectivity,
        pendingTranscriptionService: PendingTranscriptionService,
        exportService: ExportService
    ) {
        self.audioService = audioService
        self.storageService = storageService
        self.transcriptionService = transcriptionService
        self.aiModelService = aiModelService
        self.summarizationService = summarizationService
        self.healthService = healthService
        self.connectivity = connectivity
        self.pendingTranscriptionService = pendingTranscriptionService
        self.exportService = exportService
    }
}
