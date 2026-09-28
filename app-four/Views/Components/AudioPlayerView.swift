import SwiftUI

/// The pen's inline player (DESIGN.md §8.24): a 28-pt violet play disc, quantised waveform bars,
/// and the duration in one small caption. Lives inside the Day Details AI card.
struct AudioPlayerView: View {
    let recording: Recording
    @State private var viewModel: AudioPlaybackViewModel

    init(recording: Recording, storageService: AudioFileStorageService) {
        self.recording = recording
        self._viewModel = State(initialValue: AudioPlaybackViewModel(recording: recording, storageService: storageService))
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            playPauseButton

            PlaybackWaveformBars(
                seed: recording.id.uuidString,
                progress: viewModel.duration > 0 ? viewModel.currentTime / viewModel.duration : 0,
                onSeek: { fraction in
                    viewModel.seek(to: fraction * max(viewModel.duration, 0.001))
                }
            )

            Text(timeString(viewModel.currentTime))
                .font(Typography.micro)
                .monospacedDigit()
                .foregroundStyle(Ink.secondary)
                .frame(minWidth: 36, alignment: .trailing)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    private var playPauseButton: some View {
        Button {
            switch viewModel.state {
            case .playing:
                viewModel.pause()
            case .idle, .paused, .finished, .error:
                viewModel.play()
            case .loading:
                break
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Ink.onAccent)
                .frame(width: 28, height: 28)
                .background(Accent.violet, in: .circle)
                .frame(minWidth: Metrics.minTapTarget, minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch viewModel.state {
        case .playing: Icons.pause
        case .loading: Icons.more
        case .idle, .paused, .finished, .error: Icons.play
        }
    }

    private var accessibilityLabel: String {
        switch viewModel.state {
        case .playing: "Pause"
        case .loading: "Loading"
        case .idle, .paused, .finished, .error: "Play"
        }
    }

    /// One duration format app-wide ("3:24", as `Recording.formattedDuration`) — UI-54.
    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        AudioPlayerView(recording: PreviewData.recordings[0], storageService: AppServices.preview.storageService)
        AudioPlayerView(recording: PreviewData.recordings[1], storageService: AppServices.preview.storageService)
    }
    .padding()
}
