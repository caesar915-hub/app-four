import SwiftUI

/// 3-signal × 4-time-bucket matrix. Each cell shows the dominant level for that
/// signal at that time of day. Empty cells render as dashed outlines (not foggy grey).
struct DailyRhythmMatrix: View {
    let matrix: [RhythmRow]

    private let blobSize: CGFloat = 52
    private let rowLabelWidth: CGFloat = 56

    var body: some View {
        VStack(spacing: Spacing.s) {
            // Column headers
            HStack(spacing: 0) {
                Spacer().frame(width: rowLabelWidth)
                ForEach(TimeBucket.allCases, id: \.self) { bucket in
                    Text(bucket.label)
                        .font(Typography.caption)
                        .foregroundStyle(NewLook.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Spacing.l)

            ForEach(matrix, id: \.kind) { row in
                HStack(spacing: 0) {
                    Text(row.kind.label)
                        .font(Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(NewLook.inkSecondary)
                        .frame(width: rowLabelWidth, alignment: .leading)

                    ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                        RhythmCellView(cell: cell, blobSize: blobSize)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Spacing.l)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RhythmCellView: View {
    let cell: RhythmCell
    let blobSize: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            if let level = cell.dominant {
                Circle()
                    .fill(level.fillGradient)
                    .frame(width: blobSize, height: blobSize)
                Text(level.displayLabel)
                    .font(Typography.label)
                    .foregroundStyle(NewLook.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Circle()
                    .strokeBorder(
                        NewLook.inkSecondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                    )
                    .frame(width: blobSize, height: blobSize)
                Text("—")
                    .font(Typography.label)
                    .foregroundStyle(NewLook.inkSecondary.opacity(0.4))
            }
        }
        .frame(minWidth: 44, minHeight: 44)  // 44pt hit target floor
        .accessibilityLabel(a11yLabel)
    }

    private var a11yLabel: String {
        if let level = cell.dominant {
            return "\(cell.bucket.label): \(level.displayLabel)"
        }
        return "\(cell.bucket.label): no data"
    }
}

#Preview {
    let matrix: [RhythmRow] = SignalKind.allCases.map { kind in
        let cells = TimeBucket.allCases.enumerated().map { idx, bucket -> RhythmCell in
            let level: (any SignalLevel)?
            if idx % 3 == 0 {
                level = nil
            } else {
                switch kind {
                case .mood:   level = MoodLevel.allCases[min(idx, 4)]
                case .energy: level = EnergyLevel.allCases[min(idx, 4)]
                case .focus:  level = FocusLevel.allCases[min(idx, 4)]
                }
            }
            return RhythmCell(bucket: bucket, dominant: level, count: idx * 2)
        }
        return RhythmRow(kind: kind, cells: cells)
    }
    DailyRhythmMatrix(matrix: matrix)
        .padding(.vertical)
}
