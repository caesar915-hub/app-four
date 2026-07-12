import SwiftUI

/// Left-aligned serif section header + optional subtitle for the Insights screen.
/// Replaces the centered `InsightsHeaderSection`. Sections separate by this header's
/// top padding — there are no dividers between them.
struct InsightsSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.display)
                .foregroundStyle(NewLook.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.callout)
                    .foregroundStyle(NewLook.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.section)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        InsightsSectionHeader(title: "Your overall check-in breakdown", subtitle: "5 check-ins")
        InsightsSectionHeader(title: "Your month in three signals", subtitle: "Each bead is one check-in, in order")
    }
}
