import Foundation
import Observation

/// Outcome of a check-in request — lets `StartCheckInIntent` pick its dialog and
/// lets a gated attempt open onboarding instead of recording (FR-022).
enum CheckInStart: Equatable {
    case started          // onboarding complete — trigger armed, app lands in Listening
    case gatedOnboarding  // onboarding incomplete — no recording; app opens to onboarding
}

/// Cross-surface trigger/navigation state (030 / D3, D4). Owns the check-in and
/// "focus My medication" triggers so an App Intent (US1/US2) and the legacy
/// `whispernotes://checkin` deep link share ONE choke point. Consumption is
/// one-shot, so a stale trigger can never re-fire.
///
/// `requestCheckIn()` is gated on onboarding (FR-022): while onboarding is
/// incomplete it arms nothing and reports `.gatedOnboarding`. The gate is read
/// live per call so both the intent and the rewired deep link (D4) are covered.
@Observable
@MainActor
final class AppIntentRouter {
    /// The tab the app should show for the pending trigger.
    var selectedTab: Tab = .calendar

    private(set) var shouldStartCheckIn = false
    private(set) var shouldFocusMyMedication = false

    /// Reads live onboarding state (`AppSettings.hasCompletedOnboarding`) at each
    /// call. Defaults to complete so plumbing tests and previews arm normally;
    /// production injects the real SwiftData read (AppDependencies).
    private let isOnboardingComplete: @MainActor () -> Bool

    init(isOnboardingComplete: @escaping @MainActor () -> Bool = { true }) {
        self.isOnboardingComplete = isOnboardingComplete
    }

    /// Arms the check-in trigger unless onboarding is incomplete (strict gate,
    /// FR-022). Returns the outcome so the caller can respond; the return is
    /// discardable for the fire-and-forget deep-link path.
    @discardableResult
    func requestCheckIn() -> CheckInStart {
        guard isOnboardingComplete() else { return .gatedOnboarding }
        selectedTab = .checkIn
        shouldStartCheckIn = true
        return .started
    }

    /// One-shot: `true` once after a check-in was requested, then clears.
    func consumeCheckIn() -> Bool {
        defer { shouldStartCheckIn = false }
        return shouldStartCheckIn
    }

    func focusMyMedication() {
        selectedTab = .settings
        shouldFocusMyMedication = true
    }

    /// One-shot: `true` once after a My-medication focus was requested, then clears.
    func consumeMyMedicationFocus() -> Bool {
        defer { shouldFocusMyMedication = false }
        return shouldFocusMyMedication
    }
}
