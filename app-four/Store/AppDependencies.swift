import Foundation
import SwiftData

/// Global dependency locator — used ONLY at the composition root (App/ and Store/).
/// Views and ViewModels receive their dependencies via SwiftUI Environment.
@MainActor
enum AppDependencies {
    static let store = RecordingStore(context: AppModelContainer.container.mainContext)
    static let medicationBarViewModel = MedicationBarViewModel(context: AppModelContainer.container.mainContext)
    static let signalsStore = SignalsStore(context: AppModelContainer.container.mainContext)
    static let audioService: AudioRecordingService = AudioRecordingServiceImpl()
    static let storageService: AudioFileStorageService = AudioFileStorageServiceImpl(context: AppModelContainer.container.mainContext)
    static let transcriptionService: TranscriptionService = sharedWhisperKitService
    static let aiModelService: AIModelService = AIModelServiceImpl(context: AppModelContainer.container.mainContext)
    static let diagnosticsStore = DiagnosticsStore()
    static let screenTracker = ScreenTracker()
    static let summarizationService: SummarizationService = NLSummarizationService()
    static let healthService: HealthDataReading = HealthKitServiceImpl()
    static let signalSyncCoordinator = SignalSyncCoordinator(reader: healthService, store: signalsStore)

    /// Observable bundle for environment injection into ViewModels.
    static let services = AppServices(
        audioService: audioService,
        storageService: storageService,
        transcriptionService: transcriptionService,
        aiModelService: aiModelService,
        summarizationService: summarizationService,
        healthService: healthService
    )

    private static let sharedWhisperKitService = WhisperKitTranscriptionService(
        diagnosticsStore: diagnosticsStore
    )
}
