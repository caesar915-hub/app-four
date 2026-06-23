import SwiftUI
import SwiftData

/// The single Paper & Pollen first-run welcome (Feature 015, US1). Warm paper,
/// a breathing `CrescentRing` hero, a Fraunces headline, one calm privacy
/// sentence, and one Meadow-gradient primary action that lands the user on the
/// Check-in hub. No microphone step, no model-download gate — permission is
/// just-in-time and the model downloads in the background.
struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WelcomeViewModel()

    /// Invoked once completion is persisted (or recoverably failed) so the
    /// presenting cover can dismiss to the hub.
    let onComplete: () -> Void

    private let crescentSize: CGFloat = 232

    var body: some View {
        VStack(spacing: Spacing.section) {
            Spacer(minLength: Spacing.section)

            CrescentRing()
                .frame(width: crescentSize, height: crescentSize)

            VStack(spacing: Spacing.m) {
                Text("Welcome to Squirl")
                    .font(Typography.largeTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("A calm place to speak your day. Everything stays on this device.")
                    .font(Typography.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.l)

            Spacer(minLength: Spacing.section)

            Button("Start", action: start)
                .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.hero)
        .frame(maxWidth: Metrics.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private func start() {
        withAnimation(Motion.smooth) {
            viewModel.complete(modelContext: modelContext)
        }
        onComplete()
    }
}

#Preview("Welcome") {
    WelcomeView(onComplete: {})
        .modelContainer(AppModelContainer.previewContainer)
}
