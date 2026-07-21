import Foundation

/// One known medication the user can pick when logging a dose: its dose options, how long
/// until it kicks in (onset), and how long its effect lasts (the bar's fill window).
/// Static reference data — not persisted, so it adds no SwiftData schema (Constitution IX).
struct MedicationCatalogEntry: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let doseOptions: [String]
    let onsetMinutes: Int
    let durationHours: Double
}

/// The curated stimulant catalog. Beta subset: the three meds the first testers take.
/// Extends to the fuller EU list by appending entries — no other code needs to change.
/// Dose strengths, onset, and duration are typical values from each product's EU
/// Summary of Product Characteristics (SmPC); the UI must always present them as
/// typical ("≈", "may differ"), never as guidance (App Review 1.4.1).
nonisolated enum MedicationCatalog {
    static let all: [MedicationCatalogEntry] = [
        MedicationCatalogEntry(
            name: "Concerta",
            doseOptions: ["18 mg", "27 mg", "36 mg", "54 mg"],
            onsetMinutes: 60,
            durationHours: 12
        ),
        MedicationCatalogEntry(
            name: "Ritalin",
            doseOptions: ["5 mg", "10 mg", "20 mg"],
            onsetMinutes: 20,
            durationHours: 3
        ),
        MedicationCatalogEntry(
            name: "Elvanse",
            doseOptions: ["20 mg", "30 mg", "40 mg", "50 mg", "60 mg", "70 mg"],
            onsetMinutes: 90,
            durationHours: 10
        ),
    ]

    /// Resolves a free-form name to a catalog entry by its base name — the first
    /// whitespace token, lowercased — so "concerta", "Concerta", and "Concerta 36 mg" all
    /// match the Concerta entry. Returns nil for an unknown or empty name.
    static func entry(matching name: String) -> MedicationCatalogEntry? {
        let base = name.split(separator: " ").first.map(String.init)?.lowercased()
        guard let base, !base.isEmpty else { return nil }
        return all.first { $0.name.lowercased() == base }
    }
}
