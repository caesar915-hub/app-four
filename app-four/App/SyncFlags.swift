import Foundation

/// Off-by-default iCloud-sync toggle (spec 038, FR-001).
///
/// Stored in `UserDefaults` — NOT in the SwiftData store — because the container reads
/// it at build time (before any store is open, so it can't come from `AppSettings`) and
/// because the flag must never itself sync across devices.
nonisolated enum SyncFlags {
    private static let iCloudSyncKey = "settings.iCloudSyncEnabled"

    /// Absent key → `false` → sync is off on a fresh install (FR-001).
    static var iCloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: iCloudSyncKey)
    }

    static func setICloudSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: iCloudSyncKey)
    }
}
