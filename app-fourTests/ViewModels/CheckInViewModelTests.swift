import Foundation
import Testing
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct CheckInViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recording.self, configurations: config)
    }()

    var viewModel: CheckInViewModel
    var mocks: MockAppServices
    var store: RecordingStore
    var container: ModelContainer { Self.container }

    init() throws {
        TestSupport.useRealData()
        let context = Self.container.mainContext
        try context.delete(model: Recording.self)
        store = RecordingStore(context: context)
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
        #expect(CheckInViewModel.nudgePrompts[4].question == "Any strong emotions?")
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

    // MARK: Never lose a capture (US2 / T011–T020)

    /// Drives a recording to `.recording` so the stop path has a live capture to fail on.
    private func enterRecording() async {
        await mocks.audio.setPermissionGranted(true)
        await viewModel.startRecording().value
        #expect(viewModel.state == .recording)
    }

    /// T011 — a save failure (the file-write/store step throws) MUST NOT silently
    /// reset to `.idle`. The audio is retained in the retry buffer and `saveFailed`
    /// is raised so the inline "try again" surface can show (FR-005). Without the fix,
    /// `stopRecording()`'s catch sets `state = .idle` and the capture vanishes.
    @Test func saveFailureRetainsBufferAndSetsSaveFailed() async {
        await enterRecording()
        mocks.storage.shouldThrowError = true

        await viewModel.stopRecording().value

        #expect(viewModel.saveFailed == true)
        #expect(viewModel.state != .idle)
        #expect(viewModel.pendingSave != nil)
    }

    /// T012 — retrying from the buffer after the condition clears saves the recording,
    /// clears the buffer + flag, and lands on `.done` (FR-007).
    @Test func retryAfterFailureSavesAndReachesDone() async throws {
        await enterRecording()
        mocks.storage.shouldThrowError = true
        await viewModel.stopRecording().value
        #expect(viewModel.saveFailed == true)

        mocks.storage.shouldThrowError = false
        await viewModel.retrySave().value
        // The successful retry starts background transcription against the saved
        // @Model; drain it (and the follow-on processing) before this in-memory
        // container tears down, or a later test crashes touching a reset @Model.
        if let t = viewModel.transcriptionTask { await t.value }
        if let p = viewModel.processingViewModel.activeTask { await p.value }

        #expect(viewModel.saveFailed == false)
        #expect(viewModel.pendingSave == nil)
        #expect(viewModel.state == .done)
        #expect(try #require(viewModel.lastSavedRecording).id == store.recordings.first?.id)
        #expect(store.recordings.count == 1)
    }

    /// T013 — a retry that fails again keeps the failure surface up and the buffer
    /// intact: no discard, no idle reset (FR-005, US2 AC3).
    @Test func retryThatFailsAgainKeepsBuffer() async {
        await enterRecording()
        mocks.storage.shouldThrowError = true
        await viewModel.stopRecording().value

        // Still failing on retry.
        await viewModel.retrySave().value

        #expect(viewModel.saveFailed == true)
        #expect(viewModel.pendingSave != nil)
        #expect(viewModel.state != .idle)
        #expect(viewModel.state != .done)
    }

    /// T014 — explicit discard clears the buffer + flag and returns to the idle hub
    /// (FR-008).
    @Test func discardFailedCaptureClearsAndResetsToIdle() async {
        await enterRecording()
        mocks.storage.shouldThrowError = true
        await viewModel.stopRecording().value
        #expect(viewModel.pendingSave != nil)

        viewModel.discardFailedCapture()

        #expect(viewModel.pendingSave == nil)
        #expect(viewModel.saveFailed == false)
        #expect(viewModel.state == .idle)
    }

    /// T015 — a text-save failure surfaces a non-alarming `textSaveFailed` rather than
    /// silently dropping the draft (FR-009). Forced via a store subclass whose persist
    /// throws (the SwiftData layer can't be made to fail on demand).
    @Test func textSaveFailureSetsTextSaveFailed() {
        let brokenStore = ThrowingCheckInStore(context: container.mainContext)
        let vm = CheckInViewModel(store: brokenStore, services: mocks.services)

        var draft = CheckInDraft()
        draft.mood = .good
        draft.note = "energy crashed mid-afternoon"
        vm.saveTextCheckIn(draft)

        #expect(vm.textSaveFailed == true)
        #expect(vm.state != .done)
    }

    // MARK: VoiceOver gate (US3 / T021–T023)

    /// T021 — the VM derives an `isSpeaking` signal from the audio level: a value at or
    /// above the named active-voice threshold means the mic is picking up the user's
    /// voice; a value below means quiet (FR-010, R4). This is the announcement gate the
    /// previously-discarded `audioLevelStream` finally feeds — not a glow.
    @Test func isSpeakingTracksAudioLevelThreshold() {
        #expect(viewModel.isSpeaking == false)  // no level yet ⇒ not speaking

        viewModel.ingestAudioLevel(CheckInViewModel.activeVoiceThreshold + 0.1)
        #expect(viewModel.isSpeaking == true)

        viewModel.ingestAudioLevel(CheckInViewModel.activeVoiceThreshold - 0.05)
        #expect(viewModel.isSpeaking == false)

        // Exactly at the threshold counts as active voice (>=).
        viewModel.ingestAudioLevel(CheckInViewModel.activeVoiceThreshold)
        #expect(viewModel.isSpeaking == true)
    }

    /// T021 — the silence floor the real stream emits (~0.01) must read as quiet, so a
    /// recording with no speech never suppresses announcements forever.
    @Test func isSpeakingFalseAtSilenceFloor() {
        viewModel.ingestAudioLevel(0.01)
        #expect(viewModel.isSpeaking == false)
        #expect(CheckInViewModel.activeVoiceThreshold > 0.01)
    }

    /// T022 — a requested prompt-advance announcement is DEFERRED while the user is
    /// actively speaking (not eligible to post), and becomes eligible the moment the
    /// level drops back to quiet (FR-010, R4). The view reads `promptAnnouncementIsEligible`
    /// to decide whether to post now or hold.
    @Test func promptAnnouncementDeferredWhileSpeakingEligibleOnQuiet() {
        // Speaking, then a prompt advances mid-sentence.
        viewModel.ingestAudioLevel(CheckInViewModel.activeVoiceThreshold + 0.2)
        viewModel.requestPromptAnnouncement()

        #expect(viewModel.promptAnnouncementIsPending == true)
        #expect(viewModel.promptAnnouncementIsEligible == false)  // held — don't talk over them

        // The user pauses.
        viewModel.ingestAudioLevel(0.02)
        #expect(viewModel.promptAnnouncementIsEligible == true)   // now safe to post

        // The view posts and consumes it; nothing left pending.
        viewModel.consumePromptAnnouncement()
        #expect(viewModel.promptAnnouncementIsPending == false)
        #expect(viewModel.promptAnnouncementIsEligible == false)
    }

    /// T022 — a prompt advance during quiet is immediately eligible (no artificial delay
    /// when the user isn't speaking).
    @Test func promptAnnouncementEligibleImmediatelyWhenQuiet() {
        viewModel.ingestAudioLevel(0.02)
        viewModel.requestPromptAnnouncement()
        #expect(viewModel.promptAnnouncementIsEligible == true)
    }

    /// T022 — only the latest advance matters: if the prompt advances again while an
    /// earlier one is still deferred, there is still exactly one pending announcement to
    /// post on the next quiet (the user hears the current prompt, not a backlog).
    @Test func promptAnnouncementCoalescesWhileDeferred() {
        viewModel.ingestAudioLevel(CheckInViewModel.activeVoiceThreshold + 0.2)
        viewModel.requestPromptAnnouncement()
        viewModel.requestPromptAnnouncement()
        #expect(viewModel.promptAnnouncementIsPending == true)

        viewModel.ingestAudioLevel(0.02)
        #expect(viewModel.promptAnnouncementIsEligible == true)
        viewModel.consumePromptAnnouncement()
        #expect(viewModel.promptAnnouncementIsPending == false)
    }

    // MARK: 8-minute soft landing (US4 / T028–T031)

    /// T028 — `isApproachingCap` is `false` until `elapsedTime` crosses
    /// `maxDuration − approachWindow`, then `true`; the cue is one-shot, so once
    /// `hasShownCapApproach` flips it never re-arms even as elapsed advances further
    /// (FR-014, R5). The view keys a single faint "wrapping up soon" line off this.
    @Test func isApproachingCapTrueOnlyInFinalWindow() {
        #expect(viewModel.approachWindow > 0)
        let cap = viewModel.maxDuration
        let window = viewModel.approachWindow

        // Well before the window: not approaching.
        viewModel.elapsedTime = cap - window - 1
        #expect(viewModel.isApproachingCap == false)
        #expect(viewModel.hasShownCapApproach == false)

        // Just past the window boundary: approaching.
        viewModel.elapsedTime = cap - window + 0.1
        #expect(viewModel.isApproachingCap == true)
    }

    /// T028 — the one-shot guard latches: once shown, marking it consumes the cue so
    /// advancing deeper into the window (or to the cap) does NOT re-arm it.
    @Test func capApproachCueIsOneShot() {
        let cap = viewModel.maxDuration
        let window = viewModel.approachWindow

        viewModel.elapsedTime = cap - window + 0.1
        #expect(viewModel.isApproachingCap == true)
        #expect(viewModel.hasShownCapApproach == false)

        // The view shows the cue once and marks it consumed.
        viewModel.markCapApproachShown()
        #expect(viewModel.hasShownCapApproach == true)

        // Advancing further never re-arms the one-shot.
        viewModel.elapsedTime = cap - 1
        #expect(viewModel.hasShownCapApproach == true)
    }


    // MARK: FR-015 Preload-task handle (026 RED→GREEN)

    /// RED: `viewModel.modelPreloadTask` does not exist yet — compile failure confirms RED.
    /// GREEN: property added in T009; cancelRecording() cancels it before the async cleanup body.
    @Test func preloadTaskIsCancelledOnDiscard() async {
        await mocks.transcription.setLoadModelHangs(true)

        let start = viewModel.startRecording()
        await start.value

        await viewModel.cancelRecording().value

        #expect(viewModel.modelPreloadTask?.isCancelled == true)
    }

    // MARK: FR-017 Phantom-tick guard (026 RED→GREEN)

    /// RED: `viewModel.advanceTick()` does not exist yet — compile failure confirms RED.
    /// GREEN: extracted in T011 with `guard !Task.isCancelled`; task is cancelled before
    /// the body starts on @MainActor, so elapsedTime is never incremented.
    @Test func advanceTickIsNoOpAfterCancellation() async {
        let t = Task { @MainActor in
            self.viewModel.advanceTick()
        }
        t.cancel()
        await t.value
        #expect(viewModel.elapsedTime == 0)
    }

    /// T029 — reaching the cap takes the SAME stop/save path as a manual stop: it goes
    /// `.processing → .done` on success via the mock, i.e. the capped save lands on the
    /// Settle path, never a hard drop (FR-015). `startTimer()`'s auto-stop calls exactly
    /// this `stopRecording()`, so asserting the call here proves the cap settles.
    @Test func reachingCapSavesThroughStopPathToDone() async throws {
        await mocks.aiModel.setStubIsDownloaded(true)
        await enterRecording()

        // The cap fires the same call the auto-stop timer makes at maxDuration.
        let task = viewModel.stopRecording()
        #expect(viewModel.state == .processing)  // not a hard drop straight past Settle
        await task.value
        if let t = viewModel.transcriptionTask { await t.value }
        if let p = viewModel.processingViewModel.activeTask { await p.value }

        #expect(viewModel.state == .done)
        #expect(viewModel.lastSavedRecording != nil)
    }
}

/// Test seam: a store whose text-note persistence always throws, so the view-model's
/// text-save failure path (FR-009) can be exercised deterministically.
@MainActor
private final class ThrowingCheckInStore: RecordingStore {
    override func persistCheckInNote(_ draft: CheckInDraft) throws -> Recording {
        throw RecordingError.unknown
    }
}
