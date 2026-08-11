import Testing
import Foundation
@testable import app_four

@Suite struct ExtractionValidatorTests {
    let lexicon = LexiconLoader.loadBundled()
    
    private func makeExtraction(
        mood: String? = nil, energy: String? = nil, focus: String? = nil,
        sleepHours: Double? = nil, sleepQuality: String? = nil,
        medications: [MedicationExtraction] = [], emotions: [String] = [],
        activities: [String] = [], topics: [String] = [], lexicon: [String] = [],
        summary: String? = nil, sideEffects: [String] = []
    ) -> UnifiedExtraction {
        UnifiedExtraction(mood: mood, energy: energy, focus: focus, sleepHours: sleepHours, sleepQuality: sleepQuality, medications: medications, emotions: emotions, activities: activities, topics: topics, lexicon: lexicon, summary: summary, sideEffects: sideEffects)
    }

    // Mood clamping
    @Test(arguments: ["low", "flat", "okay", "good", "great"])
    func validMoodPassesClamping(mood: String) {
        let extraction = makeExtraction(mood: mood)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.mood == mood)
    }
    
    @Test(arguments: ["Bad", "fantastic", "Awful", "happy", "GOOD", ""])
    func invalidMoodClampedToNil(mood: String) {
        let extraction = makeExtraction(mood: mood)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.mood == nil)
    }

    // Energy clamping
    @Test(arguments: ["sluggish", "tired", "steady", "alert", "charged"])
    func validEnergyPasses(energy: String) {
        let extraction = makeExtraction(energy: energy)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.energy == energy)
    }
    
    @Test(arguments: ["fantastic", "Low", "energized", "CHARGED"])
    func invalidEnergyClamped(energy: String) {
        let extraction = makeExtraction(energy: energy)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.energy == nil)
    }

    // Focus clamping
    @Test(arguments: ["foggy", "distracted", "present", "sharp", "lockedIn"])
    func validFocusPasses(focus: String) {
        let extraction = makeExtraction(focus: focus)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.focus == focus)
    }
    
    @Test(arguments: ["lockedin", "locked_in", "LockedIn", "focused"])
    func invalidFocusClamped(focus: String) {
        let extraction = makeExtraction(focus: focus)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.focus == nil)
    }

    // SleepHours range
    @Test func sleepHoursRangeClamping() {
        #expect(ExtractionValidator.validate(makeExtraction(sleepHours: 7.5), lexicon: lexicon).sleepHours == 7.5)
        #expect(ExtractionValidator.validate(makeExtraction(sleepHours: 0.0), lexicon: lexicon).sleepHours == 0.0)
        #expect(ExtractionValidator.validate(makeExtraction(sleepHours: 24.0), lexicon: lexicon).sleepHours == 24.0)
        #expect(ExtractionValidator.validate(makeExtraction(sleepHours: -1.0), lexicon: lexicon).sleepHours == nil)
        #expect(ExtractionValidator.validate(makeExtraction(sleepHours: 25.0), lexicon: lexicon).sleepHours == nil)
        #expect(ExtractionValidator.validate(makeExtraction(sleepHours: nil), lexicon: lexicon).sleepHours == nil)
    }

    // SleepQuality clamping
    @Test(arguments: ["restless", "light", "okay", "good", "deep"])
    func validSleepQualityPasses(quality: String) {
        let extraction = makeExtraction(sleepQuality: quality)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.sleepQuality == quality)
    }
    
    @Test(arguments: ["poor", "insomnia", "bad", "excellent"])
    func invalidSleepQualityClamped(quality: String) {
        let extraction = makeExtraction(sleepQuality: quality)
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.sleepQuality == nil)
    }

    // Sleep level derivation
    @Test func sleepLevelDerivation() {
        #expect(ExtractionValidator.deriveSleepLevel(hours: 4.0) == "restless")
        #expect(ExtractionValidator.deriveSleepLevel(hours: 5.0) == "light")
        #expect(ExtractionValidator.deriveSleepLevel(hours: 6.0) == "okay")
        #expect(ExtractionValidator.deriveSleepLevel(hours: 7.0) == "good")
        #expect(ExtractionValidator.deriveSleepLevel(hours: 9.0) == "deep")
    }
    
    @Test func nilSleepHoursReturnsNilLevel() {
        #expect(ExtractionValidator.deriveSleepLevel(hours: nil) == nil)
    }
    
    @Test func explicitQualityTakesPrecedence() {
        let extraction = makeExtraction(sleepHours: 4.0, sleepQuality: "good")
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.sleepQuality == "good")
        #expect(validated.sleepHours == 4.0)
    }

    // Emotion filtering
    @Test func emotionFiltering() {
        let extraction = makeExtraction(emotions: ["excited", "blissful", "grateful", "happy", "anxious"])
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.emotions == ["excited", "grateful", "anxious"])
    }

    // Activity filtering
    @Test func activityFiltering() {
        let extraction = makeExtraction(activities: ["Work", "Napping", "Fitness", "Meditating"])
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.activities == ["Work", "Fitness"])
    }

    // SideEffect filtering
    @Test func sideEffectFiltering() {
        let valid = lexicon.sideEffectCues.first ?? "headache"
        let extraction = makeExtraction(sideEffects: [valid, "MadeUpSideEffect"])
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.sideEffects.contains(valid))
        #expect(!validated.sideEffects.contains("MadeUpSideEffect"))
    }

    // Topics
    @Test func topicsTruncated() {
        let extraction = makeExtraction(topics: ["A", "B", "C", "D", "E"])
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.topics.count == 4)
    }
    
    @Test func lexiconTruncated() {
        let extraction = makeExtraction(lexicon: ["A", "B", "C", "D", "E", "F"])
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.lexicon.count == 5)
    }

    // Summary
    @Test func emptySummarySetToNil() {
        #expect(ExtractionValidator.validate(makeExtraction(summary: ""), lexicon: lexicon).summary == nil)
        #expect(ExtractionValidator.validate(makeExtraction(summary: "  "), lexicon: lexicon).summary == nil)
    }

    // Medications
    @Test func nonLexiconMedicationsKept() {
        let med = MedicationExtraction(name: "Tylenol")
        let extraction = makeExtraction(medications: [med])
        let validated = ExtractionValidator.validate(extraction, lexicon: lexicon)
        #expect(validated.medications.count == 1)
        #expect(validated.medications.first?.name == "Tylenol")
    }

    // Topic injection
    @Test func medicationsTopicInjected() {
        let extraction = makeExtraction(medications: [MedicationExtraction(name: "Adderall")])
        let topics = ExtractionValidator.deriveTopics([], extraction: extraction, lexicon: lexicon)
        #expect(topics.contains("Medications"))
    }
    
    @Test func symptomsTopicInjected() {
        let extraction = makeExtraction(sideEffects: ["Headache"])
        let topics = ExtractionValidator.deriveTopics([], extraction: extraction, lexicon: lexicon)
        #expect(topics.contains("Symptoms"))
    }
    
    @Test func noDuplicateTopics() {
        let extraction = makeExtraction(medications: [MedicationExtraction(name: "Adderall")])
        let topics = ExtractionValidator.deriveTopics(["Medications"], extraction: extraction, lexicon: lexicon)
        #expect(topics.filter { $0 == "Medications" }.count == 1)
    }
    
    @Test func noInjectionWhenContentAbsent() {
        let extraction = makeExtraction()
        let topics = ExtractionValidator.deriveTopics([], extraction: extraction, lexicon: lexicon)
        #expect(!topics.contains("Medications"))
        #expect(!topics.contains("Symptoms"))
    }
}
