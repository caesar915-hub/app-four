import Foundation
import Testing
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct ExtractionReviewViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
    }()

    let store: RecordingStore

    init() throws {
        let context = Self.container.mainContext
        try context.delete(model: Recording.self)
        try context.delete(model: MedicationEvent.self)
        try context.delete(model: AppSettings.self)
        store = RecordingStore(context: context)
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

    // MARK: - Part 3 (Phase 1)

    @Test func unmodifiedFieldsYieldLLMTagsAndModifiedYieldUserCorrected() {
        let rec = makeRecording()
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        
        vm.setMood("great") // modify mood
        // leave energy unmodified (it was steady in result)
        
        vm.confirm()
        
        let tags = rec.correctionTags ?? []
        let moodTag = tags.first(where: { $0.category == TagCategory.mood.rawValue })
        let energyTag = tags.first(where: { $0.category == TagCategory.energy.rawValue })
        
        #expect(moodTag?.source == TagSource.userCorrected.rawValue)
        #expect(energyTag?.source == TagSource.llm.rawValue)
    }

    @Test func confirmAppliesEditedColumns() {
        let rec = makeRecording()
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        
        vm.setMood("great")
        vm.setEnergy(.charged)
        vm.confirm()
        
        #expect(rec.mood == "great")
        #expect(rec.energyLevel == "charged")
    }

    // MARK: - Part 3 (Phase 2, 3, 4)

    // T004: Comma-to-Dot Sleep Normalisation
    @Test func sleepNormalisationParsesCommasAsDots() {
        let rec = makeRecording()
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        
        vm.setSleepHours(fromString: "7,5")
        #expect(vm.sleepHours == 7.5)
        
        vm.setSleepHours(fromString: "6.2")
        #expect(vm.sleepHours == 6.2)
    }

    // T007: Cancel Semantics
    @Test func cancelSetsStatusToFailedIfNotCompleted() {
        let rec = makeRecording()
        rec.summaryStatus = SummaryStatus.generating.rawValue
        
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        vm.cancel()
        
        #expect(rec.summaryStatus == SummaryStatus.failed.rawValue)
    }

    @Test func cancelIgnoresIfAlreadyCompleted() {
        let rec = makeRecording()
        rec.summaryStatus = SummaryStatus.completed.rawValue
        
        let vm = ExtractionReviewViewModel(result: result(mood: "good"), recording: rec, store: store, onComplete: { _ in })
        vm.cancel()
        
        #expect(rec.summaryStatus == SummaryStatus.completed.rawValue)
    }

    // T009: Nil Extraction Safety
    @Test func nilExtractionResultSafelyDefaultsToNilAndEmpty() {
        let rec = makeRecording()
        // Create an empty fallback result
        let fallback = SummaryResult(
            bullets: [], medications: [], generatedTitle: "Generated Title",
            energyLevel: nil, focusLevel: nil, mood: nil, sleepHours: nil,
            sleepQuality: nil, sleepEvent: nil, sleepLevel: nil, sideEffects: [],
            emotions: [], topics: [], noteExtraction: nil
        )
        
        let vm = ExtractionReviewViewModel(result: fallback, recording: rec, store: store, onComplete: { _ in })
        
        #expect(vm.mood == "")
        #expect(vm.energy == nil)
        #expect(vm.focus == nil)
        #expect(vm.sleepHours == nil)
        #expect(vm.medications.isEmpty)
        #expect(vm.emotions.isEmpty)
        #expect(vm.sideEffects.isEmpty)
        
        // Ensure saving this empty fallback doesn't crash and generates no tags
        vm.confirm()
        
        let tags = rec.correctionTags ?? []
        #expect(tags.isEmpty)
        #expect(rec.mood == nil)
    }

    // T003/SC-006 — the production path (convenience init, used by RecordingDetailView)
    // must rebuild noteExtractionJSON on save: edited meds/title/sleep land in the JSON,
    // and column-less fields from the prior extraction are carried over.
    @Test func productionPathRebuildsNoteExtractionJSON() throws {
        let rec = makeRecording(title: "Voice Note")
        rec.mood = "good"
        rec.energyLevel = "steady"
        rec.focusLevel = "sharp"
        let stale = NoteExtraction(activities: ["Fitness"], title: "Voice Note", durationHours: 8)
        rec.noteExtractionJSON = String(data: try JSONEncoder().encode(stale), encoding: .utf8)

        let vm = ExtractionReviewViewModel(recording: rec, store: store, onComplete: { _ in })
        vm.setMood("great")
        vm.setSleepHours(fromString: "7,5")
        vm.setSleepLevel(.good)
        vm.addMedication("Vyvanse")
        vm.name = "My Day"
        vm.confirm()

        let json = try #require(rec.decodedNoteExtraction)
        #expect(json.title == "My Day")                       // user title wins, JSON matches
        #expect(rec.title == "My Day")
        #expect(json.activities == ["Fitness"])               // carried over, not dropped
        #expect(json.durationHours == 8)                      // carried over
        #expect(json.medications.map(\.name) == ["Vyvanse"])  // med edit lands in JSON
        #expect(json.sleep?.hours == 7.5)                     // sleep edit lands in JSON
        #expect(json.sleep?.quality == SleepLevel.good.rawValue)
        // Redundant-with-column fields are still stripped by applySummary.
        #expect(json.mood == nil)
        #expect(rec.mood == "great")
        // The sleep event JSON tracks the edited sleep too.
        #expect(rec.decodedSleepEvent?.hours == 7.5)
    }

    // MARK: - UI-39 (spec 057): dirty gate, medication rows, idempotent cancel

    @Test func isDirtyTracksEveryField() {
        let rec = makeRecording()
        let meds = [MedEvent(name: "Concerta", dose: "36 mg", time: "08:00")]
        let vm = ExtractionReviewViewModel(result: result(meds: meds), recording: rec, store: store, onComplete: { _ in })
        #expect(!vm.isDirty)
        vm.setMood("low"); #expect(vm.isDirty); vm.setMood("good"); #expect(!vm.isDirty)
        vm.setEnergy(.charged); #expect(vm.isDirty); vm.setEnergy(.steady); #expect(!vm.isDirty)
        vm.setFocus(.foggy); #expect(vm.isDirty); vm.setFocus(.sharp); #expect(!vm.isDirty)
        vm.setSleepLevel(.deep); #expect(vm.isDirty); vm.setSleepLevel(nil); #expect(!vm.isDirty)
        vm.setSleepHours(7); #expect(vm.isDirty); vm.setSleepHours(nil); #expect(!vm.isDirty)
        vm.toggleEmotion("proud"); #expect(vm.isDirty); vm.toggleEmotion("proud"); #expect(!vm.isDirty)
        vm.toggleSideEffect("headache"); #expect(vm.isDirty); vm.toggleSideEffect("headache"); #expect(!vm.isDirty)
        vm.toggleMedTaken(meds[0]); #expect(vm.isDirty); vm.toggleMedTaken(vm.medications[0]); #expect(!vm.isDirty)
        vm.addMedication("Ritalin"); #expect(vm.isDirty); vm.removeMedication("Ritalin"); #expect(!vm.isDirty)
        let seededDate = vm.date
        vm.date = seededDate.addingTimeInterval(3600); #expect(vm.isDirty); vm.date = seededDate; #expect(!vm.isDirty)
        vm.name = "Renamed"; #expect(vm.isDirty)
    }

    @Test func medicationRowsGroupByName() {
        let meds = [MedEvent(name: "Concerta", dose: "36 mg", time: "08:00"),
                    MedEvent(name: "Ritalin", dose: "10 mg", time: "13:00"),
                    MedEvent(name: "Concerta", dose: "18 mg", time: "16:00")]
        let vm = ExtractionReviewViewModel(result: result(meds: meds), recording: makeRecording(), store: store, onComplete: { _ in })
        let rows = vm.medicationRows
        #expect(rows.map(\.name) == ["Concerta", "Ritalin"])
        #expect(rows[0].events.map(\.dose) == ["36 mg", "18 mg"])
        #expect(rows[1].events.count == 1)
    }

    @Test func cancelIfUnsavedSkipsAfterConfirmAndIsIdempotent() {
        let saved = makeRecording()
        saved.summaryStatus = SummaryStatus.notGenerated.rawValue
        let vm = ExtractionReviewViewModel(result: result(), recording: saved, store: store, onComplete: { _ in })
        vm.confirm()
        vm.cancelIfUnsaved()
        #expect(saved.summaryStatus != SummaryStatus.failed.rawValue)

        let abandoned = makeRecording()
        abandoned.summaryStatus = SummaryStatus.notGenerated.rawValue
        let vm2 = ExtractionReviewViewModel(result: result(), recording: abandoned, store: store, onComplete: { _ in })
        vm2.cancelIfUnsaved()
        vm2.cancelIfUnsaved()
        #expect(abandoned.summaryStatus == SummaryStatus.failed.rawValue)
    }
}
