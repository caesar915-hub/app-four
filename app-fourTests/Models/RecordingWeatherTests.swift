import Foundation
import Testing
import SwiftData
@testable import app_four

/// T006 — `Recording` weather helpers.
@MainActor
struct RecordingWeatherTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        context = container.mainContext
    }

    @Test func freshRecordingHasNoWeather() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        #expect(r.weatherJSON == nil)
        #expect(r.decodedWeather == nil)
    }

    @Test func applyWeatherRoundTripsAndBumpsUpdatedAt() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        // Pin updatedAt to the epoch so the bump is observable without a sleep (a plain
        // `>= before` would pass even if applyWeather never wrote updatedAt — x >= x).
        let stale = Date(timeIntervalSince1970: 0)
        r.updatedAt = stale
        let snap = WeatherSnapshot(
            conditionCode: "clear", temperatureC: 18, symbolName: "sun.max",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        r.applyWeather(snap)
        #expect(r.decodedWeather == snap)
        #expect(r.updatedAt > stale)
    }
}
