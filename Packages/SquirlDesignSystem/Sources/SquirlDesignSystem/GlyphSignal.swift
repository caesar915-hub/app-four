import Foundation

/// The five drawable signal marks. A glyph-layer scope distinct from the Insights `SignalKind`
/// (the three ramped self-state signals): this adds `sleep` (a 1→5 moon ramp since spec 057)
/// and `medication` (a single capsule). Names reuse the level-enum SSOT — no parallel table.
public enum GlyphSignal: String, CaseIterable, Hashable, Sendable {
    case mood, energy, focus, sleep, medication


    public var title: String {
        switch self {
        case .mood: "Mood"
        case .energy: "Energy"
        case .focus: "Focus"
        case .sleep: "Sleep"
        case .medication: "Medication"
        }
    }

    /// Whether the glyph encodes a 1…5 level (false → a single fixed icon).
    public var variesByLevel: Bool {
        switch self {
        case .mood, .energy, .focus, .sleep: true
        case .medication: false
        }
    }
}

// MARK: - Pure helpers (Constitution Principle X — covered by SignalGlyphTests)

/// Clamp a raw level into 1…5. `nil` passes through (absent ≠ level 1); out-of-range
/// snaps to the nearest valid level so a bad extraction never crashes or draws nothing.
public nonisolated func clampedSignalLevel(_ raw: Int?) -> Int? {
    guard let raw else { return nil }
    return min(5, max(1, raw))
}

/// The named level for a ramped signal ("Great", "Alert", "Locked In", "Deep"). `nil` for
/// `medication` (no level) or an unresolvable level.
public nonisolated func signalName(_ kind: GlyphSignal, level: Int) -> String? {
    switch kind {
    case .mood: MoodLevel.allCases.first { $0.numericValue == level }?.displayLabel
    case .energy: EnergyLevel.allCases.first { $0.numericValue == level }?.displayLabel
    case .focus: FocusLevel.allCases.first { $0.numericValue == level }?.displayLabel
    case .sleep: SleepLevel.allCases.first { $0.numericValue == level }?.displayLabel
    case .medication: nil
    }
}

/// The synonym line ("bright, thriving"). Reuses each level enum's `subtitle`. `nil` for medication.
public nonisolated func signalSynonym(_ kind: GlyphSignal, level: Int) -> String? {
    switch kind {
    case .mood: MoodLevel.allCases.first { $0.numericValue == level }?.subtitle
    case .energy: EnergyLevel.allCases.first { $0.numericValue == level }?.subtitle
    case .focus: FocusLevel.allCases.first { $0.numericValue == level }?.subtitle
    case .sleep: SleepLevel.allCases.first { $0.numericValue == level }?.subtitle
    case .medication: nil
    }
}

/// VoiceOver label: "Energy: Alert, 4 of 5" for ramped signals, or just the title
/// ("Sleep", "Medication") for a single icon / absent level.
public nonisolated func signalAccessibilityLabel(_ kind: GlyphSignal, level: Int?) -> String {
    guard kind.variesByLevel, let level = clampedSignalLevel(level),
          let name = signalName(kind, level: level) else {
        return kind.title
    }
    return "\(kind.title): \(name), \(level) of 5"
}
