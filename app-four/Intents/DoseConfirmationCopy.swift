import Foundation

/// Confirmation copy for an expedited dose log (030 / FR-005, FR-011, FR-023).
/// `named` (the "Name medication in confirmations" setting) governs every surface
/// uniformly. Never includes journal content beyond the just-logged fact (FR-021);
/// the guarded line names the earlier dose's time, never the drug.
enum DoseConfirmationCopy {
    static func text(for outcome: DoseLogOutcome, named: Bool) -> String {
        switch outcome {
        case let .logged(name, dose, at):
            let time = shortTime(at)
            return named ? "\(name) \(dose) logged · \(time)" : "Dose logged · \(time)"
        case let .guarded(activeSince):
            return "Your \(shortTime(activeSince)) dose is still active."
        case .notConfigured:
            return "Set your medication first."
        case .failed:
            return "Couldn't save that dose — nothing was logged. Try again in the app."
        }
    }

    /// System short time style (locale-aware; 24h or AM/PM per the device).
    static func shortTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
