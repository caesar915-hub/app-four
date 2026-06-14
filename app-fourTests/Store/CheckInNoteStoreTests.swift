import Foundation
import Testing
import SwiftData
@testable import app_four

@MainActor
struct CheckInNoteStoreTests {
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
    }

    @Test func savesSelectedSignalsAsScalars() {
        var draft = CheckInDraft()
        draft.mood = .good; draft.energy = .steady; draft.focus = .sharp
        draft.sleepQuality = "okay"

        let r = store.createCheckInNote(draft)
        #expect(r.mood == "good")
        #expect(r.energyLevel == "steady")
        #expect(r.focusLevel == "sharp")
        #expect(r.sleepQuality == "okay")
        #expect(r.title == "Good · Steady · Sharp")
        #expect(r.status == .completed)
        #expect(store.recordings.contains { $0.id == r.id })
    }

    @Test func linksManualMedEvents() {
        var draft = CheckInDraft()
        draft.meds = [CheckInDraft.DraftMedication(name: "Concerta", dose: "50mg")]

        let r = store.createCheckInNote(draft)
        #expect(r.medicationEvents.count == 1)
        #expect(r.medicationEvents.first?.source == .manual)
        #expect(r.medicationEvents.first?.recording?.id == r.id)
        #expect(r.hasMedication == true)
    }

    @Test func titleFallsBackToNoteThenDefault() {
        var draft = CheckInDraft()
        draft.note = "rough start but better after lunch today honestly"
        #expect(store.createCheckInNote(draft).title == "rough start but better after")

        let r2 = store.createCheckInNote(CheckInDraft(sleepQuality: "good"))
        #expect(r2.title == "Check-in")
    }

    @Test func noteBecomesTranscript() {
        var draft = CheckInDraft()
        draft.note = "settled in after meds"
        let r = store.createCheckInNote(draft)
        #expect(r.fullTranscriptText == "settled in after meds")
    }

    @Test func whitespaceOnlyNoteFallsBackToDefaultTitle() {
        var draft = CheckInDraft()
        draft.note = "   \n  "
        let r = store.createCheckInNote(draft)
        #expect(r.title == "Check-in")
        #expect(r.fullTranscriptText == "")
    }
}
