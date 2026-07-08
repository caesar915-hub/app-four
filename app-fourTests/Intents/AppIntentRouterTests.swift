import Testing
import Foundation
@testable import app_four

/// T005 (030 / FR-013, FR-022 plumbing) — RED until `AppIntentRouter` exists (T009).
/// Scope: trigger-state plumbing and one-shot consumption ONLY. The onboarding
/// gate (FR-022) is US2 / T024 and is deliberately not exercised here — a fresh
/// router with no gate always arms the check-in trigger.
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
}
