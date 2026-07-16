import Foundation
import SquirlLiveActivity

/// 037 — owns the ActivityKit lifecycle for the check-in recording surface
/// (research D3, contracts §2). Isolated behind a protocol so the controller
/// logic is mockable and the app degrades cleanly when Live Activities are
/// disabled (FR-014): every method no-ops rather than throwing when unavailable.
@MainActor
protocol LiveActivityController: Sendable {
    /// `Activity.request` for a new recording; no-op when Live Activities are
    /// unavailable/disabled — recording proceeds without the surface (FR-014, SC-007).
    func begin(startedAt: Date, cap: TimeInterval) async

    /// `activity.update` to reflect a phase change (research D4 — paused passes
    /// `pausedAt` so `Text(timerInterval:pauseTime:)` freezes).
    func update(_ phase: RecordingActivityPhase, pausedAt: Date?) async

    /// `activity.end(.immediate)` so the surface clears within seconds (SC-005).
    func end() async

    /// Launch cleanup: end any recording activity that no longer maps to a live
    /// capture, so a killed-app run never leaves a stale "recording" pill (research D15).
    func endAllStale() async
}
