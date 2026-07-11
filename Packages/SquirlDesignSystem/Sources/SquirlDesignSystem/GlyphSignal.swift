import Foundation

/// The five drawable signal marks. A glyph-layer scope distinct from the Insights
/// `SignalKind` (which is the three ramped self-state signals): this adds `sleep` and
/// `medication`, which are single icons, not 1→5 ramps. Names/synonyms reuse the existing
/// `MoodLevel`/`EnergyLevel`/`FocusLevel` SSOT — no parallel table.
public enum GlyphSignal: String, CaseIterable, Hashable, Sendable {
    case mood, energy, focus, sleep, medication

    /// The three self-state signals that carry a 1→5 level (pickers, ramps).
    public static let selfState: [GlyphSignal] = [.mood, .energy, .focus]

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
        case .mood, .energy, .focus: true
        case .sleep, .medication: false
        }
    }
}

/// A small descriptor letting a tag/badge carry a Paper & Pollen glyph instead of an
/// SF Symbol. Set on the signal tags; absent on non-signal tags (category, emotion…).
public struct GlyphBadge: Hashable, Sendable {
    public let kind: GlyphSignal
    public var level: Int? = nil

    public init(kind: GlyphSignal, level: Int? = nil) {
        self.kind = kind
        self.level = level
    }
}

// MARK: - Pure helpers (Constitution Principle X — covered by SignalGlyphTests)

/// Clamp a raw level into 1…5. `nil` passes through (absent ≠ level 1); out-of-range
/// snaps to the nearest valid level so a bad extraction never crashes or draws nothing.
public nonisolated func clampedSignalLevel(_ raw: Int?) -> Int? {
    guard let raw else { return nil }
    return min(5, max(1, raw))
}

/// The named level for a self-state signal ("Great", "Alert", "Locked In"). `nil` for
/// `sleep`/`medication` (no level) or an unresolvable level.
public nonisolated func signalName(_ kind: GlyphSignal, level: Int) -> String? {
    switch kind {
    case .mood: MoodLevel.allCases.first { $0.numericValue == level }?.rawValue.capitalized
    case .energy: EnergyLevel.allCases.first { $0.numericValue == level }?.rawValue.capitalized
    case .focus: FocusLevel.allCases.first { $0.numericValue == level }?.displayLabel
    case .sleep, .medication: nil
    }
}

/// The synonym line shown under the picker ("bright, thriving"). Reuses each level
/// enum's `subtitle`. `nil` for non-level signals.
public nonisolated func signalSynonym(_ kind: GlyphSignal, level: Int) -> String? {
    switch kind {
    case .mood: MoodLevel.allCases.first { $0.numericValue == level }?.subtitle
    case .energy: EnergyLevel.allCases.first { $0.numericValue == level }?.subtitle
    case .focus: FocusLevel.allCases.first { $0.numericValue == level }?.subtitle
    case .sleep, .medication: nil
    }
}

/// VoiceOver label: "Energy: Alert, 4 of 5" for self-state signals, or just the title
/// ("Sleep") for single icons / absent level.
public nonisolated func signalAccessibilityLabel(_ kind: GlyphSignal, level: Int?) -> String {
    guard kind.variesByLevel, let level = clampedSignalLevel(level),
          let name = signalName(kind, level: level) else {
        return kind.title
    }
    return "\(kind.title): \(name), \(level) of 5"
}
