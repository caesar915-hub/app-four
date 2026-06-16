import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Notification

extension Notification.Name {
    /// Posted by `RecordingStore.save()` whenever medication-related data may have changed.
    static let medicationEventsDidChange = Notification.Name("medicationEventsDidChange")
}

// MARK: - ViewModel

/// Single app-level instance — injected via `.environment(AppDependencies.medicationBarViewModel)`.
@Observable
@MainActor
final class MedicationBarViewModel {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var observerToken: NSObjectProtocol?

    /// Up to 3 active doses, sorted oldest → newest (1st dose at top).
    var activeDoses: [DoseDisplay] = []

    struct DoseDisplay: Equatable {
        let eventID: UUID
        let name: String
        /// Recorded dose for this specific event, e.g. "36mg".
        let dose: String?
        /// The recorded dose, or nil when none was captured. UI shows just the
        /// med name when nil (no phantom default).
        let effectiveDose: String?
        let takenAt: Date
        let endsAt: Date
        let doseNumber: Int
        let totalDosesToday: Int
        let progress: Double

        var color: Color { MedicationBarViewModel.effectColor(for: progress) }
    }

    /// Lavender(0–20%) → deep purple(20–80%) → light red(80–100%).
    static func effectColor(for progress: Double) -> Color {
        let p = min(1, max(0, progress))
        typealias RGB = (r: Double, g: Double, b: Double)
        let lavender: RGB = (0.82, 0.72, 1.00)
        let purple:   RGB = (0.45, 0.00, 0.75)
        let lightRed: RGB = (1.00, 0.55, 0.55)
        func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
            (a.r + t * (b.r - a.r), a.g + t * (b.g - a.g), a.b + t * (b.b - a.b))
        }
        let c: RGB
        switch p {
        case 0..<0.2:  c = lerp(lavender, purple,  p / 0.2)
        case 0.2..<0.8: c = purple
        default:       c = lerp(purple,   lightRed, (p - 0.8) / 0.2)
        }
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    init(context: ModelContext? = nil) {
        self.context = context ?? AppModelContainer.container.mainContext
        observerToken = NotificationCenter.default.addObserver(
            forName: .medicationEventsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue → already on the main actor.
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    deinit {
        if let token = observerToken { NotificationCenter.default.removeObserver(token) }
    }

    // MARK: - Public

    func refresh(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-24 * 3600)
        let mockMode = UserDefaults.standard.bool(forKey: "debugMockMode")
        var descriptor = FetchDescriptor<MedicationEvent>(
            predicate: #Predicate { $0.taken == true && $0.takenAt > cutoff && $0.isMockData == mockMode },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        guard let events = try? context.fetch(descriptor) else {
            activeDoses = []
            return
        }

        // Up to 3 most-recent events still within their window, then reversed for oldest-first display.
        let active = events
            .filter { $0.takenAt.addingTimeInterval($0.durationHours * 3600) > now }
            .prefix(3)
            .reversed() // oldest first → 1st dose at top

        let todayStart = Calendar.current.startOfDay(for: now)

        activeDoses = active.map { event in
            // Normalise to first word (lowercase) so "Concerta", "Concerta 36mg", "Concerta 27 mg"
            // all resolve to the same base name for ordinal counting.
            let baseName = event.name.split(separator: " ").first.map(String.init)?.lowercased()
                           ?? event.name.lowercased()
            let todayDoses = events
                .filter {
                    let b = $0.name.split(separator: " ").first.map(String.init)?.lowercased()
                            ?? $0.name.lowercased()
                    return b == baseName && $0.takenAt >= todayStart
                }
                .sorted { $0.takenAt < $1.takenAt }
            let doseNumber = (todayDoses.firstIndex(where: { $0.id == event.id }) ?? 0) + 1
            let endsAt = event.takenAt.addingTimeInterval(event.durationHours * 3600)
            let progress = min(1, max(0, now.timeIntervalSince(event.takenAt) / (event.durationHours * 3600)))

            return DoseDisplay(
                eventID: event.id,
                name: event.name,
                dose: event.dose,
                effectiveDose: event.dose,
                takenAt: event.takenAt,
                endsAt: endsAt,
                doseNumber: doseNumber,
                totalDosesToday: todayDoses.count,
                progress: progress
            )
        }
    }

    func logManualDose(name: String, dose: String?, takenAt: Date, durationHours: Double = 10.0) {
        let event = MedicationEvent(
            name: name,
            dose: dose,
            takenAt: takenAt,
            taken: true,
            durationHours: durationHours,
            source: .manual
        )
        context.insert(event)
        try? context.save()
        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
    }

    func deleteEvent(id: UUID) {
        var descriptor = FetchDescriptor<MedicationEvent>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let event = try? context.fetch(descriptor).first else { return }
        context.delete(event)
        try? context.save()
        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
    }
}
