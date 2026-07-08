import Foundation
import Observation

/// Cross-surface trigger/navigation state (030 / D3, D4). Owns the check-in and
/// "focus My medication" triggers so an App Intent (US1/US2) and the legacy
/// `whispernotes://checkin` deep link share ONE choke point. Consumption is
/// one-shot, so a stale trigger can never re-fire.
///
/// The onboarding gate (FR-022) is added in US2 (T026); today `requestCheckIn()`
/// always arms the trigger — plumbing only.
@Observable
@MainActor
final class AppIntentRouter {
    /// The tab the app should show for the pending trigger.
    var selectedTab: Tab = .calendar

    private(set) var shouldStartCheckIn = false
    private(set) var shouldFocusMyMedication = false

    func requestCheckIn() {
        selectedTab = .checkIn
        shouldStartCheckIn = true
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
