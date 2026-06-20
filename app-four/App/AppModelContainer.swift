import Foundation
import SwiftData

/// Manages the SwiftData ModelContainer for the entire app.
@MainActor
enum AppModelContainer {
    /// The main production container.
    static let container: ModelContainer = {
        let schema = Schema([
            Recording.self,
            TranscriptionSegment.self,
            ModelMetadata.self,
            AppSettings.self,
            RecordingTag.self,
            MedicationEvent.self,
            DailySignals.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let storeDir = config.url.deletingLastPathComponent()
        // Pre-create Application Support so SwiftData doesn't log a wall of CoreData
        // diagnostic errors on first launch while it recovers the missing directory.
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        @MainActor func makeContainer() throws -> ModelContainer {
            let c = try ModelContainer(for: schema, configurations: [config])
            // Transcript and medication data is sensitive health information —
            // exclude the store directory from iCloud backup.
            try? (storeDir as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)

            // Seed 10 days of dummy data on debug builds (simulator and device) when
            // the store is empty — so on-device test runs have content. Never in release.
            #if DEBUG
            let context = c.mainContext
            let fetchDescriptor = FetchDescriptor<Recording>()
            if (try? context.fetchCount(fetchDescriptor)) == 0 {
                MockDataGenerator.generate(context: context)
            }
            #endif

            return c
        }

        do {
            return try makeContainer()
        } catch {
            // Schema mismatch on a pre-release build — wipe the store and start fresh.
            AppLogger.log("AppModelContainer: schema conflict, wiping store — \(error)")
            let storeURL = config.url
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")
            for url in [storeURL, walURL, shmURL] {
                try? FileManager.default.removeItem(at: url)
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
        let schema = Schema([
            Recording.self,
            TranscriptionSegment.self,
            ModelMetadata.self,
            AppSettings.self,
            RecordingTag.self,
            MedicationEvent.self,
            DailySignals.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])

            // Add mock data
            MockDataGenerator.generate(context: container.mainContext)

            return container
        } catch {
            fatalError("Could not create Preview ModelContainer: \(error)")
        }
    }()
}
