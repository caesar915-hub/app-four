import Testing
import Foundation
import SwiftData
@testable import app_four

@MainActor
struct MoodLibraryContextTests {
    var container: ModelContainer
    var context: ModelContext
    var recordingStore: RecordingStore
    var contextStore: DayContextStore

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self, DayCalendarContext.self,
            configurations: config
        )
        context = container.mainContext
        recordingStore = RecordingStore(context: context)
        contextStore = DayContextStore(context: context)
    }

    private func makeRecording(audioFileName: String, on date: Date) throws -> Recording {
        let rec = Recording(audioFileName: audioFileName, duration: 0, title: "Test", mood: "good")
        rec.createdAt = date
        context.insert(rec)
        try context.save()
        recordingStore.loadRecordings()
        return rec
    }

    private func dayKey(year: Int, month: Int, day: Int) -> Date {
        let comps = DateComponents(year: year, month: month, day: day)
        return Calendar.current.startOfDay(for: Calendar.current.date(from: comps)!)
    }

    private func makePayload(title: String) -> CapturedDayEvents {
        CapturedDayEvents(events: [
            CapturedEvent(
                title: title,
                start: Date(timeIntervalSince1970: 1_000_000),
                end: Date(timeIntervalSince1970: 1_003_600),
                isAllDay: false,
                attendeeCount: 2,
                availability: "busy"
            )
        ])
    }

    // MARK: - T023: context populated on TimelineDay

    @Test func dayWithUpsertedContextHasNonNilContext() throws {
        let day1 = dayKey(year: 2020, month: 1, day: 5)
        let day2 = dayKey(year: 2020, month: 1, day: 10)

        try makeRecording(audioFileName: "r1.m4a", on: day1)
        try makeRecording(audioFileName: "r2.m4a", on: day2)

        let payload = makePayload(title: "Standup")
        contextStore.upsert(dayKey: day1, payload: payload, titlesIncluded: true)

        let vm = MoodLibraryViewModel(store: recordingStore)
        vm.currentMonth = day2
        vm.attach(dayContextStore: contextStore, coordinator: NoOpCalendarCoordinator())

        let days = vm.timelineDays
        let matched = days.first { Calendar.current.isDate($0.date, inSameDayAs: day1) }
        let unmatched = days.first { Calendar.current.isDate($0.date, inSameDayAs: day2) }

        #expect(matched?.context == payload)
        #expect(unmatched?.context == nil)
    }

    @Test func dayWithoutUpsertHasNilContext() throws {
        let day = dayKey(year: 2020, month: 3, day: 15)
        try makeRecording(audioFileName: "r.m4a", on: day)

        let vm = MoodLibraryViewModel(store: recordingStore)
        vm.currentMonth = day
        vm.attach(dayContextStore: contextStore, coordinator: NoOpCalendarCoordinator())

        let days = vm.timelineDays
        let matched = days.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
        #expect(matched?.context == nil)
    }

    @Test func filteredDaysRetainContext() throws {
        let day1 = dayKey(year: 2020, month: 2, day: 3)
        let day2 = dayKey(year: 2020, month: 2, day: 8)

        try makeRecording(audioFileName: "a.m4a", on: day1)
        try makeRecording(audioFileName: "b.m4a", on: day2)

        let payload = makePayload(title: "All-hands")
        contextStore.upsert(dayKey: day1, payload: payload, titlesIncluded: false)

        let vm = MoodLibraryViewModel(store: recordingStore)
        vm.currentMonth = day2
        vm.attach(dayContextStore: contextStore, coordinator: NoOpCalendarCoordinator())

        let filtered = vm.timelineDaysFilteredToSelectedDate(day2)
        let matched = filtered.first { Calendar.current.isDate($0.date, inSameDayAs: day1) }
        #expect(matched?.context == payload)
    }
}

// MARK: - NoOpCalendarCoordinator

private struct NoOpCalendarCoordinator: CalendarContextCoordinator {
    func checkInSaved(dayKey: Date) async {}
    func checkInDateChanged(from oldDay: Date, to newDay: Date) async {}
    func checkInDeleted(dayKey: Date) async {}
    func sweep() async {}
    func recaptureAll() async {}
}
