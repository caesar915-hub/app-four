import Foundation
import SwiftData

/// Global dependency locator — used ONLY at the composition root (App/ and Store/).
/// Views and ViewModels receive their dependencies via SwiftUI Environment.
@MainActor
enum AppDependencies {
    static let store = RecordingStore(context: AppModelContainer.container.mainContext)
    static let medicationBarViewModel = MedicationBarViewModel(context: AppModelContainer.container.mainContext)
    static let audioService: AudioRecordingService = AudioRecordingServiceImpl()
    static let storageService: AudioFileStorageService = AudioFileStorageServiceImpl(context: AppModelContainer.container.mainContext)
    static let transcriptionService: TranscriptionService = sharedWhisperKitService
    static let aiModelService: AIModelService = AIModelServiceImpl(context: AppModelContainer.container.mainContext)
    static let diagnosticsStore = DiagnosticsStore()
    static let screenTracker = ScreenTracker()
    /// 037 — ActivityKit surface + the process-level recording coordinator. ONE instance
    /// of the coordinator is shared: threaded into `services` (for the view model) AND
    /// registered with `AppDependencyManager` as `any RecordingControlSurface` (for the
    /// Live Activity intents), so both drive the same live session.
    static let liveActivityController: LiveActivityController = LiveActivityControllerImpl()
    static let recordingSessionController: RecordingSessionController = RecordingSessionControllerImpl(liveActivity: liveActivityController)
    /// Single choke point for check-in / My-medication triggers (App Intents + deep link).
    /// Reads live onboarding state so the FR-022 gate reflects the current install.
    static let appIntentRouter = AppIntentRouter(
        isOnboardingComplete: {
            let context = AppModelContainer.container.mainContext
            return (try? context.fetch(FetchDescriptor<AppSettings>()).first)?.hasCompletedOnboarding ?? false
        }
    )
    /// Owns the expedited dose write (030); consumed only by `LogDefaultDoseIntent`,
    /// never by the in-app Log Dose sheet (clarification Option A).
    static let doseLogService: any DoseLogService = DoseLogServiceImpl()
    static let summarizationService: SummarizationService = NLSummarizationService()
    static let connectivity: Connectivity = NetworkConnectivity()
    static let pendingTranscriptionService: PendingTranscriptionService = PendingTranscriptionServiceImpl(
        store: store,
        transcriptionService: transcriptionService,
        summarizationService: summarizationService,
        aiModelService: aiModelService
    )
    static let exportService: ExportService = ExportServiceImpl()

    /// Observable bundle for environment injection into ViewModels.
    static let services = AppServices(
        audioService: audioService,
        storageService: storageService,
        transcriptionService: transcriptionService,
        aiModelService: aiModelService,
        summarizationService: summarizationService,
        connectivity: connectivity,
        pendingTranscriptionService: pendingTranscriptionService,
        exportService: exportService,
        recordingSessionController: recordingSessionController
    )

    private static let sharedWhisperKitService = WhisperKitTranscriptionService(
        diagnosticsStore: diagnosticsStore
    )
}
