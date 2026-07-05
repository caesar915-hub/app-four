import Foundation
@testable import app_four

/// Test double for `HealthDataReading`. An `actor` (not `@unchecked Sendable`) so it is
/// genuinely data-race-safe: stubs are set and the call count read via the actor.
actor MockHealthDataReading: HealthDataReading {
    private var state: HealthAuthorizationState
    private var signals: [DaySignalsDTO]
    private var nutritionEvents: [NutritionEventDTO]
    private(set) var readCallCount = 0
    private(set) var nutritionReadCallCount = 0
    /// The range passed to the most recent `readSignals` call — lets tests assert the
    /// window the coordinator requested.
    private(set) var lastRequestedRange: (start: Date, end: Date)?

    init(state: HealthAuthorizationState = .authorized,
         signals: [DaySignalsDTO] = [],
         nutritionEvents: [NutritionEventDTO] = []) {
        self.state = state
        self.signals = signals
        self.nutritionEvents = nutritionEvents
    }

    func setState(_ state: HealthAuthorizationState) { self.state = state }
    func setSignals(_ signals: [DaySignalsDTO]) { self.signals = signals }
    func setNutritionEvents(_ events: [NutritionEventDTO]) { self.nutritionEvents = events }

    func authorizationState() async -> HealthAuthorizationState { state }
    func requestAuthorization() async throws -> HealthAuthorizationState { state }
    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO] {
        readCallCount += 1
        lastRequestedRange = (startDay, endDay)
        return signals
    }
    func readNutritionEvents(from startDay: Date, to endDay: Date) async throws -> [NutritionEventDTO] {
        nutritionReadCallCount += 1
        // Only events whose day falls in range (mirrors the real reader's per-day walk).
        return nutritionEvents.filter { $0.startDate >= startDay && $0.startDate < endDay.addingTimeInterval(86400) }
    }
}
