import Foundation
import SwiftData

/// Versioned schema baseline for feature 038 (iCloud Sync).
///
/// `V1` is the CloudKit-compatible shape (no `@Attribute(.unique)` on synced models,
/// all attributes optional-or-defaulted, all relationships optional). It is the FIRST
/// version the per-configuration stores ever see — the pre-038 single `default.store`
/// is intentionally abandoned once (Constitution IX pre-release reset), so no old-shape
/// snapshot is needed. Wiring the plan now makes the NEXT change a clean V1→V2 hop.
///
/// ⚠️ Reconciliation: when `fix/app-store-readiness` (which also introduces a versioned
/// schema + crash-safe container) merges, this file and `AppModelContainer` must be
/// merged by hand.
nonisolated enum SquirlSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recording.self,
            TranscriptionSegment.self,
            RecordingTag.self,
            MedicationEvent.self,
            AppSettings.self,
            ModelMetadata.self,
        ]
    }
}

/// Single-version plan. Empty `stages` is correct: both per-configuration stores are
/// created fresh at V1, so there is no older on-disk version to migrate. The next
/// schema change adds `SquirlSchemaV2` + a `MigrationStage` here.
nonisolated enum SquirlMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SquirlSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
