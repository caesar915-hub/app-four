import Testing
@testable import app_four

/// P0.7 — mood aggregation = present-tense-wins. Past-tense moods are context;
/// the present-tense mood is the headline.
struct NLNoteExtractorTenseTests {

    let extractor = NLNoteExtractor()

    // "started okay ... by evening I'm at rock bottom" → low (present wins).
    @Test func presentLowBeatsPastOkay() {
        let result = extractor.extract(from: "This morning started okay. By evening I'm at rock bottom.")
        #expect(result.mood == "low")
    }

    // "This morning I was a mess but now I feel okay" → okay (present wins).
    @Test func presentOkayBeatsPastLow() {
        let result = extractor.extract(from: "This morning I was a mess. Right now I feel okay.")
        #expect(result.mood == "okay")
    }

    // All-present single sentence is unaffected.
    @Test func singlePresentSentenceUnchanged() {
        let result = extractor.extract(from: "I feel great today.")
        #expect(result.mood == "great")
    }

    // Tie / all-past falls back to the most recent sentence.
    @Test func allPastFallsBackToMostRecent() {
        let result = extractor.extract(from: "Earlier I felt great. Later I felt depressed.")
        #expect(result.mood == "low")
    }
}

/// Direct unit tests for the tense classifier.
struct TenseClassifierTests {
    let classifier = TenseClassifier()

    @Test func detectsPresent() {
        #expect(classifier.tense(of: "Right now I feel anxious.") == .present)
        #expect(classifier.tense(of: "I'm calm today.") == .present)
    }

    @Test func detectsPast() {
        #expect(classifier.tense(of: "This morning I was a mess.") == .past)
        #expect(classifier.tense(of: "Earlier I felt depressed.") == .past)
    }

    @Test func pastProgressiveIsPast() {
        #expect(TenseClassifier().tense(of: "I was feeling really anxious") == .past)
    }

    @Test func presentPerfectProgressiveIsPresent() {
        #expect(TenseClassifier().tense(of: "I've been feeling great lately") == .present)
    }

    @Test func presentMoodBeatsPastProgressiveMood() {
        let r = NLNoteExtractor().extract(from: "I was feeling really anxious on Monday. Today I am calm.")
        #expect(r.mood == "good")   // calm → good; past anxious must not win the headline
    }
}
