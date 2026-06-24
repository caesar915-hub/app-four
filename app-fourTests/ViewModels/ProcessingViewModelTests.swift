import Testing
import SwiftData
import Foundation
@testable import app_four

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

    @Test func pipelineCompletesWhenModelReady() async throws {
        let recording = Recording(audioFileName: "test.m4a", title: "Draft")
        store.addRecording(recording)

        let task = viewModel.processRawTranscription(
            "Took Concerta 36mg at 8am. Feeling focused.",
            duration: 15,
            language: nil,
            audioFileName: "test.m4a"
        )
        await task.value

        if case .completed(let r) = viewModel.state {
            #expect(r.hasMedication == true)
            #expect(r.medicationInfo == "Concerta 36mg at 8am")
            #expect(r.summaryStatus == SummaryStatus.completed.rawValue)
        } else {
            Issue.record("Expected .completed state, got \(viewModel.state)")
        }
    }

    @Test func pipelineFailsWhenRecordingNotFound() async throws {
        let task = viewModel.processRawTranscription(
            "Some transcript",
            duration: 10,
            language: nil,
            audioFileName: "ghost.m4a"
        )
        await task.value

        if case .failed(let message) = viewModel.state {
            #expect(message.contains("ghost.m4a"))
        } else {
            Issue.record("Expected .failed state when recording is missing, got \(viewModel.state)")
        }
    }

    @Test func pipelineFailsWhenSummarizationThrows() async throws {
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

        if case .failed = viewModel.state {
            // expected
        } else {
            Issue.record("Expected .failed state when summarization throws, got \(viewModel.state)")
        }
    }

    @Test func cancelProcessingResetsToIdle() async throws {
        let recording = Recording(audioFileName: "cancel.m4a", title: "Cancel Test")
        store.addRecording(recording)

        viewModel.processRawTranscription(
            "Some text",
            duration: 10,
            language: nil,
            audioFileName: "cancel.m4a"
        )
        viewModel.cancelProcessing()

        if case .idle = viewModel.state {} else {
            Issue.record("Expected .idle after cancel, got \(viewModel.state)")
        }
    }

    @Test func initialStateIsIdle() {
        if case .idle = viewModel.state {} else {
            Issue.record("Expected initial state to be .idle, got \(viewModel.state)")
        }
        if case .idle = viewModel.state {} else {
            Issue.record("Expected initial state to be .idle, got \(viewModel.state)")
        }
    }
}
