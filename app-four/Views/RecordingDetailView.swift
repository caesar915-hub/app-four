import SwiftUI

/// Day Details as the pen draws it (spec 057, `iPhone 17 - 1`): a back pill + relative title +
/// dated subtitle with a `•••` menu (Edit · Transcript · Delete), the three-signal summary card,
/// emotion chips, sleep and side-effect chip rows (kept — D7), the medication rows, and the
/// "Daily check-in" AI card with its inline player, followed by the transcript disclosure.
/// One check-in per page (D18); the floating chrome stays visible (D-N4).
struct RecordingDetailView: View {
    let recording: Recording
    @State private var viewModel: RecordingDetailViewModel

    @State private var editViewModel: ExtractionReviewViewModel?
    @State private var pendingDelete = false
    @State private var showDeleteConfirm = false
    @State private var showTranscript = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(RecordingStore.self) private var store
    @Environment(AppServices.self) private var services

    init(recording: Recording, store: RecordingStore, services: AppServices) {
        self.recording = recording
        self._viewModel = State(initialValue: RecordingDetailViewModel(
            recording: recording,
            store: store,
            services: services
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                header
                signalsSection
                emotionsSection
                sleepSection
                sideEffectsSection
                medicationsSection
                checkInSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Surface.screen.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: Metrics.floatingChromeInset)
        }
        .toolbar(.hidden, for: .navigationBar)
        .trackScreen("RecordingDetailView")
        .sheet(item: $editViewModel) { vm in
            ExtractionReviewView(viewModel: vm)
        }
        // Delete only after this view is torn down: deleting a @Model while a view still reads it
        // re-renders a detached object and traps in SwiftData.
        .onDisappear { if pendingDelete { viewModel.delete() } }
        .confirmationDialog("Delete this check-in?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                pendingDelete = true
                // Dismiss after the dialog's own pop animation, or SwiftUI swallows it.
                Task { @MainActor in dismiss() }
            }
        } message: {
            Text("The recording, its transcript and its signals are removed from this device.")
        }
        .alert("Insights Model Not Downloaded", isPresented: $viewModel.showModelMissing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your note is saved, but mood, energy and focus weren't extracted because the insights model isn't on this device yet. Download it from Settings › AI Models.")
        }
    }

    // MARK: - Header

    private var header: some View {
        NavHeader(title: viewModel.relativeTitle, subtitle: viewModel.subtitle, onBack: { dismiss() }) {
            Menu {
                Button("Edit check-in", systemImage: Icons.note) { openEditor() }
                Button(showTranscript ? "Hide transcript" : "Show transcript", systemImage: Icons.voice) {
                    withAnimation(reduceMotion ? nil : Motion.expand) { showTranscript.toggle() }
                }
                Button("Delete check-in", systemImage: Icons.trash, role: .destructive) { showDeleteConfirm = true }
            } label: {
                Image(systemName: Icons.more)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Accent.deepText)
                    .frame(width: Metrics.navPill, height: Metrics.navPill)
                    .background(Surface.card, in: .circle)
                    .overlay { Circle().strokeBorder(Stroke.chip, lineWidth: Stroke.hairlineWidth) }
                    .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
            }
            .accessibilityLabel("More")
        }
    }

    private func openEditor() {
        editViewModel = ExtractionReviewViewModel(
            recording: viewModel.recording,
            store: store,
            onComplete: { [self] _ in editViewModel = nil }
        )
    }

    // MARK: - Signals (Mood · Focus · Energy — the pen's order)

    private var hasSignals: Bool {
        viewModel.recording.mood != nil
            || viewModel.recording.energyLevel != nil
            || viewModel.recording.focusLevel != nil
    }

    @ViewBuilder private var signalsSection: some View {
        if hasSignals {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("How did you feel?")
                    .font(Typography.question)
                    .foregroundStyle(Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                SignalSummaryCard(
                    mood: MoodLevel(name: viewModel.recording.mood),
                    focus: viewModel.recording.focusLevel.flatMap { FocusLevel(rawValue: $0) },
                    energy: viewModel.recording.energyLevel.flatMap { EnergyLevel(rawValue: $0) }
                )
            }
        }
    }

    // MARK: - Chip rows

    @ViewBuilder private var emotionsSection: some View {
        let emotions = viewModel.recording.decodedEmotions
        if !emotions.isEmpty {
            chipSection("Emotions", words: emotions)
        }
    }

    @ViewBuilder private var sleepSection: some View {
        if let label = sleepLabel {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeading("Sleep")
                HStack(spacing: Spacing.s) {
                    SignalGlyph(.sleep, level: viewModel.recording.decodedSleepLevel?.numericValue, size: Metrics.glyphInline, decorative: true)
                    BillChip(label, style: .solid, large: true)
                }
            }
        }
    }

    private var sleepLabel: String? {
        if let level = viewModel.recording.decodedSleepLevel {
            if let hours = viewModel.recording.sleepLabel { return "\(level.displayLabel) · \(hours)" }
            return level.displayLabel
        }
        return viewModel.recording.sleepLabel
    }

    @ViewBuilder private var sideEffectsSection: some View {
        let effects = viewModel.recording.decodedSideEffects
        if !effects.isEmpty {
            chipSection("Side effects", words: effects)
        }
    }

    private func chipSection(_ title: String, words: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeading(title)
            ChipRow {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    BillChip(word.capitalized, style: .solid, large: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(words.map(\.capitalized).joined(separator: ", "))")
        }
    }

    // MARK: - Medications

    private var medicationEvents: [MedicationEvent] {
        viewModel.recording.medicationEvents.sorted { $0.takenAt < $1.takenAt }
    }

    @ViewBuilder private var medicationsSection: some View {
        if !medicationEvents.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeading("Your medications")
                VStack(spacing: Spacing.m) {
                    ForEach(Array(medicationEvents.enumerated()), id: \.element.id) { index, event in
                        if index > 0 { HairlineDivider() }
                        HStack(spacing: Spacing.m) {
                            MedicationBadge(size: 28)
                            Text(medicationLine(event))
                                .font(Typography.rowLabel)
                                .foregroundStyle(Ink.title)
                            Spacer(minLength: Spacing.s)
                            if !event.taken {
                                Text("Missed")
                                    .font(Typography.status)
                                    .foregroundStyle(Ink.tertiary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .card(.small)
            }
        }
    }

    private func medicationLine(_ event: MedicationEvent) -> String {
        var text = event.dose.map { "\(event.name) · \($0)" } ?? event.name
        let qty = event.quantity ?? 1.0
        if qty == 0.5 { text += " ×½" }
        else if qty != 1.0 {
            let f = qty == qty.rounded() ? String(Int(qty)) : String(format: "%.1f", qty)
            text += " ×\(f)"
        }
        return text
    }

    // MARK: - Daily check-in (AI summary + player + transcript)

    private var isTextCheckIn: Bool { viewModel.recording.audioFileName.hasPrefix("text-") }

    /// The fallback "summary" is the raw transcript echoed back — never present it under the AI byline.
    private var hasSummary: Bool {
        let bullets = viewModel.recording.summaryBullets
        return !bullets.isEmpty && bullets != [viewModel.recording.fullTranscriptText]
    }

    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeading("Daily check-in")
            VStack(alignment: .leading, spacing: Spacing.rowInset) {
                if hasSummary {
                    byline
                    HairlineDivider()
                    ForEach(viewModel.recording.summaryBullets, id: \.self) { bullet in
                        Text(bullet)
                            .font(Typography.narrative)
                            .foregroundStyle(Ink.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    transcriptionState
                }
                if !isTextCheckIn {
                    HairlineDivider()
                    AudioPlayerView(recording: viewModel.recording, storageService: services.storageService)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .raisedCard(.large, padding: Spacing.rowInset)

            transcriptDisclosure
        }
    }

    private var byline: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: Icons.sparkle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Accent.connection)
                .accessibilityHidden(true)
            Text("Written by on-device AI from your voice. Tap Edit to correct.")
                .font(Typography.captionQuiet)
                .foregroundStyle(Ink.placeholder)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// What the card shows before a summary exists: the transcription's state, with the only
    /// recovery path the app has (retry) — kept, D7.
    @ViewBuilder private var transcriptionState: some View {
        switch viewModel.recording.status {
        case .transcribing:
            HStack(spacing: Spacing.s) {
                ProgressView().tint(Accent.primary)
                Text("Transcribing…")
                    .font(Typography.narrative)
                    .foregroundStyle(Ink.tertiary)
            }
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(viewModel.recording.fullTranscriptText.isEmpty ? "Transcription failed." : viewModel.recording.fullTranscriptText)
                    .font(Typography.cardSubtitle)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry transcription") { viewModel.retryTranscription() }
                    .buttonStyle(.outlined(.small))
            }
        default:
            if viewModel.recording.fullTranscriptText.isEmpty {
                Text("Waiting for the voice model — your check-in is saved.")
                    .font(Typography.narrative)
                    .foregroundStyle(Ink.tertiary)
            } else {
                Text(viewModel.recording.transcriptText)
                    .font(Typography.narrative)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var transcriptDisclosure: some View {
        let transcript = viewModel.recording.fullTranscriptText
        if hasSummary, !transcript.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Button {
                    withAnimation(reduceMotion ? nil : Motion.expand) { showTranscript.toggle() }
                } label: {
                    HStack(spacing: Spacing.s) {
                        Text("Transcript")
                            .font(Typography.rowTitle)
                            .foregroundStyle(Ink.primary)
                        Spacer()
                        Image(systemName: showTranscript ? Icons.chevronUp : Icons.chevronDown)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Accent.primaryText)
                    }
                    .frame(minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(showTranscript ? [.isSelected] : [])
                .accessibilityValue(showTranscript ? "Expanded" : "Collapsed")

                if showTranscript {
                    Text(transcript)
                        .font(Typography.narrative)
                        .foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .card(.small, padding: Spacing.cardInset)
        }
    }
}

// MARK: - Signal summary card

/// The pen's three-column signal card: glyph · label · value word · 86 × 4 bar, split by hairlines.
private struct SignalSummaryCard: View {
    let mood: MoodLevel?
    let focus: FocusLevel?
    let energy: EnergyLevel?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.m) { columns }
            } else {
                HStack(alignment: .top, spacing: 0) { columns }
            }
        }
        .frame(maxWidth: .infinity)
        .card(.small, padding: Spacing.l)
    }

    @ViewBuilder private var columns: some View {
        column(.mood, level: mood?.numericValue, word: mood?.displayLabel, color: mood?.wordColor ?? Ink.tertiary)
        separator
        column(.focus, level: focus?.numericValue, word: focus?.displayLabel, color: Accent.focusText)
        separator
        column(.energy, level: energy?.numericValue, word: energy?.displayLabel, color: Accent.energyText)
    }

    @ViewBuilder private var separator: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HairlineDivider()
        } else {
            Rectangle().fill(Stroke.separator).frame(width: Stroke.hairlineWidth, height: 80)
        }
    }

    private func column(_ kind: GlyphSignal, level: Int?, word: String?, color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            SignalGlyph(kind, level: level, size: 32, decorative: true)
            Text(kind.title)
                .font(Typography.rowLabel)
                .foregroundStyle(Ink.primary)
            Text(word ?? "—")
                .font(Typography.status)
                .foregroundStyle(word == nil ? Ink.tertiary : color)
            SignalMiniBar(level: level ?? 0, color: color)
                .frame(maxWidth: 86)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word.map { "\(kind.title): \($0)" } ?? "\(kind.title): not captured")
    }
}

#Preview {
    NavigationStack {
        RecordingDetailView(
            recording: PreviewData.recordings[0],
            store: .preview,
            services: .preview
        )
    }
    .withPreviewEnvironment()
}
