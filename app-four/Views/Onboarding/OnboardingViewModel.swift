import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class OnboardingViewModel {

    /// Overall phase of the Whisper download step.
    enum DownloadPhase: Equatable {
        case notStarted
        case downloading
        case completed
        case failed(String)
    }

    var currentPage: Int = 0
    var permissionGranted: Bool = false

    // Whisper-only model-download state.
    var downloadPhase: DownloadPhase = .notStarted
    var whisperProgress: Double = 0
    var whisperComplete: Bool = false

    /// True once Whisper is installed — the onboarding exit is gated on this
    /// (unless a download failed, in which case the view offers an explicit Skip).
    var modelsReady: Bool { whisperComplete }

    @ObservationIgnored private let audioService: AudioRecordingService
    @ObservationIgnored private let aiModelService: AIModelService
    @ObservationIgnored private var downloadTask: Task<Void, Never>?

    init(services: AppServices) {
        self.audioService = services.audioService
        self.aiModelService = services.aiModelService
    }

    func requestMicrophonePermission() async {
        permissionGranted = await audioService.requestPermission()
    }

    /// Downloads Whisper if not already installed.
    /// Already-installed models are skipped, so Retry resumes where it failed.
    @discardableResult
    func downloadModels() -> Task<Void, Never> {
        downloadTask?.cancel()
        downloadPhase = .downloading
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                // Whisper (transcription) — required before recording works.
                guard try await self.ensureDownloaded(.whisper, onProgress: { self.whisperProgress = $0 }) else {
                    self.downloadPhase = .failed("Whisper download didn't complete. Check your connection and retry.")
                    return
                }
                self.whisperComplete = true
                self.downloadPhase = .completed
            } catch is CancellationError {
                // Reset is handled by cancelDownload().
            } catch {
                self.downloadPhase = .failed(error.localizedDescription)
            }
        }
        downloadTask = task
        return task
    }

    /// Returns true once `type` is installed. Skips the network entirely if it already is.
    private func ensureDownloaded(
        _ type: AIModelType,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> Bool {
        if let metadata = await aiModelService.status(for: type),
           metadata.isDownloaded,
           aiModelService.localPath(for: type) != nil {
            onProgress(1.0)
            return true
        }

        let stream = try await aiModelService.download(type)
        for await progress in stream {
            try Task.checkCancellation()
            onProgress(progress)
        }

        guard let metadata = await aiModelService.status(for: type), metadata.isDownloaded else {
            return false
        }
        onProgress(1.0)
        return true
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadPhase = .notStarted
        whisperProgress = 0
        whisperComplete = false
    }

    func completeOnboarding(modelContext: ModelContext) {
        downloadTask?.cancel()
        downloadTask = nil
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.hasCompletedOnboarding = true
        } else {
            let settings = AppSettings(hasCompletedOnboarding: true)
            modelContext.insert(settings)
        }
        try? modelContext.save()
    }
}
