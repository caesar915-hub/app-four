import Foundation

/// The extracted ADHD journal schema from a voice note transcript.
public struct NoteExtraction: Sendable, Codable, Equatable {
    public var mood: String?          // MoodLevel rawValue (dark/low/flat/okay/good/high)
    public var energy: EnergyLevel?
    public var focus: FocusLevel?
    public var emotions: [String]     // curated Mood-Meter emotions (anxious, grateful, etc.)
    public var activities: [String]   // e.g. ["resting", "hobbies", "fitness"]
    public var medications: [MedEvent]
    public var sideEffects: [String]
    public var sleep: SleepNote?
    public var tasksCompleted: [String]
    public var tasksAvoided: [String]
    public var wins: [String]
    public var overwhelm: [String]
    public var highlights: [String]
    public var title: String

    // MARK: - Expanded triage fields
    public var executiveDysfunction: [String]
    public var physicalStim: [String]
    public var physicalSideEffects: [String]
    public var reboundTerms: [String]
    public var appetiteLoss: [String]
    public var appetiteReturn: [String]
    public var appointments: [String]

    // MARK: - Structured regex extractions
    public var extractedDose: String?
    public var sleepHours: Double?
    public var onsetMinutes: Int?
    public var durationHours: Double?
    public var crashTime: String?
    public var intakeContext: String?

    public nonisolated init(
        mood: String? = nil,
        energy: EnergyLevel? = nil,
        focus: FocusLevel? = nil,
        emotions: [String] = [],
        activities: [String] = [],
        medications: [MedEvent] = [],
        sideEffects: [String] = [],
        sleep: SleepNote? = nil,
        tasksCompleted: [String] = [],
        tasksAvoided: [String] = [],
        wins: [String] = [],
        overwhelm: [String] = [],
        highlights: [String] = [],
        title: String = "Voice Note",
        executiveDysfunction: [String] = [],
        physicalStim: [String] = [],
        physicalSideEffects: [String] = [],
        reboundTerms: [String] = [],
        appetiteLoss: [String] = [],
        appetiteReturn: [String] = [],
        appointments: [String] = [],
        extractedDose: String? = nil,
        sleepHours: Double? = nil,
        onsetMinutes: Int? = nil,
        durationHours: Double? = nil,
        crashTime: String? = nil,
        intakeContext: String? = nil
    ) {
        self.mood = mood
        self.energy = energy
        self.focus = focus
        self.emotions = emotions
        self.activities = activities
        self.medications = medications
        self.sideEffects = sideEffects
        self.sleep = sleep
        self.tasksCompleted = tasksCompleted
        self.tasksAvoided = tasksAvoided
        self.wins = wins
        self.overwhelm = overwhelm
        self.highlights = highlights
        self.title = title
        self.executiveDysfunction = executiveDysfunction
        self.physicalStim = physicalStim
        self.physicalSideEffects = physicalSideEffects
        self.reboundTerms = reboundTerms
        self.appetiteLoss = appetiteLoss
        self.appetiteReturn = appetiteReturn
        self.appointments = appointments
        self.extractedDose = extractedDose
        self.sleepHours = sleepHours
        self.onsetMinutes = onsetMinutes
        self.durationHours = durationHours
        self.crashTime = crashTime
        self.intakeContext = intakeContext
    }

