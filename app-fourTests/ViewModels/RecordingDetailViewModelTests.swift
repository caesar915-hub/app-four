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

    @Test func retryTranscriptionSavesOncePerCompletion() async throws {
        recording.status = .failed
        store.resetSaveCallCount()

        viewModel.retryTranscription()

        // Wait for the whole chain (transcribe → completion save → summary save)
        // deterministically: `applySummary` sets summaryStatus synchronously
        // before the summary save on the same actor turn, so observing a settled
        // status guarantees every save has landed. A fixed sleep flakes under
        // full-suite parallel load.
        for _ in 0..<500 {
            let status = recording.summaryStatus
            if status == SummaryStatus.completed.rawValue || status == SummaryStatus.failed.rawValue { break }
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(recording.status == .completed)
        #expect(recording.fullTranscriptText == "This is a mock transcript.")
        // Start (.transcribing) save, completion save, and summary save = 3 total.
        // If a per-segment save remained, this would be 4 (with one segment) or more.
        #expect(store.saveCallCount == 3, "Transcription completion must produce exactly one save, with no per-segment writes")
    }

    @Test func deleteRemovesRecordingFromStore() {
        store.addRecording(recording)
        viewModel.delete()
        #expect(store.recordings.isEmpty)
    }

    // Regenerate previously refreshed the summary/signals but not medication events;
    // the mock summary carries a Concerta dose, which must land on the recording.
    @Test func regenerateRefreshesMedicationEvents() async {
        #expect(recording.medicationEvents.isEmpty)
        // Regenerate summarizes the transcript; a non-empty transcript is required or
        // generateSummary() short-circuits before the summarization path runs.
        recording.fullTranscriptText = "Took Concerta this morning, feeling focused."
        store.context.insert(recording)
        viewModel.startRegenerate()
        await viewModel.summaryTask?.value
        #expect(recording.medicationEvents.contains { $0.name == "Concerta" })
    }
}
