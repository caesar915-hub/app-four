import Foundation
import Testing
import SwiftData
@testable import app_four

@MainActor
struct RecordingApplySummaryTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        context = container.mainContext
    }

    private func makeResult(
        mood: String? = "great", energy: String? = "charged", focus: String? = "sharp",
        sleepHours: Double? = 8, sleepQuality: String? = "good", meds: [MedEvent] = [],
        topics: [String] = []
    ) -> SummaryResult {
        SummaryResult(
            bullets: ["a bullet"], medications: meds, generatedTitle: "Generated",
            energyLevel: energy, focusLevel: focus, mood: mood,
            sleepHours: sleepHours, sleepQuality: sleepQuality,
            sleepEvent: nil, sleepLevel: nil, sideEffects: [], feelings: [],
            topics: topics, noteExtraction: nil
        )
    }

    @Test func fillOnlyPreservesUserScalars() {
        let r = Recording(audioFileName: "t.m4a", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(), fillOnly: true)
        #expect(r.mood == "good")
        #expect(r.energyLevel == "charged")
        #expect(r.focusLevel == "sharp")
        #expect(r.sleepQuality == "good")
    }

    @Test func fillOnlyKeepsTitle() {
        let r = Recording(audioFileName: "t.m4a", title: "Good · Steady", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(), fillOnly: true)
        #expect(r.title == "Good · Steady")
    }

    @Test func defaultApplySummaryStillOverwrites() {
        let r = Recording(audioFileName: "t.m4a", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(mood: "low"))
        #expect(r.mood == "low")
    }

    @Test func fillOnlyStillWritesSummaryMetadata() {
        let r = Recording(audioFileName: "t.m4a", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(), fillOnly: true)
        #expect(r.summaryStatus == SummaryStatus.completed.rawValue)
        #expect(r.summary?.contains("a bullet") == true)
    }

    @Test func fillOnlyFillsMedicationInfoWhenNil() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        r.applySummary(makeResult(meds: [MedEvent(name: "Concerta", dose: "36mg")]), fillOnly: true)
        #expect(r.medicationInfo == "Concerta 36mg")
    }

    @Test func transcriptMedSkippedWhenManualExists() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        let manual = MedicationEvent(name: "Concerta", takenAt: r.createdAt, taken: true, source: .manual)
        context.insert(manual); manual.recording = r

        r.setMedicationEvents(
            from: [MedEvent(name: "concerta"), MedEvent(name: "Magnesium")],
            durationHours: nil, context: context
        )
        let names = r.medicationEvents.map(\.name).sorted()
        #expect(names == ["Concerta", "Magnesium"])
        #expect(r.medicationEvents.filter { $0.name == "Concerta" }.count == 1)
    }

    @Test func hasMedicationTrueWithManualOnly() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        let manual = MedicationEvent(name: "Concerta", takenAt: r.createdAt, taken: true, source: .manual)
        context.insert(manual); manual.recording = r

        r.setMedicationEvents(from: [], durationHours: nil, context: context)
        #expect(r.hasMedication == true)
    }

    @Test func appliesTopicsToTopicTagsJSON() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        r.applySummary(makeResult(topics: ["Medications", "Symptoms"]))
        #expect(r.topicCategories == [.medications, .symptoms])
    }

    @Test func emptyTopicsLeaveExistingJSONUntouched() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        r.topicTagsJSON = "[\"General\"]"
        r.applySummary(makeResult())
        #expect(r.topicCategories == [.general])
    }
}
