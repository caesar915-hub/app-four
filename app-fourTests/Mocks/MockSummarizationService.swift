import Foundation
@testable import app_four

actor MockSummarizationService: SummarizationService {
    var stubResult = SummaryResult(
        bullets: ["Took Concerta 36mg at 8am", "Feeling focused"],
        medications: [MedEvent(name: "Concerta", dose: "36mg", time: "08:00", timeLabel: "8am", taken: true)],
        generatedTitle: "Morning Medication Entry",
        energyLevel: "high",
        focusLevel: "high",
        mood: "positive",
        sleepHours: nil,
        sleepQuality: nil,
        sleepEvent: nil,
        sleepLevel: nil,
        sideEffects: [],
        emotions: [],
        topics: [],
        noteExtraction: nil
    )
    var shouldThrow = false

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }

    func summarize(rawTranscription: String) async throws -> SummaryResult {
        if shouldThrow { throw SummarizationError.inferenceFailed("Mock error") }
        return stubResult
    }
}
