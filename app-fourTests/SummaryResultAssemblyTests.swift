import Testing
import Foundation
@testable import app_four

@Suite struct SummaryResultAssemblyTests {
    let lexicon = LexiconLoader.loadBundled()
    
    @Test func mapsAllFieldsCorrectly() {
        let extraction = UnifiedExtraction(
            mood: "good",
            energy: "alert",
            focus: "sharp",
            sleepHours: 8.0,
            sleepQuality: "good",
            medications: [],
            emotions: ["excited"],
            activities: [],
            topics: ["Work"],
            lexicon: [],
            summary: "You had a productive day",
            sideEffects: []
        )
        
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        let result = ExtractionValidator.assembleSummaryResult(from: validated, lexicon: lexicon, rawTranscript: "I had a productive day")
        
        #expect(result.mood == "good")
        #expect(result.energyLevel == "alert")
        #expect(result.focusLevel == "sharp")
        #expect(result.sleepHours == 8.0)
        #expect(result.sleepQuality == "good")
        #expect(result.emotions == ["excited"])
        #expect(result.topics.contains("Work"))
        #expect(result.bullets.contains("You had a productive day"))
    }
    
    @Test func mapsMedicationToMedEvent() throws {
        let med = MedicationExtraction(name: "Vyvanse", dose: "30mg", taken: true)
        let extraction = UnifiedExtraction(medications: [med])
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        let result = ExtractionValidator.assembleSummaryResult(from: validated, lexicon: lexicon, rawTranscript: "Took meds")
        
        try #require(result.medications.count == 1)
        #expect(result.medications[0].name == "Vyvanse")
        #expect(result.medications[0].dose == "30mg")
        #expect(result.medications[0].taken == true)
    }
    
    @Test func titleFromSignalParts() {
        let ex1 = UnifiedExtraction(mood: "good", energy: "alert", focus: "sharp")
        let res1 = ExtractionValidator.assembleSummaryResult(from: ex1, lexicon: lexicon, rawTranscript: "")
        #expect(res1.generatedTitle == "Good · Alert · Sharp")
        
        let ex2 = UnifiedExtraction(mood: "good")
        let res2 = ExtractionValidator.assembleSummaryResult(from: ex2, lexicon: lexicon, rawTranscript: "")
        #expect(res2.generatedTitle == "Good")
        
        let ex3 = UnifiedExtraction()
        let res3 = ExtractionValidator.assembleSummaryResult(from: ex3, lexicon: lexicon, rawTranscript: "")
        #expect(res3.generatedTitle == "Journal Entry")
    }
    
    @Test func fallbackOnNilExtraction() {
        let result = ExtractionValidator.fallbackResult(rawTranscript: "This is a raw transcript.")
        #expect(result.bullets == ["This is a raw transcript."])
        #expect(result.mood == nil)
        #expect(result.energyLevel == nil)
        #expect(result.focusLevel == nil)
        #expect(result.generatedTitle == "Journal Entry")
    }
    
    @Test func endToEndFallback() {
        let garbage = "Not json at all"
        let extraction = ExtractionValidator.parseExtraction(from: garbage)
        #expect(extraction == nil)
        let result = extraction.map { ExtractionValidator.assembleSummaryResult(from: $0, lexicon: lexicon, rawTranscript: garbage) } ?? ExtractionValidator.fallbackResult(rawTranscript: garbage)
        #expect(result.bullets == [garbage])
    }
}
