import Foundation
import SwiftData

/// One row per local calendar day — the source of truth for the four health signals
/// (sleep, activity, heart, menstrual cycle). HealthKit mirrors into these fields; a
/// manual edit sets the matching group's source to `.manual`, so later syncs leave it
/// untouched.
///
/// No `@Attribute(.unique)` and every attribute optional or defaulted, to keep the
/// schema CloudKit-compatible (Constitution IX). One-row-per-day is enforced by
/// `SignalsStore.upsert` (fetch-by-day then insert), not by the schema.
@Model
final class DailySignals {
    /// Start-of-day in the user's calendar — the logical per-day key (non-unique).
    var dayStart: Date = Date.distantPast
    var updatedAt: Date = Date()

    // MARK: Sleep
    var sleepHours: Double? = nil
    /// Raw value of `SleepLevel` (restless…deep) — the named 5-step scale, not a colour ramp.
    var sleepLevelValue: String? = nil
    var sleepSource: SignalSource = SignalSource.none

    // MARK: Activity
    var steps: Int? = nil
    var activeEnergyKcal: Double? = nil
    var exerciseMinutes: Int? = nil
    var activitySource: SignalSource = SignalSource.none

    // MARK: Heart
    var restingHeartRate: Double? = nil
    var hrvSDNN: Double? = nil
    var heartSource: SignalSource = SignalSource.none

    // MARK: Menstrual cycle
    var menstrualFlow: MenstrualFlow? = nil
    /// `[String]` of symptom tags, JSON-encoded (matches the codebase `*JSON` convention;
    /// avoids a CloudKit relationship).
    var cycleSymptomsJSON: String? = nil
    var cycleSource: SignalSource = SignalSource.none

    var isMockData: Bool = false

    init(dayStart: Date) {
        self.dayStart = dayStart
        self.updatedAt = Date()
    }
}

extension DailySignals {
    /// The named sleep level, bridged over the stored raw value.
    var sleepLevel: SleepLevel? {
        get { sleepLevelValue.flatMap(SleepLevel.init(rawValue:)) }
        set { sleepLevelValue = newValue?.rawValue }
    }

    /// Symptom tags as an array, bridged over `cycleSymptomsJSON`. Empty → nil JSON.
    var cycleSymptoms: [String] {
        get {
            guard let json = cycleSymptomsJSON,
                  let data = json.data(using: .utf8),
                  let tags = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return tags
        }
        set {
            guard !newValue.isEmpty,
                  let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                cycleSymptomsJSON = nil
                return
            }
            cycleSymptomsJSON = json
        }
    }
}
