import Testing
@testable import app_four

// MARK: - CalendarAccessPresentation tests
//
// Covers every predicate in `CalendarAccessPresentation` across the full
// state × flag matrix that the spec and contract care about.
// Spec 029 §FR-001, §FR-010, §US2 acceptance; contracts §4.

struct CalendarAccessPresentationTests {

    // MARK: - shouldShowInvitationCard

    // The ONE combination that must be true.
    @Test func invitationCard_visibleWhenNotDeterminedAndNotDismissedAndNotDeclined() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .notDetermined,
                invitationDismissed: false,
                explainerDeclined: false
            ) == true
        )
    }

    // Dismissed flag suppresses the card even when everything else qualifies.
    @Test func invitationCard_hiddenWhenDismissed() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .notDetermined,
                invitationDismissed: true,
                explainerDeclined: false
            ) == false
        )
    }

    // Declined flag suppresses the card — user already said no once.
    @Test func invitationCard_hiddenWhenExplainerDeclined() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .notDetermined,
                invitationDismissed: false,
                explainerDeclined: true
            ) == false
        )
    }

    // Both flags set — still false.
    @Test func invitationCard_hiddenWhenDismissedAndDeclined() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .notDetermined,
                invitationDismissed: true,
                explainerDeclined: true
            ) == false
        )
    }

    // Every non-notDetermined state hides the card regardless of flags.
    @Test func invitationCard_hiddenWhenFullAccess() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .fullAccess,
                invitationDismissed: false,
                explainerDeclined: false
            ) == false
        )
    }

    @Test func invitationCard_hiddenWhenWriteOnly() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .writeOnly,
                invitationDismissed: false,
                explainerDeclined: false
            ) == false
        )
    }

    @Test func invitationCard_hiddenWhenDenied() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .denied,
                invitationDismissed: false,
                explainerDeclined: false
            ) == false
        )
    }

    @Test func invitationCard_hiddenWhenRestricted() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .restricted,
                invitationDismissed: false,
                explainerDeclined: false
            ) == false
        )
    }

    // MARK: - shouldAutoOfferExplainer

    // Auto-offer is on only when notDetermined and not yet declined.
    @Test func autoOfferExplainer_trueWhenNotDeterminedAndNotDeclined() {
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .notDetermined,
                explainerDeclined: false
            ) == true
        )
    }

    // Declined blocks auto-offer permanently (FR-010 / SC-004 — zero re-prompts).
    @Test func autoOfferExplainer_falseWhenDeclined() {
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .notDetermined,
                explainerDeclined: true
            ) == false
        )
    }

    // Access already resolved — nothing to offer.
    @Test func autoOfferExplainer_falseWhenFullAccess() {
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .fullAccess,
                explainerDeclined: false
            ) == false
        )
    }

    @Test func autoOfferExplainer_falseWhenDenied() {
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .denied,
                explainerDeclined: false
            ) == false
        )
    }

    @Test func autoOfferExplainer_falseWhenRestricted() {
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .restricted,
                explainerDeclined: false
            ) == false
        )
    }

    @Test func autoOfferExplainer_falseWhenWriteOnly() {
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .writeOnly,
                explainerDeclined: false
            ) == false
        )
    }

    // Declined + non-notDetermined: still false (both conditions failing independently).
    @Test func autoOfferExplainer_falseWhenDeniedAndDeclined() {
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .denied,
                explainerDeclined: true
            ) == false
        )
    }

    // MARK: - showsSystemSettingsPath

    // denied and restricted are the two states that warrant a Settings-redirect prompt.
    @Test func systemSettingsPath_trueWhenDenied() {
        #expect(CalendarAccessPresentation.showsSystemSettingsPath(accessState: .denied) == true)
    }

    @Test func systemSettingsPath_trueWhenRestricted() {
        #expect(CalendarAccessPresentation.showsSystemSettingsPath(accessState: .restricted) == true)
    }

    // Not-denied states should NOT show a Settings redirect.
    @Test func systemSettingsPath_falseWhenNotDetermined() {
        #expect(CalendarAccessPresentation.showsSystemSettingsPath(accessState: .notDetermined) == false)
    }

    @Test func systemSettingsPath_falseWhenFullAccess() {
        #expect(CalendarAccessPresentation.showsSystemSettingsPath(accessState: .fullAccess) == false)
    }

    // writeOnly has partial access — not a denied state; no Settings redirect.
    @Test func systemSettingsPath_falseWhenWriteOnly() {
        #expect(CalendarAccessPresentation.showsSystemSettingsPath(accessState: .writeOnly) == false)
    }

    // MARK: - captureIsAvailable

    @Test func captureAvailable_onlyForFullAccess() {
        #expect(CalendarAccessPresentation.captureIsAvailable(accessState: .fullAccess) == true)
    }

    @Test func captureAvailable_falseWhenNotDetermined() {
        #expect(CalendarAccessPresentation.captureIsAvailable(accessState: .notDetermined) == false)
    }

    @Test func captureAvailable_falseWhenWriteOnly() {
        #expect(CalendarAccessPresentation.captureIsAvailable(accessState: .writeOnly) == false)
    }

    @Test func captureAvailable_falseWhenDenied() {
        #expect(CalendarAccessPresentation.captureIsAvailable(accessState: .denied) == false)
    }

    @Test func captureAvailable_falseWhenRestricted() {
        #expect(CalendarAccessPresentation.captureIsAvailable(accessState: .restricted) == false)
    }

    // MARK: - calendarAffordancesVisible

    @Test func affordancesVisible_onlyForFullAccess() {
        #expect(CalendarAccessPresentation.calendarAffordancesVisible(accessState: .fullAccess) == true)
    }

    @Test func affordancesVisible_falseWhenNotDetermined() {
        #expect(CalendarAccessPresentation.calendarAffordancesVisible(accessState: .notDetermined) == false)
    }

    @Test func affordancesVisible_falseWhenDenied() {
        #expect(CalendarAccessPresentation.calendarAffordancesVisible(accessState: .denied) == false)
    }

    @Test func affordancesVisible_falseWhenRestricted() {
        #expect(CalendarAccessPresentation.calendarAffordancesVisible(accessState: .restricted) == false)
    }

    @Test func affordancesVisible_falseWhenWriteOnly() {
        #expect(CalendarAccessPresentation.calendarAffordancesVisible(accessState: .writeOnly) == false)
    }

    // MARK: - Cross-predicate invariants

    // FR-010: when explainerDeclined, no auto-offer fires for any access state.
    @Test func invariant_declinedBlocksAutoOfferAcrossAllStates() {
        let allStates: [CalendarAccessState] = [.notDetermined, .fullAccess, .writeOnly, .denied, .restricted]
        for state in allStates {
            #expect(
                CalendarAccessPresentation.shouldAutoOfferExplainer(
                    accessState: state,
                    explainerDeclined: true
                ) == false,
                "explainerDeclined must block auto-offer for state \(state)"
            )
        }
    }

    // Invitation card is a strict subset of auto-offer conditions.
    // If invitation card is visible, auto-offer must also be true.
    @Test func invariant_invitationCardImpliesAutoOffer() {
        let cardVisible = CalendarAccessPresentation.shouldShowInvitationCard(
            accessState: .notDetermined,
            invitationDismissed: false,
            explainerDeclined: false
        )
        let autoOffer = CalendarAccessPresentation.shouldAutoOfferExplainer(
            accessState: .notDetermined,
            explainerDeclined: false
        )
        if cardVisible {
            #expect(autoOffer == true)
        }
    }

    // SC-004: denied/revoked = zero calendar affordances in main UI.
    @Test func invariant_deniedOrRestrictedShowsNoAffordances() {
        let deniedStates: [CalendarAccessState] = [.denied, .restricted]
        for state in deniedStates {
            #expect(
                CalendarAccessPresentation.calendarAffordancesVisible(accessState: state) == false,
                "No affordances for denied/restricted state \(state)"
            )
            #expect(
                CalendarAccessPresentation.shouldShowInvitationCard(
                    accessState: state,
                    invitationDismissed: false,
                    explainerDeclined: false
                ) == false,
                "No invitation card for denied/restricted state \(state)"
            )
        }
    }

    // fullAccess: no entry affordances (invitation/auto-offer) — already in.
    @Test func invariant_fullAccessShowsNoEntryAffordances() {
        #expect(
            CalendarAccessPresentation.shouldShowInvitationCard(
                accessState: .fullAccess,
                invitationDismissed: false,
                explainerDeclined: false
            ) == false
        )
        #expect(
            CalendarAccessPresentation.shouldAutoOfferExplainer(
                accessState: .fullAccess,
                explainerDeclined: false
            ) == false
        )
    }
}
