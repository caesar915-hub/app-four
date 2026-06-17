import Foundation
import Testing
import SwiftData
@testable import app_four

/// Per-med duration (Edit-sheet inline-expand) must flow from the `MedEvent` DTO through
/// `Recording.setMedicationEvents` onto the materialized `MedicationEvent`, and fall back
/// to the catalog/default when nil. (008 mockup-parity, FR-009 — the one sanctioned hook.)
@MainActor
struct MedEventDurationTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Recording.self, MedicationEvent.self, AppSettings.self,
            configurations: config
        )
        context = container.mainContext
    }

    private func transcriptEvent(after meds: [MedEvent]) throws -> MedicationEvent? {
        let rec = Recording(audioFileName: "t.m4a")
        context.insert(rec)
        rec.setMedicationEvents(from: meds, durationHours: nil, context: context)
        try context.save()
        return try context.fetch(FetchDescriptor<MedicationEvent>()).first { $0.source == .transcript }
    }

    @Test func perMedDurationFlowsToEvent() throws {
        let event = try transcriptEvent(after: [MedEvent(name: "Concerta", durationHours: 5)])
        #expect(event?.durationHours == 5)
    }

    @Test func nilDurationFallsBackToCatalog() throws {
        let event = try transcriptEvent(after: [MedEvent(name: "Concerta")])
        #expect(event?.durationHours == MedicationCatalog.entry(matching: "Concerta")?.durationHours)
    }
}
