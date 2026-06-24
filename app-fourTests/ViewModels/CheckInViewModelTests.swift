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

    // MARK: Record-before-model-ready (US3 / T018)

    /// When the transcription model is NOT ready, finishing a recording must persist it
    /// as `.pendingTranscription` (never `.transcribing`, never `.failed`) and still reach
    /// the `.done`/"Captured." UI state — the audio queues for later draining (FR-011/012).
    @Test func stopWhenModelNotReadyPersistsPendingAndStillReachesDone() async throws {
        await mocks.aiModel.setStubIsDownloaded(false)  // localPath(for: .whisper) == nil

        let task = viewModel.stopRecording()
        await task.value
        if let t = viewModel.transcriptionTask { await t.value }

        let saved = try #require(viewModel.lastSavedRecording)
        #expect(saved.status == .pendingTranscription)
        #expect(saved.status != .transcribing)
        #expect(saved.status != .failed)
        #expect(viewModel.state == .done)
    }

    /// When the model IS ready, the stop path is unchanged: the recording transcribes as
    /// today and ends `.completed` (guards that the pending branch doesn't leak in).
    @Test func stopWhenModelReadyTranscribesAsToday() async throws {
        await mocks.aiModel.setStubIsDownloaded(true)

        let task = viewModel.stopRecording()
        await task.value
        if let t = viewModel.transcriptionTask { await t.value }
        if let p = viewModel.processingViewModel.activeTask { await p.value }

        let saved = try #require(viewModel.lastSavedRecording)
        #expect(saved.status == .completed)
        #expect(viewModel.state == .done)
    }

    // MARK: Just-in-time microphone permission (US4 / T027)

    /// Deleting the onboarding permission step (US1) leaves the just-in-time recovery
    /// contract as the only place permission is taught: a denied mic at the first record
    /// attempt MUST surface `permissionDenied` (which drives the in-context "Open Settings"
    /// recovery, [CheckInView.swift#L39](../../app-four/Views/CheckIn/CheckInView.swift#L39))
    /// and MUST NOT start a recording (FR-019/020).
    @Test func startRecordingSetsPermissionDeniedWhenDenied() async {
        await mocks.audio.setPermissionGranted(false)

        await viewModel.startRecording().value

        #expect(viewModel.permissionDenied == true)
        #expect(viewModel.state == .idle)
        #expect(await mocks.audio.startRecordingCalled == false)
    }

    /// The mirror guard: an authorized mic must never raise the recovery flag and must
    /// proceed to record (FR-021) — so the alert can't false-fire for granted users.
    @Test func startRecordingDoesNotSetPermissionDeniedWhenGranted() async {
        await mocks.audio.setPermissionGranted(true)

        await viewModel.startRecording().value

        #expect(viewModel.permissionDenied == false)
        #expect(viewModel.state == .recording)
        #expect(await mocks.audio.startRecordingCalled == true)
    }

    // MARK: Re-entry guard (FND / T002–T003)

    /// Starting a recording while one is already `.recording` MUST be a no-op:
    /// it must not zero a live `elapsedTime` and must not open a second audio
    /// session (FR-016, SC-005). Without the guard, the second call runs the full
    /// async start path — zeroing the timer and calling the audio service again.
    @Test func startRecordingWhileRecordingIsNoOp() async {
        await mocks.audio.setPermissionGranted(true)

        await viewModel.startRecording().value
        #expect(viewModel.state == .recording)
        let firstStartCount = await mocks.audio.startRecordingCallCount
        #expect(firstStartCount == 1)

        // Simulate a live, mid-recording timer.
        viewModel.elapsedTime = 12.3

        // Re-entrant start (rapid double-tap / auto-start firing while live).
        await viewModel.startRecording().value

        #expect(viewModel.state == .recording)
        #expect(viewModel.elapsedTime == 12.3)
        #expect(await mocks.audio.startRecordingCallCount == 1)
    }

    /// A clean start from `.idle` must clear any stale recovery flags left over
    /// from a prior failed attempt (FR-016, critique §4 P3).
    @Test func startRecordingClearsStaleRecoveryFlags() async {
        await mocks.audio.setPermissionGranted(true)
        viewModel.permissionDenied = true
        viewModel.lowDiskSpace = true

        await viewModel.startRecording().value

        #expect(viewModel.state == .recording)
        #expect(viewModel.permissionDenied == false)
        #expect(viewModel.lowDiskSpace == false)
    }
}
