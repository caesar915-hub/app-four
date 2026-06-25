import Testing
import SwiftData
import Foundation
@testable import app_four

/// ProcessingViewModel no longer exposes an in-memory state machine (it was
/// unobserved); the pipeline's outcome lives on the persisted `Recording.summaryStatus`,
/// which is the single source of truth the UI observes. These tests assert on that.
@MainActor
struct ProcessingViewModelTests {
    var viewModel: ProcessingViewModel
    var mockSummarizationService: MockSummarizationService
    var mockAIModelService: MockAIModelService
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
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
}
