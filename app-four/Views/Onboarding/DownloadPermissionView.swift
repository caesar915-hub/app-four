import SwiftUI
import SwiftData

/// Step 3 of the four-screen first-run flow (welcome → Siri → here → LLM):
/// the explicit voice-model-download opt-in. Explains *why* the Whisper model exists
/// (voice stays on-device), then branches: "Download Now" downloads and advances
/// to the LLM step (whose download/skip completes onboarding); "Skip for Now"
/// advances the same way and records the decline so the background download stays
/// off. A mid-flight failure shows the typed cause in calm copy and returns both
/// actions (retry or skip); the back button hides only while a download is in
/// flight.
struct DownloadPermissionView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: OnboardingViewModel
    @State private var showLLMStep = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content
                    .frame(maxWidth: Metrics.maxContentWidth)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .background(Surface.screen.ignoresSafeArea())
        .navigationBarBackButtonHidden(viewModel.isDownloading)
        // Whisper resolved (downloaded or skipped) → the insights-model step.
        .navigationDestination(isPresented: $showLLMStep) {
            LLMDownloadView(viewModel: viewModel)
        }
        .onChange(of: viewModel.didResolveWhisper) { _, resolved in
            if resolved { showLLMStep = true }
        }
    }

    private var content: some View {
        VStack(spacing: Spacing.section) {
            Spacer(minLength: Spacing.section)

            Image(systemName: Icons.lockShield)
                .font(.system(size: 64))
                .foregroundStyle(Accent.primary)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.m) {
                Text("On-Device Privacy")
                    .font(Typography.pageTitle)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("To keep your journal completely private, Squirl processes your voice directly on this device.")
                    .font(Typography.narrative)
                    .foregroundStyle(Ink.tertiary)
                    .multilineTextAlignment(.center)

                if let error = viewModel.downloadError {
                    Text(error.userMessage)
                        .font(Typography.captionQuiet)
                        .foregroundStyle(Ink.destructive)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.s)
                }
            }
            .padding(.horizontal, Spacing.l)

            Spacer(minLength: Spacing.section)

            VStack(spacing: Spacing.m) {
                if viewModel.isDownloading {
                    VStack(spacing: Spacing.s) {
                        ProgressView(value: viewModel.downloadProgress)
                            .progressViewStyle(.linear)
                            .tint(Accent.primary)
                        Text("Downloading model... \(Int(viewModel.downloadProgress * 100))%")
                            .font(Typography.captionQuiet)
                            .foregroundStyle(Ink.tertiary)
                    }
                    .padding(.horizontal, Spacing.xl)
                } else {
                    Button(action: downloadModel) {
                        Text("Download Now (~150 MB)")
                    }
                    .buttonStyle(.filled(fullWidth: true))

                    Button(action: skip) {
                        Text("Skip for Now")
                    }
                    .buttonStyle(.outlined(fullWidth: true))
                }
            }
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.hero)
    }

    private func downloadModel() {
        Haptics.selection()
        Task {
            await viewModel.downloadModel(modelContext: modelContext)
        }
    }

    private func skip() {
        Haptics.selection()
        withAnimation(Motion.smooth) {
            viewModel.skipModelDownload(modelContext: modelContext)
        }
    }
}

#Preview("Download Permission") {
    NavigationStack {
        DownloadPermissionView(viewModel: OnboardingViewModel(aiModelService: AppServices.preview.aiModelService))
    }
    .modelContainer(AppModelContainer.previewContainer)
}
