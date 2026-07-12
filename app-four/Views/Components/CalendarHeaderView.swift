import SwiftUI

/// Collapsible week↔month calendar header for the Calendar tab.
/// Collapsed shows the selected day's week; tapping the month label/chevron expands
/// to the full month. Horizontal swipe pages months. At accessibility text sizes the
/// month grid is force-collapsed to a single week (cells get unreadable otherwise).
struct CalendarHeaderView: View {
    let model: CalendarMonthModel
    @Binding var selectedDay: Date
    @Binding var isExpanded: Bool
    let monthLabel: String
    let onSelect: (CalendarMonthModel.DayCell) -> Void
    let onPageMonth: (Int) -> Void   // -1 = older, +1 = newer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private var forceWeek: Bool { dynamicTypeSize >= .accessibility1 }
    private var effectiveExpanded: Bool { isExpanded && !forceWeek }

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
        VStack(spacing: Spacing.s) {
            header
            weekdayCaps
            grid
        }
        .gesture(monthSwipe)
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            if forceWeek {
                // At AX text sizes the month grid is force-collapsed; the button does
                // nothing, so render plain text to avoid a no-op interactive element.
                Text(monthLabel)
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
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
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                if !forceWeek {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NewLook.inkSecondary)
                        .rotationEffect(.degrees(effectiveExpanded ? 90 : 0))
                        .accessibilityHidden(true)   // decorative; the month text is the label
                }
            }
            .frame(minHeight: Metrics.minTapTarget, alignment: .leading)   // ≥44pt tap target (HIG)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayCaps: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { i in
                Text(weekdaySymbols[i])
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
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
        monthLabel: "June 2026",
        onSelect: { selected = $0.date },
        onPageMonth: { _ in }
    )
    .padding()
}
