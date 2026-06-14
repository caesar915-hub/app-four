import SwiftUI

struct ModelDownloadRow: View {
    let title: String
    let icon: String
    let isInstalled: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onDownload: () -> Void
    let onDelete: () -> Void

    @State private var showingActions = false

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(Typography.body)
            Spacer()
            if isDownloading {
                if downloadProgress > 0 {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Starting…")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Circle()
                    .fill(isInstalled ? Theme.statusDone : Theme.statusInProgress)
                    .frame(width: 8, height: 8)
                Text(isInstalled ? "Installed" : "Not installed")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            if isDownloading { return }
            if isInstalled {
                showingActions = true
            } else {
                onDownload()
            }
        }
        .confirmationDialog(
            "\(title) Options",
            isPresented: $showingActions,
            titleVisibility: .visible
        ) {
            Button("Delete Model", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    VStack(spacing: Spacing.m) {
        ModelDownloadRow(
            title: "Whisper Transcription",
            icon: "waveform",
            isInstalled: true,
            isDownloading: false,
            downloadProgress: 0,
            onDownload: {},
            onDelete: {}
        )
        ModelDownloadRow(
            title: "Whisper Transcription",
            icon: "waveform",
            isInstalled: false,
            isDownloading: true,
            downloadProgress: 0.42,
            onDownload: {},
            onDelete: {}
        )
    }
    .padding(Spacing.l)
}
