import Testing
import Foundation
@testable import app_four

/// T013 (030 / FR-005, FR-011, FR-023) — confirmation copy matrix.
/// Time assertions compute the expected string via the same formatter, so they
/// hold under any locale / 12h-24h setting.
struct ConfirmationCopyTests {

    private let at = Date(timeIntervalSince1970: 1_700_000_000)
    private var time: String { DoseConfirmationCopy.shortTime(at) }

    // MARK: - Logged × named/discreet

    @Test func loggedDiscreetHidesMedication() {
        let copy = DoseConfirmationCopy.text(for: .logged(name: "Elvanse", dose: "30 mg", at: at), named: false)
        #expect(copy == "Dose logged · \(time)")
        #expect(!copy.localizedCaseInsensitiveContains("Elvanse"))
    }

    @Test func loggedNamedShowsMedicationAndDose() {
        let copy = DoseConfirmationCopy.text(for: .logged(name: "Elvanse", dose: "30 mg", at: at), named: true)
        #expect(copy == "Elvanse 30 mg logged · \(time)")
    }

    // MARK: - Guarded names the time, never the drug (both settings)

    @Test func guardedNamesTimeNeverDrug() {
        for named in [false, true] {
            let copy = DoseConfirmationCopy.text(for: .guarded(activeSince: at), named: named)
            #expect(copy == "Your \(time) dose is still active.")
            #expect(copy.contains(time))
            #expect(!copy.localizedCaseInsensitiveContains("Elvanse"))
            #expect(!copy.localizedCaseInsensitiveContains("mg"))
        }
    }

    // MARK: - Not configured (same both settings)

    @Test func notConfiguredIsIdenticalRegardlessOfNaming() {
        let discreet = DoseConfirmationCopy.text(for: .notConfigured, named: false)
        let named = DoseConfirmationCopy.text(for: .notConfigured, named: true)
        #expect(discreet == "Set your medication first.")
        #expect(discreet == named)
    }

    // MARK: - Failed (same both settings; honest, calm, actionable — SC-007)

    @Test func failedIsIdenticalCalmAndNamesNothing() {
        let discreet = DoseConfirmationCopy.text(for: .failed, named: false)
        let named = DoseConfirmationCopy.text(for: .failed, named: true)
        #expect(discreet == "Couldn't save that dose — nothing was logged. Try again in the app.")
        #expect(discreet == named)
        #expect(!discreet.localizedCaseInsensitiveContains("Elvanse"))
    }

    // MARK: - Matrix is non-empty and distinct where it should be

    @Test func discreetAndNamedLoggedDiffer() {
        let discreet = DoseConfirmationCopy.text(for: .logged(name: "Concerta", dose: "36 mg", at: at), named: false)
        let named = DoseConfirmationCopy.text(for: .logged(name: "Concerta", dose: "36 mg", at: at), named: true)
        #expect(discreet != named)
        #expect(!discreet.isEmpty && !named.isEmpty)
    }

    // MARK: - shortTime itself is time-shaped (FR-005)

    /// The matrix tests derive their expected strings through `shortTime`, so a
    /// regression inside the formatter (e.g. `.shortened` → `.omitted`) would match
    /// on both sides and stay green. This pins the output's shape independently.
    @Test func shortTimeIsNonEmptyAndContainsDigits() {
        let t = DoseConfirmationCopy.shortTime(at)
        #expect(!t.isEmpty)
        #expect(t.contains(where: { $0.isNumber }))
    }
}