    // Custom decoder so that `noteExtractionJSON` persisted before `appointments`
    // existed still decodes: Swift's synthesized Decodable requires every key and
    // does NOT fall back to property defaults, so a missing `appointments` key would
    // throw keyNotFound and silently null the whole extraction (Recording uses `try?`).
    // `decodeIfPresent` is used for `appointments` only; all other keys keep their
    // original required semantics.
    public nonisolated init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mood = try c.decodeIfPresent(String.self, forKey: .mood)
        energy = try c.decodeIfPresent(EnergyLevel.self, forKey: .energy)
        focus = try c.decodeIfPresent(FocusLevel.self, forKey: .focus)
        emotions = try c.decode([String].self, forKey: .emotions)
        activities = try c.decode([String].self, forKey: .activities)
        medications = try c.decode([MedEvent].self, forKey: .medications)
        sideEffects = try c.decode([String].self, forKey: .sideEffects)
        sleep = try c.decodeIfPresent(SleepNote.self, forKey: .sleep)
        tasksCompleted = try c.decode([String].self, forKey: .tasksCompleted)
        tasksAvoided = try c.decode([String].self, forKey: .tasksAvoided)
        wins = try c.decode([String].self, forKey: .wins)
        overwhelm = try c.decode([String].self, forKey: .overwhelm)
        highlights = try c.decode([String].self, forKey: .highlights)
        title = try c.decode(String.self, forKey: .title)
        executiveDysfunction = try c.decode([String].self, forKey: .executiveDysfunction)
        physicalStim = try c.decode([String].self, forKey: .physicalStim)
        physicalSideEffects = try c.decode([String].self, forKey: .physicalSideEffects)
        reboundTerms = try c.decode([String].self, forKey: .reboundTerms)
        appetiteLoss = try c.decode([String].self, forKey: .appetiteLoss)
        appetiteReturn = try c.decode([String].self, forKey: .appetiteReturn)
        appointments = try c.decodeIfPresent([String].self, forKey: .appointments) ?? []
        extractedDose = try c.decodeIfPresent(String.self, forKey: .extractedDose)
        sleepHours = try c.decodeIfPresent(Double.self, forKey: .sleepHours)
        onsetMinutes = try c.decodeIfPresent(Int.self, forKey: .onsetMinutes)
        durationHours = try c.decodeIfPresent(Double.self, forKey: .durationHours)
        crashTime = try c.decodeIfPresent(String.self, forKey: .crashTime)
        intakeContext = try c.decodeIfPresent(String.self, forKey: .intakeContext)
    }
}

public enum MedEventChange: String, Codable, Sendable {
    case regular
    case started
    case stopped
}

public struct MedEvent: Sendable, Codable, Equatable, Hashable {
    public var name: String
    public var dose: String?
    public var time: String?        // HH:mm 24h (e.g. "10:00"); nil when not derivable
    public var timeLabel: String?   // raw transcript phrasing (e.g. "around 10 am", "morning")
    public var taken: Bool          // default true; false when negation detected
    public var quantity: Double?    // nil = 1.0 (full dose); 0.5 = half pill
    public var change: MedEventChange?
    public var durationHours: Double?  // per-dose duration (Edit-sheet inline-expand); nil → catalog/default

    public nonisolated init(name: String, dose: String? = nil, time: String? = nil, timeLabel: String? = nil, taken: Bool = true, quantity: Double? = nil, change: MedEventChange? = nil, durationHours: Double? = nil) {
        self.name = name
        self.dose = dose
        self.time = time
        self.timeLabel = timeLabel
        self.taken = taken
        self.quantity = quantity
        self.change = change
        self.durationHours = durationHours
    }
}

public struct SleepNote: Sendable, Codable, Equatable {
    public var mentioned: Bool
    public var hours: Double?
    public var quality: String?

    public nonisolated init(mentioned: Bool = false, hours: Double? = nil, quality: String? = nil) {
        self.mentioned = mentioned
        self.hours = hours
        self.quality = quality
    }
}

public struct SleepEvent: Sendable, Codable, Equatable {
    public var mentioned: Bool
    public var hours: Double?
    public var quality: String?         // "good" | "poor" | "insomnia"
    public var bedtime: String?         // raw label e.g. "11pm", "midnight"
    public var wakeTime: String?        // raw label e.g. "7am"
    public var latencyMinutes: Int?     // how long to fall asleep

    public nonisolated init(
        mentioned: Bool = false,
        hours: Double? = nil,
        quality: String? = nil,
        bedtime: String? = nil,
        wakeTime: String? = nil,
        latencyMinutes: Int? = nil
    ) {
        self.mentioned = mentioned
        self.hours = hours
        self.quality = quality
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.latencyMinutes = latencyMinutes
    }
}

/// Protocol for extracting structured ADHD journal data from a transcript.
public protocol NoteExtractor: Sendable {
    func extract(from transcript: String) -> NoteExtraction
}
