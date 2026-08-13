import Foundation
import SquirlSignals

nonisolated enum MLXPromptBuilder {
    static func buildSystemPrompt(lexicon: Lexicon) -> String {
        let moodLabels = MoodLevel.allCases.map { $0.rawValue }.joined(separator: ", ")
        let energyLabels = EnergyLevel.allCases.map { $0.rawValue }.joined(separator: ", ")
        let focusLabels = FocusLevel.allCases.map { $0.rawValue }.joined(separator: ", ")
        let sleepLabels = SleepLevel.allCases.map { $0.rawValue }.joined(separator: ", ")
        
        let medications = lexicon.medications.joined(separator: ", ").replacingOccurrences(of: "PM", with: "pm").replacingOccurrences(of: "AM", with: "am")
        
        // Build vocabulary section dynamically
        var vocabLines: [String] = []
        if let firstMood = lexicon.moodSpecific.first?.word {
            vocabLines.append("- Mood: \(firstMood), bouncing off the walls")
        }
        if let firstFocus = lexicon.focusFoggy.first {
            vocabLines.append("- Focus: \(firstFocus), brain fog")
        }
        if let firstEnergy = lexicon.energyTired.first {
            vocabLines.append("- Energy: \(firstEnergy), no spoons")
        }
        if let firstSleep = lexicon.sleepQualityBad.first {
            vocabLines.append("- Sleep: \(firstSleep), tossed and turned")
        }
        if let firstExec = lexicon.executiveDysfunction.first {
            vocabLines.append("- Executive Dysfunction: \(firstExec), doom pile")
        }
        
        let vocabSection = vocabLines.joined(separator: "\n        ")
        
        let prompt = """
        You are an expert clinical extractor. Extract ADHD journal signals from the transcription.
        You must return ONLY JSON. no surrounding text, no markdown backticks, no explanations.
        
        ALLOWED SIGNAL LABELS:
        - Mood: \(moodLabels)
        - Energy: \(energyLabels)
        - Focus: \(focusLabels)
        - Sleep: \(sleepLabels)
        
        COMMON VOCABULARY & SLANG (use to detect signals):
        \(vocabSection)
        
        KNOWN MEDICATIONS:
        \(medications), Vyvanse, Concerta, addy, vyvance
        
        FEW-SHOT Examples:
        
        Example 1 (Short Check-in):
        {
          "summary": null,
          "mood": "okay",
          "topics": ["medication"],
          "lexiconPhrases": []
        }
        
        Example 2 (Journal):
        {
          "summary": "Had a rough day, couldn't focus.",
          "mood": "low",
          "focus": "foggy",
          "topics": ["work"],
          "lexiconPhrases": ["brain fog"]
        }
        
        Example 3 (Hybrid):
        {
          "summary": "Feeling great after gym.",
          "mood": "good",
          "energy": "charged",
          "topics": ["exercise"],
          "lexiconPhrases": ["bouncing off the walls"]
        }
        """
        
        return prompt
    }
    
    static func buildUserMessage(transcript: String) -> String {
        return "Extract signals from this transcript:\n\(transcript)"
    }
}
