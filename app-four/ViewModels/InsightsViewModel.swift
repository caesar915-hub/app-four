import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class InsightsViewModel {

    struct CalendarDay: Identifiable {
        var id: Date { date }
        let date: Date
        let isCurrentMonth: Bool
        let recordings: [Recording]

        var dominantColor: Color? { recordings.first?.moodColor }
        var hasEntries: Bool { !recordings.isEmpty }
    }

    var currentMonth: Date = Date()

    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored let calendar = Calendar.current
    @ObservationIgnored private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var monthLabel: String { monthFormatter.string(from: currentMonth) }

    var isCurrentMonth: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    var availableMonths: [Date] {
        let allDates = store.recordings.map(\.createdAt)
        guard let earliest = allDates.min() else { return [currentMonth] }
        var months: [Date] = []
        var date = calendar.startOfMonth(for: earliest)
        let end = calendar.startOfMonth(for: Date())
        while date <= end {
            months.append(date)
            date = calendar.date(byAdding: .month, value: 1, to: date) ?? end
        }
        return months.isEmpty ? [currentMonth] : months
    }

    var monthRecordings: [Recording] {
        store.recordings.filter {
            calendar.isDate($0.createdAt, equalTo: currentMonth, toGranularity: .month)
        }
    }

    init(store: RecordingStore) {
        self.store = store
    }

    func prevMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    func nextMonth() {
        guard !isCurrentMonth else { return }
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    func jumpToToday() {
        currentMonth = Date()
    }

    func recording(for id: UUID) -> Recording? {
        store.recordings.first { $0.id == id }
    }


    var hasAnyData: Bool { !monthRecordings.isEmpty }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
