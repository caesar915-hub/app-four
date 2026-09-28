import SwiftUI

/// One day of the week strip: a 12/600 number, a 32-pt green-800 disc when selected, and a
/// 5-pt green dot beneath days that have check-ins (D6.2). Future and out-of-month days are
/// non-interactive and greyed; VoiceOver carries "today" / "has check-ins" as the state.
struct CalendarDayCell: View {
    let cell: CalendarMonthModel.DayCell
    let isSelected: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .caption) private var diameter: CGFloat = 32

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                Text("\(cell.dayNumber)")
                    .font(Typography.stripNumber)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(numberColor)
                    .frame(width: min(diameter, 40), height: min(diameter, 40))
                    .background {
                        if isSelected {
                            Circle().fill(Ink.title)
                        }
                    }
                marker.frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(cell.isFuture)
        .accessibilityLabel(a11yLabel)
        .accessibilityInputLabels(["\(cell.dayNumber)"])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var numberColor: Color {
        if isSelected { return Ink.onAccent }
        if cell.isFuture || !cell.isInMonth { return Ink.disabled }
        return Ink.secondary
    }

    @ViewBuilder private var marker: some View {
        switch cell.marker {
        case .mood: Circle().fill(Palette.green400)
        case .neutral: Circle().fill(Ink.tertiary)
        case .none: Color.clear
        }
    }

    private var a11yLabel: String {
        let day = cell.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let state: String
        switch cell.marker {
        case .mood: state = "has check-ins"
        case .neutral: state = "has entries"
        case .none: state = cell.isFuture ? "future" : "no check-ins"
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
    .padding(Spacing.gutter)
    .background(Surface.screen)
}
