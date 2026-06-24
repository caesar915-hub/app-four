import Foundation
import Testing
import SwiftData
@testable import app_four

@MainActor
struct ExtractionReviewViewModelTests {
    let container: ModelContainer
    let store: RecordingStore

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
        store = RecordingStore(context: container.mainContext)
    }

    private func makeRecording(title: String = "Voice Note", date: Date = Date()) -> Recording {
        let rec = Recording(audioFileName: "t.m4a", duration: 60, title: title)
        rec.createdAt = date
        store.context.insert(rec)
        return rec
    }

    private func result(mood: String? = "good", meds: [MedEvent] = []) -> SummaryResult {
        SummaryResult(
            bullets: ["a bullet"],
            medications: meds,
            generatedTitle: "Generated Title",
            energyLevel: EnergyLevel.steady.rawValue,
            focusLevel: FocusLevel.sharp.rawValue,
            mood: mood,
            sleepHours: nil,
            sleepQuality: nil,
            sleepEvent: nil,
            sleepLevel: nil,
            sideEffects: [],
            emotions: [],
            topics: [],
            noteExtraction: NoteExtraction(mood: mood, activities: ["Fitness"], durationHours: 8)
        )
    }

    // P0.5 — a user-edited title survives confirm (not clobbered by auto-title).
    @Test func userEditedTitleIsPreserved() {
        let rec = makeRecording(title: "Voice Note")
        let vm = ExtractionReviewViewModel(result: result(), recording: rec, store: store, onComplete: { _ in })
        vm.name = "My Custom Name"
        vm.confirm()
        #expect(rec.title == "My Custom Name")
    }

    // P0.5 — when the user does NOT edit the title, the auto "Mood · Energy · Focus" title applies.
    @Test func uneditedTitleGetsAutoTitle() {
        let rec = makeRecording(title: "Voice Note")
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        vm.confirm()
        #expect(rec.title.contains("Good"))
        #expect(rec.title != "My Custom Name")
    }

    // P0.5 — editing the date in review lands med takenAt on the new day.
    @Test func medTimeResolvesAgainstNewDate() {
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000) // fixed
        let rec = makeRecording(date: oldDate)
        let meds = [MedEvent(name: "Concerta", dose: "36mg", time: "08:00", timeLabel: "morning")]
        let vm = ExtractionReviewViewModel(result: result(meds: meds), recording: rec, store: store, onComplete: { _ in })

        let newDate = Calendar.current.date(byAdding: .day, value: 3, to: oldDate)!
        vm.date = newDate
        vm.confirm()

        let event = rec.medicationEvents.first { $0.name == "Concerta" }
        #expect(event != nil)
        let cal = Calendar.current
        #expect(cal.isDate(event!.takenAt, inSameDayAs: newDate))
    }

    // P0.5 (Bug 12) — edited mood scalar matches the persisted JSON's mood.
    @Test func editedMoodMatchesPersistedJSON() {
        let rec = makeRecording()
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        vm.setMood("low")
        vm.confirm()
        // The scalar column is the single source of truth (P1.4)…
        #expect(rec.mood == "low")
        // …and the redundant mood is no longer duplicated into the JSON blob,
        // so it can never drift from the column.
        #expect(rec.decodedNoteExtraction?.mood == nil)
    }

    // P1.4 — the persisted JSON keeps column-less fields (activities) but drops
    // the 6 fields that have dedicated columns (no redundancy = no drift).
    @Test func jsonKeepsColumnlessFieldsDropsRedundant() {
        let rec = makeRecording()
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        vm.confirm()
        let json = rec.decodedNoteExtraction
        // Column-less field survives (consumed by InsightsViewModel.activityCounts).
        #expect(json?.activities == ["Fitness"])
        // Redundant-with-column fields are stripped from the JSON.
        #expect(json?.mood == nil)
        #expect(json?.energy == nil)
        #expect(json?.focus == nil)
        #expect(json?.emotions.isEmpty == true)
        #expect(json?.sideEffects.isEmpty == true)
        #expect(json?.sleepHours == nil)
    }
}
