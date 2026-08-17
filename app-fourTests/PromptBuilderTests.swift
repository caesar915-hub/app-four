import Testing
@testable import app_four
import SquirlSignals

@Suite struct SummaryPromptBuilderTests {
    @Test func systemPromptDescribesHolisticSummary() {
        let prompt = SummaryPromptBuilder.buildSystemPrompt()
        #expect(prompt.contains("1-2 sentence"))
        #expect(prompt.contains("full arc"))
        #expect(prompt.contains("only the summary text"))
    }

    @Test func userMessageInterpolatesTranscript() {
        let message = SummaryPromptBuilder.buildUserMessage(transcript: "Felt rough this morning, much better now.")
        #expect(message.contains("Felt rough this morning, much better now."))
        #expect(!message.contains("\\(transcript)"))
    }
}

@Suite struct SignalPromptBuilderTests {
    let lexicon: Lexicon

    init() {
        // loadBundled() is non-throwing (falls back to code defaults).
        self.lexicon = LexiconLoader.loadBundled()
    }

    @Test(arguments: MoodLevel.allCases)
    func promptContainsMoodLabel(_ level: MoodLevel) {
        #expect(SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon).contains(level.rawValue))
    }

    @Test(arguments: EnergyLevel.allCases)
    func promptContainsEnergyLabel(_ level: EnergyLevel) {
        #expect(SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon).contains(level.rawValue))
    }

    @Test(arguments: FocusLevel.allCases)
    func promptContainsFocusLabel(_ level: FocusLevel) {
        #expect(SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon).contains(level.rawValue))
    }

    @Test(arguments: SleepLevel.allCases)
    func promptContainsSleepLabel(_ level: SleepLevel) {
        #expect(SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon).contains(level.rawValue))
    }

    @Test func promptContainsTemporalRules() {
        let prompt = SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains("TEMPORAL RULES"))
        #expect(prompt.contains("CURRENT"))
        #expect(prompt.contains("NOW"))
    }

    @Test func promptNarrowsNullEscapeHatch() {
        let prompt = SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains("no evidence at all"))
        #expect(prompt.contains("Never return null for a signal the user explicitly states"))
    }

    @Test func promptContainsFewShotExampleWithRealLabels() {
        let prompt = SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains("\"mood\":\"great\""))
        #expect(prompt.contains("\"focus\":\"lockedIn\""))
    }

    @Test func promptContainsMedicationVocabulary() {
        let prompt = SignalPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains("Vyvanse"))
        #expect(prompt.contains("Concerta"))
        #expect(prompt.contains("addy"))
        #expect(prompt.contains("vyvance"))
    }

    @Test func userMessageHasNoSummaryKey() {
        let message = SignalPromptBuilder.buildUserMessage(transcript: "Took my Vyvanse this morning")
        #expect(message.contains("Took my Vyvanse this morning"))
        #expect(!message.contains("\"summary\""))
        #expect(!message.contains("\\(transcript)"))
    }
}
