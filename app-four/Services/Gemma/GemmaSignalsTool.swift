import Foundation

/// Typed pass-2 signals payload. Mirrors `UnifiedExtraction`'s fields and JSON keys
/// so the Tool-Use path and the free-form-JSON path converge on a single mapping.
public nonisolated struct SignalsToolArguments: Codable, Sendable, Equatable {
    public var mood: String?
    public var energy: String?
    public var focus: String?
    public var sleepHours: Double?
    public var sleepQuality: String?
    public var medications: [MedicationExtraction]
    public var emotions: [String]
    public var activities: [String]
    public var topics: [String]
    public var lexicon: [String]
    public var sideEffects: [String]
    public var summary: String?

    public init(
        mood: String? = nil, energy: String? = nil, focus: String? = nil,
        sleepHours: Double? = nil, sleepQuality: String? = nil,
        medications: [MedicationExtraction] = [], emotions: [String] = [],
        activities: [String] = [], topics: [String] = [], lexicon: [String] = [],
        sideEffects: [String] = [], summary: String? = nil
    ) {
        self.mood = mood; self.energy = energy; self.focus = focus
        self.sleepHours = sleepHours; self.sleepQuality = sleepQuality
        self.medications = medications; self.emotions = emotions
        self.activities = activities; self.topics = topics; self.lexicon = lexicon
        self.sideEffects = sideEffects; self.summary = summary
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mood = try c.decodeIfPresent(String.self, forKey: .mood)
        energy = try c.decodeIfPresent(String.self, forKey: .energy)
        focus = try c.decodeIfPresent(String.self, forKey: .focus)
        sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours)
        sleepQuality = try c.decodeIfPresent(String.self, forKey: .sleepQuality)
        medications = try c.decodeIfPresent([MedicationExtraction].self, forKey: .medications) ?? []
        emotions = try c.decodeIfPresent([String].self, forKey: .emotions) ?? []
        activities = try c.decodeIfPresent([String].self, forKey: .activities) ?? []
        topics = try c.decodeIfPresent([String].self, forKey: .topics) ?? []
        lexicon = try c.decodeIfPresent([String].self, forKey: .lexicon) ?? []
        sideEffects = try c.decodeIfPresent([String].self, forKey: .sideEffects) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
    }
}

/// Maps a pass-2 tool-call payload into the shared `UnifiedExtraction`. No clamping
/// here — `ExtractionValidator.validate` owns normalization, so the Tool-Use path and
/// the free-form-JSON path produce identical `UnifiedExtraction` for the same content.
nonisolated enum SignalsTool {
    static func unifiedExtraction(from args: SignalsToolArguments) -> UnifiedExtraction {
        UnifiedExtraction(
            mood: args.mood, energy: args.energy, focus: args.focus,
            sleepHours: args.sleepHours, sleepQuality: args.sleepQuality,
            medications: args.medications, emotions: args.emotions,
            activities: args.activities, topics: args.topics, lexicon: args.lexicon,
            summary: args.summary, sideEffects: args.sideEffects
        )
    }
}
