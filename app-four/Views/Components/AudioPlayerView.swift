import SwiftUI

struct AudioPlayerView: View {
    let recording: Recording
    @State private var viewModel: AudioPlaybackViewModel

    init(recording: Recording, storageService: AudioFileStorageService) {
        self.recording = recording
        self._viewModel = State(initialValue: AudioPlaybackViewModel(recording: recording, storageService: storageService))
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            PlaybackWaveformBars(
                seed: recording.id.uuidString,
                progress: viewModel.duration > 0 ? viewModel.currentTime / viewModel.duration : 0,
                onSeek: { fraction in
                    viewModel.seek(to: fraction * max(viewModel.duration, 0.001))
                }
            )

            Text(timeString(viewModel.currentTime))
                .font(.system(.subheadline, design: .monospaced))
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)

            playPauseButton
                .frame(width: 40, height: 40)
        }
        .padding(.vertical, Spacing.m)
        .padding(.horizontal, Spacing.l)
        .background(Color(.secondarySystemBackground))
        .clipShape(.capsule)
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
                .font(Typography.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray3), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch viewModel.state {
        case .playing: return "pause.fill"
        case .loading: return "ellipsis"
        case .idle, .paused, .finished, .error: return "play.fill"
        }
    }

    private var accessibilityLabel: String {
        switch viewModel.state {
        case .playing: return "Pause"
        case .loading: return "Loading"
        case .idle, .paused, .finished, .error: return "Play"
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(time)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        AudioPlayerView(recording: PreviewData.recordings[0], storageService: AppServices.preview.storageService)
        AudioPlayerView(recording: PreviewData.recordings[1], storageService: AppServices.preview.storageService)
    }
    .padding()
}
