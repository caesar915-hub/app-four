import Foundation

/// Codable representation of the lexicon, loaded from a bundled `lexicon.json`.
/// This is the reviewable, growable data form of the vocabulary; `LexiconData`
/// builds the typed `Lexicon` the extractor consumes. The `Lexicon(...)` memberwise
/// init is kept for tests and overlays — only the *defaults* move to data.
///
/// Shape mirrors `Lexicon` 1:1 so the loader is a pure mapping (no behaviour
/// change vs. the former hard-coded `defaultX` lists). The two label/keyword maps
/// (mood, time-of-day) are encoded as `[entry]` pairs to stay JSON-friendly.
public nonisolated struct LexiconData: Codable, Sendable {

    public struct MoodEntry: Codable, Sendable {
        public let word: String
        public let label: String
    }

    public struct TimeKeyword: Codable, Sendable {
        public let keyword: String
        public let normalized: String
    }

    public struct ActivityEntry: Codable, Sendable {
        public let category: String
        public let keywords: [String]
    }

    public var medications: [String]
    public var moodSpecific: [MoodEntry]
    public var energyCharged: [String]
    public var energyAlert: [String]
    public var energySteady: [String]
    public var energyTired: [String]
    public var energySluggish: [String]
    public var focusLockedIn: [String]
    public var focusSharp: [String]
    public var focusPresent: [String]
    public var focusDistracted: [String]
    public var focusFoggy: [String]
    public var emotions: [String]
    public var taskCompletionCues: [String]
    public var taskAvoidanceCues: [String]
    public var winCues: [String]
    public var overwhelmCues: [String]
    public var executiveDysfunction: [String]
    public var appointmentCues: [String]
    public var sideEffectCues: [String]
    public var physicalStim: [String]
    public var physicalSideEffects: [String]
    public var sleepQualityGood: [String]
    public var sleepQualityBad: [String]
    public var sleepInsomnia: [String]
    public var reboundTerms: [String]
    public var appetiteLoss: [String]
    public var appetiteReturn: [String]
    public var negationTokens: [String]
    public var medNotTakenVerbs: [String]
    public var timeOfDayKeywords: [TimeKeyword]
    public var activityKeywords: [ActivityEntry]

    /// Build the typed `Lexicon` this data represents. A `personalOverlay` (P2.3)
    /// can append user-specific terms on top of the bundled base.
    public func toLexicon(personalOverlay: PersonalLexicon? = nil) -> Lexicon {
        let extraMood = personalOverlay?.moodSpecific.map { ($0.word, $0.label) } ?? []
        let extraMeds = personalOverlay?.medications ?? []
        let extraEmotions = personalOverlay?.emotions ?? []

        return Lexicon(
            medications: medications + extraMeds,
            moodSpecific: moodSpecific.map { ($0.word, $0.label) } + extraMood,
            energyCharged: energyCharged,
            energyAlert: energyAlert,
            energySteady: energySteady,
            energyTired: energyTired,
            energySluggish: energySluggish,
            focusLockedIn: focusLockedIn,
            focusSharp: focusSharp,
            focusPresent: focusPresent,
            focusDistracted: focusDistracted,
            focusFoggy: focusFoggy,
            emotions: emotions + extraEmotions,
            taskCompletionCues: taskCompletionCues,
            taskAvoidanceCues: taskAvoidanceCues,
            winCues: winCues,
            overwhelmCues: overwhelmCues,
            executiveDysfunction: executiveDysfunction,
            appointmentCues: appointmentCues,
            sideEffectCues: sideEffectCues,
            physicalStim: physicalStim,
            physicalSideEffects: physicalSideEffects,
            sleepQualityGood: sleepQualityGood,
            sleepQualityBad: sleepQualityBad,
            sleepInsomnia: sleepInsomnia,
            reboundTerms: reboundTerms,
            appetiteLoss: appetiteLoss,
            appetiteReturn: appetiteReturn,
            negationTokens: negationTokens,
            medNotTakenVerbs: medNotTakenVerbs,
            timeOfDayKeywords: timeOfDayKeywords.map { ($0.keyword, $0.normalized) },
            activityKeywords: activityKeywords.map { ($0.category, $0.keywords) }
        )
    }
}

/// User-specific vocabulary layered over the bundled base (P2.3). Seeded from the
/// `RecordingTag(source: .userCorrected)` rows written in review confirm.
public struct PersonalLexicon: Codable, Sendable {
    public var medications: [String] = []
    public var moodSpecific: [LexiconData.MoodEntry] = []
    public var emotions: [String] = []

    public init(medications: [String] = [], moodSpecific: [LexiconData.MoodEntry] = [], emotions: [String] = []) {
        self.medications = medications
        self.moodSpecific = moodSpecific
        self.emotions = emotions
    }
}

public nonisolated enum LexiconLoader {
    /// Loads the bundled `lexicon.json`. Falls back to the code defaults if the
    /// resource is missing or malformed, so extraction never silently breaks.
    public static func loadBundled(overlay: PersonalLexicon? = nil) -> Lexicon {
        guard let url = Bundle.main.url(forResource: "lexicon", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(LexiconData.self, from: data) else {
            return Lexicon()   // code defaults
        }
        return decoded.toLexicon(personalOverlay: overlay)
    }
}
