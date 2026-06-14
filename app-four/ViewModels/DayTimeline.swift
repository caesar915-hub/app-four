import Foundation

/// A single day's merged timeline of mood/voice check-ins and medication doses,
/// collapsed into time-ordered nodes.
enum DayTimeline {

    /// One moment on the day's timeline. A node groups everything that happened
    /// at the same instant: a recording, one or more dose intakes, or both.
    struct Node: Identifiable {
        /// Stable across rebuilds for SwiftUI diffing (timestamp + event ids).
        let id: String
        let time: Date
        /// The recording logged at `time`, if any. Drives centre fill, title, and navigation.
        let recording: Recording?
        /// Doses whose `takenAt == time` — the fresh intakes "checked in" at this node.
        let intakeDoses: [MedicationEvent]
        /// Every dose still inside its effect window at `time`, oldest→newest, max 3.
        /// `rings[0]` is the outermost (oldest) ring.
        let rings: [Ring]
    }

    /// One concentric progress ring, already evaluated at its node's time.
    /// Carries the dose's name/strength so an active carry-over dose can be
    /// labelled (e.g. "Concerta 36mg · 40%") in the row's content column.
    struct Ring: Identifiable, Equatable {
        let doseID: UUID
        let progress: Double
        let name: String
        let dose: String?
        var id: UUID { doseID }
    }
}

/// Pure, store-free builder. Everything it reads is a stored property or a value
/// method, so it is fully unit-testable without `now`-mocking: a past node's ring
/// progress is historical and fixed at that node's own time.
enum DayTimelineBuilder {

    /// Builds time-ordered nodes (newest first) for a single day.
    /// - Parameters:
    ///   - recordings: recordings whose `createdAt` falls on the day.
    ///   - doses: taken medication events whose `takenAt` falls on the day.
    @MainActor
    static func build(recordings: [Recording], doses: [MedicationEvent]) -> [DayTimeline.Node] {
        // 1. Every distinct instant where something happened.
        var instants = Set<Date>()
        recordings.forEach { instants.insert($0.createdAt) }
        doses.forEach { instants.insert($0.takenAt) }

        // 2. One node per instant.
        let nodes = instants.map { instant -> DayTimeline.Node in
            // At most one recording per exact instant in practice (createdAt = Date() at capture).
            let recording = recordings.first { $0.createdAt == instant }
            let intakeDoses = doses.filter { $0.takenAt == instant }
            let rings = activeRings(at: instant, doses: doses)
            return DayTimeline.Node(
                id: nodeID(instant: instant, recording: recording, intakeDoses: intakeDoses),
                time: instant,
                recording: recording,
                intakeDoses: intakeDoses,
                rings: rings
            )
        }

        // 3. Newest first (top of the day section).
        return nodes.sorted { $0.time > $1.time }
    }

    /// Doses whose effect window covers `instant`, capped at the 3 most-recent and
    /// then ordered oldest→newest so the oldest dose is the outermost ring.
    private static func activeRings(at instant: Date, doses: [MedicationEvent]) -> [DayTimeline.Ring] {
        Array(
            doses
                .filter { dose in
                    let start = dose.takenAt
                    let end = start.addingTimeInterval(dose.durationHours * 3600)
                    return start <= instant && instant < end
                }
                .sorted { $0.takenAt > $1.takenAt }   // newest first
                .prefix(3)                            // keep the 3 most-recent (matches the med bar)
                .reversed()                           // oldest first → outermost
        )
        .map { DayTimeline.Ring(doseID: $0.id, progress: $0.effectProgress(at: instant), name: $0.name, dose: $0.dose) }
    }

    private static func nodeID(instant: Date, recording: Recording?, intakeDoses: [MedicationEvent]) -> String {
        var parts = [String(instant.timeIntervalSince1970)]
        if let recording { parts.append(recording.id.uuidString) }
        parts.append(contentsOf: intakeDoses.map(\.id.uuidString).sorted())
        return parts.joined(separator: "-")
    }
}
