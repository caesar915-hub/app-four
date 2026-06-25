import Testing
import Foundation
@testable import app_four

/// US1 (017): `AppSettings.reduceMotionEnabled` was an orphaned store — never read,
/// never written. The screen now honors iOS Reduce Motion only. A fresh `AppSettings`
/// must carry the remaining defaults and expose no `reduceMotionEnabled` member.
struct AppSettingsTests {

    @Test func freshDefaults() {
        let settings = AppSettings()
        #expect(settings.hasCompletedOnboarding == false)
        #expect(settings.defaultLanguage == "en")
        #expect(settings.downloadOverCellular == false)
        #expect(settings.transcriptionCount == 0)
        #expect(settings.promptPaceSeconds == PromptPace.relaxed.rawValue)
    }

    @Test func exposesNoReduceMotionMember() {
        let names = Mirror(reflecting: AppSettings()).children.compactMap(\.label)
        #expect(!names.contains { $0.localizedCaseInsensitiveContains("reduceMotion") })
    }
}
