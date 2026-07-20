import Foundation
import Testing
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct RecordingDetailViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recording.self, configurations: config)
    }()

    var viewModel: RecordingDetailViewModel
    var mocks: MockAppServices
    var store: RecordingStore
    var recording: Recording

    init() throws {
        TestSupport.useRealData()
        let context = Self.container.mainContext
        try context.delete(model: Recording.self)
        store = RecordingStore(context: context)
        mocks = MockAppServices()
        recording = Recording(audioFileName: "test-026.m4a")
        store.context.insert(recording)
        try store.context.save()
        viewModel = RecordingDetailViewModel(recording: recording, store: store, services: mocks.services)
    }

    // MARK: FR-019 Re-entry protection (026 RED\u2192GREEN)

    /// RED: `viewModel.summaryTask` and `viewModel.startRegenerate()` do not exist \u2014
    /// compile failure confirms RED.
    /// GREEN: T013 adds both; second call cancels the first task and stores the new one.
    @Test func startRegenerateOnSecondCallCancelsPreviousTask() async {
        await mocks.summarization.setHangs(true)

        viewModel.startRegenerate()
        let first = viewModel.summaryTask
        viewModel.startRegenerate()

        #expect(first?.isCancelled == true)
        #expect(viewModel.summaryTask != nil)
    }

    // MARK: US3 Delete characterization

    @Test func deleteRemovesRecordingFromStore() {
        store.addRecording(recording)
        viewModel.delete()
        #expect(store.recordings.isEmpty)
    }

    // MARK: Deleted-@Model safety (CODE_AUDIT §5.1 Critical)
    //
    // Repro the audit's crash path: retry/summarize run across long awaits while the
    // user deletes the recording (confirm → dismiss → onDisappear → delete()). Writing
    // into the freed @Model traps SwiftData ("BackingData detached without resolving
    // faults"), so delete() must cancel in-flight work and every mutation must be
    // gated on a context-grounded existence check.

    @Test func deleteCancelsInFlightRetryTask() async {
        recording.status = .failed
        store.save()

        viewModel.retryTranscription()
        let inFlight = viewModel.retryTask
        viewModel.delete()

        #expect(inFlight?.isCancelled == true)
        await inFlight?.value  // unwind before the next test reuses the shared container
    }

    @Test func deleteCancelsInFlightSummaryTask() async {
        await mocks.summarization.setHangs(true)

        viewModel.startRegenerate()
        let inFlight = viewModel.summaryTask
        viewModel.delete()

        #expect(inFlight?.isCancelled == true)
        await inFlight?.value
    }

    /// The guard must short-circuit before the model is read, so the service is never
    /// even reached for a row that no longer exists.
    ///
    /// The non-empty transcript is load-bearing: with the default empty one, the
    /// pre-existing `!fullTranscriptText.isEmpty` guard returns first and the assertion
    /// would hold even with the existence check removed — a test that cannot fail.
    @Test func regenerateSummaryAfterDeleteDoesNoWork() async {
        recording.fullTranscriptText = "a transcript worth summarizing"
        store.save()
        store.deleteRecording(recording)

        await viewModel.regenerateSummary()

        #expect(await mocks.summarization.summarizeCallCount == 0)
    }

    @Test func generateSummaryAfterDeleteDoesNoWork() async {
        recording.fullTranscriptText = "a transcript worth summarizing"
        store.save()
        store.deleteRecording(recording)

        await viewModel.generateSummary()

        #expect(await mocks.summarization.summarizeCallCount == 0)
    }
}
