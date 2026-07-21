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
        // ScrollView keeps the fixed-size crescent and the Start button reachable
        // when Dynamic Type scales the text past the viewport (AX5). At normal
        // sizes the minHeight fill centers the content exactly as a static layout.
        GeometryReader { geo in
            ScrollView {
                content
                    .frame(maxWidth: Metrics.maxContentWidth)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .background(NewLook.screen.ignoresSafeArea())
    }

    private var content: some View {
        VStack(spacing: Spacing.section) {
            Spacer(minLength: Spacing.section)

            CrescentRing()
                .frame(width: crescentSize, height: crescentSize)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.m) {
                Text("Welcome to Squirl")
                    .font(Typography.largeTitle)
                    .foregroundStyle(NewLook.inkPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("A calm place to speak your day. Private by default, on your device.")
                    .font(Typography.body)
                    .foregroundStyle(NewLook.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.l)

            Spacer(minLength: Spacing.section)

            Button("Start", action: start)
                .buttonStyle(.checkInPrimary)
                .accessibilityHint("Opens your check-in")
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.hero)
    }

    private func start() {
        Haptics.success()
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
