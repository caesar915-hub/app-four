import Foundation

/// Dose-guard state (030 / FR-008..FR-012). Non-persisted; stored on `AppSettings`
/// as `doseGuardModeRaw`. Governs expedited (sticker/voice/Shortcuts) logs only —
/// the in-app Log Dose sheet never consults it.
enum DoseGuardMode: String, CaseIterable, Sendable {
    case off
    case total
    case window

    /// Forward-safe decode: an unrecognized persisted raw value degrades to `.off`.
    init(raw: String) {
        self = DoseGuardMode(rawValue: raw) ?? .off
    }

    /// Whether an expedited log must be BLOCKED given the most recent dose event.
    /// Boundary closed (FR-012): at exactly window-end / effect-end the guard opens.
    /// - `total` reuses the shipped `MedicationEvent.isActive(at:)` (`effectProgress < 1`),
    ///   so it honors a per-event edited duration, not the catalog default.
    /// - `window` is purely time-since-dose, independent of effect duration.
    func blocksLog(previousDose: MedicationEvent?, windowHours: Int, now: Date) -> Bool {
        guard let previousDose else { return false }
        switch self {
        case .off:
            return false
        case .total:
            return previousDose.isActive(at: now)
        case .window:
            return now.timeIntervalSince(previousDose.takenAt) < Double(windowHours) * 3600
        }
    }
}
