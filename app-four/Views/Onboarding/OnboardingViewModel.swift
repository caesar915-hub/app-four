import Foundation
import Observation
import SwiftData

/// Drives the first-run flow (welcome → Siri → Whisper download → LLM
/// download): persist that onboarding is done, then signal so the cover can
/// dismiss to the Check-in hub. Idempotent, and — per FR-005 — it signals
/// completion even when the persist write fails, so the user is never stranded
/// on an undismissable cover.
///
/// The two model screens run in sequence and are independently skippable.
/// "Download Now" on the Whisper screen resolves that step and advances to the
/// LLM screen; the LLM screen's download/skip completes onboarding. A
/// failure surfaces the typed cause and keeps the user on the current screen
/// (retry or skip). Each "Skip for Now" records its own decline flag so the
/// launch-time background downloads honor the user's choice per model.
@Observable
@MainActor
final class OnboardingViewModel {

    /// Set once the welcome has done its job; the cover observes this to dismiss.
    /// True even if the persist write failed (FR-005).
    private(set) var didComplete = false

    /// Set when the Whisper step resolves (downloaded or skipped); the
    /// permission screen observes this to push the LLM step.
    private(set) var didResolveWhisper = false

    // Model download state (shared by both steps; each download resets it)
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

    // MARK: - Whisper step

    /// "Skip for Now" on the Whisper screen — records the explicit decline
    /// (`declinedOnboardingModelDownload`) so its background download stays
    /// off, then advances to the LLM step. The decline is persisted
    /// immediately: quitting before the next step must not lose the choice.
    /// Capture keeps working: recordings queue as `.pendingTranscription` until
    /// the model arrives via Settings.
    func skipModelDownload(modelContext: ModelContext) {
        settingsRow(in: modelContext).declinedOnboardingModelDownload = true
        try? persist(modelContext)
        didResolveWhisper = true
    }

    func downloadModel(modelContext: ModelContext) async {
        await runDownload(.whisper) { [self] in
            didResolveWhisper = true
        }
    }

    // MARK: - LLM step

    /// "Skip for Now" on the LLM screen — records the insights-model decline
    /// and completes onboarding. Check-ins still transcribe; they simply skip
    /// signal extraction until the model arrives via Settings.
    func skipLLMDownload(modelContext: ModelContext) {
        settingsRow(in: modelContext).declinedOnboardingLLMDownload = true
        complete(modelContext: modelContext)
    }

    func downloadLLMModel(modelContext: ModelContext) async {
        await runDownload(.llm) { [self] in
            complete(modelContext: modelContext)
        }
    }

    // MARK: - Shared download driver

    private func runDownload(_ type: AIModelType, onSuccess: () -> Void) async {
        guard !isDownloading else { return }
        // Already installed (e.g. a force-quit between steps after the download
        // landed) — skip straight to the resolved/advance state.
        if aiModelService.localPath(for: type) != nil {
            onSuccess()
            return
        }
        isDownloading = true
        downloadError = nil
        downloadProgress = 0.0

        do {
            let stream = try await aiModelService.download(type)
            for try await progress in stream {
                self.downloadProgress = progress
            }
            // Finished successfully
            isDownloading = false
            onSuccess()
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
