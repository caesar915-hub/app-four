import Foundation

/// The result of an expedited dose log (030 / FR-003..FR-012). Maps 1:1 to the
/// intent's confirmation dialogs via `DoseConfirmationCopy`.
enum DoseLogOutcome: Equatable, Sendable {
    /// Event written and saved.
    case logged(name: String, dose: String, at: Date)
    /// Nothing written — a guard blocked it; carries the earlier dose's time for the calm message.
    case guarded(activeSince: Date)
    /// Nothing written — no usable default medication is configured.
    case notConfigured
    /// Nothing durably written — dose history was unreadable while a guard was armed
    /// (fails closed, SC-005) or the save itself failed (SC-007). Always safe to retry.
    case failed
}

/// Records a dose of the user's default medication without opening the app.
/// The single owner of settings resolution, catalog re-validation, guard evaluation,
/// and the event write (Constitution VIII — an intent cannot depend on a view model).
protocol DoseLogService {
    func logDefaultDose(now: Date) async -> DoseLogOutcome
}
