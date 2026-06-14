import Foundation

enum AudioConstants {
    static let sampleRate: Int = 16000
    static let channels: Int = 1
    static let formatLabel: String = "16 kHz • M4A"
}

enum LayoutConstants {
    static let maxRecordingDuration: TimeInterval = 480 // 8 minutes
    static let minDiskSpaceForRecordingBytes: Int64 = 50 * 1024 * 1024 // 50 MB
}

enum ModelConstants {
    nonisolated static let whisperDownloadBase: URL = {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("whisperkit")
    }()
}

enum SettingsKeys {
    static let medicalPromptEnabled = "medicalPromptEnabled"
}

extension UserDefaults {
    /// Whether the medical-context prompt biases Whisper. Defaults to `true` so the
    /// prompt stays on for existing users until they explicitly opt out in Settings.
    /// `nonisolated` because `UserDefaults` is thread-safe and the transcription actor
    /// reads this off the main actor.
    nonisolated var medicalPromptEnabled: Bool {
        get { object(forKey: SettingsKeys.medicalPromptEnabled) as? Bool ?? true }
        set { set(newValue, forKey: SettingsKeys.medicalPromptEnabled) }
    }
}
