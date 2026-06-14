import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording
    @State private var viewModel: RecordingDetailViewModel

    @State private var editViewModel: ExtractionReviewViewModel?
    @State private var isTranscriptExpanded = false
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
            VStack(spacing: Spacing.l) {
                headerCard
                ADHDSummarySection(
                    recording: viewModel.recording,
                    onRegenerate: { Task { await viewModel.regenerateSummary() } }
                )
                transcriptSection
                audioPlayerSection
                actionButtons
            }
            .padding(Spacing.l)
        }
        .medicationBarOverlay()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("RecordingDetailView")
        .sheet(item: $editViewModel) { vm in
            ExtractionReviewView(viewModel: vm)
        }
    }

    // MARK: - Header card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                Circle()
                    .fill(viewModel.recording.moodColor)
                    .frame(width: 44, height: 44)

                Text(viewModel.recording.title)
                    .font(Typography.title)

                Spacer()

                Button {
                    editViewModel = ExtractionReviewViewModel(
                        recording: viewModel.recording,
                        store: store,
                        onComplete: { [self] _ in editViewModel = nil }
                    )
                } label: {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Edit extracted fields")
            }

            HStack(spacing: Spacing.xs) {
                Text(viewModel.recording.createdAt, style: .date)
                Text(viewModel.recording.createdAt, style: .time)
                Text("·")
                Text(viewModel.recording.durationString)
                    .monospacedDigit()
            }
            .font(Typography.body)
            .foregroundStyle(.secondary)
        }
        .card(padding: Spacing.xxl)
    }

    // MARK: - Transcript section

    @ViewBuilder
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTranscriptExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Transcript")
                        .font(Typography.headline)
                    Spacer()
                    transcriptionStatusPill
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isTranscriptExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isTranscriptExpanded)
                }
            }
            .buttonStyle(.plain)

            if isTranscriptExpanded {
                if viewModel.recording.status == .transcribing {
                    HStack(spacing: Spacing.s) {
                        ProgressView().scaleEffect(0.8)
                        Text("Transcribing with Whisper…")
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Spacing.s)
                } else if viewModel.recording.fullTranscriptText.isEmpty {
                    Text("No transcript available yet.")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text(viewModel.recording.transcriptText)
                        .font(Typography.body)
                        .lineSpacing(4)
                }
            }
        }
        .card(padding: Spacing.xxl)
    }

    private var audioPlayerSection: some View {
        AudioPlayerView(recording: viewModel.recording, storageService: services.storageService)
    }

    // MARK: - Status pill

    @ViewBuilder
    private var transcriptionStatusPill: some View {
        switch viewModel.recording.status {
        case .recorded:
            statusLabel("Recorded", color: .orange)
        case .transcribing:
            statusLabel("Transcribing", color: .blue)
        case .completed:
            statusLabel("Completed", color: .green)
        case .failed:
            statusLabel("Failed", color: .red)
        default:
            EmptyView()
        }
    }

    private func statusLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Typography.caption)
            .fontWeight(.medium)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        Button(role: .destructive) {
            viewModel.delete()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Recording")
            }
            .frame(maxWidth: .infinity)
            .card()
        }
        .accessibilityLabel("Delete recording")
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
