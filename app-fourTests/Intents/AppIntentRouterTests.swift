import Testing
import Foundation
@testable import app_four

/// T005 (plumbing) + T024 (US2 / FR-022 gate). Trigger-state plumbing, one-shot
/// consumption, AND the onboarding gate. The default `AppIntentRouter()` models a
/// returning user (onboarding complete) so the plumbing tests arm the trigger; the
/// gate tests inject `isOnboardingComplete` explicitly.
@MainActor
struct AppIntentRouterTests {

    @Test func requestCheckInSetsTabAndArmsTrigger() {
        let router = AppIntentRouter()
        router.requestCheckIn()
        #expect(router.selectedTab == .checkIn)
        #expect(router.consumeCheckIn() == true)
    }

    @Test func checkInConsumptionIsOneShot() {
        let router = AppIntentRouter()
        router.requestCheckIn()
        #expect(router.consumeCheckIn() == true)   // first consume fires the auto-start
        #expect(router.consumeCheckIn() == false)  // a stale trigger can never re-fire (FR-014 spirit)
    }

    @Test func consumeCheckInWithoutRequestIsNoOp() {
        let router = AppIntentRouter()
        #expect(router.consumeCheckIn() == false)
    }

    @Test func focusMyMedicationSetsSettingsTabAndOneShotFocus() {
        let router = AppIntentRouter()
        router.focusMyMedication()
        #expect(router.selectedTab == .settings)
        #expect(router.consumeMyMedicationFocus() == true)
        #expect(router.consumeMyMedicationFocus() == false)  // one-shot
    }

    @Test func consumeMyMedicationFocusWithoutRequestIsNoOp() {
        let router = AppIntentRouter()
        #expect(router.consumeMyMedicationFocus() == false)
    }

    // MARK: - T024 (US2 / FR-022) — strict onboarding gate on the check-in trigger

    @Test func onboardingIncompleteGatesAndArmsNoTrigger() {
        let router = AppIntentRouter(isOnboardingComplete: { false })
        #expect(router.requestCheckIn() == .gatedOnboarding)
        // Strict gate: no recording is ever armed while onboarding is incomplete.
        #expect(router.consumeCheckIn() == false)
    }

    @Test func onboardingCompleteStartsAndArmsTrigger() {
        let router = AppIntentRouter(isOnboardingComplete: { true })
        #expect(router.requestCheckIn() == .started)
        #expect(router.selectedTab == .checkIn)
        #expect(router.consumeCheckIn() == true)
    }

    // The gate is re-evaluated per call (not captured once), so finishing onboarding
    // between a gated attempt and a later one flips the outcome — the choke point both
    // the intent (US2) and the legacy whispernotes://checkin URL (D4) pass through.
    @Test func gateIsReevaluatedPerCall() {
        var complete = false
        let router = AppIntentRouter(isOnboardingComplete: { complete })
        #expect(router.requestCheckIn() == .gatedOnboarding)
        complete = true
        #expect(router.requestCheckIn() == .started)
        #expect(router.consumeCheckIn() == true)
    }
}
