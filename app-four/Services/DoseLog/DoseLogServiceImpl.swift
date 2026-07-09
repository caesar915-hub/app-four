import Foundation
import SwiftData

/// MainActor-isolated (repo default) — a fetch-limit-1 + insert is trivial work,
/// so no background context or detached task (research D5/D6). Injectable context
/// for isolated tests; production uses the app's shared main context.
@MainActor
final class DoseLogServiceImpl: DoseLogService {
    private let context: ModelContext

    init(context: ModelContext? = nil) {
        self.context = context ?? AppModelContainer.container.mainContext
    }

    func logDefaultDose(now: Date) async -> DoseLogOutcome {
        let settings = fetchOrCreateSettings()

        // Configured only when both fields are set AND the name still resolves in the
        // catalog — a dangling default (catalog changed) degrades to not-configured (FR-007).
        guard let name = settings.defaultMedicationName,
              let dose = settings.defaultMedicationDose,
              let entry = MedicationCatalog.entry(matching: name) else {
            return .notConfigured
        }

        // Guard evaluates against the most recent dose event regardless of medication or
        // logging surface (clarification Q3); `.off` never blocks (FR-009..FR-012).
        let mode = DoseGuardMode(raw: settings.doseGuardModeRaw)
        if let previous = mostRecentDose(),
           mode.blocksLog(previousDose: previous, windowHours: settings.doseGuardWindowHours, now: now) {
            return .guarded(activeSince: previous.takenAt)
        }

        let event = MedicationEvent(
            name: name,
            dose: dose,
            takenAt: now,
            durationHours: entry.durationHours,
            source: .manual
        )
        context.insert(event)
        try? context.save()
        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
        return .logged(name: name, dose: dose, at: now)
    }

    private func fetchOrCreateSettings() -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        try? context.save()
        return created
    }

    /// Most recent real, taken dose — any medication, any surface. No time cutoff:
    /// a stale latest event simply passes the guard (data-model.md).
    private func mostRecentDose() -> MedicationEvent? {
        var descriptor = FetchDescriptor<MedicationEvent>(
            predicate: #Predicate { $0.taken == true && $0.isMockData == false },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
