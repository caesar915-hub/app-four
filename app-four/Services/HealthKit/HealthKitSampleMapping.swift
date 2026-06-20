import Foundation

/// Pure value mapping for HealthKit reads. Deliberately imports no HealthKit types so it
/// is unit-testable; the actor converts samples to these primitive inputs.
enum HealthKitSampleMapping {
    /// Maps the raw value of `HKCategoryValueVaginalBleeding` to our domain flow.
    /// Raw integers: 0 = notApplicable (Obj-C only), 1 = unspecified, 2 = light,
    /// 3 = medium, 4 = heavy, 5 = none. Only graded flow is recorded; unspecified /
    /// none / unknown → nil (no flow that day).
    static func flow(fromHKValue raw: Int) -> MenstrualFlow? {
        switch raw {
        case 2: return .light
        case 3: return .medium
        case 4: return .heavy
        default: return nil
        }
    }

    /// Coarse sleep level from sleep efficiency (`asleepHours / inBedHours`). A heuristic,
    /// not a diagnosis — efficiency norms put ~85–90%+ as healthy, ≥80% as a normal floor.
    /// Returns nil when there is no in-bed reference (Assumption A3 fallback).
    static func sleepLevel(asleepHours: Double, inBedHours: Double) -> SleepLevel? {
        guard inBedHours > 0, asleepHours >= 0 else { return nil }
        let efficiency = asleepHours / inBedHours
        guard efficiency.isFinite else { return nil }
        switch efficiency {
        case ..<0.70: return .restless
        case ..<0.80: return .light
        case ..<0.88: return .okay
        case ..<0.94: return .good
        default: return .deep
        }
    }
}
