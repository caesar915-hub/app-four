import SwiftUI
import SwiftData

/// Step 4 of the first-run flow (welcome → Siri → Whisper → here): the
/// journal-insights model opt-in. Explains *why* a second, larger model exists
/// (it reads the transcript and pulls out mood, energy, focus, sleep and meds —
/// still fully on-device), then branches: "Download Now" downloads and
/// completes onboarding; "Skip for Now" records the insights-model decline and
/// completes without it. A mid-flight failure shows the typed cause in calm
/// copy and returns both actions (retry or skip).
struct LLMDownloadView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: OnboardingViewModel

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
    }

    private var content: some View {
        VStack(spacing: Spacing.section) {
            Spacer(minLength: Spacing.section)

            Image(systemName: Icons.brain)
                .font(.system(size: 64))
                .foregroundStyle(Accent.primary)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.m) {
                Text("Journal Insights")
                    .font(Typography.pageTitle)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("A second on-device model reads your check-ins and picks out mood, energy, focus, sleep and medications — still private, still on this iPhone.")
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
                        Text("Downloading insights model... \(Int(viewModel.downloadProgress * 100))%")
                            .font(Typography.captionQuiet)
                            .foregroundStyle(Ink.tertiary)
                    }
                    .padding(.horizontal, Spacing.xl)
                } else {
                    Button(action: downloadModel) {
                        Text("Download Now (~740 MB)")
                    }
                    .buttonStyle(.filled(fullWidth: true))

                    Text("Wi-Fi recommended")
                        .font(Typography.captionQuiet)
                        .foregroundStyle(Ink.tertiary)

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
            await viewModel.downloadLLMModel(modelContext: modelContext)
        }
    }

    private func skip() {
        Haptics.selection()
        withAnimation(Motion.smooth) {
            viewModel.skipLLMDownload(modelContext: modelContext)
        }
    }
}

#Preview("LLM Download") {
    NavigationStack {
        LLMDownloadView(viewModel: OnboardingViewModel(aiModelService: AppServices.preview.aiModelService))
    }
    .modelContainer(AppModelContainer.previewContainer)
}
