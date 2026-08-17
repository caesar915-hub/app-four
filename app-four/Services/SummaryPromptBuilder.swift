import Foundation

/// Pass 1 of the two-pass pipeline: holistic narrative summary.
/// Owns the `summary` field — Pass 2 (`SignalPromptBuilder`) never sees it.
nonisolated enum SummaryPromptBuilder {
    static func buildSystemPrompt() -> String {
        return PromptLoader.loadSummarySystemPrompt()
    }

    static func buildUserMessage(transcript: String) -> String {
        return PromptLoader.loadSummaryUserPrompt(transcript: transcript)
    }
}
