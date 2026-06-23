import Testing
import SwiftData
import Foundation
@testable import app_four

/// US1 (Feature 015) — the welcome's completion/persistence contract.
/// `complete(modelContext:)` must: persist `hasCompletedOnboarding == true`,
/// be idempotent (no duplicate `AppSettings` row), and signal completion even
/// when the persist write fails so the cover can always dismiss to the hub (FR-005).
@MainActor
struct WelcomeViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: AppSettings.self, configurations: config)
    }

    @Test func completePersistsHasCompletedOnboarding() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = WelcomeViewModel()

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

        let vm = WelcomeViewModel()
        vm.complete(modelContext: context)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.count == 1, "Existing AppSettings row must be updated, not duplicated")
        #expect(settings.first?.hasCompletedOnboarding == true)
    }

    @Test func completeIsIdempotentAcrossRepeatedCalls() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let vm = WelcomeViewModel()

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
        let vm = WelcomeViewModel()
        vm.persist = { _ in throw CocoaError(.fileWriteUnknown) }

        vm.complete(modelContext: context)

        #expect(vm.didComplete == true, "User must still reach the hub when the persist write fails")
    }
}
