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
        // Also sweep the SYSTEM list: activities outlive the process, so after a death
        // the tracked handle is nil while orphans still sit on the Lock Screen — FR-010
        // must hold against ActivityKit's list, not this instance's memory (QA 07-17:
        // three stacked "Recording" cards). Ours doesn't exist yet, so end everything.
        for orphan in Activity<CheckInActivityAttributes>.activities {
            await orphan.end(nil, dismissalPolicy: .immediate)
        }
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
        // Detach BEFORE the await: a reentrant begin() during the suspension must see
        // no tracked activity, or its post-await write could clobber a newer handle.
        self.activity = nil
        await activity.end(
            ActivityContent(
                state: CheckInActivityAttributes.ContentState(startedAt: activity.content.state.startedAt, phase: .ended, pausedAt: nil),
                staleDate: nil
            ),
            dismissalPolicy: .immediate  // clears within seconds (SC-005)
        )
    }

    func endAllStale() async {
        // Reconcile (research D15): a killed-app run leaves orphaned "recording" pills
        // with no live capture. End every one EXCEPT our own live activity — a cold-launch
        // deep-link auto-start may have already begun one, and this can race that begin().
        // ActivityKit populates `.activities` asynchronously at cold launch, so an empty
        // first read gets one delayed retry before we trust it.
        var listed = Activity<CheckInActivityAttributes>.activities
        if listed.isEmpty {
            try? await Task.sleep(for: .seconds(2))
            listed = Activity<CheckInActivityAttributes>.activities
        }
        for stale in listed where stale.id != activity?.id {
            AppLogger.log("Ending stale Live Activity \(stale.id)")
            await stale.end(nil, dismissalPolicy: .immediate)
        }
    }
}
