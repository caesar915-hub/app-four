import SwiftUI

/// One day in the calendar grid: number + mood marker dot, with selection/today/
/// future styling. Selection chrome is neutral (`Color.primary` circle) so it never
/// competes with the mood-coloured marker dot.
struct CalendarDayCell: View {
    let cell: CalendarMonthModel.DayCell
    let isSelected: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 30

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(cell.dayNumber)")
                    .font(.callout)                                   // Dynamic Type (no hardcoded size)
                    .fontWeight(isSelected || cell.isToday ? .bold : .regular)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)                          // shrink (don't truncate) at AX text sizes
                    .foregroundStyle(numberColor)
                    .frame(width: min(diameter, 40), height: min(diameter, 40))
                    .background {
                        if isSelected {
                            Circle().fill(Color.primary)
                        } else if cell.isToday {
                            Circle().strokeBorder(Color.primary, lineWidth: 1.6)
                        }
                    }
                marker.frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)   // ≥44pt tap target (HIG)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.isFuture)
        .accessibilityLabel(a11yLabel)
        .accessibilityInputLabels(["\(cell.dayNumber)"])   // Voice Control: "tap 10"
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var numberColor: Color {
        if isSelected { return Color(.systemBackground) }   // on the primary circle
        if cell.isFuture { return Color(.tertiaryLabel) }
        if !cell.isInMonth { return Color(.tertiaryLabel) }
        return .primary
    }

    @ViewBuilder private var marker: some View {
        switch cell.marker {
        case .mood(let color): Circle().fill(color)
        case .neutral:         Circle().fill(Theme.textSecondary)
        case .none:            Color.clear
        }
    }

    private var a11yLabel: String {
        let day = cell.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let state: String
        switch cell.marker {
        case .mood:    state = "has check-ins"
        case .neutral: state = "has entries"
        case .none:    state = cell.isFuture ? "future" : "no check-ins"
        }
        return cell.isToday ? "\(day), today, \(state)" : "\(day), \(state)"
    }
}

#Preview {
    HStack(spacing: 0) {
        ForEach(Array(CalendarMonthModel(month: .now, days: [], today: .now).cells.prefix(7))) { cell in
            CalendarDayCell(cell: cell, isSelected: cell.isToday, onTap: {})
        }
    }
    .padding()
}
