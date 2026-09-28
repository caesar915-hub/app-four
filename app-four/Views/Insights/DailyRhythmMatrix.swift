import SwiftUI

/// The daily rhythm matrix (DESIGN.md §8.16): uppercase time-of-day headers (narrow fallback),
/// icon + label row heads, and 44 ⌀ tinted tiles (`RhythmTint`, D-I4) with the dominant level's
/// glyph and word. Empty cells are outlined with "—". `RhythmCell` is the untouched model.
struct DailyRhythmMatrix: View {
    let matrix: [RhythmRow]

    private let rowLabelWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: 0) {
                Color.clear.frame(width: rowLabelWidth, height: 1)
                ForEach(TimeBucket.allCases, id: \.self) { bucket in
                    ViewThatFits(in: .horizontal) {
                        Text(bucket.label.uppercased())
                        Text(bucket.shortLabel.uppercased())
                    }
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            ForEach(matrix, id: \.kind) { row in
                HStack(alignment: .top, spacing: 0) {
                    HStack(spacing: Spacing.xs) {
                        IdentityIcon(row.kind.glyphSignal, size: 14)
                        Text(row.kind.label)
                            .font(Typography.captionMedium)
                            .foregroundStyle(Ink.primary)
                    }
                    .frame(width: rowLabelWidth, alignment: .leading)
                    .padding(.top, Spacing.m)
                    .accessibilityHidden(true)

                    ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                        RhythmTile(cell: cell, signal: row.kind)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RhythmTile: View {
    let cell: RhythmCell
    let signal: SignalKind

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                if let level = cell.dominant, let tint = RhythmTint.tint(level: level.numericValue) {
                    Circle().fill(tint)
                    SignalGlyph(signal.glyphSignal, level: level.numericValue, size: Metrics.glyphInline, decorative: true)
                } else {
                    Circle().strokeBorder(Stroke.empty, lineWidth: Stroke.hairlineWidth)
                }
            }
            .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
            Text(cell.dominant?.displayLabel ?? "—")
                .font(Typography.micro)
                .foregroundStyle(cell.dominant == nil ? Ink.placeholder : Ink.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        let where_ = "\(signal.label), \(cell.bucket.label)"
        return cell.dominant.map { "\(where_): \($0.displayLabel)" } ?? "\(where_): no data"
    }
}

#Preview {
    let matrix: [RhythmRow] = SignalKind.allCases.map { kind in
        let cells = TimeBucket.allCases.enumerated().map { index, bucket -> RhythmCell in
            let level: (any SignalLevel)? = switch kind {
            case .mood: MoodLevel.allCases[min(index + 2, 4)]
            case .energy: EnergyLevel.allCases[min(index + 2, 4)]
            case .focus: FocusLevel.allCases[min(index + 2, 4)]
            }
            return RhythmCell(bucket: bucket, dominant: index == 3 ? nil : level, count: index * 2)
        }
        return RhythmRow(kind: kind, cells: cells)
    }
    DailyRhythmMatrix(matrix: matrix)
        .padding(Spacing.gutter)
}
