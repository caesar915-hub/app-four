import Foundation
import Observation
import SwiftData

/// Supplies the Log-Dose picker with the names a user can choose from: the static catalog
/// first, then any medication they've logged before that isn't already a catalog entry.
/// Holds no persistence logic of its own — it reads distinct names through the shared
/// `ModelContext` and resolves catalog metadata; logging itself stays on the bar's
/// `logManualDose` path (Constitution VIII).
@Observable
@MainActor
final class MedicationPickerViewModel {
    /// Catalog names first, then novel history names (deduped by base name).
    private(set) var pickableNames: [String] = []

    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext? = nil) {
        self.context = context ?? AppModelContainer.container.mainContext
        refresh()
    }

    func refresh() {
        pickableNames = Self.merge(
            catalog: MedicationCatalog.all.map(\.name),
            history: fetchDistinctHistoryNames()
        )
    }

    /// Catalog metadata for a chosen name, or nil for a free-text medication.
    func catalogEntry(for name: String) -> MedicationCatalogEntry? {
        MedicationCatalog.entry(matching: name)
    }

    // MARK: - Pure, testable helpers

    /// Catalog names, then each history name whose base name isn't already represented —
    /// so "Concerta 36 mg" in history folds into the catalog's "Concerta" instead of
    /// listing twice (FR-014). Dedups within history too.
    static func merge(catalog: [String], history: [String]) -> [String] {
        var seen = Set(catalog.map(baseName))
        var result = catalog
        for name in history {
            let base = baseName(name)
            guard !base.isEmpty, !seen.contains(base) else { continue }
            seen.insert(base)
            result.append(name)
        }
        return result
    }

    /// First whitespace token, lowercased — the dose-insensitive identity of a med name.
    static func baseName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init)?.lowercased() ?? name.lowercased()
    }

    // MARK: - Private

    private func fetchDistinctHistoryNames() -> [String] {
        var descriptor = FetchDescriptor<MedicationEvent>(
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        guard let events = try? context.fetch(descriptor) else { return [] }

        var seen = Set<String>()
        var names: [String] = []
        for event in events {
            let base = Self.baseName(event.name)
            guard !base.isEmpty, !seen.contains(base) else { continue }
            seen.insert(base)
            names.append(event.name)
        }
        return names
    }
}
