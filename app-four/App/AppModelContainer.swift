import Foundation
import SwiftData

/// Manages the SwiftData ModelContainer for the entire app.
///
/// Spec 038 (iCloud Sync): the store is partitioned into TWO configurations in one
/// container — "Synced" (journal models, mirrored to the user's private CloudKit
/// database when the user opts in) and "Local" (`AppSettings`/`ModelMetadata`, never
/// synced, so they may keep `@Attribute(.unique)`). Sync is OFF by default
/// (`cloudKitDatabase: .none` until `SyncFlags.iCloudSyncEnabled`).
///
/// NOTE (pre-release reset): moving from the pre-038 single `default.store` to two
/// named stores abandons the old rows one time — acceptable pre-release (Constitution
/// IX). The versioned schema is wired now so the next schema change is a clean
/// V1→V2 migration.
@MainActor
enum AppModelContainer {
    private static let syncedModels: [any PersistentModel.Type] = [
        Recording.self, TranscriptionSegment.self, RecordingTag.self, MedicationEvent.self,
    ]
    private static let localModels: [any PersistentModel.Type] = [
        AppSettings.self, ModelMetadata.self,
    ]

    /// Must match the `com.apple.developer.icloud-container-identifiers` entitlement,
    /// provisioned for every bundle id (main + Stable channel).
    private static let cloudContainerID = "iCloud.Rythm-App.app-four"

    /// Unit tests use this app as their host, so the app's launch path builds this
    /// container inside the test process. Backing it with the REAL on-device stores there
    /// is both a correctness hazard (the wipe-fallback below can delete the owner's real
    /// data mid-run) and a contention hazard (400+ parallel `@MainActor` tests fighting a
    /// second Core Data stack). Under XCTest it is in-memory, un-seeded and never
    /// CloudKit-backed; tests build their own containers.
    private static let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static let container: ModelContainer = {
        let fullSchema = Schema(versionedSchema: SquirlSchemaV1.self)

        // Off by default. `.none` skips CloudKit schema validation, so a non-compliant
        // synced model would only surface when the user first enables sync — the four
        // synced models are made CloudKit-compliant up front to avoid that trap.
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase =
            (SyncFlags.iCloudSyncEnabled && !isRunningTests) ? .private(cloudContainerID) : .none

        let syncedConfig = ModelConfiguration(
            "Synced",
            schema: Schema(syncedModels),
            isStoredInMemoryOnly: isRunningTests,
            cloudKitDatabase: cloudKitDatabase
        )
        let localConfig = ModelConfiguration(
            "Local",
            schema: Schema(localModels),
            isStoredInMemoryOnly: isRunningTests,
            cloudKitDatabase: .none
        )

        let storeDir = localConfig.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        @MainActor func makeContainer() throws -> ModelContainer {
            let c = try ModelContainer(
                for: fullSchema,
                migrationPlan: SquirlMigrationPlan.self,
                configurations: [syncedConfig, localConfig]
            )
            // Sensitive health data: keep the store directory out of iCloud *device
            // backup*. This is distinct from CloudKit sync — the Synced store still
            // mirrors to the user's private CloudKit DB (sensitive fields E2E-encrypted
            // under ADP); excluding it from device backup avoids double-storage
            // (Constitution VI). Re-applied here because file ops reset the flag.
            try? (storeDir as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

            // Seed 10 days of dummy data on debug builds when the store is empty — so
            // on-device test runs have content. Never in release.
            #if DEBUG
            if !isRunningTests {
                let context = c.mainContext
                if (try? context.fetchCount(FetchDescriptor<Recording>())) == 0 {
                    MockDataGenerator.generate(context: context)
                }
            }
            #endif

            return c
        }

        do {
            return try makeContainer()
        } catch {
            // Pre-release wipe fallback (Constitution IX). Also clears the stale pre-038
            // single store so it never lingers. Replaced by the crash-safe container
            // when `fix/app-store-readiness` merges — before v1.2 launch, wiping real
            // user data is NOT acceptable.
            AppLogger.log("AppModelContainer: schema conflict, wiping stores — \(error)")
            // Never destroy real store files from inside a test run.
            guard !isRunningTests else {
                fatalError("Test-host container failed to build: \(error)")
            }
            let legacyStore = storeDir.appendingPathComponent("default.store")
            for base in [syncedConfig.url, localConfig.url, legacyStore] {
                for url in [base, base.appendingPathExtension("wal"), base.appendingPathExtension("shm")] {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            do {
                return try makeContainer()
            } catch {
                fatalError("Could not create ModelContainer even after store wipe: \(error)")
            }
        }
    }()

    /// A container prepopulated with mock data for SwiftUI Previews and testing.
    static let previewContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SquirlSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            MockDataGenerator.generate(context: container.mainContext)
            return container
        } catch {
            fatalError("Could not create Preview ModelContainer: \(error)")
        }
    }()
}
