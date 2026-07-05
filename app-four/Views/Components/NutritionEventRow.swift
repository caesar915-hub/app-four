import SwiftUI

/// One read-only food or exercise event on the expanded day timeline (spec 031, mockup
/// variant A): a smaller hollow bead on the shared rail so mood check-ins stay the anchor,
/// then the event name in its lane colour and its values. No chevron — these don't navigate.
struct NutritionEventRow: View {
    let item: NutritionEventItem
    let isLast: Bool

    private var hue: Color {
        item.kind == .food ? Palette.nutritionFood : Palette.nutritionExercise
    }
    private var glyph: String {
        item.kind == .food ? "fork.knife" : "flame.fill"
    }
    private var title: String {
        item.name ?? (item.kind == .food ? "Food" : "Workout")
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            beadColumn
            content
                .padding(.top, Spacing.s)   // align name against the bead centre
                .padding(.bottom, isLast ? 0 : Spacing.section)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Bead + connector (subordinate to the 42pt mood bead)

    private var beadColumn: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(hue.opacity(0.12))
                .overlay(Circle().strokeBorder(hue, lineWidth: 1.5))
                .overlay {
                    Image(systemName: glyph)
                        .font(.system(size: Metrics.nutritionBead * 0.42, weight: .medium))
                        .foregroundStyle(hue)
                }
                .frame(width: Metrics.nutritionBead, height: Metrics.nutritionBead)
                .frame(width: Metrics.timeBead + 2)   // centre on the shared rail axis
            if !isLast {
                Rectangle()
                    .fill(Theme.separator)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(title)
                    .font(.fraunces(Metrics.rowMoodText))
                    .foregroundStyle(hue)
                Text(item.startDate, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.plexMono(Metrics.rowTime))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: Spacing.s)
            }
            valueLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var valueLine: some View {
        let values = valueStrings
        if !values.isEmpty {
            HStack(spacing: Spacing.m) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.plexMono(Metrics.rowTime))
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    /// "845 kcal", "26 g protein", "125 mg" for food; "35 min", "310 kcal" for exercise.
    /// Absent metrics are simply omitted (FR-003).
    private var valueStrings: [String] {
        var out: [String] = []
        switch item.kind {
        case .food:
            if let kcal = item.kcal { out.append("\(Int(kcal.rounded())) kcal") }
            if let p = item.proteinGrams { out.append("\(Int(p.rounded())) g protein") }
            if let mg = item.caffeineMg { out.append("\(Int(mg.rounded())) mg") }
        case .exercise:
            if let min = item.durationMinutes { out.append("\(Int(min.rounded())) min") }
            if let kcal = item.kcal { out.append("\(Int(kcal.rounded())) kcal") }
        }
        return out
    }

    private var accessibilityLabel: String {
        let time = item.startDate.formatted(.dateTime.hour().minute(.twoDigits))
        let spoken = valueStrings.map { $0.replacingOccurrences(of: "kcal", with: "kilocalories")
            .replacingOccurrences(of: " g protein", with: " grams protein")
            .replacingOccurrences(of: " mg", with: " milligrams caffeine") }
        return ([title, time] + spoken).joined(separator: ", ")
    }
}

#Preview("Food & exercise rows") {
    VStack(alignment: .leading, spacing: 0) {
        NutritionEventRow(item: .init(kind: .food, startDate: .now, name: "Lunch",
                                      kcal: 780, proteinGrams: 34, caffeineMg: nil,
                                      durationMinutes: nil, source: .healthKit, isMockData: true),
                          isLast: false)
        NutritionEventRow(item: .init(kind: .exercise, startDate: .now, name: "Run",
                                      kcal: 310, proteinGrams: nil, caffeineMg: nil,
                                      durationMinutes: 35, source: .healthKit, isMockData: true),
                          isLast: false)
        NutritionEventRow(item: .init(kind: .food, startDate: .now, name: "Coffee",
                                      kcal: nil, proteinGrams: nil, caffeineMg: 125,
                                      durationMinutes: nil, source: .healthKit, isMockData: true),
                          isLast: true)
    }
    .padding()
    .background(Theme.cardBackground)
}
