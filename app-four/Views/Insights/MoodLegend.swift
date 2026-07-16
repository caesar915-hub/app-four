import SwiftUI

/// Legend chips under `MoodBubbleChart` (a07): white hairline capsules — dot + label + count.
struct MoodLegend: View {
    let shares: [MoodShare]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.s)],
            spacing: Spacing.s
        ) {
            ForEach(shares, id: \.level) { share in
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(share.level.fillGradient)
                        .frame(width: 8, height: 8)
                    Text(share.level.displayLabel)
                        .font(Typography.caption)
                        .foregroundStyle(NewLook.inkPrimary)
                    Text("(\(share.count))")
                        .font(Typography.caption)
                        .foregroundStyle(NewLook.inkSecondary)
                }
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xs)
                .background(NewLook.card, in: Capsule())
                .overlay(Capsule().strokeBorder(NewLook.hairline, lineWidth: 1))
                .accessibilityLabel("\(share.level.displayLabel): \(share.count)")
            }
        }
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
