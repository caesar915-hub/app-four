import Foundation
import Testing
import SwiftData
@testable import app_four

/// T023 — Weather × mood correlation: bucketing, best/worst selection, and gating.
@MainActor
struct InsightsWeatherTests {
    let container: ModelContainer
    let context: ModelContext
    let store: RecordingStore
    let month = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!

    init() throws {
        TestSupport.useRealData()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, MedicationEvent.self, AppSettings.self, configurations: config)
        context = container.mainContext
        store = RecordingStore(context: context)
    }

    @discardableResult
    private func add(day: Int, mood: String, condition: String) -> Recording {
        let date = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: day, hour: 10))!
        let r = Recording(createdAt: date, audioFileName: "r.m4a", mood: mood)
        r.applyWeather(WeatherSnapshot(conditionCode: condition, temperatureC: 15, symbolName: "x", capturedAt: date))
        context.insert(r)
        try? context.save(); store.loadRecordings()
        return r
    }

    private func vm() -> InsightsViewModel {
        let v = InsightsViewModel(store: store); v.currentMonth = month; return v
    }

    private var weather: Connection { vm().connections[3] }

    @Test func gatedBelowFiveWeatheredEntries() {
        add(day: 1, mood: "good", condition: "clear")
        add(day: 2, mood: "low", condition: "rain")
        guard case .gated = weather.state else { Issue.record("expected gated weather×mood"); return }
        #expect(vm().weatherCorrelationShown == false) // attribution stays hidden while gated
    }

    @Test func gatedWhenOnlyOneFamilyDespiteEnoughEntries() {
        for d in 1...5 { add(day: d, mood: "good", condition: "clear") }
        guard case .gated = weather.state else { Issue.record("expected gated — single family"); return }
    }

    @Test func unlocksAndRanksClearAboveRain() {
        // Clear days: great (mood 5). Rainy days: low (mood 2). 5 entries, 2 families.
        for d in 1...3 { add(day: d, mood: "great", condition: "clear") }
        for d in 4...5 { add(day: d, mood: "low", condition: "rain") }
        guard case let .unlocked(sentence, fraction, _, leading, trailing) = weather.state else {
            Issue.record("expected unlocked weather×mood"); return
        }
        #expect(sentence.contains("highest on clear"))
        #expect(sentence.contains("lowest on rainy"))
        #expect(leading == "Clear days")
        #expect(trailing == "Rainy days")
        #expect(abs(fraction - 1.0) < 0.0001) // clear avg = great = 5/5
        #expect(vm().weatherCorrelationShown == true) // attribution surfaces when unlocked
    }

    @Test func tieBreaksDeterministicallyByLabel() {
        // Two families with equal average mood (both "good" = 3). best/worst must still
        // resolve to distinct families via the label tie-break, not crash or collapse.
        for d in 1...3 { add(day: d, mood: "good", condition: "clear") }
        for d in 4...6 { add(day: d, mood: "good", condition: "rain") }
        guard case let .unlocked(_, _, _, leading, trailing) = weather.state else {
            Issue.record("expected unlocked weather×mood"); return
        }
        #expect(leading != trailing)
    }
}
