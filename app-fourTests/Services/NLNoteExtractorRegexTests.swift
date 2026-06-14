import Testing
@testable import app_four

/// P0.6 — tighten loose regex fallbacks (Bug 14).
struct NLNoteExtractorRegexTests {

    let extractor = NLNoteExtractor()

    // "worked 12 hours" in a sleep-keyword sentence must NOT be read as 12h sleep.
    @Test func workHoursInSleepSentenceIsNotSleepHours() {
        let result = extractor.extract(from: "I couldn't sleep, so I worked 12 hours.")
        #expect(result.sleepHours == nil)
    }

    // A genuine sleep-duration phrase still extracts.
    @Test func realSleptHoursStillExtract() {
        let result = extractor.extract(from: "I slept 7 hours last night.")
        #expect(result.sleepHours == 7)
    }

    // "took 2 hours to fall asleep" is latency, not medication onset.
    @Test func fallAsleepLatencyIsNotOnset() {
        let result = extractor.extract(from: "It took 2 hours to fall asleep.")
        #expect(result.onsetMinutes == nil)
    }

    // A real onset phrase still extracts.
    @Test func realOnsetStillExtracts() {
        let result = extractor.extract(from: "The meds kicked in after 45 minutes.")
        #expect(result.onsetMinutes == 45)
    }
}
