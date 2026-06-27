import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording
    @State private var viewModel: RecordingDetailViewModel

    @State private var editViewModel: ExtractionReviewViewModel?
    @State private var isTranscriptExpanded = false
    @State private var pendingDelete = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss
    @Environment(RecordingStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            VStack(alignment: .leading, spacing: Spacing.l) {
                titleBlock
                if hasSignals { signalGlyphRow }
                ADHDSummarySection(recording: viewModel.recording)
                transcriptSection
                audioCard
                deleteButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
        }
        .background(Theme.background.ignoresSafeArea())
        .medicationBarOverlay()
        // Pushed from the calendar / insights (spec 023): a standard back control returns to the day;
        // the date rides the nav bar and the ⋯ menu carries the quiet Delete affordance.
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(navDate).cardEyebrow()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editViewModel = ExtractionReviewViewModel(
                        recording: viewModel.recording,
                        store: store,
                        onComplete: { [self] _ in editViewModel = nil }
                    )
                } label: {
                    Image(systemName: "pencil")
                        .font(Typography.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(Theme.cardBackground, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
                }
                .accessibilityLabel("Edit check-in")
            }
        }
        .trackScreen("RecordingDetailView")
        .sheet(item: $editViewModel) { vm in
            ExtractionReviewView(viewModel: vm)
        }
        // Delete only after this view is torn down. Deleting a @Model is an
        // @Observable mutation that invalidates every view still reading it;
        // doing it while the sheet is mounted re-renders a detached object and
        // traps in SwiftData (BackingData "detached without resolving faults").
        .onDisappear { if pendingDelete { viewModel.delete() } }
        .confirmationDialog("Delete this check-in?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                pendingDelete = true
                dismiss()
            }
        }
    }

    // MARK: - Title + meta

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(viewModel.recording.displayTitle)
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(metaLine)
                .font(Typography.mono12)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var navDate: String {
        let d = viewModel.recording.createdAt
        return "\(d.formatted(.dateTime.weekday(.abbreviated))) · \(d.formatted(.dateTime.day().month(.wide)))"
    }

    private var metaLine: String {
        let time = viewModel.recording.createdAt.formatted(date: .omitted, time: .shortened)
        return "\(time) · \(viewModel.recording.durationString)"
    }

    // MARK: - Signal glyph summary row

    private var hasSignals: Bool {
        viewModel.recording.mood != nil
            || viewModel.recording.energyLevel != nil
            || viewModel.recording.focusLevel != nil
    }

    private var signalGlyphRow: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            if let mood = viewModel.recording.mood {
                glyphSummaryItem(.mood, level: MoodLevel(name: mood)?.numericValue, label: mood.capitalized)
            }
            // energyLevel / focusLevel are stored as the canonical enum rawValue
            // ("charged", "lockedIn"); match it verbatim and show the human displayLabel.
            if let energy = viewModel.recording.energyLevel, let level = EnergyLevel(rawValue: energy) {
                glyphSummaryItem(.energy, level: level.numericValue, label: level.displayLabel)
            }
            if let focus = viewModel.recording.focusLevel, let level = FocusLevel(rawValue: focus) {
                glyphSummaryItem(.focus, level: level.numericValue, label: level.displayLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func glyphSummaryItem(_ kind: GlyphSignal, level: Int?, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            SignalGlyph(kind, level: level, size: 30, decorative: true)
            Text(label)
                .font(Typography.label)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title): \(label)")
    }

    // MARK: - Transcript

    @ViewBuilder
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    isTranscriptExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Transcript").cardEyebrow()
                    Spacer()
                    transcriptionStatusPill
                    Image(systemName: "chevron.down")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isTranscriptExpanded ? 180 : 0))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isTranscriptExpanded)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isTranscriptExpanded ? "Collapse transcript" : "Expand transcript")

            if viewModel.recording.status == .failed {
                Button("Retry transcription") {
                    viewModel.retryTranscription()
                }
                .buttonStyle(.secondary)
            }

            if isTranscriptExpanded {
                if viewModel.recording.status == .transcribing {
                    HStack(spacing: Spacing.s) {
                        ProgressView().scaleEffect(0.8)
                        Text("Transcribing…")
                            .font(Typography.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, Spacing.s)
                } else if viewModel.recording.fullTranscriptText.isEmpty {
                    Text("No transcript available yet.")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text(viewModel.recording.transcriptText)
                        .font(Typography.body)
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private var transcriptionStatusPill: some View {
        switch viewModel.recording.status {
        case .recorded:
            statusLabel("Recorded", color: Theme.meadowAmber)
        case .transcribing:
            statusLabel("Transcribing", color: Theme.accent)
        case .completed:
            statusLabel("Completed", color: Theme.statusDone)
        case .failed:
            statusLabel("Failed", color: Theme.danger)
        default:
            EmptyView()
        }
    }

    private func statusLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Typography.label)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    // MARK: - Audio (last card)

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Audio").cardEyebrow()
            AudioPlayerView(recording: viewModel.recording, storageService: services.storageService)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Delete (visible destructive action)

    private var deleteButton: some View {
        Button("Delete check-in", role: .destructive) {
            showDeleteConfirm = true
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.danger)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s)
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
