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

    func recoverIfNeeded() async {
        await liveActivity.endAllStale()
    }

    // MARK: RecordingControlSurface (driven by the Live Activity intents)

    func pause() async {
        guard let session, session.state == .recording else { return }
        await session.pauseCapture()
        // Re-check the SAME session is still live after the await: a racing finalize could
        // have run recordingDidFinish (session = nil) during the suspension.
        guard self.session === session else { return }
        let now = Date()
        pausedAt = now
        await liveActivity.update(for: .paused, startedAt: anchor, pausedAt: now)
    }

    func resume() async throws {
        guard let session, session.state == .paused, let pausedAt else { return }
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
              session.state == .recording || session.state == .paused else { return }
        isFinalizing = true
        // The background-task assertion now lives in `CheckInViewModel.stopRecording()`
        // so EVERY finalize path (in-app, Lock Screen, cap auto-stop) holds it — not just
        // this one. Awaiting the Task covers the save commit; the VM's terminal callback
        // (`recordingDidFinish`) ends the surface.
        await session.stopRecording().value
    }
}
