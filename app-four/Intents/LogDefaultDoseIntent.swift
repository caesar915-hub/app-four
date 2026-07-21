import AppIntents
import Foundation

/// 030 / US1 — "Log My Meds": records the default medication dose without opening
/// the app (FR-003..FR-007). Thin translation over `DoseLogService`; every domain
/// rule (settings resolution, catalog re-validation, guard, write) lives in the
/// service (Constitution VIII — an intent cannot depend on a view model).
struct LogDefaultDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Log My Meds"
    static let description = IntentDescription(
        "Logs your default medication dose. Set the medication once in Squirl's settings."
    )
    /// Background by default; `.dynamic` foreground serves only the not-configured
    /// path (D2 rev. — `openAppWhenRun`/`ForegroundContinuableIntent` are deprecated
    /// on the iOS 26 target).
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]
    /// The platform default, declared as documented intent: locked Siri works;
    /// worst case is journal pollution, nothing is read back (D8).
    static let authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed
    /// 1.0 ships hands-free logging hidden (no AppShortcutsProvider, not
    /// discoverable in Shortcuts/Spotlight) pending its S1–S10 device QA.
    /// Revert the hide-handsfree commit to restore the full surface.
    static let isDiscoverable = false

    @AppDependency private var service: any DoseLogService
    @AppDependency private var router: AppIntentRouter

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = await service.logDefaultDose(now: .now)
        let named = await service.namesMedicationInConfirmations()
        let line = DoseConfirmationCopy.text(for: outcome, named: named)
        let dialog = IntentDialog(full: "\(line)", supporting: "\(line)")

        if case .notConfigured = outcome {
            // FR-007: offer to finish setup. A declined or impossible transition
            // (locked device, background-only context) leaves the calm dialog
            // standing — never an error surface.
            do {
                try await continueInForeground(dialog, alwaysConfirm: true)
                router.focusMyMedication()
            } catch {}
        }
        return .result(dialog: dialog)
    }
}
