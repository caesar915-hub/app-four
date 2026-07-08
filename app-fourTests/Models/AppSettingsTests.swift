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

    // MARK: - 030 App Intents: default-medication, dose-guard, confirmation-style (T003, RED until T007)

    @Test func doseIntentFieldsFreshDefaults() {
        let settings = AppSettings()
        #expect(settings.defaultMedicationName == nil)
        #expect(settings.defaultMedicationDose == nil)
        #expect(settings.doseGuardModeRaw == "off")
        #expect(settings.doseGuardWindowHours == 2)
        #expect(settings.nameMedicationInConfirmations == false)
    }

    @Test func exposesDoseIntentMembers() {
        // `@Model` backing ivars are underscore-prefixed (e.g. "_doseGuardModeRaw"),
        // so match by substring — the same tolerance `exposesNoReduceMotionMember` relies on.
        let names = Mirror(reflecting: AppSettings()).children.compactMap(\.label)
        for field in [
            "defaultMedicationName", "defaultMedicationDose",
            "doseGuardModeRaw", "doseGuardWindowHours", "nameMedicationInConfirmations",
        ] {
            #expect(names.contains { $0.localizedCaseInsensitiveContains(field) })
        }
    }
}
