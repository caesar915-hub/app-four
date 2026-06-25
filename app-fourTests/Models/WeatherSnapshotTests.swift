import Foundation
import Testing
@testable import app_four

/// T005 — value-type contract for the per-entry weather snapshot.
struct WeatherSnapshotTests {

    private func snap(_ code: String) -> WeatherSnapshot {
        WeatherSnapshot(conditionCode: code, temperatureC: 0, symbolName: "", capturedAt: Date())
    }

    @Test func codableRoundTripsLosslessly() throws {
        let original = WeatherSnapshot(
            conditionCode: "rain", temperatureC: 12.5, symbolName: "cloud.rain",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeatherSnapshot.self, from: data)
        #expect(decoded == original)
    }

    @Test func conditionLabelHumanizesCamelCase() {
        #expect(snap("rain").conditionLabel == "Rain")
        #expect(snap("mostlyCloudy").conditionLabel == "Mostly Cloudy")
        #expect(snap("heavyRain").conditionLabel == "Heavy Rain")
        #expect(snap("clear").conditionLabel == "Clear")
    }

    @Test func familyMapsRepresentativeCodes() {
        #expect(snap("clear").family == .clear)
        #expect(snap("mostlyClear").family == .clear)
        #expect(snap("partlyCloudy").family == .cloudy)
        #expect(snap("foggy").family == .cloudy)
        #expect(snap("rain").family == .rain)
        #expect(snap("heavyRain").family == .rain)
        #expect(snap("thunderstorms").family == .rain)
        #expect(snap("sunShowers").family == .rain)   // "shower" beats "sun"
        #expect(snap("snow").family == .snow)
        #expect(snap("blizzard").family == .snow)
        #expect(snap("sunFlurries").family == .snow)   // "flurr" beats "sun"
        #expect(snap("windy").family == .other)
    }
}
