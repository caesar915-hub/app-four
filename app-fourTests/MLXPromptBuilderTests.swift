import Testing
@testable import app_four
import SquirlSignals

@Suite struct MLXPromptBuilderTests {
    let lexicon: Lexicon
    
    init() {
        // loadBundled() is non-throwing (falls back to code defaults).
        self.lexicon = LexiconLoader.loadBundled()
    }
    
    @Test(arguments: MoodLevel.allCases)
    func promptContainsMoodLabel(_ level: MoodLevel) throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains(level.rawValue))
    }
    
    @Test(arguments: EnergyLevel.allCases)
    func promptContainsEnergyLabel(_ level: EnergyLevel) throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains(level.rawValue))
    }
    
    @Test(arguments: FocusLevel.allCases)
    func promptContainsFocusLabel(_ level: FocusLevel) throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains(level.rawValue))
    }
    
    @Test(arguments: SleepLevel.allCases)
    func promptContainsSleepLabel(_ level: SleepLevel) throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains(level.rawValue))
    }
    
    @Test func promptContainsMedicationVocabulary() throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains("Vyvanse"))
        #expect(prompt.contains("Concerta"))
        #expect(prompt.contains("addy"))
        #expect(prompt.contains("vyvance"))
    }
    
    @Test func promptContainsLexiconVocabulary() throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        // Check representative inclusions
        #expect(prompt.contains("bouncing off the walls"))
        #expect(prompt.contains("brain fog"))
        #expect(prompt.contains("no spoons"))
        #expect(prompt.contains("doom pile"))
        #expect(prompt.contains("tossed and turned"))
        
        // Check strict exclusions
        #expect(!prompt.contains("not taken"))
        #expect(!prompt.contains("forgot"))
        #expect(!prompt.contains("AM"))
        #expect(!prompt.contains("PM"))
    }
    
    @Test func promptContainsFewShotExamples() throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        // Check for specific few-shot markers
        #expect(prompt.contains("\"summary\": null"))
        #expect(prompt.contains("\"topics\":"))
        #expect(prompt.contains("\"lexiconPhrases\":"))
    }
    
    @Test func promptInstructsJsonOnly() throws {
        let prompt = MLXPromptBuilder.buildSystemPrompt(lexicon: lexicon)
        #expect(prompt.contains("ONLY JSON"))
        #expect(prompt.contains("no surrounding text"))
    }
    
    @Test func userMessageInterpolatesTranscript() {
        let message = MLXPromptBuilder.buildUserMessage(transcript: "Took my Vyvanse this morning")
        #expect(message.contains("Took my Vyvanse this morning"))
        #expect(!message.contains("\\(transcript)"))
    }
}
