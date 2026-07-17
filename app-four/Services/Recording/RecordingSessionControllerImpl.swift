import Foundation
import SquirlLiveActivity

/// 037 — the process-level coordinator (contract §1). Drives the ActivityKit surface
/// off the recording lifecycle and routes the Live Activity intents into the live
/// session's existing pipeline. It is the SOLE writer of the surface (begin/update/end),
/// so a Lock-Screen pause and an in-app transition can't race two divergent updates.
@MainActor
final class RecordingSessionControllerImpl: RecordingSessionController {
    /// STRONG — the process-lifetime finalize authority. A recording started from a
    /// view that is later torn down (tab switch, memory purge) must still be finalizable
    /// from the Lock Screen, so the session is retained here and released ONLY on a
    /// terminal transition via `recordingDidFinish()`, so the VM↔controller reference is
    /// never permanent (was `weak` — that orphaned the recorder and lost the capture).
    private var session: CheckInSession?
    private let liveActivity: LiveActivityController

    /// Guards a double finalize when a Lock-Screen STOP and an in-app STOP (or the cap
    /// auto-stop) race. The view model's own state-guard is the second line. Reset in
    /// `recordingDidFinish` so a no-op'd stop can't wedge it `true` for the next capture.
    private var isFinalizing = false

    /// The pause-adjusted timer anchor mirrored to the Live Activity, advanced past the
    /// paused gap on resume so the surface never over-reports elapsed time.
    private var anchor: Date = .distantPast
    private var pausedAt: Date?

    init(liveActivity: LiveActivityController) {
        self.liveActivity = liveActivity
    }

    // MARK: Lifecycle hooks (driven by the view model)

    func recordingDidStart(_ session: CheckInSession, startedAt: Date, cap: TimeInterval) async {
        // Defense-in-depth against a two-VM orphan (a torn-down + recreated CheckInView
        // under memory pressure spawning a second VM over the one shared audio service):
        // never replace a still-live session. Normal sequential recordings pass because
        // recordingDidFinish nils `session` first.
        guard self.session == nil || self.session?.state == .idle || self.session?.state == .done else { return }
        self.session = session
        anchor = startedAt
        pausedAt = nil
        isFinalizing = false
        await liveActivity.begin(startedAt: startedAt, cap: cap)
    }

    func recordingDidFinish() async {
        await liveActivity.end()
        session = nil
        pausedAt = nil
        isFinalizing = false
    }

    func interruptionDidChangeState() async {
        guard let session else { return }
        switch session.state {
        case .paused:
            // Already reflected (e.g. a Lock-Screen pause raced the interruption) → no-op.
            guard pausedAt == nil else { return }
            let now = Date()
            pausedAt = now
            await liveActivity.update(for: .paused, startedAt: anchor, pausedAt: now)
        case .recording:
            guard let pausedAt else { return }
            anchor = anchor.addingTimeInterval(Date().timeIntervalSince(pausedAt))
            self.pausedAt = nil
            await liveActivity.update(for: .recording, startedAt: anchor, pausedAt: nil)
        case .idle, .processing, .done:
            return
        }
    }

    func recoverIfNeeded() async {
        await liveActivity.endAllStale()
    }

    /// A Lock-Screen tap on an ORPHANED surface (its process died mid-recording) is the
    /// only code guaranteed to run in that background launch — reap the lie instead of
    /// silently no-oping (QA 07-17: "dead" buttons over immortal cards). Never fires
    /// while a live capture or finalize exists: the guard passes only when there is no
    /// session or it is terminal.
    private func endOrphanedSurfaceIfSessionless() async {
        guard session == nil || session?.state == .idle || session?.state == .done else { return }
        AppLogger.log("Live Activity intent arrived with no live session — reaping orphaned surfaces")
        await liveActivity.endAllStale()
    }

    // MARK: RecordingControlSurface (driven by the Live Activity intents)

    func pause() async {
        guard let session, session.state == .recording else {
            await endOrphanedSurfaceIfSessionless()
            return
        }
        await session.pauseCapture()
        // Re-check the SAME session is still live after the await: a racing finalize could
        // have run recordingDidFinish (session = nil) during the suspension.
        guard self.session === session else { return }
        let now = Date()
        pausedAt = now
        await liveActivity.update(for: .paused, startedAt: anchor, pausedAt: now)
    }

    func resume() async throws {
        guard let session, session.state == .paused, let pausedAt else {
            await endOrphanedSurfaceIfSessionless()
            return
        }
        try await session.resumeCapture()
        // Re-check the SAME session is still live after the await (a racing finalize could
        // have detached it during the suspension).
        guard self.session === session else { return }
        // Advance the anchor past the paused gap so the timer continues from where it
        // froze — displayed elapsed then equals the recorded (pause-excluded) duration.
        anchor = anchor.addingTimeInterval(Date().timeIntervalSince(pausedAt))
        self.pausedAt = nil
        await liveActivity.update(for: .recording, startedAt: anchor, pausedAt: nil)
    }

    func stopAndSave() async {
        guard !isFinalizing, let session,
              session.state == .recording || session.state == .paused else {
            // Mid-finalize the session is retained in `.processing`, so the helper's
            // own guard makes this a no-op there — it reaps only true orphans.
            await endOrphanedSurfaceIfSessionless()
            return
        }
        isFinalizing = true
        // The background-task assertion now lives in `CheckInViewModel.stopRecording()`
        // so EVERY finalize path (in-app, Lock Screen, cap auto-stop) holds it — not just
        // this one. Awaiting the Task covers the save commit; the VM's terminal callback
        // (`recordingDidFinish`) ends the surface.
        await session.stopRecording().value
    }
}
