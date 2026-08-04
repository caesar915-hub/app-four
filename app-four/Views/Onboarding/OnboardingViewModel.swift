import Foundation
import Observation
import SwiftData

/// Drives the two-screen onboarding flow (welcome → model-download permission):
/// persist that onboarding is done, then signal so the cover can dismiss to the
/// Check-in hub. Idempotent, and — per FR-005 — it signals completion even when
/// the persist write fails, so the user is never stranded on an undismissable
/// cover.
///
/// "Download Now" downloads the Whisper model and completes on success; a
/// failure surfaces the typed cause and keeps the user on the permission screen
/// (retry or skip). "Skip for Now" completes without the model and records the
/// decline so the launch-time background download honors the user's choice.
@Observable
@MainActor
final class OnboardingViewModel {

    /// Set once the welcome has done its job; the cover observes this to dismiss.
    /// True even if the persist write failed (FR-005).
    private(set) var didComplete = false

    // Model download state
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0.0
    private(set) var downloadError: ModelDownloadFailure?

    @ObservationIgnored private let aiModelService: AIModelService

    /// Persist seam — defaults to a real `ModelContext.save()`, overridden in tests
    /// to exercise the save-failure path deterministically.
    @ObservationIgnored var persist: (ModelContext) throws -> Void = { try $0.save() }

    /// Dependencies arrive from the composition root (`AppServices` via the
    /// presenting view) — never from `AppDependencies` directly.
    init(aiModelService: AIModelService) {
        self.aiModelService = aiModelService
    }

    func complete(modelContext: ModelContext) {
        settingsRow(in: modelContext).hasCompletedOnboarding = true
        try? persist(modelContext)
        didComplete = true
    }

    /// "Skip for Now" — completes onboarding without the model and remembers the
    /// explicit decline (`declinedOnboardingModelDownload`) so the background
    /// download stays off. Capture keeps working: recordings queue as
    /// `.pendingTranscription` until the model arrives via Settings.
    func skipModelDownload(modelContext: ModelContext) {
        settingsRow(in: modelContext).declinedOnboardingModelDownload = true
        complete(modelContext: modelContext)
    }

    func downloadModel(modelContext: ModelContext) async {
        guard !isDownloading else { return }
        isDownloading = true
        downloadError = nil
        downloadProgress = 0.0

        do {
            let stream = try await aiModelService.download(.whisper)
            for try await progress in stream {
                self.downloadProgress = progress
            }
            // Finished successfully
            isDownloading = false
            complete(modelContext: modelContext)
        } catch let error as ModelDownloadFailure {
            isDownloading = false
            downloadError = error
        } catch {
            isDownloading = false
            // Type tag only — a raw error string must never reach the UI.
            downloadError = .other(String(describing: Swift.type(of: error)))
        }
    }

    /// Fetch-or-insert the single settings row; callers mutate and `persist` saves.
    private func settingsRow(in modelContext: ModelContext) -> AppSettings {
        if let existing = try? modelContext.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let row = AppSettings()
        modelContext.insert(row)
        return row
    }
}
