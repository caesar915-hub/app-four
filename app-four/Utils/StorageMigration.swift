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
            merge(from: oldDir, into: destinationRoot.appendingPathComponent(folder, isDirectory: true),
                  fileManager: fileManager)
        }
    }

    /// Merges one legacy directory into its destination, file by file.
    /// Same-named directories recurse (pre-1.0 `Documents` was Files-app
    /// exposed, so user-created subfolders are possible) — a whole tree is
    /// never won or lost on its container's mtime. On a file collision the
    /// newer copy wins: normally the destination (already migrated), but a
    /// TestFlight downgrade writes FRESH files to Documents under fixed names
    /// (e.g. sessionSnapshots.json). The legacy directory is removed only once
    /// empty, so a failed move never deletes an un-migrated file.
    private static func merge(from oldDir: URL, into newDir: URL, fileManager: FileManager) {
        try? fileManager.createDirectory(at: newDir, withIntermediateDirectories: true)

        let contents = (try? fileManager.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil)) ?? []
        for file in contents {
            let target = newDir.appendingPathComponent(file.lastPathComponent)
            var sourceIsDir: ObjCBool = false
            var targetIsDir: ObjCBool = false
            guard fileManager.fileExists(atPath: file.path, isDirectory: &sourceIsDir) else { continue }
            let targetExists = fileManager.fileExists(atPath: target.path, isDirectory: &targetIsDir)

            if targetExists && sourceIsDir.boolValue && targetIsDir.boolValue {
                merge(from: file, into: target, fileManager: fileManager)
            } else if targetExists && sourceIsDir.boolValue != targetIsDir.boolValue {
                // Mixed dir-vs-file collision: neither side may win by mtime —
                // removeItem is recursive, so the loser could be a whole tree.
                // Preserve both: the legacy item moves aside under a
                // disambiguated name (left in place if even that is taken).
                let aside = newDir.appendingPathComponent(file.lastPathComponent + ".legacy")
                if !fileManager.fileExists(atPath: aside.path) {
                    try? fileManager.moveItem(at: file, to: aside)
                }
            } else if targetExists {
                if modificationDate(of: file, fileManager) > modificationDate(of: target, fileManager) {
                    try? fileManager.removeItem(at: target)
                    try? fileManager.moveItem(at: file, to: target)
                } else {
                    try? fileManager.removeItem(at: file)
                }
            } else {
                try? fileManager.moveItem(at: file, to: target)
            }
        }

        if let remaining = try? fileManager.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil),
           remaining.isEmpty {
            try? fileManager.removeItem(at: oldDir)
        }
    }

    private static func modificationDate(of url: URL, _ fileManager: FileManager) -> Date {
        ((try? fileManager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date) ?? .distantPast
    }
}
