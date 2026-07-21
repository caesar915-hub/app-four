import SwiftData

/// Versioned schema for the app's SwiftData store.
///
/// Introducing this with the *current* model set is a no-op for existing stores
/// (SwiftData matches a store to a schema by entity structure, not by version
/// number). The value is forward-looking: the next model change adds a `V2`
/// versioned schema plus a `MigrationStage` below, so migrations run
/// deterministically instead of falling through to a destructive store wipe.
enum SquirlSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recording.self,
            TranscriptionSegment.self,
            ModelMetadata.self,
            AppSettings.self,
            RecordingTag.self,
            MedicationEvent.self
        ]
    }
}

enum SquirlMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SquirlSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
