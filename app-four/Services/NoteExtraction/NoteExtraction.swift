import Foundation

/// The extracted ADHD journal schema from a voice note transcript.
public struct NoteExtraction: Sendable, Codable, Equatable {
    public var mood: String?          // MoodLevel rawValue (dark/low/flat/okay/good/high)
    public var energy: EnergyLevel?
    public var focus: FocusLevel?
    public var feelings: [String]     // specific emotions (anxious, grateful, etc.)
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
        feelings: [String] = [],
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
        self.feelings = feelings
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
        feelings = try c.decode([String].self, forKey: .feelings)
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

public enum MoodLevel: String, Sendable, Codable, Equatable, CaseIterable {
    case low    // 1 — heavy, muted
    case flat   // 2 — neutral, still
    case okay   // 3 — steady, fine
    case good   // 4 — warm, lifted
    case great  // 5 — bright, thriving

    public var numericValue: Int {
        switch self { case .low: 1; case .flat: 2; case .okay: 3; case .good: 4; case .great: 5 }
    }
    public var subtitle: String {
        switch self {
        case .low:   return "heavy, muted"
        case .flat:  return "neutral, still"
        case .okay:  return "steady, fine"
        case .good:  return "warm, lifted"
        case .great: return "bright, thriving"
        }
    }
}

public enum EnergyLevel: String, Sendable, Codable, Equatable, CaseIterable {
    case sluggish  // 1 — slow, heavy
    case tired     // 2 — low, dim
    case steady    // 3 — moderate, stable
    case alert     // 4 — awake, ready
    case charged   // 5 — electric, on

    public var numericValue: Int {
        switch self { case .sluggish: 1; case .tired: 2; case .steady: 3; case .alert: 4; case .charged: 5 }
    }
    public var subtitle: String {
        switch self {
        case .sluggish: return "slow, heavy"
        case .tired:    return "low, dim"
        case .steady:   return "moderate, stable"
        case .alert:    return "awake, ready"
        case .charged:  return "electric, on"
        }
    }
}

public enum FocusLevel: String, Sendable, Codable, Equatable, CaseIterable {
    case foggy      // 1 — hazy, drifting
    case distracted // 2 — pulled, unsteady
    case present    // 3 — grounded, there
    case sharp      // 4 — clear, on track
    case lockedIn   // 5 — deep, flowing

    public var numericValue: Int {
        switch self { case .foggy: 1; case .distracted: 2; case .present: 3; case .sharp: 4; case .lockedIn: 5 }
    }
    public var displayLabel: String {
        switch self {
        case .foggy:      return "Foggy"
        case .distracted: return "Distracted"
        case .present:    return "Present"
        case .sharp:      return "Sharp"
        case .lockedIn:   return "Locked In"
        }
    }
    public var subtitle: String {
        switch self {
        case .foggy:      return "hazy, drifting"
        case .distracted: return "pulled, unsteady"
        case .present:    return "grounded, there"
        case .sharp:      return "clear, on track"
        case .lockedIn:   return "deep, flowing"
        }
    }
}

public enum MedEventChange: String, Codable, Sendable {
    case regular
    case started
    case stopped
}

public struct MedEvent: Sendable, Codable, Equatable {
    public var name: String
    public var dose: String?
    public var time: String?        // HH:mm 24h (e.g. "10:00"); nil when not derivable
    public var timeLabel: String?   // raw transcript phrasing (e.g. "around 10 am", "morning")
    public var taken: Bool          // default true; false when negation detected
    public var quantity: Double?    // nil = 1.0 (full dose); 0.5 = half pill
    public var change: MedEventChange?

    public nonisolated init(name: String, dose: String? = nil, time: String? = nil, timeLabel: String? = nil, taken: Bool = true, quantity: Double? = nil, change: MedEventChange? = nil) {
        self.name = name
        self.dose = dose
        self.time = time
        self.timeLabel = timeLabel
        self.taken = taken
        self.quantity = quantity
        self.change = change
    }
}

public enum SleepLevel: String, Sendable, Codable, Equatable, CaseIterable {
    case restless  // 1 — broken, tossing
    case light     // 2 — thin, barely resting
    case okay      // 3 — decent, adequate
    case good      // 4 — solid, rested
    case deep      // 5 — restorative, refreshed

    public var numericValue: Int {
        switch self { case .restless: 1; case .light: 2; case .okay: 3; case .good: 4; case .deep: 5 }
    }
    public var subtitle: String {
        switch self {
        case .restless: return "broken, tossing"
        case .light:    return "thin, barely resting"
        case .okay:     return "decent, adequate"
        case .good:     return "solid, rested"
        case .deep:     return "restorative, refreshed"
        }
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
