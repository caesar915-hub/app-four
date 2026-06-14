import SwiftUI

/// Area-proportional bubble chart for mood distribution.
/// Each bubble's area is proportional to that mood's share of check-ins.
/// Positioned low→great left→right with slight vertical elevation for higher moods.
struct MoodBubbleChart: View {
    let shares: [MoodShare]
    @Environment(\.colorScheme) private var colorScheme

    private let chartHeight: CGFloat = 160
    private let maxDiameter: CGFloat = 118
    private let minDiameter: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(shares, id: \.level) { share in
                    let d = diameter(for: share)
                    let x = xPos(for: share, width: geo.size.width)
                    let y = yPos(for: share, height: geo.size.height)
                    BubbleCell(share: share, diameter: d, colorScheme: colorScheme)
                        .position(x: x, y: y)
                }
            }
        }
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(a11ySummary)
    }

    private func diameter(for share: MoodShare) -> CGFloat {
        let maxFrac = shares.map(\.fraction).max() ?? 1
        guard maxFrac > 0 else { return minDiameter }
        let rel = sqrt(share.fraction / maxFrac)
        return minDiameter + (maxDiameter - minDiameter) * rel
    }

    private func xPos(for share: MoodShare, width: CGFloat) -> CGFloat {
        let step = width / CGFloat(5)
        return step * CGFloat(share.level.numericValue - 1) + step / 2
    }

    private func yPos(for share: MoodShare, height: CGFloat) -> CGFloat {
        let mid = height / 2
        let normalized = CGFloat(share.level.numericValue - 3)  // −2…+2
        return mid - normalized * 14  // great floats up, low sinks down
    }

    private var a11ySummary: String {
        shares.map { "\($0.level.displayLabel) \(Int(($0.fraction * 100).rounded()))%" }
              .joined(separator: ", ")
    }
}

private struct BubbleCell: View {
    let share: MoodShare
    let diameter: CGFloat
    let colorScheme: ColorScheme

    var body: some View {
        let ink = Color.contrastingInk(for: share.level.color, in: colorScheme)
        ZStack {
            Circle()
                .fill(share.level.bubbleFill)
                .frame(width: diameter, height: diameter)
            VStack(spacing: 1) {
                Text("\(Int((share.fraction * 100).rounded()))%")
                    .font(Typography.label)
                    .fontWeight(.semibold)
                if diameter >= 68 {
                    Text(share.level.displayLabel)
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .foregroundStyle(ink)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityLabel("\(share.level.displayLabel): \(share.count) check-in\(share.count == 1 ? "" : "s"), \(Int((share.fraction * 100).rounded()))%")
    }
}

#Preview {
    let shares: [MoodShare] = [
        MoodShare(level: .low,   count: 1, fraction: 0.083),
        MoodShare(level: .flat,  count: 2, fraction: 0.167),
        MoodShare(level: .okay,  count: 4, fraction: 0.333),
        MoodShare(level: .good,  count: 4, fraction: 0.333),
        MoodShare(level: .great, count: 1, fraction: 0.083),
    ]
    MoodBubbleChart(shares: shares)
        .padding()
}
