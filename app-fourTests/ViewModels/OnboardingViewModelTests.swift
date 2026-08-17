import Testing
import SwiftData
import Foundation
@testable import app_four

/// US1 (Feature 015) — the welcome's completion/persistence contract, plus the
/// two-screen flow's download branching.
/// `complete(modelContext:)` must: persist `hasCompletedOnboarding == true`,
/// be idempotent (no duplicate `AppSettings` row), and signal completion even
/// when the persist write fails so the cover can always dismiss to the hub (FR-005).
/// `downloadModel(modelContext:)` must complete onboarding on success, and on
/// failure surface the typed cause WITHOUT completing (the user may retry or skip).
@Suite(.serialized)
@MainActor
struct OnboardingViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        // Fresh in-memory container per test: batch deletes on a shared
        // container don't evict already-registered rows from the context,
        // which leaked state between tests.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppSettings.self, configurations: config)
    }

    private func makeViewModel() -> OnboardingViewModel {
        OnboardingViewModel(aiModelService: MockAIModelService())
    }

    @Test func completePersistsHasCompletedOnboarding() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        vm.complete(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let first = try #require(settings.first)
        #expect(first.hasCompletedOnboarding == true)
        #expect(vm.didComplete == true)
    }

    @Test func completeUpdatesExistingRowWithoutDuplicating() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(AppSettings(hasCompletedOnboarding: false))
        try context.save()

        let vm = makeViewModel()
        vm.complete(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.count == 1, "Existing AppSettings row must be updated, not duplicated")
        #expect(settings.first?.hasCompletedOnboarding == true)
    }

    @Test func completeIsIdempotentAcrossRepeatedCalls() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        vm.complete(modelContext: context)
        vm.complete(modelContext: context)
        vm.complete(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.count == 1, "Repeated completion must not create duplicate AppSettings rows")
        #expect(settings.first?.hasCompletedOnboarding == true)
    }

    /// FR-005: a failed persist must NOT strand the user on an undismissable cover.
    /// The completion signal must fire even when the save throws.
    @Test func completeSignalsCompletionEvenWhenSaveFails() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()
        vm.persist = { _ in throw CocoaError(.fileWriteUnknown) }

        vm.complete(modelContext: context)

        #expect(vm.didComplete == true, "User must still reach the hub when the persist write fails")
    }

    /// "Download Now" path: a finished Whisper download resolves the voice step
    /// and advances to the LLM step — onboarding is NOT complete yet.
    @Test func downloadSuccessResolvesWhisperStepWithoutCompleting() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        await vm.downloadModel(modelContext: context)

        #expect(vm.didResolveWhisper == true)
        #expect(vm.didComplete == false)
        #expect(vm.isDownloading == false)
        #expect(vm.downloadError == nil)
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.first?.hasCompletedOnboarding != true)
    }

    /// Failure path: the typed cause is surfaced for retry, and onboarding is
    /// NOT completed — the user stays on the permission screen (retry or skip).
    @Test func downloadFailureSurfacesErrorWithoutCompleting() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let mock = MockAIModelService()
        await mock.setDownloadFailure(.noNetwork)
        let vm = OnboardingViewModel(aiModelService: mock)

        await vm.downloadModel(modelContext: context)

        #expect(vm.didComplete == false)
        #expect(vm.didResolveWhisper == false)
        #expect(vm.isDownloading == false)
        #expect(vm.downloadError == .noNetwork)
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.isEmpty, "Failed download must not persist onboarding completion")
    }

    /// Whisper "Skip for Now": records the explicit decline (so its background
    /// download stays off) and advances to the LLM step — not a completion.
    @Test func whisperSkipRecordsDeclineAndResolvesStep() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        vm.skipModelDownload(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let row = try #require(settings.first)
        #expect(settings.count == 1, "Skip must upsert the single settings row, not duplicate")
        #expect(row.declinedOnboardingModelDownload == true)
        #expect(row.hasCompletedOnboarding == false)
        #expect(vm.didResolveWhisper == true)
        #expect(vm.didComplete == false)
    }

    /// A successful download completes onboarding without recording a decline,
    /// leaving the background download available as a resume path.
    @Test func downloadSuccessDoesNotRecordDecline() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        await vm.downloadModel(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.first?.declinedOnboardingModelDownload != true)
    }

    /// An unclassified engine error must surface as a content-free type tag —
    /// the raw error string never reaches user-facing copy.
    @Test func unclassifiedDownloadErrorSurfacesTypeTagOnly() async throws {
        let container = try makeContainer()
        let mock = MockAIModelService()
        await mock.setShouldThrowOnDownload(true)
        let vm = OnboardingViewModel(aiModelService: mock)

        await vm.downloadModel(modelContext: container.mainContext)

        guard case .other(let tag) = vm.downloadError else {
            Issue.record("Expected .other, got \(String(describing: vm.downloadError))")
            return
        }
        #expect(!tag.contains("Mock download error"), "Raw error message must never reach the UI")
        #expect(vm.didComplete == false)
    }

    // MARK: - LLM step (044)

    /// LLM "Download Now" success completes onboarding and persists it.
    @Test func llmDownloadSuccessCompletesOnboarding() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        await vm.downloadLLMModel(modelContext: context)

        #expect(vm.didComplete == true)
        #expect(vm.isDownloading == false)
        #expect(vm.downloadError == nil)
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let row = try #require(settings.first)
        #expect(row.hasCompletedOnboarding == true)
        #expect(row.declinedOnboardingLLMDownload == false)
    }

    /// LLM "Skip for Now": records the insights decline AND completes.
    @Test func llmSkipRecordsDeclineAndCompletes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        vm.skipLLMDownload(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let row = try #require(settings.first)
        #expect(settings.count == 1)
        #expect(row.hasCompletedOnboarding == true)
        #expect(row.declinedOnboardingLLMDownload == true)
        #expect(vm.didComplete == true)
    }

    /// LLM failure: typed cause surfaced, user stays on the step (retry/skip).
    @Test func llmDownloadFailureSurfacesErrorWithoutCompleting() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let mock = MockAIModelService()
        await mock.setDownloadFailure(.noNetwork)
        let vm = OnboardingViewModel(aiModelService: mock)

        await vm.downloadLLMModel(modelContext: context)

        #expect(vm.didComplete == false)
        #expect(vm.isDownloading == false)
        #expect(vm.downloadError == .noNetwork)
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.first?.hasCompletedOnboarding != true)
    }
}
