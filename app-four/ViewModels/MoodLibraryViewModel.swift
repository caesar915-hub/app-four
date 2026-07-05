import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class MoodLibraryViewModel {

    struct TimelineDay: Identifiable {
        let date: Date          // start-of-day; stable id for scroll-sync
        let label: String
        let nodes: [DayTimeline.Node]
        var nutrition: DayNutrition? = nil   // spec 031; nil = day card unchanged
        var id: Date { date }
    }

    var currentMonth: Date = Date()

    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private let signalsStore: SignalsStore?
    @ObservationIgnored private let calendar = Calendar.current

    /// Taken medication events (manual + transcript). Observed so the timeline
    /// recomputes when the medication bar logs or deletes a dose.
    private var medicationEvents: [MedicationEvent] = []

    /// Nutrition/exercise events (spec 031). Observed like `medicationEvents`; SwiftData
    /// writes from sync/seeding land out-of-band, so `loadNutrition()` is re-called
    /// explicitly after those complete.
    private var nutritionEvents: [NutritionEvent] = []
    @ObservationIgnored private var medObserver: NSObjectProtocol?
    @ObservationIgnored private var nutritionObserver: NSObjectProtocol?
    @ObservationIgnored private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()
    @ObservationIgnored private let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f
    }()
    @ObservationIgnored private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var monthLabel: String { monthFormatter.string(from: currentMonth) }

    var isCurrentMonth: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    var hasAnyEntries: Bool {
        !store.recordings.isEmpty || !medicationEvents.isEmpty
    }

    /// Grid model for the currently displayed month.
    var calendarMonth: CalendarMonthModel {
        CalendarMonthModel(month: currentMonth, days: timelineDays, today: Date(), calendar: calendar)
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

    var timelineDays: [TimelineDay] {
        guard hasAnyEntries else { return [] }   // first-launch: let the view show its empty state

        let monthRecordings = store.recordings.filter {
            calendar.isDate($0.createdAt, equalTo: currentMonth, toGranularity: .month)
        }
        let monthDoses = medicationEvents.filter {
            calendar.isDate($0.takenAt, equalTo: currentMonth, toGranularity: .month)
        }
        let recordingsByDay = Dictionary(grouping: monthRecordings) { calendar.startOfDay(for: $0.createdAt) }
        let dosesByDay = Dictionary(grouping: monthDoses) { calendar.startOfDay(for: $0.takenAt) }

        let firstOfMonth = calendar.startOfMonth(for: currentMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0
        let startOfToday = calendar.startOfDay(for: Date())
        let nutritionMap = nutritionByDay

        var result: [TimelineDay] = []
        for offset in 0..<daysInMonth {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            if dayStart > startOfToday { break }     // never show future days
            result.append(TimelineDay(
                date: dayStart,
                label: dayLabel(for: dayStart),
                nodes: DayTimelineBuilder.build(
                    recordings: recordingsByDay[dayStart] ?? [],
                    doses: dosesByDay[dayStart] ?? []
                ),
                nutrition: nutritionMap[dayStart]
            ))
        }
        return result.sorted { $0.date > $1.date }   // newest first
    }

    /// `timelineDays` with every day strictly more recent than `selectedDate` removed
    /// (FR-010): a pure transform of the existing month-scoped, newest-first list. The
    /// selected day becomes the top entry when it has data in the current month; older days
    /// remain and scroll below. The calendar week-row is NOT filtered by this — it greys
    /// more-recent days in place instead (FR-011).
    func timelineDaysFilteredToSelectedDate(_ selectedDate: Date) -> [TimelineDay] {
        let cap = calendar.startOfDay(for: selectedDate)
        return timelineDays.filter { $0.date <= cap }
    }

    init(store: RecordingStore, signalsStore: SignalsStore? = nil) {
        self.store = store
        self.signalsStore = signalsStore
        loadMedicationEvents()
        loadNutrition()
        medObserver = NotificationCenter.default.addObserver(
            forName: .medicationEventsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue → already on the main actor.
            MainActor.assumeIsolated { self?.loadMedicationEvents() }
        }
        nutritionObserver = NotificationCenter.default.addObserver(
            forName: .nutritionEventsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.loadNutrition() }
        }
    }

    deinit {
        if let medObserver { NotificationCenter.default.removeObserver(medObserver) }
        if let nutritionObserver { NotificationCenter.default.removeObserver(nutritionObserver) }
    }

    private func loadMedicationEvents() {
        let mockMode = UserDefaults.standard.bool(forKey: "debugMockMode")
        let descriptor = FetchDescriptor<MedicationEvent>(
            predicate: #Predicate { $0.taken == true && $0.isMockData == mockMode },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        medicationEvents = (try? store.context.fetch(descriptor)) ?? []
    }

    // MARK: - Nutrition (spec 031)

    /// Re-fetches nutrition/exercise events. Called from `init` and again after HealthKit
    /// sync or mock seeding completes (out-of-band SwiftData writes don't trigger Observation).
    /// Fetches BOTH partitions — real-wins-per-day is resolved in `nutritionByDay`.
    func loadNutrition() {
        guard let signalsStore else { return }
        nutritionEvents = signalsStore.fetchEvents(from: .distantPast, to: Date())
    }

    /// Per-day resolution (spec 031 FR-009): mock mode off → real events only; mock mode
    /// on → a day with ANY real event uses only its real events, else its mock events.
    /// Never mixed within a day.
    private var nutritionByDay: [Date: DayNutrition] {
        guard !nutritionEvents.isEmpty else { return [:] }
        let mockMode = UserDefaults.standard.bool(forKey: "debugMockMode")
        let grouped = Dictionary(grouping: nutritionEvents) { calendar.startOfDay(for: $0.startDate) }
        var result: [Date: DayNutrition] = [:]
        for (day, events) in grouped {
            let real = events.filter { !$0.isMockData }
            let chosen = mockMode ? (real.isEmpty ? events.filter(\.isMockData) : real) : real
            guard !chosen.isEmpty else { continue }
            let items = chosen.sorted { $0.startDate > $1.startDate }.map(NutritionEventItem.init)   // newest first
            result[day] = DayNutrition(events: items, summary: NutritionEventGrouping.summary(for: items))
        }
        return result
    }

    func prevMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    func nextMonth() {
        guard !isCurrentMonth else { return }
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    func delete(_ recording: Recording) {
        store.deleteRecording(recording)
    }

    func recording(for id: UUID) -> Recording? {
        store.recordings.first { $0.id == id }
    }

    // MARK: - Day labels

    func dayLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today, \(dayFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(dayFormatter.string(from: date))"
        } else {
            return weekdayFormatter.string(from: date)
        }
    }
}
