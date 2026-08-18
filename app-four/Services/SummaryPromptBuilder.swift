import Foundation

/// Defines progressive summary length and token budgets based on transcript duration (from 15 seconds up to 15+ minutes).
public enum SummaryLengthTier: Sendable {
    case micro          // < 1 min (< 120 words): 1-2 sentences (max 100 tokens)
    case standard       // 1-3 min (120-400 words): 2-3 sentences (max 160 tokens)
    case extended       // 3-7 min (400-1000 words): 3-4 sentences (max 240 tokens)
    case longSession    // 7-12 min (1000-1800 words): 4-5 sentences (max 320 tokens)
    case comprehensive  // 12-15+ min (> 1800 words): 5-6 structured sentences (max 420 tokens)

    public static func tier(for transcript: String) -> SummaryLengthTier {
        let words = transcript.split(whereSeparator: \.isWhitespace).count
        switch words {
        case ..<120:
            return .micro
        case 120..<400:
            return .standard
        case 400..<1000:
            return .extended
        case 1000..<1800:
            return .longSession
        default:
            return .comprehensive
        }
    }

    public var maxTokens: Int {
        switch self {
        case .micro: return 100
        case .standard: return 160
        case .extended: return 240
        case .longSession: return 320
        case .comprehensive: return 420
        }
    }

    public var instruction: String {
        switch self {
        case .micro:
            return "Write a concise 1-2 sentence summary capturing what the speaker experienced:"
        case .standard:
            return "Write a clear 2-3 sentence summary capturing the speaker's activities, feelings, and key reflections:"
        case .extended:
            return "Write a structured 3-4 sentence summary synthesizing the progression of events, medications, emotional state, and actions across the session:"
        case .longSession:
            return "Write a comprehensive 4-5 sentence summary synthesizing the multi-phase day arc, emotional shifts, interventions, and key takeaways:"
        case .comprehensive:
            return "Write an in-depth 5-6 sentence clinical narrative summary capturing the full multi-phase reflection, core behavioral patterns, triggers, medication responses, and present baseline:"
        }
    }
}

/// Pass 1 of the two-pass pipeline: holistic narrative summary.
/// Owns the `summary` field — Pass 2 (`SignalPromptBuilder`) never sees it.
public nonisolated enum SummaryPromptBuilder {
    public static func buildSystemPrompt() -> String {
        return PromptLoader.loadSummarySystemPrompt()
    }

    public static func buildUserMessage(transcript: String, tier: SummaryLengthTier? = nil) -> String {
        let activeTier = tier ?? SummaryLengthTier.tier(for: transcript)
        return PromptLoader.loadSummaryUserPrompt(transcript: transcript, tier: activeTier)
    }
}
