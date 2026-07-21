import Foundation
import SwiftData

@Model
final class AppSettings {
    // Inline defaults mirror `init` exactly. Required by Constitution IX
    // (optional-or-defaulted): a non-optional stored property with no default is NULL-able
    // in the store, and materializing such a row on `fetch` traps (research §R2).
    @Attribute(.unique) var id: UUID = UUID()
    var hasCompletedOnboarding: Bool = false
    var defaultLanguage: String = "en"
    var downloadOverCellular: Bool = false
    var transcriptionCount: Int = 0
    var promptPaceSeconds: Int = PromptPace.relaxed.rawValue

    // MARK: - 030 App Intents (default medication · dose guard · confirmation style)
    // All defaulted/optional, no `.unique` (Constitution IX, CloudKit-compatible).
    var defaultMedicationName: String? = nil
    var defaultMedicationDose: String? = nil
    var doseGuardModeRaw: String = "off"
    var doseGuardWindowHours: Int = 2
    var nameMedicationInConfirmations: Bool = false

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
