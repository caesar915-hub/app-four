import Foundation

/// Authorization status we care about, decoupled from `HKAuthorizationStatus` so callers
/// never import HealthKit.
enum HealthAuthorizationState: Sendable {
    case notDetermined
    case denied
    case authorized
    case unavailable   // HealthKit not available on this device
}

/// The only seam to Apple Health. Implemented by an actor that imports HealthKit;
/// mocked in tests. Returns Sendable DTOs only — never `HKObject`s.
///
/// Note: HealthKit deliberately does not expose READ authorization status, so
/// `authorizationState()` reports `.authorized` whenever data is available and reads
/// simply return empty when access was denied (denial is indistinguishable from
/// "no data").
protocol HealthDataReading: Sendable {
    func authorizationState() async -> HealthAuthorizationState
    func requestAuthorization() async throws -> HealthAuthorizationState
    /// Reads all four signals for each day in `[startDay, endDay]` inclusive. Days with
    /// no samples are omitted or returned with nil fields. Never throws for "no data".
    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO]
}
