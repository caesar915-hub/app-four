import Foundation
import Testing
import SwiftData
@testable import app_four

@MainActor
struct MoodLibraryViewModelNutritionTests {
    var container: ModelContainer
    var context: ModelContext
    var store: RecordingStore
    var signalsStore: SignalsStore

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
                 DailySignals.self, NutritionEvent.self,
            configurations: config
        )
        context = container.mainContext
        store = RecordingStore(context: context)
        signalsStore = SignalsStore(context: context)
    }

    private let calendar = Calendar.current

    /// A recording today so `hasAnyEntries` is true and the timeline materializes.
    private func seedAnchorRecording(at date: Date = Date()) throws {
        let recording = Recording(audioFileName: "anchor.m4a", duration: 0, title: "Good", mood: "good")
        recording.createdAt = date
        context.insert(recording)
        try context.save()
        store.loadRecordings()
    }

    private func insertEvent(kind: NutritionEventKind = .food, at date: Date,
                             kcal: Double? = nil, caffeine: Double? = nil,
                             mock: Bool = false) throws {
        let event = NutritionEvent(startDate: date, kind: kind)
        event.kcal = kcal
        event.caffeineMg = caffeine
        event.isMockData = mock
        context.insert(event)
        try context.save()
    }

    private func makeVM() -> MoodLibraryViewModel {
        MoodLibraryViewModel(store: store, signalsStore: signalsStore)
    }

    @Test func eventsGroupIntoTheirTimelineDay() throws {
        let today = calendar.startOfDay(for: Date())
        try seedAnchorRecording()
        try insertEvent(at: today.addingTimeInterval(8 * 3600), kcal: 520, caffeine: 95)
        try insertEvent(at: today.addingTimeInterval(13 * 3600), kcal: 780)

        let vm = makeVM()
        let day = vm.timelineDays.first { $0.date == today }
        let nutrition = try #require(day?.nutrition)
        #expect(nutrition.events.count == 2)
        #expect(nutrition.summary.kcalIn == 1300)
        #expect(nutrition.summary.caffeineMg == 95)
    }

    @Test func daysWithoutEventsHaveNilNutrition() throws {
        try seedAnchorRecording()
        let vm = makeVM()
        // Anchor recording's day exists but no nutrition events anywhere.
        #expect(vm.timelineDays.allSatisfy { $0.nutrition == nil })
    }

    @Test func lateEveningEventBelongsToItsOwnDay() throws {
        let today = calendar.startOfDay(for: Date())
        let lateYesterday = calendar.date(byAdding: .minute, value: -2, to: today)!   // 23:58 yesterday
        try seedAnchorRecording(at: lateYesterday)
        try insertEvent(at: lateYesterday, kcal: 300)

        let vm = makeVM()
        vm.currentMonth = lateYesterday   // robust on the 1st of a month
        let yesterday = calendar.startOfDay(for: lateYesterday)
        #expect(vm.timelineDays.first { $0.date == yesterday }?.nutrition != nil)
        #expect(vm.timelineDays.first { $0.date == today }?.nutrition == nil)
    }

    @Test func mockEventsAreHiddenWhenMockModeIsOff() throws {
        let today = calendar.startOfDay(for: Date())
        try seedAnchorRecording()
        try insertEvent(at: today.addingTimeInterval(8 * 3600), kcal: 520, mock: true)

        let vm = makeVM()   // TestSupport.useRealData() → debugMockMode == false
        #expect(vm.timelineDays.first { $0.date == today }?.nutrition == nil)
    }

    @Test func mockEventsShowWhenMockModeIsOn() throws {
        defer { TestSupport.useRealData() }
        let today = calendar.startOfDay(for: Date())
        try seedAnchorRecording()
        try insertEvent(at: today.addingTimeInterval(8 * 3600), kcal: 520, mock: true)

        UserDefaults.standard.set(true, forKey: "debugMockMode")
        // Mock mode also flips recording fetches; re-anchor with a mock recording.
        let mockRecording = Recording(audioFileName: "m.m4a", duration: 0, title: "Good", mood: "good")
        mockRecording.createdAt = Date()
        mockRecording.isMockData = true
        context.insert(mockRecording)
        try context.save()
        store.loadRecordings()

        let vm = makeVM()
        vm.loadNutrition()
        #expect(vm.timelineDays.first { $0.date == today }?.nutrition?.summary.kcalIn == 520)
    }
}
