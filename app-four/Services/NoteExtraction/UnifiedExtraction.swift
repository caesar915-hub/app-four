import Foundation

public struct UnifiedExtraction: Codable, Sendable, Equatable {
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
    public var summary: String?
    public var sideEffects: [String]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mood = try container.decodeIfPresent(String.self, forKey: .mood)
        self.energy = try container.decodeIfPresent(String.self, forKey: .energy)
        self.focus = try container.decodeIfPresent(String.self, forKey: .focus)
        self.sleepHours = try container.decodeIfPresent(Double.self, forKey: .sleepHours)
        self.sleepQuality = try container.decodeIfPresent(String.self, forKey: .sleepQuality)
        self.medications = try container.decodeIfPresent([MedicationExtraction].self, forKey: .medications) ?? []
        self.emotions = try container.decodeIfPresent([String].self, forKey: .emotions) ?? []
        self.activities = try container.decodeIfPresent([String].self, forKey: .activities) ?? []
        self.topics = try container.decodeIfPresent([String].self, forKey: .topics) ?? []
        self.lexicon = try container.decodeIfPresent([String].self, forKey: .lexicon) ?? []
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.sideEffects = try container.decodeIfPresent([String].self, forKey: .sideEffects) ?? []
    }
    
    // Explicit init for tests/construction
    public init(
        mood: String? = nil,
        energy: String? = nil,
        focus: String? = nil,
        sleepHours: Double? = nil,
        sleepQuality: String? = nil,
        medications: [MedicationExtraction] = [],
        emotions: [String] = [],
        activities: [String] = [],
        topics: [String] = [],
        lexicon: [String] = [],
        summary: String? = nil,
        sideEffects: [String] = []
    ) {
        self.mood = mood
        self.energy = energy
        self.focus = focus
        self.sleepHours = sleepHours
        self.sleepQuality = sleepQuality
        self.medications = medications
        self.emotions = emotions
        self.activities = activities
        self.topics = topics
        self.lexicon = lexicon
        self.summary = summary
        self.sideEffects = sideEffects
    }
}

public struct MedicationExtraction: Codable, Sendable, Equatable {
    public var name: String
    public var dose: String?
    public var taken: Bool
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.dose = try container.decodeIfPresent(String.self, forKey: .dose)
        self.taken = try container.decodeIfPresent(Bool.self, forKey: .taken) ?? true
    }
    
    // Explicit init for tests/construction
    public init(name: String, dose: String? = nil, taken: Bool = true) {
        self.name = name
        self.dose = dose
        self.taken = taken
    }
}
