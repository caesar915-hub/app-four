import SwiftUI

/// The pen's week strip (DESIGN.md §8.22): "September 2026 ›" then seven columns of 3-letter
/// day names over day numbers. Tapping the month label expands to the full month (kept — D6.1);
/// a horizontal swipe pages months. At accessibility text sizes the grid is force-collapsed to
/// one week and the day names fall back to single letters.
struct CalendarHeaderView: View {
    let model: CalendarMonthModel
    @Binding var selectedDay: Date
    @Binding var isExpanded: Bool
    let monthLabel: String
    let onSelect: (CalendarMonthModel.DayCell) -> Void
    let onPageMonth: (Int) -> Void   // -1 = older, +1 = newer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var forceWeek: Bool { dynamicTypeSize >= .accessibility1 }
    private var effectiveExpanded: Bool { isExpanded && !forceWeek }

    /// Monday-first day names from the locale — "Mon Tue …", or "M T …" at accessibility sizes.
    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = forceWeek ? calendar.veryShortWeekdaySymbols : calendar.shortWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    private var weeks: [[CalendarMonthModel.DayCell]] {
        stride(from: 0, to: model.cells.count, by: 7).map {
            Array(model.cells[$0..<min($0 + 7, model.cells.count)])
        }
    }
    private var selectedWeekIndex: Int {
        weeks.firstIndex { week in
            week.contains { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
        } ?? 0
    }
    private var visibleWeeks: [[CalendarMonthModel.DayCell]] {
        guard !weeks.isEmpty else { return [] }
        return effectiveExpanded ? weeks : [weeks[safe: selectedWeekIndex] ?? []]
    }

    var body: some View {
        VStack(spacing: Spacing.m) {
            header
            weekdayCaps
            grid
        }
        .gesture(monthSwipe)
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            if forceWeek {
                Text(monthLabel)
                    .font(Typography.rowTitle)
                    .foregroundStyle(Ink.primary)
                    .frame(minHeight: Metrics.minTapTarget, alignment: .leading)
            } else {
                expandButton
                    .accessibilityHint(effectiveExpanded ? "Collapse to week" : "Expand to month")
            }
            Spacer()
        }
    }

    private var expandButton: some View {
        Button {
            guard !forceWeek else { return }
            withAnimation(reduceMotion ? nil : Motion.smooth) { isExpanded.toggle() }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(monthLabel)
                    .font(Typography.rowTitle)
                    .foregroundStyle(Ink.primary)
                Image(systemName: Icons.chevronRight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.primary)
                    .rotationEffect(.degrees(effectiveExpanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Metrics.minTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var weekdayCaps: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { i in
                Text(weekdaySymbols[i])
                    .font(Typography.stripDay)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var grid: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(visibleWeeks.indices, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(visibleWeeks[row]) { cell in
                        CalendarDayCell(
                            cell: cell,
                            isSelected: Calendar.current.isDate(cell.date, inSameDayAs: selectedDay),
                            onTap: { onSelect(cell) }
                        )
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.smooth, value: effectiveExpanded)
        .animation(reduceMotion ? nil : Motion.smooth, value: model.month)
    }

    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                onPageMonth(value.translation.width > 0 ? -1 : 1)   // swipe right → older
            }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    @Previewable @State var selected = Calendar.current.startOfDay(for: .now)
    @Previewable @State var expanded = false
    CalendarHeaderView(
        model: CalendarMonthModel(month: .now, days: [], today: .now),
        selectedDay: $selected,
        isExpanded: $expanded,
        monthLabel: "September 2026",
        onSelect: { selected = $0.date },
        onPageMonth: { _ in }
    )
    .padding(Spacing.gutter)
    .background(Surface.screen)
}
