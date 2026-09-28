import SwiftUI

/// Settings › Your data: the on-device promise restated in calm language (the onboarding's
/// `WelcomeView` says the same), the ephemeral-store warning when storage could not be opened,
/// and the Privacy Policy / Acknowledgements rows (FR-016/017).
struct YourDataSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if AppModelContainer.isEphemeral {
                HStack(alignment: .top, spacing: Spacing.m) {
                    Image(systemName: Icons.warning)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Ink.destructive)
                        .frame(width: 21, height: 21)
                        .accessibilityHidden(true)
                    Text("Storage couldn't be opened this session, so new check-ins won't be saved. Restarting the app usually fixes this.")
                        .font(Typography.cardSubtitle)
                        .foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Warning: storage couldn't be opened this session, so new check-ins won't be saved. Restarting the app usually fixes this.")
                HairlineDivider()
            }

            Text("Your recordings, check-ins, and signals stay on this device. Nothing is uploaded.")
                .font(Typography.cardSubtitle)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            HairlineDivider()
            Link(destination: URL(string: "https://squirl.pt/privacy")!) {
                SettingsLinkRow(title: "Privacy Policy", symbol: Icons.privacy)
            }
            .accessibilityHint("Opens in Safari.")

            HairlineDivider()
            NavigationLink {
                AcknowledgementsView()
            } label: {
                SettingsLinkRow(title: "Acknowledgements", symbol: Icons.credits)
            }
            .buttonStyle(.plain)
        }
    }
}

/// A Settings navigation row: 21 pt leading icon, 14/500 title, trailing chevron; 44 pt tall.
struct SettingsLinkRow: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Accent.primaryText)
                .frame(width: 21, height: 21)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.rowLabel)
                .foregroundStyle(Ink.primary)
            Spacer(minLength: Spacing.s)
            Image(systemName: Icons.chevronRight)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ink.primary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Metrics.minTapTarget)
        .contentShape(.rect)
    }
}

/// Plain-text credits for the open-source components Squirl builds on. Kept calm and brief.
private struct AcknowledgementsView: View {
    var body: some View {
        ScreenContainer(title: "Acknowledgements", showsMedicationBar: false) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                Text("Acknowledgements")
                    .font(Typography.navTitle)
                    .foregroundStyle(Ink.title)
                    .accessibilityAddTraits(.isHeader)
                credit(
                    "WhisperKit",
                    detail: "On-device speech recognition that turns your voice into text without leaving the device."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.xl)
        }
    }

    private func credit(_ name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(name)
                .font(Typography.sectionTitle)
                .foregroundStyle(Ink.primary)
            Text(detail)
                .font(Typography.cardSubtitle)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.medium)
    }
}

#Preview {
    NavigationStack {
        YourDataSection()
            .card(.medium)
            .padding(Spacing.gutter)
            .background(Surface.screen)
    }
    .withPreviewEnvironment()
}
