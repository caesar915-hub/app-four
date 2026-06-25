import Foundation

/// The four self-state / sleep level scales, hoisted out of `NoteExtraction.swift`
/// into a leaf module so both the app (NoteExtraction service) and `SquirlDesignSystem`
/// (glyphs + palette) can depend on them without a SwiftUI edge. Pure `Foundation` value
/// types — no SwiftUI, no SwiftData. Behaviour is identical to the original definitions.

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
