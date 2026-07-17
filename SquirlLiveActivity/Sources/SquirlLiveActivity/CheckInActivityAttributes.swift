import ActivityKit
import Foundation

/// The Live Activity contract for an in-progress voice check-in (spec 037).
///
/// Shared by the app (which calls `Activity.request`/`update`/`end`) and the
/// `SquirlWidgets` extension (which renders it). Deliberately carries ONLY timing
/// and recording state — never transcript, mood, or medication content — because
/// the Lock Screen is visible to anyone holding the phone (FR-016, Constitution VI).
public struct CheckInActivityAttributes: ActivityAttributes {

    /// The mutable slice pushed via `activity.update`.
    public struct ContentState: Codable, Hashable, Sendable {
        /// The pause-adjusted anchor for the self-updating elapsed timer
        /// (`Text(timerInterval:)`). It lives in `ContentState`, NOT the immutable
        /// `attributes`, precisely so `resume` can advance it past the paused gap —
        /// otherwise the timer would count wall-clock and over-report elapsed by the
        /// paused duration after every pause. The range is `startedAt … startedAt + cap`.
        public var startedAt: Date
        public var phase: RecordingActivityPhase
        /// The freeze point for `Text(timerInterval:pauseTime:)` while paused;
        /// `nil` while recording or ended. Invariant: non-nil iff `phase == .paused`.
        public var pausedAt: Date?

        public init(startedAt: Date, phase: RecordingActivityPhase, pausedAt: Date? = nil) {
            self.startedAt = startedAt
            self.phase = phase
            self.pausedAt = pausedAt
        }
    }

    /// Max-duration cap — fixed for the capture, so it stays in the immutable attributes.
    public let cap: TimeInterval

    public init(cap: TimeInterval) {
        self.cap = cap
    }
}

/// The only recording state the Lock Screen / Dynamic Island renders.
public enum RecordingActivityPhase: String, Codable, Hashable, Sendable {
    case recording
    case paused
    case ended
}
