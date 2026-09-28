import Foundation
import SquirlDesignSystem

/// Pure derivation of a day-card's folded summary from its timeline (Constitution
/// Principle X). Mood, energy and focus are rounded-up averages of all check-ins that
/// day; medication and sleep keep the most-recent rules. `FoldedDayCardHeader` renders
/// what this produces. Nodes are newest-first by construction (`DayTimelineBuilder`), so
/// "first matching" means "most recent" for medication/sleep.
struct DayCardSummary {
    let day: MoodLibraryViewModel.TimelineDay

    /// Rounded-up average mood across all check-ins that carry a mood.
    var mood: String? {
        MoodLevel.average(of: day.nodes.compactMap { $0.recording?.mood })?.displayLabel
    }

    /// Rounded-up average energy across all check-ins that carry an energy level.
    var energy: String? {
        EnergyLevel.average(of: day.nodes.compactMap { $0.recording?.energyLevel })?.displayLabel
    }

    /// Rounded-up average focus across all check-ins that carry a focus level.
    var focus: String? {
        FocusLevel.average(of: day.nodes.compactMap { $0.recording?.focusLevel })?.displayLabel
    }

    /// Most-recent check-in's medication name only — no dose, no time (FR-003). On a
    /// multi-medication day this is the newest intake's name.
    var mostRecentMedicationName: String? {
        day.nodes.first { !$0.intakeDoses.isEmpty }?.intakeDoses.first?.name
    }

    /// The newest intake's recorded dose ("36mg"), for the collapsed card's medication line.
    var mostRecentMedicationDose: String? {
        day.nodes.first { !$0.intakeDoses.isEmpty }?.intakeDoses.first?.dose
    }

    /// The newest recording's sleep level, for the collapsed card's moon glyph.
    var sleepLevel: SleepLevel? {
        for node in day.nodes {
            if let level = node.recording?.decodedSleepLevel { return level }
        }
        return nil
    }

    /// Most recent captured sleep for the day ("7h sleep" / "calm sleep"), or nil when no
    /// check-in that day logged sleep (spec 034). Nodes are newest-first, so the first
    /// recording carrying a sleep label is the most recent one.
    @MainActor var sleep: String? {
        for node in day.nodes {
            if let label = node.recording?.sleepLabel { return label }
        }
        return nil
    }

    /// A day with no check-ins (FR-004).
    var isEmpty: Bool { day.nodes.isEmpty }

    /// Calm empty-state copy (FR-004) — never red, never "missed"/"overdue".
    static let emptyCopy = "No check-ins this day. That's alright."
}
