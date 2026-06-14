import Foundation
import NaturalLanguage

/// Classifies a sentence as describing the present, the past, or neither.
/// Used by mood aggregation: the *present* mood is the note's headline; past
/// moods are context. (Decision 2026-06-11: present-tense wins.)
public nonisolated struct TenseClassifier: Sendable {

    public enum Tense: Sendable, Equatable {
        case present
        case past
        case neutral

        /// Weight for argmax mood selection — present dominates, past is context.
        public var temporalWeight: Double {
            switch self {
            case .present: return 1.0
            case .neutral: return 0.5
            case .past:    return 0.2
            }
        }
    }

    public init() {}

    private static let presentMarkers: [String] = [
        "right now", "currently", "today", "i feel", "i'm feeling", "i am feeling",
        "i am", "i'm", "this evening", "tonight", "at the moment", "these days",
        "now i", "now i'm", "i've been feeling", "i have been feeling"
    ]

    private static let pastMarkers: [String] = [
        "i was", "i felt", "earlier", "this morning", "yesterday", "last night",
        "by evening", "by the afternoon", "this afternoon", "woke up", "had been",
        "used to", "a while ago", "before", "was feeling", "were feeling"
    ]

    /// Classify the sentence's dominant tense. Explicit lexical markers take
    /// priority; otherwise we fall back to verb-tense from `NLTagger`.
    public func tense(of sentence: String) -> Tense {
        let lower = sentence.lowercased()

        let present = Self.presentMarkers.contains { lower.contains($0) }
        let past = Self.pastMarkers.contains { lower.contains($0) }

        // "now i feel okay" with no past marker → present; "i was ... but now" can
        // contain both — prefer present when a present marker is present, since the
        // headline is what's true now.
        if present && !past { return .present }
        if past && !present { return .past }
        if present && past {
            // Both present — the clause closest to the end ("now") usually wins.
            return lastMarkerIsPresent(in: lower) ? .present : .past
        }

        // No explicit markers: use verb tense.
        return verbTense(of: sentence)
    }

    /// True if the last-occurring tense marker in the sentence is a present one.
    private func lastMarkerIsPresent(in lower: String) -> Bool {
        let lastPresent = Self.presentMarkers.compactMap { lower.range(of: $0)?.lowerBound }.max()
        let lastPast = Self.pastMarkers.compactMap { lower.range(of: $0)?.lowerBound }.max()
        switch (lastPresent, lastPast) {
        case let (p?, q?): return p >= q
        case (.some, nil): return true
        default:           return false
        }
    }

    /// Fall back to verb morphology: a past-tense verb → past, else neutral.
    private func verbTense(of sentence: String) -> Tense {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        var sawPastVerb = false
        var sawVerb = false
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex,
                             unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if tag == .verb {
                sawVerb = true
                let word = sentence[range].lowercased()
                if word.hasSuffix("ed") || Self.irregularPastVerbs.contains(String(word)) {
                    sawPastVerb = true
                }
            }
            return true
        }
        if sawPastVerb { return .past }
        return sawVerb ? .neutral : .neutral
    }

    private static let irregularPastVerbs: Set<String> = [
        "was", "were", "felt", "had", "did", "went", "got", "woke", "became",
        "began", "came", "ran", "saw", "took", "thought", "knew", "made", "found"
    ]
}
