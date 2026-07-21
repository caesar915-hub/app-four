import Foundation

/// An off-MainActor actor that maintains a rolling buffer of the last 50
/// `SessionSnapshot`s and persists them to a JSON file in the app sandbox.
///
/// Using a plain JSON file (instead of SwiftData) keeps all I/O off the main
/// actor and avoids adding latency to heavy operations like transcription.
actor DiagnosticsStore: Sendable {
    private let maxSnapshots = 50
    private var snapshots: [SessionSnapshot] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let injected = fileURL {
            self.fileURL = injected
        } else {
            self.fileURL = AppPaths.diagnostics.appendingPathComponent("sessionSnapshots.json")
        }

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Load existing data
        self.snapshots = Self.load(from: self.fileURL)
    }

    // MARK: - Public API

    /// Append a new snapshot, trim to `maxSnapshots`, and write to disk.
    func record(_ snapshot: SessionSnapshot) {
        snapshots.append(snapshot)
        if snapshots.count > maxSnapshots {
            snapshots.removeFirst(snapshots.count - maxSnapshots)
        }
        AppLogger.log("Recorded diagnostic snapshot: \(snapshot.screenName)")
        persist()
    }

    /// Returns the most recent snapshots, newest first.
    func recentSnapshots(limit: Int = 50) -> [SessionSnapshot] {
        Array(snapshots.suffix(limit).reversed())
    }

    /// Removes all stored snapshots and deletes the JSON file.
    func clear() {
        snapshots.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    private func persist() {
        Task(priority: .utility) { [fileURL, snapshots] in
            let archive = SessionSnapshotArchive(snapshots: snapshots)
            do {
                let data = try JSONEncoder().encode(archive)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                AppLogger.log("DiagnosticsStore failed to persist: \(error)")
            }
        }
    }

    private static func load(from url: URL) -> [SessionSnapshot] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let archive = try JSONDecoder().decode(SessionSnapshotArchive.self, from: data)
            return archive.snapshots
        } catch {
            AppLogger.log("DiagnosticsStore failed to load: \(error)")
            return []
        }
    }
}
