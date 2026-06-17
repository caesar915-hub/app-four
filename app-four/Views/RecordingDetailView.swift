import SwiftUI

/// Lightweight Identifiable wrapper so a recording id can drive `.sheet(item:)`.
struct RecordingDetailRef: Identifiable { let id: UUID }

struct RecordingDetailView: View {
    let recording: Recording
    @State private var viewModel: RecordingDetailViewModel

    @State private var editViewModel: ExtractionReviewViewModel?
    @State private var isTranscriptExpanded = false
    @State private var pendingDelete = false
    @Environment(\.dismiss) private var dismiss
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
            VStack(alignment: .leading, spacing: Spacing.l) {
                titleBlock
                if hasSignals { signalGlyphRow }
                ADHDSummarySection(
                    recording: viewModel.recording,
                    onRegenerate: { Task { await viewModel.regenerateSummary() } }
                )
                transcriptSection
                audioCard
                editButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.l)
        }
        .background(Theme.background.ignoresSafeArea())
        .medicationBarOverlay()
        // §07: no back button (navigate back by swipe-left); the date rides the nav bar,
        // and the ⋯ menu carries the quiet Delete affordance.
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(navDate)
                    .font(Typography.label)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Theme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        pendingDelete = true
                        dismiss()
                    } label: {
                        Label("Delete check-in", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("More options")
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
                glyphSummaryItem(.mood, level: MoodLevel(name: mood)?.numericValue, label: mood)
            }
            if let energy = viewModel.recording.energyLevel {
                glyphSummaryItem(.energy, level: EnergyLevel(rawValue: energy.lowercased())?.numericValue, label: energy)
            }
            if let focus = viewModel.recording.focusLevel {
                glyphSummaryItem(.focus, level: FocusLevel(rawValue: focus.lowercased())?.numericValue, label: focus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func glyphSummaryItem(_ kind: GlyphSignal, level: Int?, label: String) -> some View {
        VStack(spacing: Spacing.xs) {
            SignalGlyph(kind, level: level, size: 26, decorative: true)
            Text(label.capitalized)
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
                withAnimation(.easeInOut(duration: 0.2)) {
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
                        .animation(.easeInOut(duration: 0.2), value: isTranscriptExpanded)
                }
            }
            .buttonStyle(.plain)

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

    // MARK: - Edit (single primary action)

    private var editButton: some View {
        Button("Edit check-in") {
            editViewModel = ExtractionReviewViewModel(
                recording: viewModel.recording,
                store: store,
                onComplete: { [self] _ in editViewModel = nil }
            )
        }
        .buttonStyle(.primary)
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
