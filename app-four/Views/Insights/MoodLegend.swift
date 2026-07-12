import SwiftUI

/// Dot + label legend used under `MoodBubbleChart`.
struct MoodLegend: View {
    let shares: [MoodShare]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: Spacing.s)],
            spacing: Spacing.s
        ) {
            ForEach(shares, id: \.level) { share in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(share.level.fillGradient)
                        .frame(width: 10, height: 10)
                    Text(share.level.displayLabel)
                        .font(Typography.caption)
                        .foregroundStyle(NewLook.inkPrimary)
                    Text("(\(share.count))")
                        .font(Typography.caption)
                        .foregroundStyle(NewLook.inkSecondary)
                }
                .accessibilityLabel("\(share.level.displayLabel): \(share.count)")
            }
        }
        .padding(.horizontal, Spacing.l)
    }
}

#Preview {
    MoodLegend(shares: [
        MoodShare(level: .okay,  count: 4, fraction: 0.4),
        MoodShare(level: .good,  count: 3, fraction: 0.3),
        MoodShare(level: .great, count: 2, fraction: 0.2),
        MoodShare(level: .flat,  count: 1, fraction: 0.1),
    ])
    .padding()
}
