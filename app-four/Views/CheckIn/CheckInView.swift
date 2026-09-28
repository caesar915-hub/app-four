import SwiftUI

/// The check-in flow as the pen draws it (spec 057, `iPhone 17 - 4 / 5 / 6`): the hub (A) is the
/// Check In tab root with the floating chrome; capturing (B) and the saved screen (C) hide the
/// chrome and the medication bar. One anchored ring carries all three states as a three-step
/// flow indicator (⅓ · ⅔ · full — D-R1); the hub's stack and the capture controls sit inside it.
struct CheckInView: View {
    @State private var viewModel: CheckInViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(MedicationBarViewModel.self) private var medicationBarViewModel
    @Binding var shouldAutoStart: Bool

    @State private var showMedLogSheet = false
    @State private var showComposer = false
    @State private var showCapApproachCue = false

    init(store: RecordingStore, services: AppServices, shouldAutoStart: Binding<Bool> = .constant(false)) {
        _viewModel = State(wrappedValue: CheckInViewModel(store: store, services: services))
        _shouldAutoStart = shouldAutoStart
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenContainer(title: "", showsMedicationBar: viewModel.state == .idle, scrollable: false,
                        reservesFloatingChrome: viewModel.state == .idle) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : Motion.smooth, value: viewModel.state)
        }
        // The floating tab bar leaves while capturing and while the saved screen is up (D5).
        .hidesFloatingChrome(viewModel.state != .idle)
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
        .alert("Voice Processing Model", isPresented: $viewModel.showModelDownloadPrompt) {
            Button("Download") {
                viewModel.startRecordingWithDownload()
            }
            Button("Not Now", role: .cancel) {
                viewModel.startRecordingWithoutDownload()
            }
        } message: {
            Text("To transcribe your voice accurately and securely on-device, Squirl needs to download a small language model (approx. 40MB). It will take a minute on Wi-Fi.")
        }
        .alert("Not Enough Storage for Model", isPresented: $viewModel.showStorageError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Squirl needs at least 150 MB of free space to install the language model. Free up some space and try again.")
        }
        .alert("Model Download Failed", isPresented: $viewModel.showDownloadFailedError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Something went wrong while downloading the language model. Please check your connection and try again.")
        }
        .alert("Not Enough Memory", isPresented: $viewModel.showMemoryError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Squirl couldn't generate insights because your device is low on memory. Your note is saved — close some apps, then open the check-in to try again.")
        }
        .alert("Insights Model Not Downloaded", isPresented: $viewModel.showModelMissing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your note is saved, but mood, energy and focus weren't extracted because the insights model isn't on this device yet. Download it from Settings › AI Models.")
        }
    }

    /// Posts a VoiceOver announcement (FR-010/012). A no-op when VoiceOver is off.
    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    private func consumeAutoStart() {
        guard shouldAutoStart else { return }
        shouldAutoStart = false
        switch viewModel.state {
        case .recording, .processing: return   // already capturing — never double-start (FR-016)
        case .done: viewModel.reset(); viewModel.startRecording()
        case .idle: viewModel.startRecording()
        }
    }

    private var todayDate: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .done:
            CheckInSavedView { viewModel.reset() }
        default:
            captureStage
        }
    }

    // MARK: - Capture stage (hub + capturing share one anchored ring)

    private var isCapturing: Bool { viewModel.state != .idle }

    private var captureStage: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityStage
            } else {
                anchoredStage
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .onChange(of: viewModel.saveFailed) { _, failed in
            if failed { Haptics.error() }
        }
        // FR-016: structured task lifetime tied to the view.
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

    /// D-R2 (c): the disc brightens with the mic level while recording — live-mic feedback without
    /// rotating the arc. Static under Reduce Motion.
    @ViewBuilder private func levelGlow(diameter: CGFloat) -> some View {
        if viewModel.state == .recording, !reduceMotion {
            Circle()
                .fill(Accent.primary.opacity(Double(viewModel.audioLevel) * 0.08))
                .padding(diameter * Metrics.CheckIn.ringStrokeRatio)
                .animation(.linear(duration: 0.1), value: viewModel.audioLevel)
                .allowsHitTesting(false)
        }
    }

    /// The pen's composition: the ring anchored mid-stage, the header pinned above it and the
    /// hint below, so hub → capturing swaps content without the ring moving.
    private var anchoredStage: some View {
        GeometryReader { geo in
            let ringSize = min(geo.size.width, Metrics.CheckIn.ringDiameter)
            ZStack {
                CheckInRing(progress: viewModel.flowProgress, diameter: ringSize)
                    .overlay { levelGlow(diameter: ringSize) }
                    .overlay { ringCentre(ringSize: ringSize) }

                VStack(spacing: 0) {
                    if isCapturing { capturingHeader } else { hubHeader }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    hintLine
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// Accessibility sizes: the same pieces in reading order, scrolling — once the title wraps
    /// to four lines the anchored layers overlap, so the stage becomes a column instead.
    private var accessibilityStage: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if isCapturing { capturingHeader } else { hubHeader }
                CheckInRing(progress: viewModel.flowProgress, diameter: Metrics.CheckIn.ringAccessibilityDiameter)
                    .overlay { levelGlow(diameter: Metrics.CheckIn.ringAccessibilityDiameter) }
                ringCentre(ringSize: Metrics.CheckIn.ringAccessibilityDiameter)
                hintLine
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func ringCentre(ringSize: CGFloat) -> some View {
        if isCapturing {
            if viewModel.saveFailed { failureRecovery } else { capturingCentre(ringSize: ringSize) }
        } else {
            hubStack
        }
    }

    // MARK: - Hub (A)

    private var hubHeader: some View {
        VStack(spacing: Spacing.s) {
            Text(todayDate)
                .font(Typography.navSubtitle)
                .foregroundStyle(Ink.nav)
            Text("How do you feel?")
                .font(Typography.pageTitle)
                .foregroundStyle(Ink.title)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Take a moment to check in with yourself")
                .font(Typography.pageSubtitle)
                .foregroundStyle(Ink.primary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    private var hubStack: some View {
        VStack(spacing: Spacing.s) {
            Button {
                viewModel.startRecording()
            } label: {
                Label("Speak check-in", systemImage: Icons.mic)
            }
            .buttonStyle(.filled)
            .accessibilityLabel("Start voice check-in")

            Button {
                showMedLogSheet = true
            } label: {
                HStack(spacing: Spacing.s) {
                    CapsuleGlyph(color: Accent.violet).frame(width: 18, height: 18)
                    Text("Log medications")
                }
            }
            .buttonStyle(.outlined(tint: .violet))

            Button {
                showComposer = true
            } label: {
                Label("Write notes", systemImage: Icons.note)
            }
            .buttonStyle(.outlined)
        }
    }

    // MARK: - Capturing (B)

    private var capturingHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            NavPill(.back) { viewModel.cancelRecording() }
                .accessibilityLabel("Cancel recording")
            promptCard
        }
        .padding(.top, Spacing.s)
    }

    /// The pen's prompt card: question, hint, five dots (active dot larger, D14) and the kept
    /// hairline countdown (spec 016 — the only cue a time-blind user gets before a prompt advances).
    private var promptCard: some View {
        VStack(spacing: Spacing.m) {
            Text(viewModel.currentPrompt.question)
                .font(Typography.promptTitle)
                .foregroundStyle(Ink.title)
                .multilineTextAlignment(.center)
                .id(viewModel.currentPromptIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            Text(viewModel.currentPrompt.hint)
                .font(Typography.promptSubtitle)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)
                .id("hint-\(viewModel.currentPromptIndex)")
                .transition(.opacity)
            VStack(spacing: Spacing.s) {
                promptDots
                promptProgressLine
            }
        }
        .frame(maxWidth: .infinity)
        .raisedCard(.medium)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: viewModel.currentPromptIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(viewModel.currentPrompt.question) \(viewModel.currentPrompt.hint)")
    }

    private var promptDots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<CheckInViewModel.nudgePrompts.count, id: \.self) { index in
                let active = index == viewModel.currentPromptIndex
                Circle()
                    .fill(active ? Accent.primary : Surface.ringTrack)
                    .frame(width: active ? 8 : 6, height: active ? 8 : 6)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private var promptProgressLine: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Stroke.separator)
                Capsule()
                    .fill(Accent.primary)
                    .frame(width: geo.size.width * viewModel.promptProgress)
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: viewModel.promptProgress)
                    // New identity per prompt so the per-window reset snaps to 0
                    // instead of animating backwards across the wrap.
                    .id(viewModel.currentPromptIndex)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }

    private func capturingCentre(ringSize: CGFloat) -> some View {
        VStack(spacing: Spacing.s) {
            // FR-011: the timer reads as one live-region status, throttled to whole seconds.
            Text(viewModel.timeString)
                .font(Typography.timerHero)
                .foregroundStyle(Ink.title)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: ringSize * (1 - 2 * Metrics.CheckIn.ringStrokeRatio) - Spacing.l)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Recording, \(viewModel.timeString) elapsed")
                .accessibilityAddTraits(.updatesFrequently)

            Button {
                viewModel.stopRecording()
            } label: {
                HStack(spacing: Spacing.s) {
                    if viewModel.state == .processing {
                        ProgressView().tint(Ink.onAccent)
                    } else {
                        RoundedRectangle(cornerRadius: Metrics.CheckIn.stopGlyphRadius)
                            .fill(Ink.onAccent)
                            .frame(width: Metrics.CheckIn.stopGlyph, height: Metrics.CheckIn.stopGlyph)
                    }
                    Text("Stop & save")
                }
            }
            .buttonStyle(.filled)
            .disabled(viewModel.state == .processing)
            .accessibilityLabel("Finish check-in")

            Button("Cancel") { viewModel.cancelRecording() }
                .buttonStyle(.outlined)
                .accessibilityLabel("Cancel recording")
        }
    }

    /// The line under the ring: the hub's reassurance, or the capture hint — swapped for the
    /// calm "wrapping up soon" cue on the approach to the cap (FR-014, no red, no ticking bar).
    private var hintLine: some View {
        Text(hintText)
            .font(Typography.rowLabel)
            .foregroundStyle(Ink.nav)
            .multilineTextAlignment(.center)
            .contentTransition(.opacity)
            .padding(.bottom, Spacing.xxl)
            .accessibilityHidden(isCapturing && !showCapApproachCue)
    }

    private var hintText: String {
        guard isCapturing else { return "A few words are enough" }
        return showCapApproachCue ? "Wrapping up soon" : "Take your time, speak freely."
    }

    // §04b Save-failed recovery — calm, recovery-framed, no alarm styling: the audio is already
    // buffered (FR-005), so reassure and offer a one-tap re-save (FR-006).
    private var failureRecovery: some View {
        VStack(spacing: Spacing.s) {
            Text("Couldn't save that one.")
                .font(Typography.sectionTitle)
                .foregroundStyle(Ink.primary)
            Text("Your check-in is safe — tap to try again.")
                .font(Typography.cardSubtitle)
                .foregroundStyle(Ink.tertiary)
                .multilineTextAlignment(.center)

            Button("Try again") { viewModel.retrySave() }
                .buttonStyle(.filled)
                .accessibilityLabel("Try saving again")

            Button("Discard") { viewModel.discardFailedCapture() }
                .buttonStyle(.underline)
                .accessibilityLabel("Discard this check-in")
        }
        .padding(.horizontal, Spacing.l)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Saved (C)

/// The pen's saved screen: the ring completes to full around a sharp green check tile (D-K1),
/// "Check-in saved", a two-line reassurance, and one full-width exit back to the hub (D5).
private struct CheckInSavedView: View {
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                NavPill(.back, action: onDone)
                Spacer()
            }
            .padding(.top, Spacing.s)

            Spacer(minLength: Spacing.l)

            VStack(spacing: Spacing.hero + Spacing.s) {
                ZStack {
                    CheckInRing(progress: settled ? 1 : 2.0 / 3.0, diameter: Metrics.CheckIn.ringSavedDiameter)
                    Rectangle()
                        .fill(Accent.primary)
                        .frame(width: Metrics.CheckIn.checkTile, height: Metrics.CheckIn.checkTile)
                        .overlay {
                            Image(systemName: Icons.check)
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(Ink.onAccent)
                        }
                        .scaleEffect(settled ? 1 : 0.6)
                        .opacity(settled ? 1 : 0)
                }
                .accessibilityHidden(true)

                VStack(spacing: Spacing.s) {
                    Text("Check-in saved")
                        .font(Typography.pageTitle)
                        .foregroundStyle(Ink.title)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("A moment for yourself, captured.\nSee you at your next check-in.")
                        .font(Typography.rowLabel)
                        .foregroundStyle(Ink.primary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer(minLength: Spacing.l)

            Button("Go back home", action: onDone)
                .buttonStyle(.filled(fullWidth: true))
                .padding(.bottom, Spacing.l)
        }
        .padding(.horizontal, Spacing.gutter)
        .onAppear {
            Haptics.success()
            guard !reduceMotion else { settled = true; return }
            withAnimation(Motion.settle) { settled = true }
        }
    }
}

#Preview {
    CheckInView(store: .preview, services: .preview)
        .withPreviewEnvironment()
}
