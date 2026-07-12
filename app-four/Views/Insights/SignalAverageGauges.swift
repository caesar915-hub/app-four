import SwiftUI

/// Three vertical gauges showing the monthly average per signal.
/// Fill grows from the bottom; a label floats at the top of the fill.
/// Five dashed tick lines mark the ordinal steps (1–5).
struct SignalAverageGauges: View {
    let averages: [SignalAverage]

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.l) {
            ForEach(averages, id: \.kind) { avg in
                GaugeColumn(average: avg)
            }
        }
        .padding(.horizontal, Spacing.l)
        .accessibilityElement(children: .contain)
    }
}

private struct GaugeColumn: View {
    let average: SignalAverage
    @Environment(\.colorScheme) private var colorScheme

    private let gaugeHeight: CGFloat = 280
    private let gaugeWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: Spacing.s) {
            SignalGlyph(average.kind.glyphSignal,
                        level: average.isEmpty ? nil : clampedSignalLevel(Int((average.fraction * 5).rounded())),
                        size: 26)
            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: Radius.control)
                    .fill(NewLook.tintNeutral)
                    .frame(width: gaugeWidth, height: gaugeHeight)

                // Dashed tick lines (5 levels)
                TickLines(gaugeHeight: gaugeHeight, gaugeWidth: gaugeWidth)

                // Fill
                if !average.isEmpty {
                    fillBar
                }
            }
            .frame(width: gaugeWidth, height: gaugeHeight)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control))

            Text(average.caption.isEmpty ? "—" : average.caption)
                .font(Typography.caption)
                .foregroundStyle(NewLook.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: gaugeWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }

    @ViewBuilder
    private var fillBar: some View {
        let fillHeight = gaugeHeight * average.fraction
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Radius.control)
                .fill(fillGradient)
                .frame(width: gaugeWidth, height: fillHeight)

            Text(average.fillLabel)
                .font(Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(fillInkColor)
                .padding(.top, 6)
                .padding(.horizontal, 4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: gaugeWidth, height: fillHeight, alignment: .bottom)
    }

    private var fillGradient: AnyShapeStyle {
        if let filled = levelFill { return AnyShapeStyle(filled.fillGradient) }
        return AnyShapeStyle(NewLook.tintNeutral)
    }

    private var fillInkColor: Color {
        guard let filled = levelFill else { return NewLook.inkPrimary }
        return Color.contrastingInk(for: filled.color, in: colorScheme)
    }

    private var levelFill: (any SignalLevel)? {
        let lowerValue = Int(average.fraction * 5)
        let clamped = max(1, min(5, lowerValue))
        switch average.kind {
        case .mood:   return MoodLevel.allCases.first { $0.numericValue == clamped }
        case .energy: return EnergyLevel.allCases.first { $0.numericValue == clamped }
        case .focus:  return FocusLevel.allCases.first { $0.numericValue == clamped }
        }
    }

    private var a11yLabel: String {
        "\(average.kind.label): \(average.fillLabel), \(average.caption)"
    }
}

private struct TickLines: View {
    let gaugeHeight: CGFloat
    let gaugeWidth: CGFloat

    var body: some View {
        ZStack {
            ForEach(1...5, id: \.self) { level in
                let y = gaugeHeight - (gaugeHeight * CGFloat(level) / 5)
                Rectangle()
                    .fill(NewLook.hairline)
                    .frame(width: gaugeWidth, height: 1)
                    .offset(y: y - gaugeHeight / 2)
                    .mask(
                        HStack(spacing: 2) {
                            ForEach(0..<8, id: \.self) { _ in
                                Rectangle().frame(width: 4)
                            }
                        }
                    )
            }
        }
        .frame(width: gaugeWidth, height: gaugeHeight)
    }
}

#Preview {
    let averages: [SignalAverage] = [
        SignalAverage(kind: .mood,   fillLabel: "Okay+",  caption: "between Okay & Good", fraction: 0.70),
        SignalAverage(kind: .energy, fillLabel: "Steady",  caption: "Steady on average",   fraction: 0.60),
        SignalAverage(kind: .focus,  fillLabel: "—",       caption: "",                    fraction: 0.00),
    ]
    SignalAverageGauges(averages: averages)
        .padding()
}
