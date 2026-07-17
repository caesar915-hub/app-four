import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class CheckInViewModel: CheckInSession {
    var state: RecordingState = .idle
    var elapsedTime: TimeInterval = 0
    let maxDuration: TimeInterval = LayoutConstants.maxRecordingDuration

    var permissionDenied: Bool = false
    var lowDiskSpace: Bool = false

    // MARK: 8-minute soft landing (US4 / FR-014, R5)

    /// How long before the cap the single calm approach cue appears. ~30s gives a
    /// time-blind user a warm "wrapping up soon" heads-up without it reading as a
    /// deadline countdown (DESIGN: no you're-late alarms). A tuned content value, not magic.
    let approachWindow: TimeInterval = 30

    /// True once the recording has entered the final approach window. Derived from
    /// `elapsedTime` so it follows the timer; the view shows ONE faint cue on the
    /// rising edge — never a ticking bar (FR-014).
    var isApproachingCap: Bool { elapsedTime >= maxDuration - approachWindow }

    /// One-shot latch so the approach cue fires exactly once per recording: the view
    /// calls `markCapApproachShown()` after presenting it, and a clean `startRecording()`
    /// re-arms it. Advancing deeper into the window never re-triggers the cue.
    private(set) var hasShownCapApproach: Bool = false

    /// The view consumes the one-shot cue after showing it, so further elapsed advance
    /// (or hitting the cap) does not re-arm it.
    func markCapApproachShown() {
        hasShownCapApproach = true
    }

    /// US2 — never lose a capture. On a save failure the just-recorded audio is held
    /// here so a retry can re-save without re-recording; cleared on success or discard.
    struct PendingSave: Equatable {
        let fileURL: URL
        let duration: TimeInterval
    }
    private(set) var pendingSave: PendingSave?
    var saveFailed: Bool = false
    var textSaveFailed: Bool = false

    // MARK: VoiceOver announcement gate (US3 / FR-010, R4)

    /// Audio level (normalized 0.0–1.0, `audioLevelStream`) at or above which the mic is
    /// treated as picking up active voice. Sits well above the ~0.01 silence floor the
    /// recorder emits so room tone reads as quiet. This is the *announcement gate* the
    /// otherwise-discarded level stream feeds — deliberately NOT a visual glow (R4).
    static let activeVoiceThreshold: Float = 0.1

    /// True while the latest audio level indicates the user is actively speaking; used to
    /// defer prompt-advance announcements so VoiceOver never talks over the speaker.
    private(set) var isSpeaking: Bool = false

    /// A prompt-advance announcement the view requested but that is held until the next
    /// quiet (it must not fire mid-sentence). The view reads `promptAnnouncementIsEligible`.
    private(set) var promptAnnouncementIsPending: Bool = false

    /// The held announcement may post now: one is pending AND the user has gone quiet.
    var promptAnnouncementIsEligible: Bool { promptAnnouncementIsPending && !isSpeaking }

    @ObservationIgnored private let audioService: AudioRecordingService
    @ObservationIgnored private let storageService: AudioFileStorageService
    @ObservationIgnored private let transcriptionService: TranscriptionService
    @ObservationIgnored private let aiModelService: AIModelService
    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private let recordingController: RecordingSessionController
    private(set) var processingViewModel: ProcessingViewModel

    private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var finalizeAssertion: UIBackgroundTaskIdentifier = .invalid
    private var levelTask: Task<Void, Never>?
    private(set) var transcriptionTask: Task<Void, Never>?
    private(set) var modelPreloadTask: Task<Void, Never>?

    var timeString: String {
        AccessibilityHelpers.formatDuration(elapsedTime)
    }

    var maxTimeString: String {
        AccessibilityHelpers.formatDuration(maxDuration)
    }

    init(store: RecordingStore, services: AppServices) {
        self.store = store
        self.recordingController = services.recordingSessionController
        self.audioService = services.audioService
        self.storageService = services.storageService
        self.transcriptionService = services.transcriptionService
        self.aiModelService = services.aiModelService
        self.processingViewModel = ProcessingViewModel(
            store: store,
            summarizationService: services.summarizationService
        )
    }

    @discardableResult
    func startRecording() -> Task<Void, Never> {
        // Re-entry guard (FR-016): a capture is already live or finishing. Bail
        // before any disk/permission/audio-session work so a rapid double-tap or a
        // re-firing auto-start can't zero a running timer or open a second session.
        guard state == .idle || state == .done else {
            return Task {}
        }
        // Clean start: drop any stale recovery flags from a prior failed attempt and
        // reset the VoiceOver announcement gate so a prior session can't leak a held
        // announcement or a stale speaking state into this one.
        permissionDenied = false
        lowDiskSpace = false
        isSpeaking = false
        promptAnnouncementIsPending = false
        hasShownCapApproach = false

        return Task {
            let available = await storageService.availableStorage()
            guard available > LayoutConstants.minDiskSpaceForRecordingBytes else {
                AppLogger.log("Disk space too low: \(available) bytes")
                self.lowDiskSpace = true
                return
            }

            let hasPermission = await audioService.requestPermission()
            guard hasPermission else {
                AppLogger.log("Microphone permission denied.")
                self.permissionDenied = true
                return
            }

            do {
                _ = try await audioService.startRecording()
                let startedAt = Date()
                self.state = .recording
                UIApplication.shared.isIdleTimerDisabled = true
                self.elapsedTime = 0
                // 037 — attach this session to the process-level controller + begin the
                // Live Activity so a Lock-Screen stop/pause reaches this same pipeline.
                await self.recordingController.recordingDidStart(self, startedAt: startedAt, cap: self.maxDuration)
                // 037 — mirror mic interruptions (call/Siri) into recording state so the
                // timer + Live Activity freeze instead of counting over a dead mic. [weak self]
                // + the controller's state guards make a stale handler a safe no-op.
                self.audioService.setInterruptionHandler { [weak self] event in
                    // Synchronous on the main queue (assumeIsolated) so .paused/.resumed
                    // apply in strict emission order — a per-event Task could reorder a
                    // rapid .paused→.resumed and wedge the capture stuck-paused.
                    MainActor.assumeIsolated { self?.handleInterruptionEvent(event) }
                }
                self.promptInterval = Self.loadPromptInterval()

                self.startTimer()
                self.startLevelMonitoring()

                // Preload model off the main actor while the user records
                // so post-recording transcription doesn't need to reload.
                self.modelPreloadTask = Task.detached(priority: .utility) { [transcriptionService] in
                    do {
                        try await transcriptionService.loadModel()
                    } catch {
                        AppLogger.log("Model preload failed (will retry on stop): \(error)")
                    }
                }
            } catch {
                AppLogger.log("Failed to start recording: \(error)")
            }
        }
    }

    @discardableResult
    func stopRecording() -> Task<Void, Never> {
        // Idempotency (037): any finalize path — in-app stop, Lock-Screen intent, cap
        // auto-stop — is a no-op once past .recording/.paused. The guard + `.processing`
        // are synchronous (no await before them), so two racing callers can't both pass.
        guard state == .recording || state == .paused else { return Task {} }
        // Keep any prior recording's transcription running — we chain after it below.
        self.stopTasks(cancelTranscription: false)
        UIApplication.shared.isIdleTimerDisabled = false
        self.state = .processing

        // The prior in-flight transcription (if any). The new one waits for it so the
        // single WhisperKit actor isn't asked to run two inferences at once, and so a
        // back-to-back recording never cancels the previous one's transcription.
        let priorTranscription = self.transcriptionTask

        return Task {
            // Hold a background-task assertion across deactivate→save-commit so iOS can't
            // suspend the app mid-finalize — covers ALL finalize paths, incl. a locked cap
            // auto-stop (037 / research D9). Balanced + idempotent on `.invalid`.
            self.beginFinalizeAssertion()
            do {
                let result = try await audioService.stopRecording()
                // The audio is now on disk. Hold it in the retry buffer BEFORE the
                // save step so a save/store failure can be re-attempted (FR-005).
                self.pendingSave = PendingSave(fileURL: result.fileURL, duration: result.duration)
                self.attemptSave(priorTranscription: priorTranscription)
            } catch {
                // The audio stop itself failed — there is no captured file to buffer.
                AppLogger.log("Failed to stop recording: \(error)")
                self.state = .idle
            }
            // Recording has stopped → clear the Lock Screen surface (a failed save is
            // retried in-app, not from the Live Activity).
            await self.recordingController.recordingDidFinish()
            self.endFinalizeAssertion()
        }
    }

    /// Saves the buffered audio and, on success, settles into `.done` and kicks off
    /// background transcription; on failure raises `saveFailed` and KEEPS the buffer
    /// so the inline retry surface can re-attempt without re-recording (FR-005/007).
    /// Shared by the initial stop and `retrySave()` so both land identically.
    private func attemptSave(priorTranscription: Task<Void, Never>?) {
        guard let buffer = pendingSave else { return }
        do {
            let recording = try storageService.saveRecording(from: buffer.fileURL, duration: buffer.duration)
            self.store.addRecording(recording)
            self.lastSavedRecording = recording
            self.pendingSave = nil
            self.saveFailed = false

            // Immediately show done; transcribe in background
            self.state = .done

            // Model not ready: persist as pending and skip transcription. The
            // PendingTranscriptionService drains it through this exact path once the
            // model lands — capture stays "Captured.", never a .failed (FR-011/012).
            guard self.aiModelService.localPath(for: .whisper) != nil else {
                recording.status = .pendingTranscription
                self.store.save()
                return
            }

            self.transcriptionTask = Task {
                // Let the prior transcription finish first (serialize on the single
                // Whisper instance). It's never cancelled here, so its work is kept.
                await priorTranscription?.value
                await self.transcribeInBackground(recording)
            }
        } catch {
            // Never silently reset to idle — retain the buffer and surface a calm,
            // recoverable "try again" (FR-005/006). State stays `.processing` so the
            // recording stage (and its inline retry surface) remains on screen.
            AppLogger.log("Failed to save capture: \(error)")
            self.saveFailed = true
        }
    }

    @discardableResult
    func retrySave() -> Task<Void, Never> {
        guard saveFailed, pendingSave != nil else { return Task {} }
        saveFailed = false
        state = .processing
        let priorTranscription = transcriptionTask
        return Task {
            self.attemptSave(priorTranscription: priorTranscription)
        }
    }

    /// Explicit discard of a failed capture: release the buffered audio file and clear
    /// the failure surface, returning to the idle hub (FR-008).
    func discardFailedCapture() {
        if let buffer = pendingSave {
            try? FileManager.default.removeItem(at: buffer.fileURL)
        }
        pendingSave = nil
        saveFailed = false
        state = .idle
    }

    /// Runs transcription in the background with a timeout so the UI never hangs.
    private func transcribeInBackground(_ recording: Recording) async {
        do {
            let stream = try await transcriptionService.transcribe(audioURL: recording.audioURL)
            try await consumeStreamWithTimeout(stream, for: recording, timeoutSeconds: 90)

            // The user may have deleted this recording (library multi-select) while it
            // transcribed in the background; never touch a freed @Model.
            guard store.recordings.contains(where: { $0.id == recording.id }) else {
                AppLogger.log("Transcription finished but recording \(recording.id) was deleted; skipping")
                return
            }
            recording.status = .completed
            store.save()
            AppLogger.log("Transcription completed for \(recording.id)")
            processingViewModel.processRawTranscription(
                recording.fullTranscriptText,
                duration: recording.duration,
                language: nil,
                audioFileName: recording.audioFileName
            )
        } catch is CancellationError {
            AppLogger.log("Transcription cancelled for \(recording.id)")
            // The enclosing task is itself cancelled here, so any `await` (incl. an
            // actor hop) may be skipped — finalize the persisted status in a fresh,
            // uncancelled MainActor task so the recording never stays stuck on
            // `.transcribing`. The service was already torn down by the caller's
            // `cancelInFlightServices()`, so no extra cancel call is needed.
            Task { @MainActor [store] in
                // The recording may have been deleted while the cancel raced — re-resolve
                // by id before touching the @Model so we never mutate a freed object.
                guard store.recordings.contains(where: { $0.id == recording.id }) else { return }
                recording.status = .failed
                recording.fullTranscriptText = "Transcription cancelled. Tap to retry in the recording detail view."
                store.save()
            }
        } catch RecordingError.timeout {
            AppLogger.log("Transcription timed out for \(recording.id)")
            await transcriptionService.cancelTranscription()
            guard store.recordings.contains(where: { $0.id == recording.id }) else { return }
            recording.status = .failed
            recording.fullTranscriptText = "Transcription timed out. Tap to retry in the recording detail view."
            store.save()
        } catch {
            AppLogger.log("Transcription failed for \(recording.id): \(error)")
            guard store.recordings.contains(where: { $0.id == recording.id }) else { return }
            recording.status = .failed
            recording.fullTranscriptText = "Transcription failed: \(error.localizedDescription)"
            store.save()
        }
    }

    /// Consumes the transcription stream, racing against a timeout.
    private func consumeStreamWithTimeout(
        _ stream: AsyncStream<TranscriptionSegmentDTO>,
        for recording: Recording,
        timeoutSeconds: UInt64
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Stream consumer — must run on MainActor because Recording is @Model.
            // Guard on each segment: the user may delete this recording via
            // multi-select while transcription is still streaming.
            group.addTask { @MainActor in
                for await segment in stream {
                    guard self.store.recordings.contains(where: { $0.id == recording.id }) else { return }
                    if segment.isError {
                        throw AudioConverterError.conversionFailed(segment.text)
                    }
                    recording.fullTranscriptText = segment.text
                    recording.status = .transcribing
                    self.store.save()
                }
            }

            // Timeout guard
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw RecordingError.timeout
            }

            // Wait for whichever finishes first
            try await group.next()
            group.cancelAll()
        }
    }

    @discardableResult
    func cancelRecording() -> Task<Void, Never> {
        guard state == .recording || state == .paused else { return Task {} }
        // No synchronous state flip: in-app Cancel and a Lock-Screen Stop cannot coexist
        // (Cancel is in the foregrounded app; Stop is on the locked screen), so there is no
        // finalize race to guard here — and flipping to `.processing` would make the UI
        // announce "Saving…" while the capture is actually being discarded.
        self.stopTasks()
        modelPreloadTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        return Task {
            await audioService.cancelRecording()
            await self.cancelInFlightServices()
            self.state = .idle
            self.elapsedTime = 0
            self.lastSavedRecording = nil
            await self.recordingController.recordingDidFinish()   // end the Live Activity on cancel
        }
    }

    // MARK: - Pause / resume (037 — Live Activity control)

    /// FR-004 — freeze the timer + pause the recorder without ending the capture. State
    /// flips BEFORE the await so a racing stop (which reads `.paused`) can't be overwritten
    /// back to `.paused` after it has moved to `.processing`.
    func pauseCapture() async {
        guard state == .recording else { return }
        state = .paused
        stopTasks(cancelTranscription: false)   // cancels the 0.1s timer → elapsedTime freezes
        await audioService.pauseRecording()
    }

    /// FR-004 — resume the same capture and restart the elapsed timer from where it froze.
    func resumeCapture() async throws {
        guard state == .paused else { return }
        try await audioService.resumeRecording()
        // Re-check after the await: a stop may have moved us to `.processing`.
        guard state == .paused else { return }
        state = .recording
        startTimer()
        startLevelMonitoring()
    }

    /// Mirror a mic interruption into recording state (037). The audio service already
    /// paused/resumed the recorder, so this ONLY updates view-model state + freezes/restarts
    /// the elapsed timer, synchronously and in emission order. It deliberately does NOT
    /// re-drive the recorder (that would race the service's own interruption path on a
    /// different executor) and does NOT touch the Live Activity (an async update from here
    /// could reorder). Consequence: the Lock-Screen surface keeps counting during a brief
    /// interruption, but the SAVED duration (service accumulatedTime) stays correct.
    private func handleInterruptionEvent(_ event: RecordingInterruption) {
        switch event {
        case .paused, .endedWithoutResume:
            guard state == .recording else { return }
            state = .paused
            stopTasks(cancelTranscription: false)   // freeze the elapsed timer
        case .resumed:
            guard state == .paused else { return }
            state = .recording
            startTimer()
            startLevelMonitoring()
        }
    }

    func reset() {
        UIApplication.shared.isIdleTimerDisabled = false
        state = .idle
        elapsedTime = 0
        lastSavedRecording = nil
    }

    @MainActor private static func loadPromptInterval() -> TimeInterval {
        let context = AppModelContainer.container.mainContext
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? context.fetch(descriptor).first {
            return PromptPace(rawValue: settings.promptPaceSeconds)?.interval ?? PromptPace.relaxed.interval
        }
        return PromptPace.relaxed.interval
    }

    // MARK: - Nudges (voice)

    struct NudgePrompt: Equatable {
        let question: String
        let hint: String
    }

    static let nudgePrompts: [NudgePrompt] = [
        NudgePrompt(question: "How's your mood?",       hint: "Heavy, light, flat, bright — whatever fits."),
        NudgePrompt(question: "What's your energy like?", hint: "Wired, steady, or running low."),
        NudgePrompt(question: "Able to focus?",          hint: "Locked in, scattered, somewhere between."),
        NudgePrompt(question: "How did you sleep?",      hint: "Hours, and how rested you feel."),
        NudgePrompt(question: "Any strong emotions?",    hint: "Something sitting with you right now."),
    ]

    /// Seconds per prompt — read from AppSettings on startRecording(), stays stable during a session.
    private(set) var promptInterval: TimeInterval = PromptPace.relaxed.interval

    var currentPromptIndex: Int {
        // Epsilon nudges the boundary so the 0.1s-accumulated elapsedTime lands on
        // the interval mark on time rather than one tick late from float drift.
        Int((elapsedTime + 1e-6) / promptInterval) % Self.nudgePrompts.count
    }

    var currentPrompt: NudgePrompt { Self.nudgePrompts[currentPromptIndex] }

    /// 0.0 → 1.0 progress within the current prompt window (drives the countdown bar).
    var promptProgress: Double {
        (elapsedTime.truncatingRemainder(dividingBy: promptInterval)) / promptInterval
    }

    /// Feeds the live audio level into the active-voice gate (FR-010, R4). Called from
    /// `startLevelMonitoring()` for each emitted sample; also the test seam for the gate.
    func ingestAudioLevel(_ level: Float) {
        isSpeaking = level >= Self.activeVoiceThreshold
    }

    /// The view requests a prompt-advance announcement when `currentPromptIndex` changes.
    /// Coalesced to a single pending announcement so a backlog never accumulates while
    /// deferred — the user hears the *current* prompt on the next quiet, not a queue.
    func requestPromptAnnouncement() {
        promptAnnouncementIsPending = true
    }

    /// The view calls this once it has posted the held announcement.
    func consumePromptAnnouncement() {
        promptAnnouncementIsPending = false
    }

    // MARK: - Text check-in

    private(set) var lastSavedRecording: Recording?

    func saveTextCheckIn(_ draft: CheckInDraft) {
        guard !draft.isEmpty else { return }
        let recording: Recording
        do {
            recording = try store.persistCheckInNote(draft)
        } catch {
            // Don't silently drop the draft — surface a calm, non-alarming retry
            // affordance (FR-009). The composer's draft is still intact for a re-save.
            AppLogger.log("Failed to save text check-in: \(error)")
            textSaveFailed = true
            return
        }
        textSaveFailed = false
        if !draft.trimmedNote.isEmpty {
            processingViewModel.processRawTranscription(
                draft.trimmedNote,
                duration: 0,
                language: nil,
                audioFileName: recording.audioFileName,
                fillOnly: true
            )
        }
        lastSavedRecording = recording
        state = .done
    }

    func advanceTick() {
        guard !Task.isCancelled else { return }
        elapsedTime += 0.1
    }

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                self.advanceTick()
                if self.elapsedTime >= self.maxDuration {
                    self.stopRecording()
                    break
                }
            }
        }
    }

    private func startLevelMonitoring() {
        levelTask = Task {
            for await level in audioService.audioLevelStream {
                if Task.isCancelled { break }
                self.ingestAudioLevel(level)
            }
        }
    }

    /// Cancels the local consumer task handles. Synchronous — the async
    /// service-level teardown is handled by `cancelInFlightServices()` from the
    /// structured Task bodies of `stopRecording()` / `cancelRecording()`.
    ///
    /// `cancelTranscription`: discarding a recording (`cancelRecording`) must kill any
    /// in-flight transcription; finishing one to record again (`stopRecording`) must
    /// NOT — the prior recording's transcription is left running and the new one
    /// chains after it, so back-to-back check-ins don't throw away each other's work.
    private func stopTasks(cancelTranscription: Bool = true) {
        timerTask?.cancel()
        timerTask = nil
        levelTask?.cancel()
        levelTask = nil
        // Monitoring stopped: no live level means no active voice. Releases the gate so a
        // pending prompt announcement isn't wedged "deferred" on the last loud sample.
        isSpeaking = false
        if cancelTranscription {
            transcriptionTask?.cancel()
            transcriptionTask = nil
        }
    }

    /// Tears down any in-flight transcription at the service level. Awaited from
    /// structured contexts so cancellation isn't dropped on the floor.
    private func cancelInFlightServices() async {
        await transcriptionService.cancelTranscription()
    }

    // MARK: - Background-task assertion (037 — locked finalize, research D9)

    private func beginFinalizeAssertion() {
        // End any still-live prior assertion first: `finalizeAssertion` is a single scalar,
        // so a back-to-back finalize (a 2nd capture stopped inside the 1st's liveActivity.end
        // window) would otherwise orphan the 1st id → unbalanced assertion → the OS kills the
        // app. Safe because a prior assertion is only still live after its save committed.
        endFinalizeAssertion()
        finalizeAssertion = UIApplication.shared.beginBackgroundTask(withName: "checkin-finalize") { [weak self] in
            // Called synchronously on the main thread when the assertion expires.
            MainActor.assumeIsolated { self?.endFinalizeAssertion() }
        }
    }

    private func endFinalizeAssertion() {
        guard finalizeAssertion != .invalid else { return }
        UIApplication.shared.endBackgroundTask(finalizeAssertion)
        finalizeAssertion = .invalid
    }
}
