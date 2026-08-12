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

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }
    
    var shouldThrowInsufficientMemory = false
    func setShouldThrowInsufficientMemory(_ value: Bool) {
        shouldThrowInsufficientMemory = value
    }

    func setHangs(_ v: Bool) { hangs = v }

    func summarize(rawTranscription: String) async throws -> SummaryResult {
        if hangs { while !Task.isCancelled { await Task.yield() } }
        if shouldThrowInsufficientMemory { throw SummarizationError.insufficientMemory }
        if shouldThrow { throw SummarizationError.inferenceFailed("Mock error") }
        return stubResult
    }
}
