import Foundation

/// What the user explicitly picked in the text check-in composer.
/// These values are authoritative — extraction may only fill what is nil here.
struct CheckInDraft: Equatable {
    var mood: MoodLevel? = nil
    var energy: EnergyLevel? = nil
    var focus: FocusLevel? = nil
    var sleepQuality: String? = nil
    var meds: [DraftMedication] = []
    var note: String = ""

    struct DraftMedication: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var dose: String?
        var takenAt: Date = .now
        var durationHours: Double = 10

        // `id` is for list identity only — two structurally identical meds are equal.
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.name == rhs.name && lhs.dose == rhs.dose
                && lhs.takenAt == rhs.takenAt && lhs.durationHours == rhs.durationHours
        }
    }

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isEmpty: Bool {
        mood == nil && energy == nil && focus == nil
            && sleepQuality == nil && meds.isEmpty && trimmedNote.isEmpty
    }
}
