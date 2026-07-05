import Foundation
import SwiftData

/// Discriminates the two timeline event types sharing one model (spec 031). String-raw
/// and bridged like `SignalSource`, so the stored attribute stays CloudKit-friendly.
enum NutritionEventKind: String, Codable, Sendable {
    case food
    case exercise
}

/// One food or exercise event at a point in time — a first-class entry on the day
/// card's unfolded timeline (spec 031). Standalone: no relationships; a day's events
/// are joined by `startDate` range via `SignalDayKey`.
///
/// Every attribute optional or defaulted, no `@Attribute(.unique)` (Constitution IX /
/// CloudKit-compatible). Re-sync dedup is replace-per-day in `SignalsStore`, not schema.
@Model
final class NutritionEvent {
    /// Event time — drives timeline position and day membership (23:58 belongs to that day).
    var startDate: Date = Date.distantPast
    /// Workouts only; food events are instants.
    var endDate: Date? = nil
    /// Raw value of `NutritionEventKind` — bridged below.
    var kindValue: String = NutritionEventKind.food.rawValue
    /// Meal name (`HKMetadataKeyFoodType`) or workout activity name; nil → generic label.
    var name: String? = nil
    /// Food: dietary energy consumed. Exercise: active energy burned.
    var kcal: Double? = nil
    var proteinGrams: Double? = nil
    var caffeineMg: Double? = nil
    var durationMinutes: Double? = nil
    /// Raw value of `SignalSource`; `.healthKit` for synced AND seeded rows (seeds are
    /// partitioned by `isMockData`, not by source). `.manual` reserved for a future editor.
    var sourceValue: String = SignalSource.healthKit.rawValue
    var isMockData: Bool = false
    var updatedAt: Date = Date()

    init(startDate: Date, kind: NutritionEventKind) {
        self.startDate = startDate
        self.kindValue = kind.rawValue
        self.updatedAt = Date()
    }
}

extension Notification.Name {
    /// Posted after nutrition events are seeded, wiped, or synced out-of-band so the
    /// calendar view-model re-fetches (same pattern as `medicationEventsDidChange`).
    static let nutritionEventsDidChange = Notification.Name("nutritionEventsDidChange")
}

extension NutritionEvent {
    var kind: NutritionEventKind {
        get { NutritionEventKind(rawValue: kindValue) ?? .food }
        set { kindValue = newValue.rawValue }
    }

    var source: SignalSource {
        get { SignalSource(rawValue: sourceValue) ?? .healthKit }
        set { sourceValue = newValue.rawValue }
    }
}
