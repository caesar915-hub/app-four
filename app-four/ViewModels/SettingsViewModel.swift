import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class SettingsViewModel {
    @ObservationIgnored private let aiModelService: AIModelService
    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private let storageService: AudioFileStorageService
    @ObservationIgnored private let context: ModelContext

    var whisperModelInstalled: Bool = false
    var isDownloadingWhisper: Bool = false
    var whisperDownloadProgress: Double = 0
    var storageUsedMB: Double = 0.0

    /// The cause of the most recent failed download, surfaced inline so the row
    /// can show plain-language recovery copy. `nil` when there is no active error
    /// (never attempted, in progress, succeeded, or cancelled).
    var downloadError: ModelDownloadFailure?

    /// True only when the active error is a cellular-metered block, so the row can
    /// offer a one-tap "allow on cellular" shortcut alongside "Try again".
    var canAllowCellular: Bool { downloadError == .cellularDisabled }

    @ObservationIgnored private var downloadTask: Task<Void, Never>?

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

    init(store: RecordingStore, services: AppServices) {
        self.store = store
        self.aiModelService = services.aiModelService
        self.storageService = services.storageService
        self.context = AppModelContainer.container.mainContext
        self.downloadOverCellular = appSettings.downloadOverCellular
        self.promptPace = PromptPace(rawValue: appSettings.promptPaceSeconds) ?? .relaxed

        Task { await updateStorage() }
        Task { await checkModels() }
    }

    func syncDownloadOverCellular() {
        appSettings.downloadOverCellular = downloadOverCellular
        try? context.save()
    }

    func syncPromptPace() {
        appSettings.promptPaceSeconds = promptPace.rawValue
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
    }

    func downloadModel(_ type: AIModelType) async {
        downloadError = nil
        setDownloading(type, to: true)
        setProgress(type, to: 0)

        let task = Task {
            defer {
                setDownloading(type, to: false)
                setProgress(type, to: 0)
            }
            do {
                let stream = try await aiModelService.download(type)
                for try await progress in stream {
                    setProgress(type, to: progress)
                }
                await checkModels()
            } catch is CancellationError {
                // User cancelled — not an error; the filesystem-truth recheck in
                // cancelDownload() settles the row.
            } catch let cause as ModelDownloadFailure {
                downloadError = cause
                await checkModels()
            } catch {
                downloadError = .other(String(describing: Swift.type(of: error)))
                await checkModels()
            }
        }
        downloadTask = task
        await task.value
        downloadTask = nil
    }

    /// Cancels an in-flight download and re-reads filesystem truth so the row
    /// returns to "not installed" with no partial/installed model left behind.
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadError = nil
        Task { await checkModels() }
    }

    /// Plain-language, non-alarming copy for each failure cause. Names the
    /// condition and points at the real remedy; never leaks a raw error string.
    func message(for failure: ModelDownloadFailure) -> String {
        switch failure {
        case .noNetwork:
            return "No connection. Reconnect to the internet, then try again."
        case .insufficientSpace:
            return "Not enough space on this device. Free up some room, then try again."
        case .cellularDisabled:
            return "You're on cellular and downloads over cellular are off. Switch to Wi-Fi, or allow cellular below."
        case .other:
            return "The download didn't finish. Try again in a moment."
        }
    }

    private func setDownloading(_ type: AIModelType, to value: Bool) {
        if type == .whisper { isDownloadingWhisper = value }
    }

    private func setProgress(_ type: AIModelType, to value: Double) {
        if type == .whisper { whisperDownloadProgress = value }
    }

    func deleteModel(_ type: AIModelType) async {
        do {
            try await aiModelService.delete(type)
            await checkModels()
        } catch {
            AppLogger.log("Failed to delete \(type.rawValue): \(error)")
        }
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
