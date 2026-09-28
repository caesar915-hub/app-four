import SwiftUI

/// "Where you averaged" row (DESIGN.md §8.15): five level pills in the mood ramp, the signal's
/// canonical words under each, a bracket over the averaged segment(s) (`RangeSpan`), and the
/// caption on the right. Long words ("Distracted", "Locked In") may take two lines.
struct RangeBar: View {
    let average: SignalAverage

    private static let pillHeight: CGFloat = 7
    private static let pillGap: CGFloat = 2
    private static let bracketHeight: CGFloat = 12

    private var span: ClosedRange<Int>? { RangeSpan.segments(level: average.level, isWhole: average.isWhole) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                IdentityIcon(average.kind.glyphSignal, size: Metrics.glyphHeader)
                Text(average.kind.label)
                    .font(Typography.rowLabel)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Spacing.s)
                Text(average.isEmpty ? "No data yet" : average.caption.sentenceCased)
                    .font(Typography.captionQuiet)
                    .foregroundStyle(Ink.tertiary)
                    .multilineTextAlignment(.trailing)
            }
            bracket
            HStack(spacing: Self.pillGap) {
                ForEach(MoodLevel.allCases, id: \.self) { level in
                    Capsule().fill(level.color).frame(height: Self.pillHeight)
                }
            }
            HStack(alignment: .top, spacing: Self.pillGap) {
                ForEach(Array(average.kind.levelLabels.enumerated()), id: \.offset) { _, word in
                    Text(word)
                        .font(Typography.captionQuiet)
                        .foregroundStyle(Ink.tertiary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(average.isEmpty ? "\(average.kind.label): no data yet" : "\(average.kind.label): \(average.caption)")
    }

    @ViewBuilder private var bracket: some View {
        if let span {
            BracketShape(start: CGFloat(span.lowerBound - 1) / 5, end: CGFloat(span.upperBound) / 5, gap: Self.pillGap)
                .stroke(Ink.secondary, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                .frame(height: Self.bracketHeight)
        } else {
            Color.clear.frame(height: Self.bracketHeight)
        }
    }
}

/// The ⊓ over the bracketed pills: `start`/`end` are fractions of the row width.
private struct BracketShape: Shape {
    let start: CGFloat
    let end: CGFloat
    let gap: CGFloat

    func path(in rect: CGRect) -> Path {
        let x0 = rect.minX + rect.width * start + (start > 0 ? gap / 2 : 0)
        let x1 = rect.minX + rect.width * end - (end < 1 ? gap / 2 : 0)
        var path = Path()
        path.move(to: CGPoint(x: x0, y: rect.maxY))
        path.addLine(to: CGPoint(x: x0, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: x1, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: x1, y: rect.maxY))
        return path
    }
}

#Preview {
    VStack(spacing: Spacing.l) {
        RangeBar(average: SignalAverage(kind: .mood, fillLabel: "Okay+", caption: "between Okay & Good", fraction: 0.7, level: 3, isWhole: false))
        HairlineDivider()
        RangeBar(average: SignalAverage(kind: .energy, fillLabel: "Steady", caption: "Steady on average", fraction: 0.6, level: 3, isWhole: true))
        HairlineDivider()
        RangeBar(average: SignalAverage(kind: .focus, fillLabel: "—", caption: "", fraction: 0, level: 0, isWhole: false))
    }
    .padding(Spacing.gutter)
}
