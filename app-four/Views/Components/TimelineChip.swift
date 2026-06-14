import SwiftUI

/// A compact chip under a timeline check-in. Inputs (feelings, sleep, side
/// effects, topics) use the neutral style; a logged medication uses the purple
/// style. The icon is always dark for a flat, consistent look.
struct TimelineChip: View {
    let icon: String
    let label: String
    var textColor: Color = Theme.textPrimary
    var background: Color = Color(.secondarySystemFill)

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(Theme.textPrimary)   // dark icon in every chip
            Text(label)
                .foregroundStyle(textColor)
        }
        .font(.system(size: 12, weight: .medium))   // fixed (no Dynamic Type scaling)
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(background, in: .capsule)
    }

    /// Purple medication chip ("Taken Concerta 36mg").
    static func medication(_ label: String) -> TimelineChip {
        TimelineChip(
            icon: "pills.fill",
            label: label,
            textColor: Palette.medication,
            background: Palette.medication.opacity(0.13)
        )
    }
}

#Preview {
    HStack {
        TimelineChip(icon: "heart.fill", label: "Happy")
        TimelineChip(icon: "moon.fill", label: "5h sleep")
        TimelineChip.medication("TAKEN CONCERTA 36MG")
    }
    .padding()
}
