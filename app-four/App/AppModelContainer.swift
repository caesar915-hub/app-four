import Foundation
import SwiftData

/// Manages the SwiftData ModelContainer for the entire app.
@MainActor
enum AppModelContainer {
    /// True when the primary store could not be opened this session and the app
    /// is running on a non-persistent in-memory container. UI should surface
    /// this — writes made in this state do not survive a relaunch.
    private(set) static var isEphemeral = false

    /// The main production container.
    static let container: ModelContainer = {
        let schema = Schema(versionedSchema: SquirlSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let storeDir = config.url.deletingLastPathComponent()
        // Pre-create Application Support so SwiftData doesn't log a wall of CoreData
        // diagnostic errors on first launch while it recovers the missing directory.
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        // A quarantine cycle that died mid-flight (crash/jetsam between quarantine
        // and its retry) self-heals here: the pending marker names the snapshot,
        // any partial retry files are discarded, and the real store is put back.
        recoverInterruptedQuarantine(storeURL: config.url)

        @MainActor func makeContainer() throws -> ModelContainer {
            let c = try ModelContainer(for: schema, migrationPlan: SquirlMigrationPlan.self, configurations: [config])
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
            AppLogger.log("AppModelContainer: primary store open failed — \(error)")

            #if DEBUG
            // Dev convenience: schema churn on a throwaway store — wipe and retry.
            for url in storeFileURLs(for: config.url) {
                try? FileManager.default.removeItem(at: url)
            }
            if let recovered = try? makeContainer() { return recovered }
            #else
            // A store whose *content* can't be opened is locked (data protection
            // during a pre-unlock background launch) or transiently unavailable —
            // not corrupt. Leave the disk untouched and degrade to in-memory for
            // the rest of this process. The container is a `static let`, so a
            // background-launched process keeps the empty container until it
            // dies — the heal happens on the next cold launch, not on mere
            // foregrounding.
            if isStoreContentReadable(config.url),
               let snapshot = quarantine(storeURL: config.url) {
                // Genuinely unopenable: quarantine the trio (rename, never delete)
                // under a pending marker, then open fresh. If the fresh open also
                // fails, the quarantine is undone so the store is never left split;
                // a crash between these steps is undone by the marker on relaunch.
                // A nil snapshot means quarantine setup itself failed — nothing
                // moved, so there is nothing to undo and no retry worth making.
                if let recovered = try? makeContainer() {
                    clearPendingMarker(storeURL: config.url)
                    return recovered
                }
                undoQuarantine(snapshot: snapshot, storeURL: config.url)
            }
            #endif

            // Last resort: an in-memory store so launch never crashes. On-disk data
            // is untouched or quarantined — never deleted in release.
            // An in-memory container can only fail on an invalid schema, which is a
            // programmer error caught by SchemaMigrationPlanTests — so this `try!`
            // cannot throw in production.
            AppLogger.log("AppModelContainer: falling back to in-memory store")
            isEphemeral = true
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memory])
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

    // MARK: - Store recovery
    //
    // Quarantine protocol: the snapshot directory and pending marker are
    // committed FIRST, then the trio moves into Quarantine/<stamp>/. Every
    // exit path resolves the marker — retry success clears it (snapshot kept
    // for forensics), retry failure undoes the quarantine, and a crash
    // anywhere is healed by `recoverInterruptedQuarantine` on the next launch.
    // The ordering is what makes the cycle atomic: marker-before-move means a
    // crash can never leave moved files without a marker pointing at them, and
    // the undo deletes a live file only when the snapshot verifiably holds the
    // real database — so neither a crashed retry's partial `default.store` nor
    // a setup failure can strand or destroy the real data.

    /// The store plus its SQLite journal sidecars. SQLite appends a literal
    /// `-wal`/`-shm` (hyphen, not a path extension) to the full database filename.
    private static func storeFileURLs(for storeURL: URL) -> [URL] {
        let dir = storeURL.deletingLastPathComponent()
        let name = storeURL.lastPathComponent
        return [storeURL,
                dir.appendingPathComponent(name + "-wal"),
                dir.appendingPathComponent(name + "-shm")]
    }

    private static func quarantineRoot(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent().appendingPathComponent("Quarantine", isDirectory: true)
    }

    private static func pendingMarkerURL(for storeURL: URL) -> URL {
        quarantineRoot(for: storeURL).appendingPathComponent("pending")
    }

    /// Distinguishes "locked or transiently unreadable" from "openable but rejected".
    /// Data protection rejects the open() itself, so open-success is the whole
    /// answer — probing a read would misread a 0-byte file (EOF) as locked. A
    /// missing file reads as readable: the failure wasn't about protected content.
    private static func isStoreContentReadable(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        try? handle.close()
        return true
    }

    /// Moves the store trio into `Quarantine/<stamp>/` (names intact, so a
    /// snapshot stays restorable as a unit). Two orderings are load-bearing:
    /// the marker is committed before the snapshot directory and both before
    /// anything moves (a crash between marker and directory is healed by
    /// recovery's clear-marker guard, leaving no unmarked cruft); and the
    /// sidecars move before the database itself, so a snapshot that contains
    /// `default.store` is provably complete — recovery can treat any files
    /// still live as a dead retry's, never the original `-wal`.
    /// Returns nil when the setup writes fail (disk full, root occupied) — in
    /// that case nothing has moved and the caller must not undo or retry.
    private static func quarantine(storeURL: URL) -> URL? {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let dest = quarantineRoot(for: storeURL).appendingPathComponent(stamp, isDirectory: true)
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: quarantineRoot(for: storeURL), withIntermediateDirectories: true)
            try Data(stamp.utf8).write(to: pendingMarkerURL(for: storeURL))
            try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        } catch {
            AppLogger.log("AppModelContainer: quarantine setup failed, store left in place — \(error)")
            try? fm.removeItem(at: dest)
            clearPendingMarker(storeURL: storeURL)
            return nil
        }
        for url in storeFileURLs(for: storeURL).reversed() where fm.fileExists(atPath: url.path) {
            try? fm.moveItem(at: url, to: dest.appendingPathComponent(url.lastPathComponent))
        }
        AppLogger.log("AppModelContainer: store quarantined to \(stamp)")
        return dest
    }

    /// Reverses a quarantine. Which side holds the real database decides what
    /// happens to live files: if the snapshot contains `default.store`, the
    /// sidecars-before-store move order proves the capture was complete, so
    /// anything still live is a dead retry's — set it ASIDE (rename, never
    /// delete) so a retry-created `-wal` can't be replayed into the restored
    /// store, then restore the database FIRST: once `default.store` leaves the
    /// snapshot, a crash mid-restore drops the next launch into the no-delete
    /// branch, which reunites the remaining sidecars instead of sweeping them.
    /// If the snapshot lacks the store, the live one never moved — delete
    /// nothing, and return stray sidecars only where no live file would be
    /// clobbered. The marker survives until the database itself is out of the
    /// snapshot, so an interrupted restore is retried, not stranded.
    private static func undoQuarantine(snapshot: URL, storeURL: URL) {
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent()
        let snapshotStore = snapshot.appendingPathComponent(storeURL.lastPathComponent)
        if fm.fileExists(atPath: snapshotStore.path) {
            let deadDir = snapshot.deletingLastPathComponent()
                .appendingPathComponent("dead-" + snapshot.lastPathComponent, isDirectory: true)
            for url in storeFileURLs(for: storeURL) where fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: deadDir, withIntermediateDirectories: true)
                if (try? fm.moveItem(at: url, to: deadDir.appendingPathComponent(url.lastPathComponent))) == nil {
                    // A same-named file from an earlier interrupted recovery
                    // already sits aside; this one is equally dead, and removing
                    // it is the only way to keep a foreign -wal from being
                    // replayed into the restored store.
                    try? fm.removeItem(at: url)
                }
            }
            for url in storeFileURLs(for: storeURL) {
                let src = snapshot.appendingPathComponent(url.lastPathComponent)
                guard fm.fileExists(atPath: src.path) else { continue }
                try? fm.moveItem(at: src, to: dir.appendingPathComponent(url.lastPathComponent))
            }
        } else {
            let contents = (try? fm.contentsOfDirectory(at: snapshot, includingPropertiesForKeys: nil)) ?? []
            for file in contents
            where !fm.fileExists(atPath: dir.appendingPathComponent(file.lastPathComponent).path) {
                try? fm.moveItem(at: file, to: dir.appendingPathComponent(file.lastPathComponent))
            }
        }
        if let remaining = try? fm.contentsOfDirectory(at: snapshot, includingPropertiesForKeys: nil),
           remaining.isEmpty {
            try? fm.removeItem(at: snapshot)
        }
        if !fm.fileExists(atPath: snapshotStore.path) {
            clearPendingMarker(storeURL: storeURL)
        }
        AppLogger.log("AppModelContainer: quarantine undone, store restored")
    }

    private static func clearPendingMarker(storeURL: URL) {
        try? FileManager.default.removeItem(at: pendingMarkerURL(for: storeURL))
    }

    /// Completes a quarantine cycle that a crash interrupted: if the pending
    /// marker exists, hand the marked snapshot to `undoQuarantine`, which
    /// works out from the snapshot's contents which side holds the real
    /// database and restores accordingly — a pre-move crash (empty snapshot)
    /// deletes nothing and just clears the marker.
    private static func recoverInterruptedQuarantine(storeURL: URL) {
        let markerURL = pendingMarkerURL(for: storeURL)
        guard let data = try? Data(contentsOf: markerURL),
              let stamp = String(data: data, encoding: .utf8) else { return }
        let snapshot = quarantineRoot(for: storeURL).appendingPathComponent(stamp, isDirectory: true)
        guard FileManager.default.fileExists(atPath: snapshot.path) else {
            clearPendingMarker(storeURL: storeURL)
            return
        }
        AppLogger.log("AppModelContainer: recovering interrupted quarantine \(stamp)")
        undoQuarantine(snapshot: snapshot, storeURL: storeURL)
    }
}
