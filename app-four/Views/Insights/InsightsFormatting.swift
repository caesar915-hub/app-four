import SwiftUI

extension String {
    /// "mostly Okay" → "Mostly Okay": the view-side casing rule (D8). The view-model strings stay
    /// exactly as the tests pin them.
    var sentenceCased: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

extension SignalKind {
    /// The status colour of the signal's "Mostly …" word — AA-safe text tokens, never the fills.
    var statusColor: Color {
        switch self {
        case .mood: Accent.primaryText
        case .energy: Accent.energyText
        case .focus: Accent.focusText
        }
    }

    /// The five canonical level words, low → high, for axes and captions.
    var levelLabels: [String] {
        switch self {
        case .mood: MoodLevel.allCases.map(\.displayLabel)
        case .energy: EnergyLevel.allCases.map(\.displayLabel)
        case .focus: FocusLevel.allCases.map(\.displayLabel)
        }
    }
}

extension TimeBucket {
    /// Narrow-column fallback for the rhythm matrix headers.
    var shortLabel: String {
        switch self {
        case .morning: "Morn"
        case .afternoon: "Aft"
        case .evening: "Eve"
        case .late: "Late"
        }
    }
}
