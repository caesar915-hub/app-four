import Foundation

/// Pure derivation of a day-card's folded summary from its timeline (Constitution
/// Principle X). Keeps the most-recent-signal and most-recent-medication rules in one
/// testable place; `FoldedDayCardHeader` renders what this produces. Nodes are newest-first
/// by construction (`DayTimelineBuilder`), so "first matching" means "most recent".
struct DayCardSummary {
    let day: MoodLibraryViewModel.TimelineDay

    /// The newest check-in that carries a recording.
    var latestRecording: Recording? {
        day.nodes.first { $0.recording != nil }?.recording
    }

    var mood: String? { nonEmpty(latestRecording?.mood) }
    var energy: String? { nonEmpty(latestRecording?.energyLevel) }
    var focus: String? { nonEmpty(latestRecording?.focusLevel) }

    /// Most-recent check-in's medication name only — no dose, no time (FR-003). On a
    /// multi-medication day this is the newest intake's name.
    var mostRecentMedicationName: String? {
        day.nodes.first { !$0.intakeDoses.isEmpty }?.intakeDoses.first?.name
    }

    /// A day with no check-ins (FR-004).
    var isEmpty: Bool { day.nodes.isEmpty }

    /// Calm empty-state copy (FR-004) — never red, never "missed"/"overdue".
    static let emptyCopy = "No check-ins this day. That's alright."

    private func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s
    }
}
