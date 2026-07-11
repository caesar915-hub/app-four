// CalendarAccessPresentation.swift
// Pure, stateless predicates that answer "what should the UI show?" given the
// current calendar access state and the user's prior choices about the
// invitation/explainer. No SwiftUI, no EventKit, no UserDefaults — all inputs
// are passed as parameters so the logic is unit-testable without any side effects.
//
// Spec 029 §FR-001, §FR-010, contracts/calendar-context-service.md §4.

import Foundation

/// Caseless namespace of pure, total predicates over calendar access presentation.
///
/// Every predicate is a function of:
/// - `accessState`: the live `CalendarAccessState` (`.notDetermined / .fullAccess / .writeOnly / .denied / .restricted`)
/// - `invitationDismissed`: the user permanently dismissed the Calendar-tab invitation card
/// - `explainerDeclined`: the user declined to proceed in the explainer sheet (sets `calendarExplainerDeclined`)
///
/// None of these functions read or write any storage. The call site owns state.
enum CalendarAccessPresentation {

    // MARK: - Invitation card (Calendar tab, one-time)

    /// True only when all three conditions hold:
    ///   1. Access has never been determined (system has not been asked).
    ///   2. The user has not permanently dismissed the invitation card.
    ///   3. The user has not declined the explainer.
    ///
    /// Contract §4 — "Rendered once while `!calendarInvitationDismissed &&
    /// accessState == .notDetermined && !calendarExplainerDeclined`."
    /// FR-001: one-time dismissible invitation; dismissal is permanent.
    static func shouldShowInvitationCard(
        accessState: CalendarAccessState,
        invitationDismissed: Bool,
        explainerDeclined: Bool
    ) -> Bool {
        accessState == .notDetermined && !invitationDismissed && !explainerDeclined
    }

    // MARK: - Explainer / auto-offer gating

    /// True when the app may auto-offer the explainer sheet in the main UI
    /// (i.e., the user has not yet declined it and access is still undecided).
    ///
    /// Once `explainerDeclined` is true the app MUST NOT raise the topic again
    /// unprompted (FR-010, SC-004). The user can still start over via Settings,
    /// but that is an explicit user-initiated action, not an auto-offer — so
    /// this predicate is false when explainerDeclined, regardless of access state.
    static func shouldAutoOfferExplainer(
        accessState: CalendarAccessState,
        explainerDeclined: Bool
    ) -> Bool {
        accessState == .notDetermined && !explainerDeclined
    }

    // MARK: - Denied / revoked path (Settings only)

    /// True when the system permission has been denied or restricted, meaning
    /// the only recovery path is the system Settings app.
    ///
    /// FR-010: "the Settings Calendar section MUST reflect the state and direct
    /// the user to system settings where applicable."
    /// Covers `.denied` (user explicitly denied) and `.restricted` (MDM/parental).
    /// `.writeOnly` is NOT included — the device has calendar write access but
    /// not read access; capture silently yields nothing, but this is not a
    /// denied state that warrants a Settings-redirect prompt. The Settings row
    /// still shows the access state for transparency (FR-008).
    static func showsSystemSettingsPath(accessState: CalendarAccessState) -> Bool {
        accessState == .denied || accessState == .restricted
    }

    // MARK: - Feature active

    /// True only when full read access is available and capture can run.
    ///
    /// `.writeOnly` does NOT qualify: the service cannot read events without
    /// full access (EKAuthorizationStatus.fullAccess). Treated as inactive for
    /// all capture-gating purposes.
    static func captureIsAvailable(accessState: CalendarAccessState) -> Bool {
        accessState == .fullAccess
    }

    // MARK: - Calendar affordances visible

    /// True when calendar-related affordances (context lines, capture triggers)
    /// should appear in the main UI.
    ///
    /// Identical to `captureIsAvailable` today, extracted as a named predicate
    /// so the call site reads at the right semantic altitude (UI visibility
    /// vs. capture pipeline availability).
    static func calendarAffordancesVisible(accessState: CalendarAccessState) -> Bool {
        accessState == .fullAccess
    }
}
