import Testing
@testable import app_four

struct NLNoteExtractorMoodTests {

    let extractor = NLNoteExtractor()

    // MARK: - Exact match coverage

    @Test func detectsHappy() {
        let result = extractor.extract(from: "I feel happy today.")
        #expect(result.mood == "great")
    }

    @Test func detectsCalm() {
        let result = extractor.extract(from: "Feeling calm and relaxed.")
        #expect(result.mood == "good")
    }

    @Test func detectsAnxious() {
        let result = extractor.extract(from: "I'm anxious about the meeting.")
        #expect(result.mood == "low")
    }

    @Test func detectsSad() {
        let result = extractor.extract(from: "Feeling really sad this morning.")
        #expect(result.mood == "low")
    }

    @Test func detectsAccomplished() {
        let result = extractor.extract(from: "I nailed it today, got shit done.")
        #expect(result.mood == "great")
    }

    @Test func detectsFlat() {
        // Was "I feel like a zombie, totally zoned out." — under longest-match-wins
        // (Task 5) "zoned out"→low (9 chars) beats "zombie"→flat (6 chars), so the
        // old answer depended on array order. Use a sentence with only the flat cue.
        let result = extractor.extract(from: "I feel like a zombie today.")
        #expect(result.mood == "flat")
    }

    @Test func detectsIrritable() {
        let result = extractor.extract(from: "I'm grumpy and snappy today.")
        #expect(result.mood == "low")
    }

    // MARK: - Previously missing lexicon terms

    @Test func detectsGreat() {
        let result = extractor.extract(from: "I feel great today.")
        #expect(result.mood == "great")
    }

    @Test func detectsGood() {
        let result = extractor.extract(from: "Feeling good overall.")
        #expect(result.mood == "good")
    }

    @Test func detectsDepressed() {
        let result = extractor.extract(from: "I'm depressed and hopeless.")
        #expect(result.mood == "low")
    }

    @Test func detectsWorried() {
        let result = extractor.extract(from: "I'm worried about my dosage.")
        #expect(result.mood == "low")
    }

    @Test func detectsAngry() {
        let result = extractor.extract(from: "I'm angry at my coworker.")
        #expect(result.mood == "low")
    }

    @Test func detectsZonedOut() {
        let result = extractor.extract(from: "Totally zoned out, can't focus.")
        #expect(result.mood == "low")
    }

    // MARK: - Negation handling

    @Test func negatesHappyToSad() {
        let result = extractor.extract(from: "I'm not happy today.")
        #expect(result.mood == "low")
    }

    @Test func negatesCalmToAnxious() {
        let result = extractor.extract(from: "I am not calm at all.")
        #expect(result.mood == "low")
    }

    @Test func negatesEmbeddingMatch() {
        let result = extractor.extract(from: "I'm not cheerful today.")
        #expect(result.mood == "low")
    }

    // MARK: - Sentiment fallback

    @Test func sentimentFallbackPositive() {
        let result = extractor.extract(from: "Everything went perfectly today. Wonderful experience.")
        #expect(result.mood == "great")
    }

    @Test func sentimentFallbackNegative() {
        let result = extractor.extract(from: "Terrible day. Everything went wrong.")
        #expect(result.mood == "low")
    }

    @Test func noFallbackForNeutral() {
        let result = extractor.extract(from: "I went to the store and bought milk.")
        #expect(result.mood == nil)
    }

    // MARK: - Edge cases

    @Test func emptyTranscriptReturnsNoMood() {
        let result = extractor.extract(from: "")
        #expect(result.mood == nil)
    }

    @Test func neutralMoodDetected() {
        let result = extractor.extract(from: "I'm feeling okay, not bad.")
        #expect(result.mood == "okay")
    }

    // MARK: - Common-word traps (Task 5)

    @Test func nothingAsPronounDoesNotSetMood() {
        #expect(extractor.extract(from: "Nothing much happened today.").mood == nil)
    }
    @Test func feelNothingSetsFlat() {
        #expect(extractor.extract(from: "I feel nothing today.").mood == "flat")
    }
    @Test func emptyObjectDoesNotSetMood() {
        #expect(extractor.extract(from: "The fridge was empty so I ordered groceries.").mood == nil)
    }
    @Test func feelEmptySetsFlat() {
        #expect(extractor.extract(from: "Honestly I just feel empty.").mood == "flat")
    }
    @Test func heavyObjectDoesNotSetMood() {
        #expect(extractor.extract(from: "My gym bag felt heavy.").mood == nil)
    }
    @Test func longestMoodPhraseWins() {
        #expect(extractor.extract(from: "Today was not bad at all.").mood == "okay")
    }
}
