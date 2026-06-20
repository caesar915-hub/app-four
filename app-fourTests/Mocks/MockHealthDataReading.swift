import Foundation
@testable import app_four

/// Test double for `HealthDataReading`. An `actor` (not `@unchecked Sendable`) so it is
/// genuinely data-race-safe: stubs are set and the call count read via the actor.
actor MockHealthDataReading: HealthDataReading {
    private var state: HealthAuthorizationState
    private var signals: [DaySignalsDTO]
    private(set) var readCallCount = 0
    /// The range passed to the most recent `readSignals` call — lets tests assert the
    /// window the coordinator requested.
    private(set) var lastRequestedRange: (start: Date, end: Date)?

    init(state: HealthAuthorizationState = .authorized, signals: [DaySignalsDTO] = []) {
        self.state = state
        self.signals = signals
    }

    func setState(_ state: HealthAuthorizationState) { self.state = state }
    func setSignals(_ signals: [DaySignalsDTO]) { self.signals = signals }

    func authorizationState() async -> HealthAuthorizationState { state }
    func requestAuthorization() async throws -> HealthAuthorizationState { state }
    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO] {
        readCallCount += 1
        lastRequestedRange = (startDay, endDay)
        return signals
    }
}
