import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var defaultLanguage: String
    var downloadOverCellular: Bool
    var transcriptionCount: Int = 0
    var promptPaceSeconds: Int = PromptPace.relaxed.rawValue

    // MARK: - 030 App Intents (default medication · dose guard · confirmation style)
    // All defaulted/optional, no `.unique` (Constitution IX, CloudKit-compatible).
    var defaultMedicationName: String? = nil
    var defaultMedicationDose: String? = nil
    var doseGuardModeRaw: String = "off"
    var doseGuardWindowHours: Int = 2
    var nameMedicationInConfirmations: Bool = false

    // MARK: - Two-screen onboarding (explicit model-download opt-in)
    // True only when the user tapped "Skip for Now" on the download-permission
    // screen: the launch-time background download stays off and the model
    // remains an explicit action (Settings). Defaulted, no `.unique` — same
    // lightweight-migration pattern as the 030 block above.
    var declinedOnboardingModelDownload: Bool = false

    /// Same semantics as `declinedOnboardingModelDownload`, for the insights
    /// model (LLM, ~740 MB): set only by an explicit "Skip for Now" on the
    /// onboarding insights screen; Settings remains the way back.
    var declinedOnboardingLLMDownload: Bool = false

    init(
        id: UUID = UUID(),
        hasCompletedOnboarding: Bool = false,
        defaultLanguage: String = "en",
        downloadOverCellular: Bool = false,
        transcriptionCount: Int = 0,
        promptPaceSeconds: Int = PromptPace.relaxed.rawValue
    ) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.defaultLanguage = defaultLanguage
        self.downloadOverCellular = downloadOverCellular
        self.transcriptionCount = transcriptionCount
        self.promptPaceSeconds = promptPaceSeconds
    }
}
