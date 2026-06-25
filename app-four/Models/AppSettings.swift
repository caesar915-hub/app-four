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
