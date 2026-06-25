import Foundation

/// Per-language configuration: every table that was English-bound in code is being
/// relocated here so a new language is data, not new code (spec 003, FR-003).
/// Built incrementally — fields are added as each English table is lifted out of
/// `NLNoteExtractor` under the byte-identical English regression gate (gate_en.sh).
public nonisolated struct LanguageConfig: Codable, Sendable {
    public struct WeakEnergyEntry: Codable, Sendable {
        public let word: String
        public let level: EnergyLevel
        public init(word: String, level: EnergyLevel) { self.word = word; self.level = level }
    }
    public struct WeakMoodEntry: Codable, Sendable {
        public let word: String
        public let label: String
        public init(word: String, label: String) { self.word = word; self.label = label }
    }

    /// Spelled-out cardinals → value (sleep-hours reading and similar).
    public let numberWords: [String: Double]

    // MARK: Sleep reading
    /// Curated sleep vocabulary, matched on word boundaries (not substring).
    public let sleepWords: [String]
    /// Extra multiword/duration sleep patterns (regex; e.g. "a wink", "lay awake").
    public let sleepMultiwordPatterns: [String]
    /// Regex for "<n> hours" sleep duration (digits or spelled-out numbers + units).
    public let sleepHoursPattern: String
    /// Regex for the terse "sleep 7" / "slept 7" form (no unit).
    public let sleepBarePattern: String

    // MARK: Weak energy/mood fallback (sentence-gated descriptors)
    /// Substrings that gate the energy fallback (consulted only if present).
    public let weakEnergyTriggers: [String]
    /// Ordered descriptor → level (extreme levels before the neutral default).
    public let weakEnergyTable: [WeakEnergyEntry]
    /// Level + phrase used when energy is named but no descriptor matched.
    public let weakEnergyDefaultLevel: EnergyLevel
    public let weakEnergyDefaultPhrase: String
    /// Regex that gates the mood fallback.
    public let weakMoodTriggerPattern: String
    /// Ordered descriptor → mood label (extreme moods before the neutral default).
    public let weakMoodTable: [WeakMoodEntry]
    /// Label + phrase used when mood is named but no descriptor matched.
    public let weakMoodDefaultLabel: String
    public let weakMoodDefaultPhrase: String

    // MARK: Tense (TenseClassifier)
    public let presentMarkers: [String]
    public let pastMarkers: [String]
    /// Verb-ending suffixes that signal past tense (English: ["ed"]).
    public let pastVerbSuffixes: [String]
    public let irregularPastVerbs: [String]

    public init(
        numberWords: [String: Double],
        sleepWords: [String],
        sleepMultiwordPatterns: [String],
        sleepHoursPattern: String,
        sleepBarePattern: String,
        weakEnergyTriggers: [String],
        weakEnergyTable: [WeakEnergyEntry],
        weakEnergyDefaultLevel: EnergyLevel,
        weakEnergyDefaultPhrase: String,
        weakMoodTriggerPattern: String,
        weakMoodTable: [WeakMoodEntry],
        weakMoodDefaultLabel: String,
        weakMoodDefaultPhrase: String,
        presentMarkers: [String],
        pastMarkers: [String],
        pastVerbSuffixes: [String],
        irregularPastVerbs: [String]
    ) {
        self.numberWords = numberWords
        self.sleepWords = sleepWords
        self.sleepMultiwordPatterns = sleepMultiwordPatterns
        self.sleepHoursPattern = sleepHoursPattern
        self.sleepBarePattern = sleepBarePattern
        self.weakEnergyTriggers = weakEnergyTriggers
        self.weakEnergyTable = weakEnergyTable
        self.weakEnergyDefaultLevel = weakEnergyDefaultLevel
        self.weakEnergyDefaultPhrase = weakEnergyDefaultPhrase
        self.weakMoodTriggerPattern = weakMoodTriggerPattern
        self.weakMoodTable = weakMoodTable
        self.weakMoodDefaultLabel = weakMoodDefaultLabel
        self.weakMoodDefaultPhrase = weakMoodDefaultPhrase
        self.presentMarkers = presentMarkers
        self.pastMarkers = pastMarkers
        self.pastVerbSuffixes = pastVerbSuffixes
        self.irregularPastVerbs = irregularPastVerbs
    }
}

