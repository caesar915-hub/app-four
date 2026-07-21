import Testing
import Foundation
@testable import app_four

struct StorageMigrationTests {
    private let fm = FileManager.default

    private func makeTempDir() throws -> URL {
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ text: String, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    @Test func movesFilesFromDocumentsToPrivateRoot() throws {
        let source = try makeTempDir()
        let dest = try makeTempDir()
        let legacyAudio = source.appendingPathComponent("Recordings/recording_a.m4a")
        try write("audio", to: legacyAudio)

        StorageMigration.run(from: source, to: dest, fileManager: fm)

        let moved = dest.appendingPathComponent("Recordings/recording_a.m4a")
        #expect(fm.fileExists(atPath: moved.path))
        #expect(!fm.fileExists(atPath: legacyAudio.path))
        // Legacy folder is emptied and removed.
        #expect(!fm.fileExists(atPath: source.appendingPathComponent("Recordings").path))
    }

    @Test func isIdempotentAcrossRepeatedRuns() throws {
        let source = try makeTempDir()
        let dest = try makeTempDir()
        try write("x", to: source.appendingPathComponent("Diagnostics/sessionSnapshots.json"))

        StorageMigration.run(from: source, to: dest, fileManager: fm)
        StorageMigration.run(from: source, to: dest, fileManager: fm)  // no-op, must not throw or duplicate

        let moved = dest.appendingPathComponent("Diagnostics/sessionSnapshots.json")
        #expect(try String(contentsOf: moved, encoding: .utf8) == "x")
    }

    private func setModificationDate(_ date: Date, on url: URL) throws {
        try fm.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    @Test func doesNotClobberAlreadyMigratedFileWithStaleLegacyCopy() throws {
        let source = try makeTempDir()
        let dest = try makeTempDir()
        let legacy = source.appendingPathComponent("Exports/e.json")
        let target = dest.appendingPathComponent("Exports/e.json")
        try write("legacy", to: legacy)
        try write("current", to: target)
        try setModificationDate(Date(timeIntervalSinceNow: -3600), on: legacy)
        try setModificationDate(Date(), on: target)

        StorageMigration.run(from: source, to: dest, fileManager: fm)

        // The newer destination copy wins; the stale legacy copy is dropped.
        #expect(try String(contentsOf: target, encoding: .utf8) == "current")
        #expect(!fm.fileExists(atPath: legacy.path))
    }

    @Test func newerLegacyCopyFromDowngradeCycleWins() throws {
        // TestFlight downgrade: a pre-1.0 build wrote a FRESH file to Documents
        // after an earlier migration had already populated the destination.
        let source = try makeTempDir()
        let dest = try makeTempDir()
        let legacy = source.appendingPathComponent("Diagnostics/sessionSnapshots.json")
        let target = dest.appendingPathComponent("Diagnostics/sessionSnapshots.json")
        try write("fresh-from-downgrade", to: legacy)
        try write("stale-migrated", to: target)
        try setModificationDate(Date(), on: legacy)
        try setModificationDate(Date(timeIntervalSinceNow: -3600), on: target)

        StorageMigration.run(from: source, to: dest, fileManager: fm)

        #expect(try String(contentsOf: target, encoding: .utf8) == "fresh-from-downgrade")
        #expect(!fm.fileExists(atPath: legacy.path))
    }

    @Test func noOpWhenNothingToMigrate() throws {
        let source = try makeTempDir()
        let dest = try makeTempDir()
        StorageMigration.run(from: source, to: dest, fileManager: fm)  // must not throw
        #expect(try fm.contentsOfDirectory(atPath: dest.path).isEmpty)
    }
}
