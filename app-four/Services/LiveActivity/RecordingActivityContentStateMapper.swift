import Foundation
import SquirlLiveActivity

/// Pure mapping from the app's `RecordingState` (+ the pause-adjusted anchor) to the
/// Live Activity `ContentState` (spec 037, data-model §2). The single builder the
/// `LiveActivityController` routes through, so the surface can never contradict the
/// capture (FR-008). No side effects — the Constitution X test seam. It also NORMALIZES
/// the payload: `pausedAt` survives only in `.paused`, so a stale freeze stamp can never
/// leak into a running or ended surface.
enum RecordingActivityContentStateMapper {

    /// The content state for a given recording state, or `nil` when no activity should
    /// exist (`.idle`). `.processing`/`.done` map to `.ended` so the caller ends the
    /// activity; `.paused` carries the freeze timestamp.
    static func contentState(
        for state: RecordingState,
        startedAt: Date,
        pausedAt: Date?
    ) -> CheckInActivityAttributes.ContentState? {
        switch state {
        case .idle:
            return nil
        case .recording:
            return .init(startedAt: startedAt, phase: .recording, pausedAt: nil)
        case .paused:
            return .init(startedAt: startedAt, phase: .paused, pausedAt: pausedAt)
        case .processing, .done:
            return .init(startedAt: startedAt, phase: .ended, pausedAt: nil)
        }
    }
}
