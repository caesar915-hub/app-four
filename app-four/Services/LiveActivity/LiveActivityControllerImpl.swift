import ActivityKit
import Foundation
import SquirlLiveActivity

/// 037 — the concrete `LiveActivityController` over ActivityKit (contract §2, research
/// D3). Holds the single active check-in `Activity`; every method degrades to a no-op
/// when Live Activities are unavailable or disabled, so recording proceeds without the
/// surface (FR-014, SC-007) — no method throws.
@MainActor
final class LiveActivityControllerImpl: LiveActivityController {
    private var activity: Activity<CheckInActivityAttributes>?
    private var cap: TimeInterval = 0

    func begin(startedAt: Date, cap: TimeInterval) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Exactly one surface at a time (FR-010): clear any prior activity first.
        await end()
        self.cap = cap
        let content = ActivityContent(
            state: CheckInActivityAttributes.ContentState(startedAt: startedAt, phase: .recording, pausedAt: nil),
            // Self-marks stale at the cap: if the app dies mid-recording the on-device
            // timer would otherwise tick forever; `isStale` lets the surface dim (D4).
            staleDate: startedAt.addingTimeInterval(cap)
        )
        do {
            activity = try Activity.request(
                attributes: CheckInActivityAttributes(cap: cap),
                content: content,
                pushType: nil
            )
        } catch {
            AppLogger.log("Live Activity request failed (recording continues without surface): \(error)")
        }
    }

    func update(for state: RecordingState, startedAt: Date, pausedAt: Date?) async {
        guard let activity else { return }
        guard let contentState = RecordingActivityContentStateMapper.contentState(
            for: state, startedAt: startedAt, pausedAt: pausedAt
        ) else {
            await end()  // .idle / terminal → clear the surface
            return
        }
        // Re-arm the stale date at the (pause-adjusted) cap while recording; a `.paused`
        // surface carries NO stale date so a long legitimate pause never dims it.
        let staleDate = contentState.phase == .paused ? nil : startedAt.addingTimeInterval(cap)
        await activity.update(ActivityContent(state: contentState, staleDate: staleDate))
    }

    func end() async {
        guard let activity else { return }
        await activity.end(
            ActivityContent(
                state: CheckInActivityAttributes.ContentState(startedAt: activity.content.state.startedAt, phase: .ended, pausedAt: nil),
                staleDate: nil
            ),
            dismissalPolicy: .immediate  // clears within seconds (SC-005)
        )
        self.activity = nil
    }

    func endAllStale() async {
        // Launch reconcile (research D15): a killed-app run can leave an orphaned
        // "recording" pill with no live capture. End every one EXCEPT our own live activity
        // — a cold-launch deep-link auto-start may have already begun one, and this runs
        // from the root .task which can race that begin().
        for stale in Activity<CheckInActivityAttributes>.activities where stale.id != activity?.id {
            await stale.end(nil, dismissalPolicy: .immediate)
        }
    }
}
