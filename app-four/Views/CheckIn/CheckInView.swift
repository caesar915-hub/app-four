import SwiftUI

struct CheckInView: View {
    @State private var viewModel: CheckInViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(MedicationBarViewModel.self) private var medicationBarViewModel
    @Binding var shouldAutoStart: Bool

    @State private var showMedLogSheet = false
    @State private var showComposer = false

    init(store: RecordingStore, services: AppServices, shouldAutoStart: Binding<Bool> = .constant(false)) {
        _viewModel = State(wrappedValue: CheckInViewModel(store: store, services: services))
        _shouldAutoStart = shouldAutoStart
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.state)
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
                viewModel.saveTextCheckIn(draft)
            }
        }
        .alert("Microphone Access Required", isPresented: $viewModel.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Whisper Notes needs microphone access to record voice notes. Enable it in Settings.")
        }
        .alert("Not Enough Storage", isPresented: $viewModel.lowDiskSpace) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Whisper Notes needs at least 50 MB of free space to record. Free up some space and try again.")
        }
    }

    private func consumeAutoStart() {
        guard shouldAutoStart else { return }
        shouldAutoStart = false
        if viewModel.state == .done { viewModel.reset() }
        viewModel.startRecording()
    }

    private var todayDate: String {
        Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            hub
        // .processing keeps the recording stage on screen (crescent spinning, stop
        // shows a spinner) for the brief save window; the headline reads "Saving…".
        case .recording, .paused, .processing:
            recordingStage
        case .done:
            CheckInSavedView(recording: viewModel.lastSavedRecording) {
                viewModel.reset()
            }
        }
    }

    // MARK: Hub

    private var hub: some View {
        VStack(spacing: Spacing.l) {
            VStack(spacing: Spacing.xs) {
                Text(todayDate)
                    .font(Typography.label)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
                Text("Ready when\nyou are.")
                    .font(Typography.title)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.top, Spacing.xl)

            Spacer()
            CrescentRing()
                .frame(width: 200, height: 200)
            Spacer()

            VStack(spacing: Spacing.s) {
                speakButton
                HStack(spacing: Spacing.s) {
                    hubOption("Log meds", icon: Icons.medication, tint: Palette.medication) {
                        showMedLogSheet = true
                    }
                    hubOption("Type note", icon: "square.and.pencil", tint: nil) {
                        showComposer = true
                    }
                }
            }
            .padding(.bottom, Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.l)
    }

    private var speakButton: some View {
        Button {
            viewModel.startRecording()
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: "mic.fill")
                Text("Speak check-in").font(Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
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
                Image(systemName: icon).foregroundStyle(tint ?? Theme.textPrimary)
                Text(label).font(Typography.headline).foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Recording

    private var recordingStage: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                promptProgressBar

                Spacer()

                heroPrompt
                    .padding(.horizontal, Spacing.l)

                Spacer()

                ZStack {
                    CrescentRing(isActive: true)
                        .frame(width: 260, height: 260)
                    VStack(spacing: Spacing.m) {
                        Text(viewModel.timeString)
                            .font(Typography.timer)
                            .foregroundStyle(Theme.textPrimary)
                        stopButton
                        Button("Cancel") { viewModel.cancelRecording() }
                            .font(Typography.callout)
                            .foregroundStyle(Theme.textSecondary)
                            .accessibilityLabel("Cancel recording")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.l)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var promptProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.textSecondary.opacity(0.15))
                Rectangle()
                    .fill(Theme.accent.opacity(0.5))
                    .frame(width: geo.size.width * viewModel.promptProgress)
                    .animation(reduceMotion ? nil : .linear(duration: 0.1), value: viewModel.promptProgress)
                    // New identity per prompt so the per-window reset snaps to 0
                    // instead of animating backwards across the wrap.
                    .id(viewModel.currentPromptIndex)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var heroPrompt: some View {
        VStack(spacing: Spacing.s) {
            Text(viewModel.currentPrompt.question)
                .font(Typography.display)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .id(viewModel.currentPromptIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            Text(viewModel.currentPrompt.hint)
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
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
        HStack(spacing: 6) {
            ForEach(0..<CheckInViewModel.nudgePrompts.count, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentPromptIndex
                          ? Theme.accent
                          : Theme.textSecondary.opacity(0.3))
                    .frame(width: 6, height: 6)
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
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.background)
                        .frame(width: 11, height: 11)
                    Text("Stop & save").font(Typography.headline)
                }
            }
            .foregroundStyle(Theme.background)
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.xxl)
            .background(Theme.textPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state == .processing)
        .accessibilityLabel("Finish check-in")
    }
}

// MARK: - Saved

/// §05 Saved — pure confirmation: a gradient checkmark that pops, "Captured." in Fraunces,
/// a calm subtitle, and Done / Check in again. No card, no transcribing UI (locked decision).
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
                    .frame(width: 78, height: 78)
                    .shadow(color: Theme.meadowAmber.opacity(0.3), radius: 20, y: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(popped ? 1 : 0.6)
            .opacity(popped ? 1 : 0)

            Text("Captured.")
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
            Text("That's today's check-in. Talk to you next time.")
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Spacer()
            VStack(spacing: Spacing.s) {
                Button("Done", action: onNewCheckIn).buttonStyle(.primary)
                Button("Check in again", action: onNewCheckIn).buttonStyle(.secondary)
            }
            .padding(.bottom, Spacing.hero)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.l)
        .onAppear {
            guard !reduceMotion else { popped = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { popped = true }
        }
    }
}

#Preview {
    CheckInView(store: .preview, services: .preview)
        .withPreviewEnvironment()
}
