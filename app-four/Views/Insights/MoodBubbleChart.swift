import SwiftUI

/// The pen's mood bubbles (DESIGN.md §8.13): five flat circles on a rising baseline, low → great
/// left → right, later levels drawn on top. Diameter follows `MoodBubbleLayout` (D-I2); the fill
/// and ink come from the level (`bubbleFill` / `bubbleInk`, AA-checked).
struct MoodBubbleChart: View {
    let shares: [MoodShare]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(shares, id: \.level) { share in
                    let diameter = MoodBubbleLayout.diameter(fraction: share.fraction)
                    BubbleCell(share: share, diameter: diameter)
                        .position(MoodBubbleLayout.center(level: share.level.numericValue, diameter: diameter, in: geo.size))
                }
            }
        }
        .frame(height: MoodBubbleLayout.chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(summary)
    }

    private var summary: String {
        shares.map { "\($0.level.displayLabel) \(Int(($0.fraction * 100).rounded()))%" }
            .joined(separator: ", ")
    }
}

private struct BubbleCell: View {
    let share: MoodShare
    let diameter: CGFloat

    private var percent: Int { Int((share.fraction * 100).rounded()) }

    var body: some View {
        ZStack {
            Circle().fill(share.level.bubbleFill)
            VStack(spacing: 1) {
                Text("\(percent)%")
                    .font(Typography.bubbleValue)
                if diameter >= 68 {
                    Text(share.level.displayLabel)
                        .font(Typography.bubbleWord)
                }
            }
            .foregroundStyle(share.level.bubbleInk)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel("\(share.level.displayLabel): \(share.count) check-in\(share.count == 1 ? "" : "s"), \(percent)%")
    }
}

#Preview {
    MoodBubbleChart(shares: [
        MoodShare(level: .low, count: 2, fraction: 0.08),
        MoodShare(level: .flat, count: 4, fraction: 0.17),
        MoodShare(level: .okay, count: 8, fraction: 0.33),
        MoodShare(level: .good, count: 7, fraction: 0.29),
        MoodShare(level: .great, count: 3, fraction: 0.13),
    ])
    .padding(Spacing.gutter)
}
