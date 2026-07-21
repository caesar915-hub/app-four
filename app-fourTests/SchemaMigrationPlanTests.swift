import Testing
import Foundation
import SwiftData
@testable import app_four

@MainActor
struct SchemaMigrationPlanTests {
    @Test func v1DeclaresEveryPersistedModel() {
        #expect(SquirlSchemaV1.models.count == 6)
    }

    @Test func migrationPlanStartsFromV1() {
        #expect(SquirlMigrationPlan.schemas.count == 1)
        #expect(SquirlMigrationPlan.schemas.first?.versionIdentifier == SquirlSchemaV1.versionIdentifier)
        // No stages yet — the first real model change adds V2 + a stage here.
        #expect(SquirlMigrationPlan.stages.isEmpty)
    }

    /// A container that builds from the versioned schema proves the schema is
    /// valid — this is the compile-time-invisible failure the launch fallback
    /// exists to survive, so guard it in CI.
    @Test func versionedSchemaBuildsAContainer() throws {
        let schema = Schema(versionedSchema: SquirlSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SquirlMigrationPlan.self,
            configurations: [config]
        )
        #expect(!container.schema.entities.isEmpty)
    }
}
