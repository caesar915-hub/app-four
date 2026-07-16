import Foundation

/// 037 — the process-level owner of the active check-in recording (research D10,
/// contracts §1). A background `LiveActivityIntent` runs with no view-model, yet
/// must pause/resume and *finalize* the live recording; so the lifecycle + the
/// single idempotent finalize live here, driven by BOTH `CheckInView` (via the
/// view-model, which delegates) and the Pause/Resume/Stop intents.
///
/// Injected via `AppDependencies` and registered with `AppDependencyManager`
/// (the 030 router/dose-service pattern) so `@AppDependency` resolves it inside
/// an intent's `perform()`, which runs in the app process.
@MainActor
protocol RecordingSessionController: Sendable {
    /// Authoritative lifecycle state; `.paused` becomes user-reachable here for the
    /// first time (research D19 — the service's pause/resume were previously dead).
    var state: RecordingState { get }

    /// Idempotency key for the single finalize (research D14): STOP, the
    /// `record(forDuration:)` finish, an interruption, and launch recovery all
    /// resolve to one save keyed by this id.
    var captureID: UUID? { get }

    /// Foreground-only (iOS blocks starting a mic session in the background).
    /// Starts the recorder with `record(forDuration: cap)` and begins the Live Activity.
    func start() async throws

    /// Suspend capture without ending it; updates the activity to `.paused` (FR-004).
    func pause() async

    /// Continue the same capture; updates the activity to `.recording` (FR-004).
    func resume() async throws

    /// Idempotent finalize (FR-003): stop the recorder, persist the file + the
    /// SwiftData record through the SAME pipeline as an in-app stop, end the
    /// activity. Background-safe (wrapped in a background-task assertion, research D9).
    func stopAndSave() async

    /// Launch reconcile (research D15): end stale activities and recover/validate
    /// an orphaned in-progress capture. No-op when there is nothing to recover.
    func recoverIfNeeded() async
}
