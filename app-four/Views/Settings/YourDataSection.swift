import SwiftUI

/// The "Your data" trust home in Settings — designed to live inside the grouped
/// `List`. Restates the onboarding on-device promise (`WelcomeView`) in calm,
/// non-technical language and pushes a brief acknowledgements screen for the
/// open-source components and font licences Squirl owes credit (FR-016/017).
struct YourDataSection: View {
    var body: some View {
        Section("Your data") {
            Text("Your recordings, check-ins, and signals stay on this device. Nothing is uploaded.")
                .font(Typography.body)
                .foregroundStyle(NewLook.inkSecondary)

            NavigationLink {
                AcknowledgementsView()
            } label: {
                Label("Acknowledgements", systemImage: "heart")
            }
        }
    }
}

/// Plain-text credits for the open-source components and fonts Squirl builds on.
/// Kept calm and brief; the fonts ship under the SIL Open Font License (FR-016).
private struct AcknowledgementsView: View {
    var body: some View {
        ScreenContainer(title: "Acknowledgements", showsMedicationBar: false) {
            VStack(alignment: .leading, spacing: Spacing.section) {
                credit(
                    "WhisperKit",
                    detail: "On-device speech recognition that turns your voice into text without leaving the device."
                )
                credit(
                    "Fraunces · DM Sans · IBM Plex Mono",
                    detail: "Typefaces used throughout Squirl, under the SIL Open Font License."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xl)
        }
    }

    private func credit(_ name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(name)
                .font(Typography.headline)
                .foregroundStyle(NewLook.inkPrimary)
            Text(detail)
                .font(Typography.callout)
                .foregroundStyle(NewLook.inkSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        List {
            YourDataSection()
        }
        .listStyle(.insetGrouped)
    }
    .withPreviewEnvironment()
}
