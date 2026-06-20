import Foundation

/// Menstrual flow level for a day. Maps to/from `HKCategoryValueVaginalBleeding`
/// inside `HealthKitServiceImpl` only (light/medium/heavy). `spotting` is a
/// manual-entry value with no distinct case in that HealthKit enum.
enum MenstrualFlow: String, Codable, Sendable, CaseIterable {
    case light
    case medium
    case heavy
    case spotting
}
