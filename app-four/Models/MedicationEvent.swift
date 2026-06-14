import Foundation
import SwiftData

/// Single persisted medication record — whether typed by the user or extracted from a transcript.
///
/// `source == .manual`     → logged by the user (med bar or a check-in); `recording` is
///                           nil for standalone doses, set when logged inside a check-in.
/// `source == .transcript` → created from NLP extraction; `recording` points to the originating note.
@Model
final class MedicationEvent {
    var id: UUID = UUID()
    var name: String = ""
    var dose: String? = nil
    /// Resolved absolute time.  Set once at save time so there is no re-parsing on every read.
    var takenAt: Date = Date()
    var taken: Bool = true
    var quantity: Double? = nil
    /// Per-medication effect window in hours (default 10). Stored so the bar doesn't hard-code it.
    var durationHours: Double = 10.0
    var change: MedEventChange? = nil
    /// Raw transcript phrase kept for provenance ("morning", "around 10 am").
    var timeLabel: String? = nil
    var source: Source = Source.manual
    var createdAt: Date = Date()
    var isMockData: Bool = false

    /// Nil for standalone manual logs; set for transcript-extracted events and
    /// for manual doses logged as part of a check-in entry.
    var recording: Recording? = nil

    // MARK: - Source

    enum Source: String, Codable, Sendable {
        case manual
        case transcript
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        dose: String? = nil,
        takenAt: Date,
        taken: Bool = true,
        quantity: Double? = nil,
        durationHours: Double = 10.0,
        change: MedEventChange? = nil,
        timeLabel: String? = nil,
        source: Source = .manual
    ) {
        self.id = id
        self.name = name
        self.dose = dose
        self.takenAt = takenAt
        self.taken = taken
        self.quantity = quantity
        self.durationHours = durationHours
        self.change = change
        self.timeLabel = timeLabel
        self.source = source
        self.createdAt = Date()
    }

    // MARK: - Effect window

    /// Fraction of the dose duration that has elapsed, clamped to [0, 1].
    func effectProgress(at date: Date = .now) -> Double {
        let total = durationHours * 3600
        guard total > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(takenAt) / total))
    }

    /// Whether the dose is still within its active window at the given time.
    func isActive(at date: Date = .now) -> Bool {
        taken && effectProgress(at: date) < 1
    }

    // MARK: - Time resolution (moved from MedicationBarViewModel.displayFrom)

    /// Converts a `MedEvent`'s raw time string / label into an absolute `Date`, resolved
    /// against the recording's creation date so the parse runs once and is stored.
    static func resolvedTakenAt(
        time: String?,
        timeLabel: String?,
        recordingDate: Date
    ) -> Date {
        // Primary: explicit HH:mm string from transcript
        if let timeString = time {
            let parts = timeString.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: recordingDate)
                comps.hour = parts[0]
                comps.minute = parts[1]
                if let parsed = cal.date(from: comps) {
                    // If the parsed time is after the recording, assume the previous day
                    return parsed > recordingDate
                        ? (cal.date(byAdding: .day, value: -1, to: parsed) ?? parsed)
                        : parsed
                }
            }
        }
        // Secondary: fuzzy time label ("morning", "afternoon", …)
        if let roughHour = approximateHour(from: timeLabel) {
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: recordingDate)
            comps.hour = roughHour
            comps.minute = 0
            return cal.date(from: comps) ?? recordingDate
        }
        // Fallback: recording creation time
        return recordingDate
    }

    private static func approximateHour(from label: String?) -> Int? {
        guard let label = label?.lowercased() else { return nil }
        if label.contains("morning") || label.contains("am") || label.contains("breakfast") { return 8 }
        if label.contains("afternoon") || label.contains("lunch") || label.contains("noon") { return 13 }
        if label.contains("evening") || label.contains("dinner") || label.contains("pm") { return 19 }
        if label.contains("night") || label.contains("bedtime") || label.contains("sleep") { return 22 }
        return nil
    }
}
