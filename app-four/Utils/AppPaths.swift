import Foundation

/// Single source of truth for the app's private on-device storage.
///
/// Health audio, transcript exports, and diagnostics live under Application
/// Support — never `Documents` — so they are invisible to the Files app and
/// iTunes/Finder file sharing, and the whole subtree is excluded from iCloud
/// backup. This is what backs the app's "nothing leaves the device" guarantee.
enum AppPaths {
    /// App-private root, excluded from iCloud backup.
    static let privateRoot: URL = {
        let base = URL.applicationSupportDirectory.appendingPathComponent("SquirlData", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        excludeFromBackup(base)
        return base
    }()

    static let recordings = subdirectory("Recordings")
    static let exports = subdirectory("Exports")
    static let diagnostics = subdirectory("Diagnostics")

    private static func subdirectory(_ name: String) -> URL {
        let url = privateRoot.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
