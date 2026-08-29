import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class SettingsViewModel {
    @ObservationIgnored private let aiModelService: AIModelService
    @ObservationIgnored private let connectivity: any Connectivity
    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private let storageService: AudioFileStorageService
    @ObservationIgnored private let exportService: ExportService
    @ObservationIgnored private let context: ModelContext

    var whisperModelInstalled: Bool = false
    var isDownloadingWhisper: Bool = false
    var whisperDownloadProgress: Double = 0
    var llmModelInstalled: Bool = false
    var isDownloadingLLM: Bool = false
    var llmDownloadProgress: Double = 0
    var storageUsedMB: Double = 0.0

    /// The cause of each model's most recent failed download, surfaced inline so
    /// its row can show plain-language recovery copy. No entry when there is no
    /// active error (never attempted, in progress, succeeded, or cancelled).
    private(set) var downloadErrors: [AIModelType: ModelDownloadFailure] = [:]

    /// True only when the model's active error is a cellular-metered block, so its
    /// row can offer a one-tap "allow on cellular" shortcut alongside "Try again".
    func canAllowCellular(for type: AIModelType) -> Bool { downloadErrors[type] == .cellularDisabled }

    @ObservationIgnored private var downloadTasks: [AIModelType: Task<Void, Never>] = [:]

    /// Re-reads filesystem truth when any download path (Settings toggle,
    /// app-launch background fetch) completes or deletes a model — otherwise a
    /// background completion leaves the toggle showing OFF while open.
    @ObservationIgnored private var modelAvailabilityObserver: (any NSObjectProtocol)?

    var recordingCount: Int {
        store.recordings.count
    }

    private var _medicalPromptEnabled: Bool = UserDefaults.standard.medicalPromptEnabled

    var medicalPromptEnabled: Bool {
        get { _medicalPromptEnabled }
        set {
            _medicalPromptEnabled = newValue
            UserDefaults.standard.medicalPromptEnabled = newValue
        }
    }

    var downloadOverCellular: Bool = false
    var promptPace: PromptPace = .relaxed

    // MARK: - 030 App Intents settings (mirror AppSettings; sync writes back)
    var defaultMedicationName: String?
    var defaultMedicationDose: String?
    var nameMedicationInConfirmations: Bool = false
    var doseGuardMode: DoseGuardMode = .off
    var doseGuardWindowHours: Int = 2

    private var appSettings: AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let new = AppSettings()
        context.insert(new)
        try? context.save()
        return new
    }

    init(store: RecordingStore, services: AppServices, context: ModelContext? = nil) {
        self.store = store
        self.aiModelService = services.aiModelService
        self.connectivity = services.connectivity
        self.storageService = services.storageService
        self.exportService = services.exportService
        self.context = context ?? AppModelContainer.container.mainContext
        let settings = appSettings
        self.downloadOverCellular = settings.downloadOverCellular
        self.promptPace = PromptPace(rawValue: settings.promptPaceSeconds) ?? .relaxed
        self.defaultMedicationName = settings.defaultMedicationName
        self.defaultMedicationDose = settings.defaultMedicationDose
        self.nameMedicationInConfirmations = settings.nameMedicationInConfirmations
        self.doseGuardMode = DoseGuardMode(raw: settings.doseGuardModeRaw)
        self.doseGuardWindowHours = settings.doseGuardWindowHours

        modelAvailabilityObserver = NotificationCenter.default.addObserver(
            forName: .aiModelAvailabilityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.checkModels() }
        }

        Task { await updateStorage() }
        Task { await checkModels() }
    }

    deinit {
        if let modelAvailabilityObserver {
            NotificationCenter.default.removeObserver(modelAvailabilityObserver)
        }
    }

    func syncDownloadOverCellular() {
        appSettings.downloadOverCellular = downloadOverCellular
        try? context.save()
    }

    func syncPromptPace() {
        appSettings.promptPaceSeconds = promptPace.rawValue
        try? context.save()
    }

    /// Any medication change clears the dose (approved T011 mockup): the default the
    /// hands-free action logs must be re-confirmed with an explicit dose tap — never
    /// auto-committed. Until then the action answers not-configured (FR-007).
    func medicationDidChange() {
        defaultMedicationDose = nil
        syncMyMedication()
    }

    func syncMyMedication() {
        let settings = appSettings
        settings.defaultMedicationName = defaultMedicationName
        settings.defaultMedicationDose = defaultMedicationDose
        try? context.save()
    }

    func syncNameInConfirmations() {
        appSettings.nameMedicationInConfirmations = nameMedicationInConfirmations
        try? context.save()
    }

    func syncDoseGuard() {
        let settings = appSettings
        settings.doseGuardModeRaw = doseGuardMode.rawValue
        settings.doseGuardWindowHours = doseGuardWindowHours
        try? context.save()
    }

    func updateStorage() async {
        let bytes = await storageService.calculateTotalStorageUsed()
        self.storageUsedMB = Double(bytes) / 1_048_576.0
    }

    func checkModels() async {
        // Filesystem is the source of truth — a SwiftData flag can lie if files
        // were evicted, partially downloaded, or restored without metadata.
        self.whisperModelInstalled = aiModelService.localPath(for: .whisper) != nil
        self.llmModelInstalled = aiModelService.localPath(for: .llm) != nil
    }

    func downloadModel(_ type: AIModelType) async {
        downloadErrors[type] = nil
        setDownloading(type, to: true)
        setProgress(type, to: 0)

        let task = Task {
            defer {
                setDownloading(type, to: false)
                setProgress(type, to: 0)
            }
            // Blips and stalls retry via the shared driver (waiting for a
            // permitted network, resuming at file granularity); only the FINAL
            // failure lands in `downloadErrors[type]` for the row's recovery copy.
            let driver = ResilientModelDownload(
                download: { [aiModelService] in try await aiModelService.download(type) },
                connectivity: connectivity,
                allowsCellular: { [weak self] in
                    self?.downloadOverCellular ?? false
                }
            )
            do {
                try await driver.run { [weak self] progress in
                    self?.setProgress(type, to: progress)
                }
                await checkModels()
            } catch is CancellationError {
                // User cancelled — not an error; the filesystem-truth recheck in
                // cancelDownload() settles the row.
            } catch let cause as ModelDownloadFailure {
                downloadErrors[type] = cause
                await checkModels()
            } catch {
                downloadErrors[type] = .other(String(describing: Swift.type(of: error)))
                await checkModels()
            }
        }
        downloadTasks[type] = task
        await task.value
        downloadTasks[type] = nil
    }

    /// Cancels an in-flight download and re-reads filesystem truth so the row
    /// returns to "not installed" with no partial/installed model left behind.
    func cancelDownload(_ type: AIModelType) {
        downloadTasks[type]?.cancel()
        downloadTasks[type] = nil
        downloadErrors[type] = nil
        Task { await checkModels() }
    }

    /// Plain-language, non-alarming copy for each failure cause — shared with
    /// every download surface via `ModelDownloadFailure.userMessage`.
    func message(for failure: ModelDownloadFailure) -> String {
        failure.userMessage
    }

    private func setDownloading(_ type: AIModelType, to value: Bool) {
        switch type {
        case .whisper: isDownloadingWhisper = value
        case .llm: isDownloadingLLM = value
        }
    }

    private func setProgress(_ type: AIModelType, to value: Double) {
        switch type {
        case .whisper: whisperDownloadProgress = value
        case .llm: llmDownloadProgress = value
        }
    }

    func deleteModel(_ type: AIModelType) async {
        do {
            try await aiModelService.delete(type)
            await checkModels()
        } catch {
            AppLogger.log("Failed to delete \(type.rawValue): \(error)")
        }
    }

    /// Snapshots the journal into a sealed archive and returns it with the one-time
    /// key that opens it. The key is NEVER stored here (no property, no persistence) —
    /// it lives only in the returned value so the view can surface it once. Serialize +
    /// seal run off the main actor inside the service.
    func exportJournal() async throws -> ExportResult {
        try await exportService.export(from: context)
    }

    /// Permanently deletes all user content: every recording (with its audio file)
    /// and all medication events. Cascade rules on `Recording` remove its segments,
    /// tags, and recording-linked medication events; standalone medication events
    /// are deleted separately. Downloaded models and preferences are intentionally
    /// kept (they have their own controls).
    func clearAllData() {
        // Use the storage service, not `store.deleteRecording`, so the audio FILE
        // is removed too (the store only drops the SwiftData row).
        for recording in Array(store.recordings) {
            try? storageService.deleteRecording(recording)
        }
        let standaloneEvents = (try? context.fetch(FetchDescriptor<MedicationEvent>())) ?? []
        for event in standaloneEvents {
            context.delete(event)
        }
        try? context.save()
        store.loadRecordings()
        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
        Task { await updateStorage() }
    }
}
