import SwiftUI

struct ModelDownloadRow: View {
    let title: String
    let icon: String
    let isInstalled: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    /// Plain-language cause copy from `SettingsViewModel.message(for:)`; `nil` when
    /// there is no active error.
    let errorMessage: String?
    /// True only for a cellular-metered block, so the row offers a one-tap allow.
    let canAllowCellular: Bool
    let onDownload: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void
    let onAllowCellular: () -> Void
    let onDelete: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var showingActions = false

    private var hasError: Bool { errorMessage != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Label(title, systemImage: icon)
                    .font(Typography.body)
                Spacer()
                trailingStatus
            }

            if hasError, let errorMessage {
                errorBlock(errorMessage)
            } else if !isInstalled && !isDownloading {
                Text("~150 MB · Wi-Fi recommended")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .contentShape(.rect)
        .onTapGesture {
            guard !isDownloading, !hasError else { return }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityActions { accessibilityActions }
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if isDownloading {
            if downloadProgress > 0 {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                Text("\(Int(downloadProgress * 100))%")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Starting…")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typography.caption.weight(.medium))
                .foregroundStyle(Theme.accent)
        } else if hasError {
            Circle()
                .fill(Theme.danger)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(isInstalled ? Theme.statusDone : Theme.statusInProgress)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(isInstalled ? "Installed" : "Not installed")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private func errorBlock(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(message)
                .font(Typography.caption)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
            // Reflows to extra rows at large Dynamic Type so the three actions never
            // clip off a fixed single-line HStack.
            FlowLayout(spacing: Spacing.s) {
                ghostPill("Try again", action: onRetry)
                if canAllowCellular {
                    ghostPill("Allow on cellular", action: onAllowCellular)
                    ghostPill("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
        }
    }

    private func ghostPill(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typography.caption.weight(.medium))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .frame(minHeight: Metrics.minTapTarget)
                .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var accessibilityLabel: String {
        if isDownloading {
            let pct = downloadProgress > 0 ? "\(Int(downloadProgress * 100)) percent" : "starting"
            return "\(title), downloading \(pct)"
        }
        if let errorMessage {
            return "\(title), \(errorMessage)"
        }
        if isInstalled {
            return "\(title), installed"
        }
        return "\(title), not installed. About 150 megabytes, Wi-Fi recommended. Double tap to download."
    }

    @ViewBuilder
    private var accessibilityActions: some View {
        if isDownloading {
            Button("Cancel", action: onCancel)
        } else if hasError {
            Button("Try again", action: onRetry)
            if canAllowCellular {
                Button("Allow on cellular", action: onAllowCellular)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        } else if isInstalled {
            Button("Delete model", action: onDelete)
        }
    }
}

#Preview {
    VStack(spacing: Spacing.m) {
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: "waveform",
            isInstalled: true,
            isDownloading: false,
            downloadProgress: 0,
            errorMessage: nil,
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: "waveform",
            isInstalled: false,
            isDownloading: false,
            downloadProgress: 0,
            errorMessage: nil,
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: "waveform",
            isInstalled: false,
            isDownloading: true,
            downloadProgress: 0.42,
            errorMessage: nil,
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: "waveform",
            isInstalled: false,
            isDownloading: false,
            downloadProgress: 0,
            errorMessage: "No connection. Reconnect to the internet, then try again.",
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: "waveform",
            isInstalled: false,
            isDownloading: false,
            downloadProgress: 0,
            errorMessage: "You're on cellular and downloads over cellular are off. Switch to Wi-Fi, or allow cellular below.",
            canAllowCellular: true,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
    }
    .padding(Spacing.l)
}
