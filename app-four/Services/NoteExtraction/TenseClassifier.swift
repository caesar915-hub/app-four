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

    private let presentMarkers: [String]
    private let pastMarkers: [String]
    private let pastVerbSuffixes: [String]
    private let irregularPastVerbs: Set<String>

    /// Markers + past-verb morphology are per-language (spec 003 FR-003); defaults are
    /// the English config so existing behavior is unchanged.
    public init(
        presentMarkers: [String] = LanguageConfig.english.presentMarkers,
        pastMarkers: [String] = LanguageConfig.english.pastMarkers,
        pastVerbSuffixes: [String] = LanguageConfig.english.pastVerbSuffixes,
        irregularPastVerbs: [String] = LanguageConfig.english.irregularPastVerbs
    ) {
        self.presentMarkers = presentMarkers
        self.pastMarkers = pastMarkers
        self.pastVerbSuffixes = pastVerbSuffixes
        self.irregularPastVerbs = Set(irregularPastVerbs)
    }

    /// Classify the sentence's dominant tense. Explicit lexical markers take
    /// priority; otherwise we fall back to verb-tense from `NLTagger`.
    public func tense(of sentence: String) -> Tense {
        let lower = sentence.lowercased()

        let present = presentMarkers.contains { lower.contains($0) }
        let past = pastMarkers.contains { lower.contains($0) }

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
        let lastPresent = presentMarkers.compactMap { lower.range(of: $0)?.lowerBound }.max()
        let lastPast = pastMarkers.compactMap { lower.range(of: $0)?.lowerBound }.max()
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
                if pastVerbSuffixes.contains(where: { word.hasSuffix($0) }) || irregularPastVerbs.contains(String(word)) {
                    sawPastVerb = true
                }
            }
            return true
        }
        if sawPastVerb { return .past }
        return sawVerb ? .neutral : .neutral
    }

}
