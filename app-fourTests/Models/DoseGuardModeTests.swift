import Testing
import Foundation
@testable import app_four

/// T004 (030 / FR-008, FR-012) — RED until `DoseGuardMode` exists (T008).
/// Pins the two responsibilities the guard enum owns: forward-safe raw decode
/// and the boundary-closed block decision. Guard evaluation reuses the shipped
/// `MedicationEvent.isActive(at:)` semantics (`effectProgress < 1`, strict `<`).
struct DoseGuardModeTests {

    // MARK: - Forward-safe raw decode

    @Test func decodesKnownRawValues() {
        #expect(DoseGuardMode(raw: "off") == .off)
        #expect(DoseGuardMode(raw: "total") == .total)
        #expect(DoseGuardMode(raw: "window") == .window)
    }

    @Test func unknownRawDecodesToOff() {
        #expect(DoseGuardMode(raw: "") == .off)
        #expect(DoseGuardMode(raw: "someFutureMode") == .off)
    }

    // MARK: - Off mode + missing previous dose never block

    @Test func offNeverBlocks() {
        let dose = MedicationEvent(name: "Elvanse", takenAt: Date())
        #expect(DoseGuardMode.off.blocksLog(previousDose: dose, windowHours: 2, now: Date()) == false)
    }

    @Test func noPreviousDoseNeverBlocks() {
        let now = Date()
        #expect(DoseGuardMode.total.blocksLog(previousDose: nil, windowHours: 2, now: now) == false)
        #expect(DoseGuardMode.window.blocksLog(previousDose: nil, windowHours: 2, now: now) == false)
    }

    // MARK: - Window mode: blocked before the boundary, open at exactly the end (FR-012)

    @Test func windowBlocksInsideAndOpensAtExactEnd() {
        let now = Date()
        let dose = MedicationEvent(name: "Elvanse", takenAt: now.addingTimeInterval(-2 * 3600))
        // exactly 2h elapsed, 2h window → boundary closed → allowed
        #expect(DoseGuardMode.window.blocksLog(previousDose: dose, windowHours: 2, now: now) == false)
        // only 2h elapsed against a 3h window → still inside → blocked
        #expect(DoseGuardMode.window.blocksLog(previousDose: dose, windowHours: 3, now: now) == true)
    }

    @Test func windowIgnoresEffectDurationUsesElapsedTime() {
        let now = Date()
        // 1h ago, short 3h Ritalin duration is irrelevant to window mode — window is purely time-since-dose
        let dose = MedicationEvent(name: "Ritalin", takenAt: now.addingTimeInterval(-1 * 3600), durationHours: 3)
        #expect(DoseGuardMode.window.blocksLog(previousDose: dose, windowHours: 4, now: now) == true)
    }

    // MARK: - Total mode: blocked while active, open at exactly effect end (matches isActive)

    @Test func totalBlocksWhileActive() {
        let now = Date()
        let active = MedicationEvent(name: "Elvanse", takenAt: now.addingTimeInterval(-2 * 3600), durationHours: 10)
        #expect(DoseGuardMode.total.blocksLog(previousDose: active, windowHours: 2, now: now) == true)
    }

    @Test func totalOpensAtExactEffectEnd() {
        let now = Date()
        // taken 4h ago with an (edited) 4h duration → effect ends exactly now → not active → allowed
        let ended = MedicationEvent(name: "Ritalin", takenAt: now.addingTimeInterval(-4 * 3600), durationHours: 4)
        #expect(DoseGuardMode.total.blocksLog(previousDose: ended, windowHours: 2, now: now) == false)
    }

    @Test func totalRespectsEditedDurationNotCatalogDefault() {
        let now = Date()
        // Ritalin catalog default is 3h, but this event was edited to 8h → still active at 5h
        let edited = MedicationEvent(name: "Ritalin", takenAt: now.addingTimeInterval(-5 * 3600), durationHours: 8)
        #expect(DoseGuardMode.total.blocksLog(previousDose: edited, windowHours: 1, now: now) == true)
    }
}
