import Foundation
import SquirlSignals

/// Pass 2 of the two-pass pipeline: present-moment signal extraction.
/// Outputs strict JSON grounded in the user's CURRENT state ("NOW"); past states
/// mentioned in the transcript are context, not telemetry. The `summary` field is
/// owned by Pass 1 (`SummaryPromptBuilder`) and is not part of this schema.
nonisolated enum SignalPromptBuilder {
    static func buildSystemPrompt(lexicon: Lexicon) -> String {
        return PromptLoader.loadSignalSystemPrompt(lexicon: lexicon)
    }

    static func buildUserMessage(transcript: String) -> String {
        return PromptLoader.loadSignalUserPrompt(transcript: transcript)
    }
}
