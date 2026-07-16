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

    @Test func doesNotClobberAlreadyMigratedFile() throws {
        let source = try makeTempDir()
        let dest = try makeTempDir()
        try write("legacy", to: source.appendingPathComponent("Exports/e.json"))
        try write("current", to: dest.appendingPathComponent("Exports/e.json"))

        StorageMigration.run(from: source, to: dest, fileManager: fm)

        // The already-present destination copy wins; the stale legacy copy is dropped.
        let target = dest.appendingPathComponent("Exports/e.json")
        #expect(try String(contentsOf: target, encoding: .utf8) == "current")
        #expect(!fm.fileExists(atPath: source.appendingPathComponent("Exports/e.json").path))
    }

    @Test func noOpWhenNothingToMigrate() throws {
        let source = try makeTempDir()
        let dest = try makeTempDir()
        StorageMigration.run(from: source, to: dest, fileManager: fm)  // must not throw
        #expect(try fm.contentsOfDirectory(atPath: dest.path).isEmpty)
    }
}
