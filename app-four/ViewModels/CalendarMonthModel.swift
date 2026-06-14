import Foundation
import SwiftUI

/// What a calendar day cell shows about that day's check-ins.
enum DayMarker: Equatable {
    case none           // no entries
    case mood(Color)    // ≥1 mood → deep average-mood dot
    case neutral        // entries but no mood (e.g. medication-only)
}

/// Pure, value-type description of one month's calendar grid for the Calendar tab.
/// Monday-first weeks for `month`; each cell tagged in-month/today/future and given
/// its `DayMarker`. Selection lives in the view, so this model isn't rebuilt per tap.
struct CalendarMonthModel: Equatable {

    struct DayCell: Identifiable, Equatable {
        let date: Date          // start-of-day
        let dayNumber: Int
        let isInMonth: Bool
        let isToday: Bool
        let isFuture: Bool
        let marker: DayMarker
        var id: Date { date }
    }

    let month: Date
    let cells: [DayCell]        // row-major, 7 * rowCount, Monday-first
    let rowCount: Int

    init(month: Date, days: [MoodLibraryViewModel.TimelineDay], today: Date, calendar: Calendar = .current) {
        self.month = month

        var markerByDay: [Date: DayMarker] = [:]
        for day in days {
            markerByDay[calendar.startOfDay(for: day.date)] = CalendarMonthModel.marker(for: day)
        }

        let startOfToday = calendar.startOfDay(for: today)
        let firstOfMonth = calendar.startOfMonth(for: month)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0

        // Monday-first leading offset (weekday: 1=Sun…7=Sat → Mon=0…Sun=6).
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekdayOfFirst + 5) % 7

        let total = leading + daysInMonth
        let rows = Int((Double(total) / 7.0).rounded(.up))
        self.rowCount = rows

        let gridStart = calendar.date(byAdding: .day, value: -leading, to: firstOfMonth) ?? firstOfMonth

        var cells: [DayCell] = []
        for i in 0..<(rows * 7) {
            let cellDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: i, to: gridStart) ?? gridStart)
            let isInMonth = calendar.isDate(cellDate, equalTo: firstOfMonth, toGranularity: .month)
            cells.append(DayCell(
                date: cellDate,
                dayNumber: calendar.component(.day, from: cellDate),
                isInMonth: isInMonth,
                isToday: calendar.isDate(cellDate, inSameDayAs: startOfToday),
                isFuture: cellDate > startOfToday,
                marker: isInMonth ? (markerByDay[cellDate] ?? .none) : .none
            ))
        }
        self.cells = cells
    }

    /// `.mood` (deep average colour) when the day has any mood; `.neutral` when it
    /// has entries but no mood; `.none` when empty.
    static func marker(for day: MoodLibraryViewModel.TimelineDay) -> DayMarker {
        let moods = day.nodes.compactMap { $0.recording?.mood }
        if let color = MoodLevel.averageDeep(of: moods) { return .mood(color) }
        return day.nodes.isEmpty ? .none : .neutral
    }
}
