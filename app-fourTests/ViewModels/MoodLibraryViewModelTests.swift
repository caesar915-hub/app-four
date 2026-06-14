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

        #expect(vm.timelineDays.count == 31)
        let populated = vm.timelineDays.first { !$0.nodes.isEmpty }
        #expect(populated?.nodes.first?.recording == nil)
        #expect(populated?.nodes.first?.intakeDoses.map(\.id) == [dose.id])
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

    @Test func pastMonthEmitsEveryDayWithEmptiesBetween() throws {
        let rec = Recording(audioFileName: "r.m4a", duration: 0, title: "Good", mood: "good")
        rec.createdAt = date(2020, 1, 10)
        context.insert(rec)
        try context.save()
        store.loadRecordings()

        let vm = MoodLibraryViewModel(store: store)
        vm.currentMonth = date(2020, 1, 15)

        #expect(vm.timelineDays.count == 31)                       // all of Jan 2020
        #expect(vm.timelineDays.first?.date == Calendar.current.startOfDay(for: date(2020, 1, 31))) // newest first
        let jan10 = vm.timelineDays.first { Calendar.current.isDate($0.date, inSameDayAs: date(2020,1,10)) }
        let jan9  = vm.timelineDays.first { Calendar.current.isDate($0.date, inSameDayAs: date(2020,1,9)) }
        #expect(jan10?.nodes.isEmpty == false)
        #expect(jan9?.nodes.isEmpty == true)                       // empty day still present
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
}
