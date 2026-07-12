import SwiftUI

struct CheckInView: View {
    @State private var viewModel: CheckInViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(MedicationBarViewModel.self) private var medicationBarViewModel
    @Binding var shouldAutoStart: Bool

    @State private var showMedLogSheet = false
    @State private var showComposer = false
    @State private var showCapApproachCue = false

    /// First-launch whisper hint (US5 / FR-018, R7): two ghost lines that orient a
    /// first-ever visitor, dismissed forever on the first capture start (voice or text).
    @AppStorage("checkInHintSeen") private var checkInHintSeen = false

    init(store: RecordingStore, services: AppServices, shouldAutoStart: Binding<Bool> = .constant(false)) {
        _viewModel = State(wrappedValue: CheckInViewModel(store: store, services: services))
        _shouldAutoStart = shouldAutoStart
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : Motion.smooth, value: viewModel.state)
        }
        .trackScreen("CheckInView")
        .onAppear { consumeAutoStart() }
        .onChange(of: shouldAutoStart) { _, isOn in if isOn { consumeAutoStart() } }
        .sheet(isPresented: $showMedLogSheet) {
            MedicationLogSheet { name, dose, takenAt, durationHours in
                medicationBarViewModel.logManualDose(name: name, dose: dose, takenAt: takenAt, durationHours: durationHours)
            }
        }
        .sheet(isPresented: $showComposer) {
            TextCheckInComposer { draft in
                checkInHintSeen = true   // a text capture also dismisses the hint (FR-018)
                viewModel.saveTextCheckIn(draft)
                return !viewModel.textSaveFailed
            }
        }
        .alert("Microphone Access Required", isPresented: $viewModel.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Squirl needs microphone access to record voice notes. Enable it in Settings.")
        }
        .alert("Not Enough Storage", isPresented: $viewModel.lowDiskSpace) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Squirl needs at least 50 MB of free space to record. Free up some space and try again.")
        }
    }

    /// Posts a VoiceOver announcement (FR-010/012). A no-op when VoiceOver is off, so it
    /// is safe to call unconditionally from state-change handlers. iOS 26 floor ⇒ the
    /// SwiftUI announcement API is always available; no UIAccessibility fallback needed.
    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    private func consumeAutoStart() {
        guard shouldAutoStart else { return }
        shouldAutoStart = false
        switch viewModel.state {
        case .recording, .paused, .processing: return   // already capturing — never double-start (FR-016)
        case .done: viewModel.reset(); startVoiceCapture()
        case .idle: startVoiceCapture()
        }
    }

    /// Single chokepoint for voice capture so the first-launch hint (US5) is dismissed
    /// the moment any capture begins, whether tapped or auto-started (FR-018).
    private func startVoiceCapture() {
        checkInHintSeen = true
        viewModel.startRecording()
    }

    private var todayDate: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .done:
            CheckInSavedView(recording: viewModel.lastSavedRecording) {
                viewModel.reset()
            }
        // Idle and recording/paused/processing share one layout (captureStage) so the crescent
        // stays anchored — it grows in place rather than jumping down when capture starts.
        // .processing keeps the stage on screen (crescent spinning, stop shows a spinner) for
        // the brief save window; the headline reads "Saving…".
        default:
            captureStage
        }
    }

    // MARK: Capture stage (idle + recording share one anchored layout)

    /// Idle and recording/paused/processing render in one ZStack so the crescent is anchored at
    /// the same screen-centre across the transition (spec 024): it grows in place (200→260) and
    /// never jumps down. Top chrome (headline ▸ progress + prompt) pins to the top, bottom chrome
    /// (Speak / Log / Type) to the bottom, and the crescent — carrying the timer + controls while
    /// recording — stays centred. The grow animates via `content`'s state animation (Reduce Motion
    /// honoured there).
    private var captureStage: some View {
        let isRecording = viewModel.state != .idle
        return ZStack {
            // Centre: the anchored crescent, plus the live status + controls while recording.
            ZStack {
                CrescentRing(isActive: viewModel.state == .recording && !viewModel.saveFailed)
                    .frame(width: crescentDiameter, height: crescentDiameter)
                    .opacity(viewModel.state == .paused ? Opacity.deEmphasis : 1)
                    .accessibilityHidden(true)
                if isRecording { recordingCentre } else { idleRingCentre }
            }

            // Top chrome floats above the centred crescent.
            VStack(spacing: 0) {
                if isRecording { recordingHeader } else { idleHeader }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.l)
        .onChange(of: viewModel.saveFailed) { _, failed in
            if failed { Haptics.error() }
        }
        // FR-016: structured task lifetime tied to the view; cancelled automatically
        // when id changes again or the view disappears.
        .task(id: viewModel.isApproachingCap) {
            guard viewModel.isApproachingCap, !viewModel.hasShownCapApproach else { return }
            viewModel.markCapApproachShown()
            withAnimation(reduceMotion ? nil : Motion.smooth) { showCapApproachCue = true }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(reduceMotion ? nil : Motion.smooth) { showCapApproachCue = false }
        }
        // FR-010: announce each prompt advance to VoiceOver once the active-voice gate is quiet.
        .onChange(of: viewModel.currentPromptIndex) { _, _ in
            viewModel.requestPromptAnnouncement()
        }
        .onChange(of: viewModel.promptAnnouncementIsEligible) { _, eligible in
            guard eligible else { return }
            announce("\(viewModel.currentPrompt.question) \(viewModel.currentPrompt.hint)")
            viewModel.consumePromptAnnouncement()
        }
        // FR-012: speak the capture's final transitions.
        .onChange(of: viewModel.state) { _, newState in
            switch newState {
            case .processing: announce("Saving…")
            case .done: announce("Captured.")
            default: break
            }
        }
    }

    private var crescentDiameter: CGFloat { Metrics.CheckIn.crescentDiameter }

    // MARK: Idle chrome

    private var idleHeader: some View {
        VStack(spacing: Spacing.xs) {
            Text(todayDate)
                .font(Typography.label)
                .textCase(.uppercase)
                .foregroundStyle(NewLook.inkSecondary)
            Text("How do you feel?")
                .font(Typography.title)
                .foregroundStyle(NewLook.inkPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            // US5 / FR-018: first-launch headline whisper — low-contrast, one-time.
            if !checkInHintSeen {
                Text("Say whatever's on your mind — a few words is plenty.")
                    .font(Typography.callout)
                    .foregroundStyle(NewLook.inkSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Spacing.xl)
        .frame(maxWidth: .infinity)
    }

    private var idleRingCentre: some View {
        VStack(spacing: Spacing.s) {
            hubOption("Log meds", icon: Icons.medication, tint: Palette.medication) {
                showMedLogSheet = true
            }
            speakButton
            hubOption("Type note", icon: "square.and.pencil", tint: nil) {
                showComposer = true
            }
        }
    }

    private var speakButton: some View {
        Button {
            startVoiceCapture()
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: "mic.fill")
                Text("Speak check-in").font(Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(width: 220)
            .padding(.vertical, Spacing.l)
            .background(Theme.meadowGradient, in: RoundedRectangle(cornerRadius: Radius.button))
            .shadow(color: Theme.meadowAmber.opacity(0.34), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start voice check-in")
    }

    private func hubOption(_ label: String, icon: String, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: icon).foregroundStyle(tint ?? NewLook.inkPrimary)
                Text(label).font(Typography.headline).foregroundStyle(NewLook.inkPrimary)
            }
            .frame(width: 220, height: Metrics.minTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Recording chrome

    private var recordingHeader: some View {
        VStack(spacing: Spacing.xl) {
            promptProgressBar
            heroPrompt
                .padding(.horizontal, Spacing.l)
        }
    }

    /// The timer + controls that sit over the anchored crescent while recording; a save failure
    /// swaps in the recovery affordance. The grouped status reads to VoiceOver as the
    /// "Recording, elapsed" live region. Paused dims the ring (above) and names the state here —
    /// an honest visual floor only, no resume / audio-append engineering (FR-017).
    @ViewBuilder private var recordingCentre: some View {
        if viewModel.saveFailed {
            failureRecovery
        } else {
            VStack(spacing: Spacing.m) {
                // FR-011: crescent + timer read as one live-region status, throttled to whole
                // seconds (timeString changes once a second, not every 0.1s tick) so VoiceOver
                // doesn't chatter.
                Text(viewModel.timeString)
                    .font(Typography.timer)
                    .foregroundStyle(NewLook.inkPrimary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(viewModel.state == .paused
                                        ? "Paused, \(viewModel.timeString) elapsed"
                                        : "Recording, \(viewModel.timeString) elapsed")
                    .accessibilityAddTraits(.updatesFrequently)

                if viewModel.state == .paused {
                    Text("Paused")
                        .font(Typography.label)
                        .textCase(.uppercase)
                        .foregroundStyle(NewLook.inkSecondary)
                }
                stopButton
                Button("Cancel") { viewModel.cancelRecording() }
                    .font(Typography.callout)
                    .foregroundStyle(NewLook.inkSecondary)
                    .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                    .accessibilityLabel("Cancel recording")

                // FR-014 / R5: a single calm "wrapping up soon" line on the approach to the cap —
                // faint, no red, no ticking bar. Fades after a beat; one-shot via the VM latch.
                Text("Wrapping up soon")
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkSecondary.opacity(0.7))
                    .opacity(showCapApproachCue ? 1 : 0)
                    .accessibilityHidden(!showCapApproachCue)
            }
        }
    }

    private var promptProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(NewLook.inkSecondary.opacity(0.15))
                Rectangle()
                    .fill(Theme.accent.opacity(0.5))
                    .frame(width: geo.size.width * viewModel.promptProgress)
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: viewModel.promptProgress)
                    // New identity per prompt so the per-window reset snaps to 0
                    // instead of animating backwards across the wrap.
                    .id(viewModel.currentPromptIndex)
            }
        }
        .frame(height: Metrics.CheckIn.promptBarHeight)
        .accessibilityHidden(true)
    }

    private var heroPrompt: some View {
        VStack(spacing: Spacing.s) {
            Text(viewModel.currentPrompt.question)
                .font(Typography.display)
                .foregroundStyle(NewLook.inkPrimary)
                .multilineTextAlignment(.center)
                .id(viewModel.currentPromptIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Text(viewModel.currentPrompt.hint)
                .font(Typography.callout)
                .foregroundStyle(NewLook.inkSecondary)
                .multilineTextAlignment(.center)
                .id("hint-\(viewModel.currentPromptIndex)")
                .transition(.opacity)

            promptDots
                .padding(.top, Spacing.xs)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: viewModel.currentPromptIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.currentPrompt.question) \(viewModel.currentPrompt.hint)")
    }

    private var promptDots: some View {
        HStack(spacing: Metrics.CheckIn.promptDot) {
            ForEach(0..<CheckInViewModel.nudgePrompts.count, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentPromptIndex
                          ? Theme.accent
                          : NewLook.inkSecondary.opacity(0.3))
                    .frame(width: Metrics.CheckIn.promptDot, height: Metrics.CheckIn.promptDot)
            }
        }
        .accessibilityHidden(true)
    }

    private var stopButton: some View {
        Button {
            viewModel.stopRecording()
        } label: {
            HStack(spacing: Spacing.s) {
                if viewModel.state == .processing {
                    ProgressView().tint(Theme.background)
                } else {
                    RoundedRectangle(cornerRadius: Metrics.CheckIn.stopGlyphRadius)
                        .fill(Theme.background)
                        .frame(width: Metrics.CheckIn.stopGlyph, height: Metrics.CheckIn.stopGlyph)
                    Text("Stop & save").font(Typography.headline)
                }
            }
            .foregroundStyle(Theme.background)
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.xxl)
            .frame(minHeight: Metrics.minTapTarget)
            .background(Theme.textPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state == .processing)
        .accessibilityLabel("Finish check-in")
    }

    // §04b Save-failed recovery — calm, recovery-framed, no alarm styling: the audio
    // is already buffered (FR-005), so reassure and offer a one-tap re-save (FR-006).
    private var failureRecovery: some View {
        VStack(spacing: Spacing.s) {
            Text("Couldn't save that one.")
                .font(Typography.headline)
                .foregroundStyle(NewLook.inkPrimary)
            Text("Your check-in is safe — tap to try again.")
                .font(Typography.callout)
                .foregroundStyle(NewLook.inkSecondary)
                .multilineTextAlignment(.center)

            Button { viewModel.retrySave() } label: {
                Text("Try again")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, Spacing.m)
                    .padding(.horizontal, Spacing.xxl)
                    .frame(minHeight: Metrics.minTapTarget)
                    .background(Theme.meadowGradient, in: Capsule())
                    .shadow(color: Theme.meadowAmber.opacity(0.34), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Try saving again")

            Button("Discard") { viewModel.discardFailedCapture() }
                .font(Typography.callout)
                .foregroundStyle(NewLook.inkSecondary)
                .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                .accessibilityLabel("Discard this check-in")
        }
        .padding(.horizontal, Spacing.l)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Saved

/// §05 Saved — pure confirmation: a gradient checkmark that settles in with a success haptic,
/// "Captured." in Fraunces, a calm subtitle, and a single Done. No card, no transcribing UI.
private struct CheckInSavedView: View {
    let recording: Recording?
    let onNewCheckIn: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped = false

    var body: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.meadowGradient)
                    .frame(width: Metrics.CheckIn.savedDisc, height: Metrics.CheckIn.savedDisc)
                    .shadow(color: Theme.meadowAmber.opacity(0.3), radius: 20, y: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: Metrics.CheckIn.savedCheck, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(popped ? 1 : 0.6)
            .opacity(popped ? 1 : 0)

            Text("Captured.")
                .font(Typography.title)
                .foregroundStyle(NewLook.inkPrimary)
            Text("That's today's check-in. Talk to you next time.")
                .font(Typography.callout)
                .foregroundStyle(NewLook.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Spacer()
            Button("Done", action: onNewCheckIn)
                .buttonStyle(.primary)
                .padding(.bottom, Spacing.hero)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.l)
        .onAppear {
            Haptics.success()
            guard !reduceMotion else { popped = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { popped = true }
        }
    }
}

#Preview {
    CheckInView(store: .preview, services: .preview)
        .withPreviewEnvironment()
}
