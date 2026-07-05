import SwiftUI

/// Per-day totals strip closing the expanded day card (spec 031, mockup variant A):
/// energy in · protein · caffeine · energy out, with "—" for any metric with no data,
/// and one provenance glyph for the day. Read-only.
struct DayNutritionFooter: View {
    let summary: NutritionSummary
    /// Leading inset so the strip lines up with the row content (right of the bead rail)
    /// when check-in/event rows sit above it; 0 on a nutrition-only day.
    var railIndent: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)
                .padding(.leading, railIndent)
            HStack(spacing: Spacing.l) {
                metric("fork.knife", summary.kcalIn, "kcal", Palette.nutritionFood)
                proteinMetric
                metric("cup.and.saucer.fill", summary.caffeineMg, "mg", Palette.nutritionFood)
                metric("flame.fill", summary.kcalOut, "kcal", Palette.nutritionExercise)
                Spacer(minLength: Spacing.s)
                Image(systemName: sourceGlyph)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.leading, railIndent)
            .padding(.top, Spacing.m)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func metric(_ glyph: String, _ value: Double?, _ unit: String, _ hue: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: glyph)
                .font(.caption2)
                .foregroundStyle(hue)
            valueText(value, unit)
        }
    }

    private var proteinMetric: some View {
        HStack(spacing: Spacing.xs) {
            Text("P")
                .font(.fraunces(Metrics.rowTime + 1, weight: .semibold))
                .foregroundStyle(Palette.nutritionFood)
            valueText(summary.proteinG, "g")
        }
    }

    @ViewBuilder
    private func valueText(_ value: Double?, _ unit: String) -> some View {
        if let value {
            (Text("\(Int(value.rounded()))").font(.plexMono(Metrics.rowTime))
                + Text(" \(unit)").font(Typography.caption))
                .foregroundStyle(.primary)
        } else {
            Text("—")
                .font(.plexMono(Metrics.rowTime))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var sourceGlyph: String {
        summary.source == .manual ? "pencil" : "heart.fill"
    }

    private var accessibilityLabel: String {
        func part(_ label: String, _ value: Double?, _ unit: String) -> String {
            value.map { "\(label) \(Int($0.rounded())) \(unit)" } ?? "\(label) no data"
        }
        let provenance = summary.source == .manual ? "entered by you" : "from Apple Health"
        return "Day totals: "
            + [part("energy in", summary.kcalIn, "kilocalories"),
               part("protein", summary.proteinG, "grams"),
               part("caffeine", summary.caffeineMg, "milligrams"),
               part("energy out", summary.kcalOut, "kilocalories")].joined(separator: ", ")
            + ", \(provenance)"
    }
}

#Preview("Full / partial / manual") {
    VStack(spacing: 24) {
        DayNutritionFooter(summary: .init(kcalIn: 2150, proteinG: 82, caffeineMg: 220, kcalOut: 410, source: .healthKit))
        DayNutritionFooter(summary: .init(kcalIn: nil, proteinG: nil, caffeineMg: 220, kcalOut: nil, source: .healthKit))
        DayNutritionFooter(summary: .init(kcalIn: 1800, proteinG: 70, caffeineMg: nil, kcalOut: 300, source: .manual))
    }
    .padding()
    .background(Theme.cardBackground)
}
