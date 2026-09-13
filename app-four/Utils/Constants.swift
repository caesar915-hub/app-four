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

    /// Base directory for the managed insights-model snapshot download. The
    /// background downloader stages files under `staging/<repoID>/` and promotes
    /// the completed snapshot to `models/<repoID>/`.
    nonisolated static let llmDownloadBase: URL = {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let base = library.appendingPathComponent("llm")
        // Legacy migration: the pre-rename download base was Library/llama. Move an
        // existing download over once so the already-downloaded model isn't re-fetched.
        let legacy = library.appendingPathComponent("llama")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: base.path),
           fileManager.fileExists(atPath: legacy.path) {
            try? fileManager.moveItem(at: legacy, to: base)
        }
        return base
    }()

    /// Insights/summarization model. Qwen2.5-1.5B-Instruct replaces
    /// Llama-3.2-1B-Instruct: the 1B Llama ignored the JSON-only output contract
    /// (replied with prose preambles → unparseable → transcript echoed as the
    /// "summary" and zero signals), while Qwen2.5 instruct models follow
    /// structured-output instructions far more reliably at a similar size.
    nonisolated static let llmHubRepoID = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"

    /// Gemma 4 E2B (text-only) via LiteRT-LM — the extraction model that supersedes
    /// Qwen2.5-1.5B/MLX (spec 056). ADDITIVE: `llmHubRepoID` above is unchanged; the
    /// switchover (repoint + DI flip) is device-gated. CPU/XNNPACK build.
    nonisolated static let gemmaLiteRTRepoID = "litert-community/gemma-4-E2B-it-litert-lm"
    nonisolated static let gemmaLiteRTFileName = "gemma-4-E2B-it.litertlm"
    nonisolated static let gemmaLiteRTExpectedBytes: Int64 = 2_588_147_712  // 2.41 GiB
}

enum SettingsKeys {
    nonisolated static let medicalPromptEnabled = "medicalPromptEnabled"
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
