import Foundation

/// One-time relocation of user data from the pre-1.0 `Documents/` location
/// (which was exposed to the Files app) into the app-private ``AppPaths`` root.
///
/// Idempotent and file-by-file so a partially-migrated state self-heals on the
/// next launch. Because `Recording` persists only the audio *filename* (not an
/// absolute path), moving the files is sufficient — no database rows change.
enum StorageMigration {
    /// Directory names that previously lived directly under `Documents`.
    private static let migratedFolders = ["Recordings", "Exports", "Diagnostics"]

    static func run(
        from source: URL = URL.documentsDirectory,
        to destinationRoot: URL = AppPaths.privateRoot,
        fileManager: FileManager = .default
    ) {
        for folder in migratedFolders {
            let oldDir = source.appendingPathComponent(folder, isDirectory: true)
            guard fileManager.fileExists(atPath: oldDir.path) else { continue }

            let newDir = destinationRoot.appendingPathComponent(folder, isDirectory: true)
            try? fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)

            let contents = (try? fileManager.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil)) ?? []
            for file in contents {
                let target = newDir.appendingPathComponent(file.lastPathComponent)
                if fileManager.fileExists(atPath: target.path) {
                    // Already migrated in a prior run — drop the stale legacy copy.
                    try? fileManager.removeItem(at: file)
                } else {
                    try? fileManager.moveItem(at: file, to: target)
                }
            }

            // Remove the legacy directory only if empty, so a failed move never
            // deletes an un-migrated file (removeItem is recursive).
            if let remaining = try? fileManager.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil),
               remaining.isEmpty {
                try? fileManager.removeItem(at: oldDir)
            }
        }
    }
}
