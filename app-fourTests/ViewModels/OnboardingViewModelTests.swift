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

    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: AppSettings.self, configurations: config)
    }()

    private func makeContainer() throws -> ModelContainer {
        try Self.container.mainContext.delete(model: AppSettings.self)
        return Self.container
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

    /// "Download Now" path: a finished download completes onboarding and persists it.
    @Test func downloadSuccessCompletesOnboarding() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        await vm.downloadModel(modelContext: context)

        #expect(vm.didComplete == true)
        #expect(vm.isDownloading == false)
        #expect(vm.downloadError == nil)
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.first?.hasCompletedOnboarding == true)
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
        #expect(vm.isDownloading == false)
        #expect(vm.downloadError == .noNetwork)
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.isEmpty, "Failed download must not persist onboarding completion")
    }

    /// "Skip for Now" path: completes onboarding AND records the explicit
    /// decline so the launch-time background download honors the user's choice.
    @Test func skipRecordsDeclineAndCompletes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        vm.skipModelDownload(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let row = try #require(settings.first)
        #expect(settings.count == 1, "Skip must upsert the single settings row, not duplicate")
        #expect(row.hasCompletedOnboarding == true)
        #expect(row.declinedOnboardingModelDownload == true)
        #expect(vm.didComplete == true)
    }

    /// A successful download completes onboarding without recording a decline,
    /// leaving the background download available as a resume path.
    @Test func downloadSuccessDoesNotRecordDecline() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = makeViewModel()

        await vm.downloadModel(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.first?.declinedOnboardingModelDownload == false)
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
}
