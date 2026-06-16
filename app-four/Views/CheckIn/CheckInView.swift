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
            VStack(alignment: .leading, spacing: 0) {
                headline
                content
            }
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
            TextCheckInComposer(recentMedicationNames: viewModel.recentMedicationNames) { draft in
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

    @ViewBuilder
    private var headline: some View {
        if !headlineText.isEmpty {
            Text(headlineText)
                .font(Typography.display)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var headlineText: String {
        switch viewModel.state {
        case .idle: "How are you?"
        case .recording, .paused: ""
        case .processing: "Saving…"
        case .done: "Check-in saved"
        }
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
        GeometryReader { geo in
            ZStack {
                CrescentRing()
                    .frame(width: ringSide(in: geo), height: ringSide(in: geo))
                VStack(spacing: Spacing.m) {
                    hubOption("Log meds", icon: Icons.medication, tint: Palette.medication) {
                        showMedLogSheet = true
                    }
                    speakButton
                    hubOption("Type note", icon: "square.and.pencil", tint: nil) {
                        showComposer = true
                    }
                }
                .frame(width: ringSide(in: geo) * 0.62)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func ringSide(in geo: GeometryProxy) -> CGFloat {
        max(0, min(geo.size.width - Spacing.l * 2, geo.size.height - Spacing.l, 320))
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
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Radius.button))
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
            ZStack {
                RoundedRectangle(cornerRadius: Radius.button)
                    .fill(.red)
                    .frame(width: 64, height: 64)
                if viewModel.state == .processing {
                    ProgressView().tint(.white)
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.white)
                        .frame(width: 22, height: 22)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state == .processing)
        .accessibilityLabel("Finish check-in")
    }
}

// MARK: - Saved

private struct SavedChip: Identifiable {
    let label: String
    let color: Color
    var id: String { label }
}

private struct CheckInSavedView: View {
    let recording: Recording?
    let onNewCheckIn: () -> Void

    var body: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.statusDone)
            if let recording {
                savedDetails(for: recording)
            }
            Spacer()
            Button("New check-in", action: onNewCheckIn)
                .font(Typography.headline)
                .foregroundStyle(Theme.accent)
                .padding(.bottom, Spacing.hero)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.l)
    }

    @ViewBuilder
    private func savedDetails(for recording: Recording) -> some View {
        let chips = savedChips(for: recording)
        if chips.isEmpty {
            Text("Picking out the details…")
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
        } else {
            Text("We picked these up — tweak any time on the entry.")
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            FlowChips {
                ForEach(chips) { chip in
                    HStack(spacing: Spacing.xs) {
                        Circle().fill(chip.color).frame(width: 8, height: 8)
                        Text(chip.label).font(Typography.caption).foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.horizontal, Spacing.s + 2)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(Theme.cardBackground, in: Capsule())
                }
            }
        }
    }

    private func savedChips(for recording: Recording) -> [SavedChip] {
        var chips: [SavedChip] = []
        if let mood = MoodLevel(name: recording.mood) {
            chips.append(SavedChip(label: mood.displayLabel, color: mood.color))
        }
        if let energy = recording.energyLevel.flatMap({ EnergyLevel(rawValue: $0.lowercased()) }) {
            chips.append(SavedChip(label: energy.displayLabel, color: energy.color))
        }
        if let focus = recording.focusLevel.flatMap({ FocusLevel(rawValue: $0.lowercased()) }) {
            chips.append(SavedChip(label: focus.displayLabel, color: focus.color))
        }
        var seenMeds = Set<String>()
        for event in recording.medicationEvents where seenMeds.insert(event.name.lowercased()).inserted {
            chips.append(SavedChip(label: event.name, color: Palette.medication))
        }
        if let quality = recording.sleepQuality {
            chips.append(SavedChip(label: "\(quality.capitalized) sleep", color: .indigo))
        }
        return chips
    }
}

#Preview {
    CheckInView(store: .preview, services: .preview)
        .withPreviewEnvironment()
}
