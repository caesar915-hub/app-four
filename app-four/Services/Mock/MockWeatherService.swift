import Foundation

/// Mock weather service for previews and tests. Returns `snapshot` (a fixed clear-sky value
/// by default) so the happy path is deterministic; set it to `nil` to exercise the
/// best-effort no-weather path. `@unchecked Sendable` mirrors `MockExportService` — the
/// mutable `snapshot` is only touched from the test's `@MainActor`.
final class MockWeatherService: WeatherService, @unchecked Sendable {
    var snapshot: WeatherSnapshot?

    init(snapshot: WeatherSnapshot? = WeatherSnapshot(
        conditionCode: "clear",
        temperatureC: 21,
        symbolName: "sun.max",
        capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )) {
        self.snapshot = snapshot
    }

    func currentSnapshot() async -> WeatherSnapshot? { snapshot }
}
