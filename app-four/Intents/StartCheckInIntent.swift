import AppIntents
import Foundation

/// 030 / US2 — "Check In": foregrounds Squirl straight into an active voice check-in
/// (FR-013/FR-014). Thin translation over `AppIntentRouter`; the onboarding gate
/// (FR-022) and the one-shot auto-start plumbing live in the router — the intent
/// only foregrounds and picks a dialog.
struct StartCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Check In"
    static let description = IntentDescription(
        "Opens Squirl and starts a voice check-in, recording right away."
    )
    /// Foreground: the system foregrounds the app before `perform()` (D2 rev. —
    /// deprecated `openAppWhenRun`/`ForegroundContinuableIntent` are banned on the
    /// iOS 26 target). Default auth policy — foregrounding requires unlock (D8), which
    /// the guide copy sets as expected behavior.
    static let supportedModes: IntentModes = .foreground

    @AppDependency private var router: AppIntentRouter

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch router.requestCheckIn() {
        case .started:
            // Trigger armed; the existing consumeAutoStart() chain lands the app in
            // Listening with recording active (FR-013), no-op if already recording (FR-014).
            return .result(dialog: "Starting your check-in.")
        case .gatedOnboarding:
            // FR-022: nothing recorded; the app is already foregrounded and shows
            // onboarding — the dialog just names why.
            return .result(dialog: "Finish setting up Squirl first.")
        }
    }
}
