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
    var hangs = false
    /// Lets a test prove the deleted-@Model guards short-circuit *before* any work starts.
    private(set) var summarizeCallCount = 0

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }

    func setHangs(_ v: Bool) { hangs = v }

    func summarize(rawTranscription: String) async throws -> SummaryResult {
        summarizeCallCount += 1
        if hangs { while !Task.isCancelled { await Task.yield() } }
        if shouldThrow { throw SummarizationError.inferenceFailed("Mock error") }
        return stubResult
    }
}
