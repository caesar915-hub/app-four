import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
import SquirlLiveActivity

/// 037 — the check-in recording Live Activity (Lock Screen + Dynamic Island).
///
/// Shows only elapsed time + phase (FR-016: never transcript, mood, or medication).
/// The elapsed clock self-updates on-device via `Text(timerInterval:)` — no app wake —
/// anchored to the pause-adjusted `state.startedAt` so it stays truthful across pauses,
/// and freezes at `pausedAt` when paused (research D4). Interactive controls appear on
/// the Lock Screen and the expanded Dynamic Island only; compact/minimal are display-only.
///
/// Note: Live Activity views are archived static snapshots — only `Text(timerInterval:)`
/// and the system's entry transition animate. No `symbolEffect` / `withAnimation` here;
/// they silently no-op (widgets skill: animations-and-transitions).
struct SquirlWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CheckInActivityAttributes.self) { context in
            // No explicit background tint: the system material adapts to the light/dark
            // Lock Screen, so default label colors stay legible in both appearances.
            CheckInLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.phase.title, systemImage: context.state.phase.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(context.state.phase.tint)
                        .opacity(context.isStale ? 0.5 : 1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    checkInTimer(context)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(context.state.phase.tint)
                        .opacity(context.isStale ? 0.5 : 1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.phase != .ended {
                        checkInControls(context)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.state.phase.tint)
                    .opacity(context.isStale ? 0.5 : 1)
            } compactTrailing: {
                checkInTimer(context)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(context.state.phase.tint)
                    .opacity(context.isStale ? 0.5 : 1)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.state.phase.tint)
                    .opacity(context.isStale ? 0.5 : 1)
            }
            .keylineTint(CheckInPalette.accent)
        }
    }
}

// MARK: - Lock Screen

private struct CheckInLockScreenView: View {
    let context: ActivityViewContext<CheckInActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: context.state.phase.symbol)
                    .font(.title3)
                    .foregroundStyle(context.state.phase.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.phase.title)
                        .font(.subheadline.weight(.semibold))
                    Text("Squirl")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                checkInTimer(context)
                    .font(.title3.weight(.light).monospacedDigit())
                    .foregroundStyle(context.state.phase.tint)
            }

            if context.state.phase != .ended {
                checkInControls(context)
            }
        }
        .padding(16)
        .opacity(context.isStale ? 0.5 : 1)
    }
}

// MARK: - Shared pieces (Lock Screen + expanded Dynamic Island)

/// The elapsed clock. Renders `state.startedAt … state.startedAt + cap` counting up;
/// freezes at `pausedAt` when paused. Self-updating on-device — the app is never woken
/// to tick it. `startedAt` is pause-adjusted, so the shown time equals the recorded time.
private func checkInTimer(_ context: ActivityViewContext<CheckInActivityAttributes>) -> Text {
    let start = context.state.startedAt
    let range = start...start.addingTimeInterval(context.attributes.cap)
    // showsHours: false — a check-in cap is ≤ 8 min, so never render an hours field (it
    // would clip in the 44pt-wide compactTrailing slot).
    return Text(timerInterval: range, pauseTime: context.state.pausedAt, countsDown: false, showsHours: false)
}

@ViewBuilder
private func checkInControls(_ context: ActivityViewContext<CheckInActivityAttributes>) -> some View {
    HStack(spacing: 8) {
        switch context.state.phase {
        case .recording:
            Button(intent: PauseRecordingIntent()) {
                Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        case .paused:
            Button(intent: ResumeRecordingIntent()) {
                Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CheckInPalette.paused)
        case .ended:
            EmptyView()
        }

        Button(intent: StopRecordingIntent()) {
            Label("Stop & save", systemImage: "stop.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(CheckInPalette.accent)
    }
    .font(.subheadline.weight(.semibold))
}

// MARK: - Phase → presentation

private enum CheckInPalette {
    /// Capture-flow green (#5FB36E) — unified in commit 81ce578c.
    static let accent = Color(red: 95 / 255, green: 179 / 255, blue: 110 / 255)
    /// Paused amber.
    static let paused = Color(red: 184 / 255, green: 134 / 255, blue: 59 / 255)
}

private extension RecordingActivityPhase {
    var title: String {
        switch self {
        case .recording: "Recording check-in"
        case .paused: "Paused"
        case .ended: "Saved"
        }
    }

    var symbol: String {
        switch self {
        case .recording: "waveform"
        case .paused: "pause.circle.fill"
        case .ended: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .recording, .ended: CheckInPalette.accent
        case .paused: CheckInPalette.paused
        }
    }
}