public extension LanguageConfig {
    /// English defaults — values MUST equal the prior in-code literals (FR-004 gate).
    static let english = LanguageConfig(
        numberWords: [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
            "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
        ],
        sleepWords: [
            "sleep", "slept", "asleep", "sleeping", "sleepless", "oversleep", "overslept",
            "woke", "woken", "awoke", "waking", "insomnia", "nightmare", "nightmares",
            "nap", "napped", "napping", "kip", "rested", "restless", "dozed", "dozing",
            "slumber", "bedtime",
        ],
        sleepMultiwordPatterns: [
            "\\bdreams?\\b", "\\bwink\\b", "\\bl(?:a|i)e? awake\\b",
            "\\b(?:hours?|hrs?)\\b[^.!?]*\\bnight\\b",
            "\\bnight\\b[^.!?]*\\b(?:hours?|hrs?)\\b",
        ],
        // Anchored to sleep-context lead-ins so work/other "N hours" in a sleep
        // sentence isn't read as sleep ("couldn't sleep, so I worked 12 hours" → nil);
        // spelled-out numbers stay supported ("slept five hours" → 5). Mirrors the
        // app's digit-only ADHDRegexPatterns anchor, widened to spelled-out cardinals.
        sleepHoursPattern: #"(?i)(?:slept|got|in bed for|was asleep for|only|about|roughly|maybe)\s+(\d{1,2}(?:\.\d)?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(\s+and\s+a\s+half)?\s*(?:hours?|hrs?|hr|h)\b"#,
        sleepBarePattern: #"(?i)\b(?:sleep|slept)\s+(\d{1,2}(?:\.\d)?)\b"#,
        weakEnergyTriggers: ["energy", "energetic"],
        weakEnergyTable: ([
            ("great", .charged), ("cracking", .charged), ("brilliant", .charged),
            ("fantastic", .charged), ("amazing", .charged), ("excellent", .charged),
            ("loads", .charged), ("tons", .charged), ("plenty", .charged), ("soaring", .charged),
            ("rubbish", .tired), ("poor", .tired), ("low", .tired), ("flat", .tired),
            ("sapped", .tired), ("drained", .tired), ("empty", .tired), ("fumes", .tired),
            ("faded", .tired), ("fading", .tired), ("tapered", .tired), ("tapering", .tired),
            ("dipped", .tired), ("dipping", .tired), ("dip", .tired), ("dips", .tired),
            ("dropped", .tired), ("dropping", .tired), ("declined", .tired), ("waned", .tired),
            ("slump", .tired), ("slumps", .tired), ("slumped", .tired), ("petered", .tired),
            ("fizzled", .tired), ("dwindled", .tired), ("nil", .tired), ("zero", .tired),
            ("meh", .tired), ("nap", .tired), ("lacking", .tired), ("sluggish", .tired),
            ("good", .steady), ("decent", .steady), ("fine", .steady), ("alright", .steady),
            ("okay", .steady), ("solid", .steady), ("consistent", .steady), ("reliable", .steady),
            ("stable", .steady), ("normal", .steady), ("manageable", .steady), ("held", .steady),
            ("hovered", .steady), ("even", .steady), ("moderate", .steady), ("reasonable", .steady),
            ("steady", .steady),
        ] as [(String, EnergyLevel)]).map { WeakEnergyEntry(word: $0.0, level: $0.1) },
        weakEnergyDefaultLevel: .steady,
        weakEnergyDefaultPhrase: "energy",
        weakMoodTriggerPattern: #"\bmood\b"#,
        weakMoodTable: ([
            ("great", "great"), ("fantastic", "great"), ("amazing", "great"), ("brilliant", "great"),
            ("wonderful", "great"), ("excellent", "great"), ("elated", "great"), ("buzzing", "great"),
            ("rough", "low"), ("low", "low"), ("bad", "low"), ("down", "low"), ("sad", "low"),
            ("gloomy", "low"), ("miserable", "low"), ("terrible", "low"), ("awful", "low"),
            ("shot", "low"), ("tanked", "low"), ("withdrawn", "low"), ("irritable", "low"),
            ("foul", "low"), ("dark", "low"), ("dejected", "low"), ("snappy", "low"),
            ("flat", "flat"),
            ("good", "good"), ("positive", "good"), ("happy", "good"), ("content", "good"),
            ("calm", "good"), ("relaxed", "good"), ("stable", "good"), ("cheerful", "good"),
            ("upbeat", "good"), ("optimistic", "good"), ("pleased", "good"), ("lifted", "good"),
            ("okay", "okay"), ("ok", "okay"), ("meh", "okay"), ("middling", "okay"),
            ("neutral", "okay"), ("alright", "okay"), ("fine", "okay"), ("even", "okay"),
        ] as [(String, String)]).map { WeakMoodEntry(word: $0.0, label: $0.1) },
        weakMoodDefaultLabel: "okay",
        weakMoodDefaultPhrase: "mood",
        presentMarkers: [
            "right now", "currently", "today", "i feel", "i'm feeling", "i am feeling",
            "i am", "i'm", "this evening", "tonight", "at the moment", "these days",
            "now i", "now i'm", "i've been feeling", "i have been feeling",
        ],
        pastMarkers: [
            "i was", "i felt", "earlier", "this morning", "yesterday", "last night",
            "by evening", "by the afternoon", "this afternoon", "woke up", "had been",
            "used to", "a while ago", "before", "was feeling", "were feeling",
        ],
        pastVerbSuffixes: ["ed"],
        irregularPastVerbs: [
            "was", "were", "felt", "had", "did", "went", "got", "woke", "became",
            "began", "came", "ran", "saw", "took", "thought", "knew", "made", "found",
        ]
    )
}
