import Testing
import Foundation
import SwiftData
@testable import app_four

/// Verifies the spec-038 CloudKit-shaped `SquirlSchemaV1` builds a valid SwiftData
/// container, models round-trip, and the `medicationEvents` relationship is optional.
/// (CloudKit-compliance itself — no `.unique`, `.private` loads — is device-verified
/// via quickstart S1–S11, since it needs an iCloud account.)
@MainActor
@Suite struct SchemaV1ContainerTests {
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: Schema(versionedSchema: SquirlSchemaV1.self),
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: Schema(versionedSchema: SquirlSchemaV1.self),
            migrationPlan: SquirlMigrationPlan.self,
            configurations: [config]
        )
    }

    @Test func v1SchemaBuildsAndMigrationPlanLoads() throws {
        _ = try makeContainer()
    }

    @Test func syncedAndLocalModelsRoundTrip() throws {
        let ctx = try makeContainer().mainContext
        ctx.insert(Recording(audioFileName: "t.m4a"))
        ctx.insert(AppSettings())
        ctx.insert(MedicationEvent(name: "Concerta", takenAt: .now))
        try ctx.save()
        #expect(try ctx.fetchCount(FetchDescriptor<Recording>()) == 1)
        #expect(try ctx.fetchCount(FetchDescriptor<AppSettings>()) == 1)
        #expect(try ctx.fetchCount(FetchDescriptor<MedicationEvent>()) == 1)
    }

    @Test func medicationEventsRelationshipIsOptionalToMany() throws {
        let ctx = try makeContainer().mainContext
        let rec = Recording(audioFileName: "t.m4a")
        ctx.insert(rec)
        try ctx.save()
        #expect((rec.medicationEvents ?? []).isEmpty)

        let med = MedicationEvent(name: "Elvanse", takenAt: .now)
        ctx.insert(med)
        med.recording = rec
        try ctx.save()
        #expect(rec.medicationEvents?.count == 1)
    }
}
