import Foundation
import Testing
import SwiftData
@testable import app_four

@MainActor
struct CheckInViewModelTests {
    var viewModel: CheckInViewModel
    var mocks: MockAppServices
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
        mocks = MockAppServices()
        viewModel = CheckInViewModel(store: store, services: mocks.services)
    }

    // MARK: Nudges

    @Test func nudgePromptsCount() {
        #expect(CheckInViewModel.nudgePrompts.count == 5)
    }

    @Test func nudgePromptContents() {
        #expect(CheckInViewModel.nudgePrompts[0].question == "How's your mood?")
        #expect(CheckInViewModel.nudgePrompts[1].question == "What's your energy like?")
        #expect(CheckInViewModel.nudgePrompts[2].question == "Able to focus?")
        #expect(CheckInViewModel.nudgePrompts[3].question == "How did you sleep?")
        #expect(CheckInViewModel.nudgePrompts[4].question == "Any strong feelings?")
    }

    @Test func nudgePromptsRotateByInterval() {
        // promptInterval defaults to Relaxed (10 s) on a fresh viewModel.
        let interval = PromptPace.relaxed.interval
        #expect(viewModel.currentPromptIndex == 0)
        viewModel.elapsedTime = interval - 0.1
        #expect(viewModel.currentPromptIndex == 0)
        viewModel.elapsedTime = interval
        #expect(viewModel.currentPromptIndex == 1)
        viewModel.elapsedTime = interval * 4
        #expect(viewModel.currentPromptIndex == 4)
        viewModel.elapsedTime = interval * 5
        #expect(viewModel.currentPromptIndex == 0)  // wraps
    }

    @Test func promptProgressIsNormalized() {
        viewModel.elapsedTime = 5.0
        let progress = viewModel.promptProgress
        #expect(progress >= 0.0 && progress < 1.0)
    }

    // MARK: Text check-in

    @Test func saveTextCheckInWithSelectorsOnlySkipsProcessing() {
        var draft = CheckInDraft()
        draft.mood = .good; draft.sleepQuality = "good"

        viewModel.saveTextCheckIn(draft)

        #expect(viewModel.state == .done)
        let saved = viewModel.lastSavedRecording
        #expect(saved?.mood == "good")
        #expect(saved?.summaryStatus == nil)  // no note -> no NLP pass
    }

    @Test func saveTextCheckInWithNoteRunsFillOnlyProcessing() async throws {
        var draft = CheckInDraft()
        draft.mood = .good
        draft.note = "Took meds late, energy spiked after."

        viewModel.saveTextCheckIn(draft)
        if let task = viewModel.processingViewModel.activeTask { await task.value }

        let saved = try #require(viewModel.lastSavedRecording)
        #expect(saved.mood == "good")            // user value survived the stub's "positive"
        #expect(saved.energyLevel == "high")     // nil column filled from stub
        #expect(saved.summaryStatus == SummaryStatus.completed.rawValue)
    }

    @Test func saveEmptyDraftDoesNothing() {
        viewModel.saveTextCheckIn(CheckInDraft())
        #expect(viewModel.state == .idle)
        #expect(viewModel.lastSavedRecording == nil)
        #expect(store.recordings.isEmpty)
    }

}
