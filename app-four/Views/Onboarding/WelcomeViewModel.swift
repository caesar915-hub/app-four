import Foundation
import Observation
import SwiftData

/// Drives the single first-run welcome: persist that onboarding is done, then
/// signal so the cover can dismiss to the Check-in hub. Idempotent, and — per
/// FR-005 — it signals completion even when the persist write fails, so the user
/// is never stranded on an undismissable cover.
@Observable
@MainActor
final class WelcomeViewModel {

    /// Set once the welcome has done its job; the cover observes this to dismiss.
    /// True even if the persist write failed (FR-005).
    private(set) var didComplete = false

    /// Persist seam — defaults to a real `ModelContext.save()`, overridden in tests
    /// to exercise the save-failure path deterministically.
    @ObservationIgnored var persist: (ModelContext) throws -> Void = { try $0.save() }

    func complete(modelContext: ModelContext) {
        let existing = try? modelContext.fetch(FetchDescriptor<AppSettings>()).first
        if let existing {
            existing.hasCompletedOnboarding = true
        } else {
            modelContext.insert(AppSettings(hasCompletedOnboarding: true))
        }
        try? persist(modelContext)
        didComplete = true
    }
}
