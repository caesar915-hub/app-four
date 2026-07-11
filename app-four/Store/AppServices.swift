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
    let calendarContextService: any CalendarContextService
    let dayContextStore: DayContextStore
    let calendarCoordinator: any CalendarContextCoordinator

    init(
        audioService: AudioRecordingService,
        storageService: AudioFileStorageService,
        transcriptionService: TranscriptionService,
        aiModelService: AIModelService,
        summarizationService: SummarizationService,
        connectivity: Connectivity,
        pendingTranscriptionService: PendingTranscriptionService,
        exportService: ExportService,
        calendarContextService: any CalendarContextService,
        dayContextStore: DayContextStore,
        calendarCoordinator: any CalendarContextCoordinator
    ) {
        self.audioService = audioService
        self.storageService = storageService
        self.transcriptionService = transcriptionService
        self.aiModelService = aiModelService
        self.summarizationService = summarizationService
        self.connectivity = connectivity
        self.pendingTranscriptionService = pendingTranscriptionService
        self.exportService = exportService
        self.calendarContextService = calendarContextService
        self.dayContextStore = dayContextStore
        self.calendarCoordinator = calendarCoordinator
    }
}
