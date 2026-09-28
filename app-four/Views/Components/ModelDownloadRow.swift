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
            mainRow
            subline
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

    /// The install switch mirrors the *filesystem* truth (`isInstalled`) and drives the existing
    /// download / delete actions — this flips the visual, not the behavior. ON downloads at once;
    /// OFF opens the same delete confirmation, and because the binding reads `isInstalled`
    /// (unchanged until the user confirms), cancelling the dialog leaves the switch on.
    private var installBinding: Binding<Bool> {
        Binding(
            get: { isInstalled },
            set: { wantsInstalled in
                if wantsInstalled { onDownload() } else { showingActions = true }
            }
        )
    }

    @ViewBuilder
    private var mainRow: some View {
        if isDownloading || hasError {
            HStack {
                titleLabel
                Spacer()
                trailingStatus
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityActions { accessibilityActions }
        } else {
            Toggle(isOn: installBinding) {
                titleLabel
            }
            .frame(minHeight: Metrics.minTapTarget)
            .accessibilityHint(isInstalled
                ? "Removes the on-device transcription model"
                : "Downloads the on-device transcription model, about 150 megabytes")
            .tint(Accent.primaryFill)
        }
    }

    private var titleLabel: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Accent.primaryText)
                .frame(width: 21, height: 21)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.rowLabel)
                .foregroundStyle(Ink.primary)
        }
    }

    @ViewBuilder
    private var subline: some View {
        if hasError, let errorMessage {
            errorBlock(errorMessage)
        } else if !isInstalled && !isDownloading {
            Text("~150 MB · Wi-Fi recommended")
                .font(Typography.captionMedium)
                .foregroundStyle(Ink.tertiary)
        }
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if isDownloading {
            if downloadProgress > 0 {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(.linear)
                    .tint(Accent.primaryFill)
                    .frame(width: 80)
                Text("\(Int(downloadProgress * 100))%")
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.tertiary)
                    .monospacedDigit()
            } else {
                ProgressView()
                    .tint(Accent.primaryFill)
                    .scaleEffect(0.8)
                Text("Starting…")
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.tertiary)
            }
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(Typography.captionMedium)
                .foregroundStyle(Accent.primaryText)
        } else if hasError {
            Circle()
                .fill(Ink.destructive)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(isInstalled ? Accent.primaryFill : Ink.tertiary)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(isInstalled ? "Installed" : "Not installed")
                .font(Typography.captionMedium)
                .foregroundStyle(isInstalled ? Accent.primaryText : Ink.tertiary)
        }
    }

    @ViewBuilder
    private func errorBlock(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(message)
                .font(Typography.captionMedium)
                .foregroundStyle(Ink.destructive)
                .fixedSize(horizontal: false, vertical: true)
            // Reflows to extra rows at large Dynamic Type so the three actions never
            // clip off a fixed single-line HStack.
            ChipRow(interactive: true) {
                Button("Try again", action: onRetry)
                    .buttonStyle(.outlined(.small))
                if canAllowCellular {
                    Button("Allow on cellular", action: onAllowCellular)
                        .buttonStyle(.outlined(.small))
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.outlined(.small))
                }
            }
        }
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
            icon: Icons.waveform,
            isInstalled: true,
            isDownloading: false,
            downloadProgress: 0,
            errorMessage: nil,
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: Icons.waveform,
            isInstalled: false,
            isDownloading: false,
            downloadProgress: 0,
            errorMessage: nil,
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: Icons.waveform,
            isInstalled: false,
            isDownloading: true,
            downloadProgress: 0.42,
            errorMessage: nil,
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: Icons.waveform,
            isInstalled: false,
            isDownloading: false,
            downloadProgress: 0,
            errorMessage: "No connection. Reconnect to the internet, then try again.",
            canAllowCellular: false,
            onDownload: {}, onRetry: {}, onCancel: {}, onAllowCellular: {}, onDelete: {}
        )
        ModelDownloadRow(
            title: "Voice Transcription",
            icon: Icons.waveform,
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
