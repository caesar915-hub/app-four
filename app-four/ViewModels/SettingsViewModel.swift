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

    var recordingCount: Int {
        store.recordings.count
    }

    private var _reduceMotion: Bool = UserDefaults.standard.bool(forKey: "reduceMotion")
    private var _medicalPromptEnabled: Bool = UserDefaults.standard.medicalPromptEnabled

    var reduceMotion: Bool {
        get { _reduceMotion }
        set {
            _reduceMotion = newValue
            UserDefaults.standard.set(newValue, forKey: "reduceMotion")
        }
    }

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
        setDownloading(type, to: true)
        setProgress(type, to: 0)
        defer {
            setDownloading(type, to: false)
            setProgress(type, to: 0)
        }
        do {
            let stream = try await aiModelService.download(type)
            for await progress in stream {
                setProgress(type, to: progress)
            }
            await checkModels()
        } catch {
            AppLogger.log("Failed to download \(type.rawValue): \(error)")
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
