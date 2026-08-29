import Foundation

/// Persists per-file resume state for a multi-file background download.
///
/// All mutations are actor-isolated and atomic writes are used so an app
/// termination mid-write never leaves a half-written JSON file.
public actor ResumeStateStore: Sendable {
    private let storeURL: URL
    private var states: [String: ResumeState] = [:]
    private let fileManager = FileManager.default

    public init(storeURL: URL) {
        self.storeURL = storeURL
    }

    /// Loads persisted state from disk. Safe to call repeatedly; later calls
    /// refresh the in-memory copy from disk.
    public func load() {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            states.removeAll()
            return
        }
        do {
            let data = try Data(contentsOf: storeURL)
            let decoded = try JSONDecoder().decode([String: ResumeState].self, from: data)
            states = decoded
        } catch {
            AppLogger.log("ResumeStateStore failed to load from \(storeURL.path): \(error)")
            states.removeAll()
        }
    }

    public func state(for fileKey: String) -> ResumeState? {
        states[fileKey]
    }

    public func setState(_ state: ResumeState) {
        states[state.fileKey] = state
        persist()
    }

    public func removeState(for fileKey: String) {
        states.removeValue(forKey: fileKey)
        persist()
    }

    public func removeAll() {
        states.removeAll()
        persist()
    }

    private func persist() {
        do {
            let directory = storeURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            if states.isEmpty {
                if fileManager.fileExists(atPath: storeURL.path) {
                    try fileManager.removeItem(at: storeURL)
                }
                return
            }
            let data = try JSONEncoder().encode(states)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            AppLogger.log("ResumeStateStore failed to persist to \(storeURL.path): \(error)")
        }
    }
}
