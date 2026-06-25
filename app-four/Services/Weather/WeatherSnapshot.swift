import Foundation

/// A point-in-time, immutable snapshot of outdoor conditions captured for a check-in.
/// Persisted as JSON on `Recording` (see `Recording.weatherJSON`). A pure value type —
/// not a SwiftData `@Model` — so it is `Sendable` and crosses actor boundaries freely.
/// `nonisolated` opts out of the project's default `@MainActor` isolation so its `Codable`
/// conformance is usable from any context (off-main decode, non-`@MainActor` tests).
nonisolated struct WeatherSnapshot: Codable, Sendable, Equatable {
    /// WeatherKit `WeatherCondition.rawValue` (e.g. "clear", "rain", "mostlyCloudy").
    let conditionCode: String
    /// Canonical storage unit (°C); display converts to the user's locale unit.
    let temperatureC: Double
    /// WeatherKit `currentWeather.symbolName` — an SF Symbol used for display.
    let symbolName: String
    /// When the weather was fetched (≈ check-in time). Records the moment, never refreshed.
    let capturedAt: Date

    /// Coarse grouping used for the mood↔weather correlation (and any aesthetic glyph).
    /// WeatherKit's raw cases are many and individually thin; bucketing keeps correlation honest.
    var family: WeatherFamily { WeatherFamily(conditionCode: conditionCode) }

    /// Human-readable condition from the raw camelCase code, e.g. "mostlyCloudy" → "Mostly Cloudy".
    var conditionLabel: String {
        conditionCode
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }
}

/// A small, correlation-friendly grouping of WeatherKit's many condition codes.
nonisolated enum WeatherFamily: String, CaseIterable, Sendable {
    case clear, cloudy, rain, snow, other

    /// Adjective for plain-language insights ("higher on clear days").
    var label: String {
        switch self {
        case .clear:  return "clear"
        case .cloudy: return "cloudy"
        case .rain:   return "rainy"
        case .snow:   return "snowy"
        case .other:  return "other"
        }
    }

    /// Keyword match over the raw condition code. Order matters: frozen precipitation and
    /// rain/storm are tested before "clear"/"sun" so e.g. "sunShowers" reads as rain and
    /// "sunFlurries" as snow.
    init(conditionCode: String) {
        let c = conditionCode.lowercased()
        if c.contains("snow") || c.contains("sleet") || c.contains("flurr")
            || c.contains("blizzard") || c.contains("wintry") || c.contains("hail") || c.contains("ice") {
            self = .snow
        } else if c.contains("rain") || c.contains("drizzle") || c.contains("shower")
            || c.contains("storm") || c.contains("thunder") {
            self = .rain
        } else if c.contains("cloud") || c.contains("fog") || c.contains("haz") || c.contains("smok") {
            self = .cloudy
        } else if c.contains("clear") || c.contains("sun") {
            self = .clear
        } else {
            self = .other
        }
    }
}
