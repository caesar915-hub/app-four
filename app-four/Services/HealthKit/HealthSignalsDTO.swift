import Foundation

/// The single source of day identity. Normalizes any instant to the start of its
/// local day so HealthKit reads and SwiftData rows agree on "which day".
enum SignalDayKey {
    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
}

/// Sendable value types returned by `HealthDataReading`. No `HKObject` ever escapes
/// the HealthKit actor — only these. Structs of value types → automatically `Sendable`.

struct SleepDTO: Sendable, Equatable {
    var hours: Double
    var level: SleepLevel?
}

struct ActivityDTO: Sendable, Equatable {
    var steps: Int?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Int?
}

struct HeartDTO: Sendable, Equatable {
    var restingHeartRate: Double?
    var hrvSDNN: Double?
}

struct CycleDTO: Sendable, Equatable {
    var flow: MenstrualFlow?
    var symptoms: [String]
}

/// One day's worth of whatever HealthKit returned. Any field may be nil when there is
/// no sample for it that day.
struct DaySignalsDTO: Sendable, Equatable {
    var dayStart: Date
    var sleep: SleepDTO?
    var activity: ActivityDTO?
    var heart: HeartDTO?
    var cycle: CycleDTO?
}
