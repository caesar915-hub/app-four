import Foundation
import SquirlLiveActivity

/// Pure mapping from the app's `RecordingState` to the Live Activity `ContentState`
/// (spec 037, data-model §2). The single source of truth both `CheckInViewModel`
/// and `RecordingSessionController` route through, so the surface can never
/// contradict the capture (FR-008). No side effects — the Constitution X test seam.
enum RecordingActivityContentStateMapper {

    /// The content state for a given recording state, or `nil` when no activity
    /// should exist (`.idle`). `.processing`/`.done` map to `.ended` so the caller
    /// ends the activity; `.paused` carries the freeze timestamp.
    static func contentState(
        for state: RecordingState,
        pausedAt: Date?
    ) -> CheckInActivityAttributes.ContentState? {
        switch state {
        case .idle:
            return nil
        case .recording:
            return .init(phase: .recording, pausedAt: nil)
        case .paused:
            return .init(phase: .paused, pausedAt: pausedAt)
        case .processing, .done:
            return .init(phase: .ended, pausedAt: nil)
        }
    }
}
