import SwiftUI
import SwiftData

/// Screen 1 of the three-screen first-run flow: the Paper & Pollen welcome
/// (Feature 015, US1) — warm paper, a static `CrescentRing` hero, one calm
/// privacy sentence — with a single primary action that pushes the hands-free
/// Siri screen (`SiriOnboardingView`) onto the `NavigationStack`, which leads
/// to the model-download permission screen. Linear and guided by design; no
/// swipe carousel.
///
/// The `ScrollView` keeps the fixed-size crescent and the Start button
/// reachable when Dynamic Type scales the text past the viewport (AX5). At
/// normal sizes the minHeight fill centers the content exactly as a static
/// layout. Completion (from either screen-2 branch) is observed via
/// `viewModel.didComplete` and reported through `onComplete`.
struct WelcomeView: View {
    @State private var viewModel: OnboardingViewModel

    /// Invoked once completion is persisted (or recoverably failed) so the
    /// presenting cover can dismiss to the hub.
    let onComplete: () -> Void

    private let crescentSize: CGFloat = 232

    init(services: AppServices, onComplete: @escaping () -> Void) {
        _viewModel = State(wrappedValue: OnboardingViewModel(aiModelService: services.aiModelService))
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    content
                        .frame(maxWidth: Metrics.maxContentWidth)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
            .background(NewLook.screen.ignoresSafeArea())
        }
        .onChange(of: viewModel.didComplete) { _, didComplete in
            if didComplete {
                onComplete()
            }
        }
    }

    private var content: some View {
        VStack(spacing: Spacing.section) {
            Spacer(minLength: Spacing.section)

            CheckInRing(progress: 1.0 / 3.0, diameter: crescentSize)

            VStack(spacing: Spacing.m) {
                Text("Welcome to Squirl")
                    .font(Typography.largeTitle)
                    .foregroundStyle(NewLook.inkPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("A calm place to speak your day. Everything stays on this device.")
                    .font(Typography.body)
                    .foregroundStyle(NewLook.inkSecondary)
                    .multilineTextAlignment(.center)

                Text("Squirl is a journal — it doesn't give medical advice.")
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.l)

            Spacer(minLength: Spacing.section)

            NavigationLink {
                SiriOnboardingView(viewModel: viewModel)
            } label: {
                Text("Start")
            }
            .buttonStyle(.checkInPrimary)
            .accessibilityHint("Shows the hands-free Siri voice commands")
            .simultaneousGesture(TapGesture().onEnded {
                Haptics.success()
            })
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.hero)
    }
}

#Preview("Welcome") {
    WelcomeView(services: .preview, onComplete: {})
        .modelContainer(AppModelContainer.previewContainer)
}
