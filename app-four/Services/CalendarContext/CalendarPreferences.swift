import Foundation

/// Single source of truth for all calendar-related UserDefaults keys and
/// their typed accessors. No SwiftUI import — safe to use from any layer.
enum CalendarPreferences {

    enum Keys {
        static let calendarTitlesIncluded       = "calendarTitlesIncluded"
        static let calendarInvitationDismissed  = "calendarInvitationDismissed"
        static let calendarExplainerDeclined    = "calendarExplainerDeclined"
        static let calendarExcludedIDs          = "calendarExcludedIDs"
        static let calendarIncludedOverrideIDs  = "calendarIncludedOverrideIDs"
    }

    // MARK: - Titles

    /// Returns `true` when unset (opt-in default per FR-003).
    static func titlesIncluded() -> Bool {
        UserDefaults.standard.object(forKey: Keys.calendarTitlesIncluded) as? Bool ?? true
    }

    static func setTitlesIncluded(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Keys.calendarTitlesIncluded)
    }

    // MARK: - ID sets (JSON-encoded [String] strings)

    static func excludedIDs() -> Set<String> {
        decodeStringSet(forKey: Keys.calendarExcludedIDs)
    }

    static func setExcludedIDs(_ value: Set<String>) {
        encodeStringSet(value, forKey: Keys.calendarExcludedIDs)
    }

    static func includedOverrideIDs() -> Set<String> {
        decodeStringSet(forKey: Keys.calendarIncludedOverrideIDs)
    }

    static func setIncludedOverrideIDs(_ value: Set<String>) {
        encodeStringSet(value, forKey: Keys.calendarIncludedOverrideIDs)
    }

    // MARK: - Composed settings

    static func currentSettings() -> CalendarCaptureSettings {
        CalendarCaptureSettings(
            titlesIncluded: titlesIncluded(),
            excludedIDs: excludedIDs(),
            includedOverrideIDs: includedOverrideIDs()
        )
    }

    // MARK: - Private helpers

    private static func decodeStringSet(forKey key: String) -> Set<String> {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let data = raw.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(array)
    }

    private static func encodeStringSet(_ value: Set<String>, forKey key: String) {
        let array = Array(value)
        if let data = try? JSONEncoder().encode(array),
           let raw = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }
}
