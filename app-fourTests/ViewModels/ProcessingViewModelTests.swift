import Testing
import SwiftData
import Foundation
@testable import app_four

/// ProcessingViewModel no longer exposes an in-memory state machine (it was
/// unobserved); the pipeline's outcome lives on the persisted `Recording.summaryStatus`,
/// which is the single source of truth the UI observes. These tests assert on that.
@Suite(.serialized)
@MainActor
struct ProcessingViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recording.self, configurations: config)
    }()

    var viewModel: ProcessingViewModel
    var mockSummarizationService: MockSummarizationService
    var mockAIModelService: MockAIModelService
    var store: RecordingStore

    init() throws {
        TestSupport.useRealData()
        let context = Self.container.mainContext
        try context.delete(model: Recording.self)
        store = RecordingStore(context: context)
        mockSummarizationService = MockSummarizationService()
        mockAIModelService = MockAIModelService()
        viewModel = ProcessingViewModel(
            store: store,
            summarizationService: mockSummarizationService
        )
    }

    @Test func pipelineCompletesAndPersistsSummary() async throws {
        let recording = Recording(audioFileName: "test.m4a", title: "Draft")
        store.addRecording(recording)

        let task = viewModel.processRawTranscription(
            "Took Concerta 36mg at 8am. Feeling focused.",
            duration: 15,
            language: nil,
            audioFileName: "test.m4a"
        )
        await task.value

        let r = try #require(store.recordings.first { $0.audioFileName == "test.m4a" })
        #expect(r.summaryStatus == SummaryStatus.completed.rawValue)
        #expect(r.hasMedication == true)
        #expect(r.medicationInfo == "Concerta 36mg at 8am")
    }

    @Test func pipelineMarksRecordingFailedWhenSummarizationThrows() async throws {
        await mockSummarizationService.setShouldThrow(true)
        let recording = Recording(audioFileName: "fail.m4a", title: "Fail Test")
        store.addRecording(recording)

        let task = viewModel.processRawTranscription(
            "Some text",
            duration: 10,
            language: nil,
            audioFileName: "fail.m4a"
        )
        await task.value

        let r = try #require(store.recordings.first { $0.audioFileName == "fail.m4a" })
        #expect(r.summaryStatus == SummaryStatus.failed.rawValue)
    }

    // MARK: FR-006 — FetchDescriptor lookup (RED→GREEN)

    /// RED test: insert via context directly (bypasses addRecording/loadRecordings so
    /// store.recordings stays stale). The old first(where:) lookup misses it and bails;
    /// the FetchDescriptor implementation finds it and completes the pipeline.
    @Test func pipelineLocatesRecordingViaFetchWhenArrayIsStale() async throws {
        let r = Recording(audioFileName: "stale-026.m4a", title: "Stale")
        store.context.insert(r)
        try store.context.save()

        await viewModel.processRawTranscription(
            "Mood is good today.",
            duration: 10,
            language: nil,
            audioFileName: "stale-026.m4a"
        ).value

        #expect(r.summaryStatus == SummaryStatus.completed.rawValue)
    }

    // MARK: FR-006a — Not-found does not crash or mutate (characterization)

    @Test func pipelineWithNoMatchingFileDoesNotMutateOrCrash() async {
        await viewModel.processRawTranscription(
            "Some text",
            duration: 5,
            language: nil,
            audioFileName: "ghost-026.m4a"
        ).value

        #expect(store.recordings.isEmpty)
    }

    // MARK: US7 — Memory Headroom Alert

    @Test func pipelineHandlesInsufficientMemory() async throws {
        await mockSummarizationService.setShouldThrowInsufficientMemory(true)
        let recording = Recording(audioFileName: "mem.m4a", title: "Memory Test")
        store.addRecording(recording)

        let task = viewModel.processRawTranscription(
            "Some transcript",
            duration: 10,
            language: nil,
            audioFileName: "mem.m4a"
        )
        await task.value

        let r = try #require(store.recordings.first { $0.audioFileName == "mem.m4a" })
        #expect(viewModel.showMemoryError == true)
        #expect(r.summaryStatus == SummaryStatus.completed.rawValue)
        // Fallback result has no signals, just transcript as bullet.
        #expect(r.decodedNoteExtraction == nil || (r.mood == nil && r.energyLevel == nil))
    }

    // MARK: Model lifecycle — insights model missing

    @Test func pipelineHandlesModelNotInstalled() async throws {
        await mockSummarizationService.setShouldThrowModelNotInstalled(true)
        let recording = Recording(audioFileName: "missing.m4a", title: "Missing Model Test")
        store.addRecording(recording)

        let task = viewModel.processRawTranscription(
            "Some transcript",
            duration: 10,
            language: nil,
            audioFileName: "missing.m4a"
        )
        await task.value

        let r = try #require(store.recordings.first { $0.audioFileName == "missing.m4a" })
        #expect(viewModel.showModelMissing == true)
        // Transcript-preserving fallback, same as the memory-pressure path.
        #expect(r.summaryStatus == SummaryStatus.completed.rawValue)
        #expect(r.mood == nil && r.energyLevel == nil)
    }
}