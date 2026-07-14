import Foundation
import Testing
import SwiftData
@testable import app_four

@MainActor
struct MoodLibraryViewModelTests {
    var container: ModelContainer
    var context: ModelContext
    var store: RecordingStore

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
        context = container.mainContext
        store = RecordingStore(context: context)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func timelineDaysIsEmptyWithNoData() {
        let vm = MoodLibraryViewModel(store: store)
        #expect(vm.timelineDays.isEmpty)
    }

    @Test func manualDoseWithoutRecordingStillProducesADay() throws {
        let when = date(2020, 1, 10)
        let dose = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: when,
                                   taken: true, durationHours: 10, source: .manual)
        context.insert(dose)
        try context.save()

        let vm = MoodLibraryViewModel(store: store)
        vm.currentMonth = when

        // feat/024: the timeline emits only days with content (empty days skipped), so a
        // lone manual dose produces exactly its own day.
        #expect(vm.timelineDays.count == 1)
        let populated = try #require(vm.timelineDays.first)
        #expect(populated.nodes.first?.recording == nil)
        #expect(populated.nodes.first?.intakeDoses.map(\.id) == [dose.id])
    }

    @Test func recordingAndLiveDoseMergeIntoOneNode() throws {
        let now = Date()
        let recording = Recording(audioFileName: "r.m4a", duration: 0, title: "Good", mood: "good")
        recording.createdAt = now
        context.insert(recording)
        let dose = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: now,
                                   taken: true, durationHours: 10, source: .transcript)
        context.insert(dose)
        dose.recording = recording
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)
        let nodes = vm.timelineDays.flatMap(\.nodes)

        #expect(nodes.count == 1)
        #expect(nodes[0].recording?.id == recording.id)
        #expect(nodes[0].intakeDoses.map(\.id) == [dose.id])
    }

    @Test func untakenDosesAreExcluded() throws {
        let dose = MedicationEvent(name: "Concerta", dose: "27mg", takenAt: Date(),
                                   taken: false, durationHours: 10, source: .manual)
        context.insert(dose)
        try context.save()

        let vm = MoodLibraryViewModel(store: store)
        #expect(vm.timelineDays.isEmpty)
    }

    @Test func monthEmitsOnlyContentDaysNewestFirst() throws {
        // feat/024: empty days are skipped — only days with a recording or dose emit,
        // newest first. (Was `pastMonthEmitsEveryDayWithEmptiesBetween`, which predated
        // that QA change.)
        for day in [10, 20] {
            let rec = Recording(audioFileName: "r\(day).m4a", duration: 0, title: "Good", mood: "good")
            rec.createdAt = date(2020, 1, day)
            context.insert(rec)
        }
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)
        vm.currentMonth = date(2020, 1, 15)

        #expect(vm.timelineDays.count == 2)                        // only Jan 10 + Jan 20
        #expect(vm.timelineDays.map(\.date) == [
            Calendar.current.startOfDay(for: date(2020, 1, 20)),   // newest first
            Calendar.current.startOfDay(for: date(2020, 1, 10))
        ])
    }

    @Test func currentMonthDoesNotEmitFutureDays() throws {
        let rec = Recording(audioFileName: "r.m4a", duration: 0, title: "ok", mood: "okay")
        rec.createdAt = Date()
        context.insert(rec)
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)   // currentMonth defaults to now
        let today = Calendar.current.startOfDay(for: Date())
        #expect(vm.timelineDays.allSatisfy { $0.date <= today })
        #expect(vm.timelineDays.first?.date == today) // newest = today
    }

    @Test func emptyStoreHasNoEntriesAndNoDays() {
        let vm = MoodLibraryViewModel(store: store)
        #expect(vm.hasAnyEntries == false)
        #expect(vm.timelineDays.isEmpty)              // first-launch: empty → view shows ContentUnavailableView
    }

    // MARK: - Filter-above (FR-009, FR-010, FR-016)

    @Test func filterToSelectedDateDropsMoreRecentDays() throws {
        for d in [5, 10, 15] {
            let rec = Recording(audioFileName: "\(d).m4a", duration: 0, title: "t", mood: "good")
            rec.createdAt = date(2020, 1, d)
            context.insert(rec)
        }
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)
        vm.currentMonth = date(2020, 1, 15)

        let jan10 = Calendar.current.startOfDay(for: date(2020, 1, 10))
        let filtered = vm.timelineDaysFilteredToSelectedDate(date(2020, 1, 10))

        #expect(filtered.allSatisfy { $0.date <= jan10 })                              // FR-010: nothing newer than selected
        #expect(filtered.first?.date == jan10)                                         // FR-009: selected day is top
        #expect(!filtered.contains { Calendar.current.isDate($0.date, inSameDayAs: date(2020, 1, 15)) }) // Jan 15 dropped
        #expect(filtered.contains { Calendar.current.isDate($0.date, inSameDayAs: date(2020, 1, 5)) })   // Jan 5 retained
        #expect(filtered.map(\.date) == filtered.map(\.date).sorted(by: >))            // FR-016: newest-first order preserved
    }

    @Test func filterAtLatestDayEqualsFullList() throws {
        let rec = Recording(audioFileName: "r.m4a", duration: 0, title: "t", mood: "good")
        rec.createdAt = date(2020, 1, 10)
        context.insert(rec)
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)
        vm.currentMonth = date(2020, 1, 15)

        // Capping at the newest visible day is a no-op (same subsequence).
        #expect(vm.timelineDaysFilteredToSelectedDate(date(2020, 1, 31)).map(\.date) == vm.timelineDays.map(\.date))
    }
}
