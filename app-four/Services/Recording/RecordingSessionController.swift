import Foundation
import SquirlLiveActivity

/// 037 — the seam the recording session exposes to the process-level controller.
///
/// `CheckInViewModel` conforms; the controller retains it for the session's lifetime and
/// drives finalize / pause / resume THROUGH it rather than owning the (view-coupled) save
/// pipeline — reuse, not a copy (Constitution III). Kept to the few calls the controller
/// needs so the controller stays unit-testable against a mock session (Constitution X).
@MainActor
protocol CheckInSession: AnyObject {
    var state: RecordingState { get }

    /// The existing finalize pipeline (stop → buffer → save → transcribe). Idempotent
    /// by state: a call when not `.recording`/`.paused` is a no-op, so an in-app stop,
    /// a Lock Screen stop, and the cap auto-stop can never double-finalize.
    @discardableResult func stopRecording() -> Task<Void, Never>

    /// FR-004 — freeze the timer + pause the recorder, keeping the file open.
    func pauseCapture() async
    /// FR-004 — resume the same capture.
    func resumeCapture() async throws
}

/// 037 — process-level coordinator of the check-in recording surface (contract §1,
/// research D10). Conforms to `RecordingControlSurface` so the Live Activity intents
/// resolve it via `@AppDependency`; the recording lifecycle notifies it through the
/// `recordingDid…` hooks so it can drive the ActivityKit surface.
///
/// It does NOT own the save pipeline — that stays in the view model, reached through
/// `CheckInSession`. `stopAndSave()` therefore runs the SAME code path as an in-app
/// stop, so a background finalize can never diverge (SC-003).
@MainActor
protocol RecordingSessionController: RecordingControlSurface {
    /// Recording started (foreground): attach the session + begin the Live Activity.
    func recordingDidStart(_ session: CheckInSession, startedAt: Date, cap: TimeInterval) async
    /// Recording finished (saved, failed, or cancelled): end the Live Activity.
    func recordingDidFinish() async
    /// A mic interruption changed the session's state (paused by a call/Siri, or resumed).
    /// Reads the session's CURRENT state rather than taking an event, so out-of-order
    /// delivery converges on the truth — the surface freezes/re-anchors to match.
    func interruptionDidChangeState() async
    /// Reconcile (research D15): clear any stale surface left by a killed-app run. Runs
    /// at launch AND on every foreground — orphans outlive the process that made them.
    func recoverIfNeeded() async
}
