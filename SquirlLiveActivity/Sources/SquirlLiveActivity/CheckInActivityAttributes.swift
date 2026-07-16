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
    public struct ContentState: Codable, Hashable {
        public var phase: RecordingActivityPhase
        /// The freeze point for `Text(timerInterval:pauseTime:)` while paused;
        /// `nil` while recording or ended. Invariant: non-nil iff `phase == .paused`.
        public var pausedAt: Date?

        public init(phase: RecordingActivityPhase, pausedAt: Date? = nil) {
            self.phase = phase
            self.pausedAt = pausedAt
        }
    }

    /// Recording start — the fixed anchor for the self-updating elapsed timer
    /// (`Text(timerInterval:)`), so the widget re-renders on-device with no app pushes.
    public let startedAt: Date
    /// Max-duration cap, so the surface can bound the timer range.
    public let cap: TimeInterval

    public init(startedAt: Date, cap: TimeInterval) {
        self.startedAt = startedAt
        self.cap = cap
    }
}

/// The only recording state the Lock Screen / Dynamic Island renders.
public enum RecordingActivityPhase: String, Codable, Hashable, Sendable {
    case recording
    case paused
    case ended
}
