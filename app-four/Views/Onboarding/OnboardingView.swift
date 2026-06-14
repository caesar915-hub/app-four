import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: OnboardingViewModel

    init(services: AppServices) {
        _viewModel = State(wrappedValue: OnboardingViewModel(services: services))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        TabView(selection: $viewModel.currentPage) {
            WelcomeStep(onContinue: { goToPage(1) })
                .tag(0)

            PermissionStep(
                permissionGranted: viewModel.permissionGranted,
                onRequest: requestPermissionThenAdvance,
                onSkip: { goToPage(2) }
            )
            .tag(1)

            DownloadStep(
                phase: viewModel.downloadPhase,
                whisperProgress: viewModel.whisperProgress,
                whisperComplete: viewModel.whisperComplete,
                onDownload: { viewModel.downloadModels() },
                onSkip: complete,
                onContinue: complete
            )
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(.systemBackground))
    }

    private func goToPage(_ page: Int) {
        withAnimation { viewModel.currentPage = page }
    }

    private func requestPermissionThenAdvance() {
        Task {
            await viewModel.requestMicrophonePermission()
            goToPage(2)
        }
    }

    private func complete() {
        viewModel.cancelDownload()
        viewModel.completeOnboarding(modelContext: modelContext)
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Spacing.section) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: Metrics.IconSize.hero))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.m) {
                Text("Welcome to Whisper Notes")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("On-device voice journaling for ADHD. Record your day and get medication, mood, energy and focus summaries — all private, all on this device.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, Spacing.section)
            .padding(.bottom, Spacing.hero) // was 48 (no 48 token; snapped to hero/40)
        }
        .padding(Spacing.xxl)
    }
}

// MARK: - Permission

private struct PermissionStep: View {
    let permissionGranted: Bool
    let onRequest: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: Spacing.section) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: Metrics.IconSize.hero))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.m) {
                Text("Microphone Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Whisper Notes needs microphone access to record voice notes. Audio is processed entirely on this device.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()

            VStack(spacing: Spacing.m) {
                Button(action: onRequest) {
                    Text(permissionGranted ? "Continue" : "Grant Microphone Access")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip for now", action: onSkip)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.section)
            .padding(.bottom, Spacing.hero) // was 48 (no 48 token; snapped to hero/40)
        }
        .padding(Spacing.xxl)
    }
}

// MARK: - Download

private struct DownloadStep: View {
    let phase: OnboardingViewModel.DownloadPhase
    let whisperProgress: Double
    let whisperComplete: Bool
    let onDownload: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: Metrics.IconSize.hero))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.m) {
                Text("Setting Up Your Models")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Whisper Notes runs entirely on this device. We'll download the transcription model now (~150 MB). Wi-Fi recommended.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            modelRows

            if case .failed(let message) = phase {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()

            actionButtons
                .padding(.horizontal, Spacing.section)
                .padding(.bottom, Spacing.hero) // was 48 (no 48 token; snapped to hero/40)
        }
        .padding(Spacing.xxl)
    }

    // MARK: - Model progress rows

    @ViewBuilder
    private var modelRows: some View {
        if phase != .notStarted {
            VStack(spacing: Spacing.xxl) {
                modelRow(
                    name: "Whisper",
                    subtitle: "Speech-to-text transcription",
                    progress: whisperProgress,
                    isComplete: whisperComplete,
                    isActive: phase == .downloading && !whisperComplete
                )
            }
            .padding(.horizontal, Spacing.xxl)
        }
    }

    private func modelRow(
        name: String,
        subtitle: String,
        progress: Double,
        isComplete: Bool,
        isActive: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("\(name) downloaded")
                } else if isActive {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: isComplete ? 1.0 : progress)
                .tint(isComplete ? .green : Color.accentColor)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Buttons (entry is gated until both models are ready)

    @ViewBuilder
    private var actionButtons: some View {
        switch phase {
        case .notStarted:
            Button(action: onDownload) {
                Text("Download Models")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .downloading:
            // Gated: no way forward until the download finishes.
            HStack(spacing: Spacing.s) {
                ProgressView()
                Text("Downloading…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.s)

        case .failed:
            VStack(spacing: Spacing.m) {
                Button(action: onDownload) {
                    Text("Retry")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Escape hatch only on failure, so users aren't trapped offline.
                Button("Skip for now", action: onSkip)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

        case .completed:
            Button(action: onContinue) {
                Text("Start Using Whisper Notes")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView(services: .preview)
        .modelContainer(AppModelContainer.previewContainer)
}

#Preview("Welcome step") {
    WelcomeStep(onContinue: {})
}

#Preview("Permission step") {
    PermissionStep(permissionGranted: false, onRequest: {}, onSkip: {})
}

#Preview("Download — in progress") {
    DownloadStep(
        phase: .downloading,
        whisperProgress: 0.42,
        whisperComplete: false,
        onDownload: {},
        onSkip: {},
        onContinue: {}
    )
}

#Preview("Download — failed") {
    DownloadStep(
        phase: .failed("Whisper download didn't complete. Check your connection and retry."),
        whisperProgress: 0.3,
        whisperComplete: false,
        onDownload: {},
        onSkip: {},
        onContinue: {}
    )
}

#Preview("Download — completed") {
    DownloadStep(
        phase: .completed,
        whisperProgress: 1.0,
        whisperComplete: true,
        onDownload: {},
        onSkip: {},
        onContinue: {}
    )
}
