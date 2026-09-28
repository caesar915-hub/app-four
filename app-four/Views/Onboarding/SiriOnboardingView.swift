import SwiftUI
import SwiftData

/// Step 2 of the three-screen first-run flow (welcome → Siri → model download):
/// the hands-free pitch. Both App Shortcuts work from install with zero setup,
/// so this screen only teaches the two phrases before step 3 asks for the
/// on-device model. Owns no state — it forwards the shared
/// `OnboardingViewModel` down the stack.
struct SiriOnboardingView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        // Same shell as the other onboarding screens: the ScrollView keeps the
        // action reachable at Dynamic Type AX sizes, the minHeight fill pins the
        // button to the bottom at normal sizes.
        GeometryReader { geo in
            ScrollView {
                content
                    .frame(maxWidth: Metrics.maxContentWidth)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .background(Surface.screen.ignoresSafeArea())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            copyBlock
            phrasesCard

            Spacer(minLength: Spacing.section)

            NavigationLink {
                DownloadPermissionView(viewModel: viewModel)
            } label: {
                HStack(spacing: Spacing.s) {
                    Text("Continue to Model Download")
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.filled(fullWidth: true))
            .accessibilityHint("Shows the on-device voice model download")
            .simultaneousGesture(TapGesture().onEnded {
                Haptics.selection()
            })
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.hero)
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Green eyebrow per the mockup — same grammar as `cardEyebrow()`
            // (label font, uppercase, tracking) with the check-in accent.
            Text("Hands-free voice")
                .font(Typography.status)
                .foregroundStyle(Accent.primaryText)

            Text("Speak to Siri anytime")
                .font(Typography.question)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)

            Text("Squirl works hands-free with Siri right out of the box — zero setup required.")
                .font(Typography.cardSubtitle)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private var phrasesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label("Siri Voice Phrases", systemImage: "mic.fill")
                .font(Typography.rowTitle)
                .foregroundStyle(Ink.primary)

            // Icons mirror the AppShortcut glyphs (pills.fill / waveform) so the
            // phrases read the same here as in Spotlight and the Shortcuts app.
            phraseBubble("Hey Siri, log my meds in Squirl", systemImage: "pills.fill")
            phraseBubble("Hey Siri, check in on Squirl", systemImage: "waveform")
        }
        .card(.large)
    }

    private func phraseBubble(_ phrase: String, systemImage: String) -> some View {
        Label {
            Text(phrase)
                .foregroundStyle(Ink.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Accent.primary)
        }
        .font(Typography.rowTitle)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Surface.screen, in: .rect(cornerRadius: Radius.cardS))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.cardS)
                .strokeBorder(Stroke.chip, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }
}

#Preview("Siri Step") {
    NavigationStack {
        SiriOnboardingView(viewModel: OnboardingViewModel(aiModelService: AppServices.preview.aiModelService))
    }
    .modelContainer(AppModelContainer.previewContainer)
}
