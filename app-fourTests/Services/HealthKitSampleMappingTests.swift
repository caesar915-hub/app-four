import Testing
import Foundation
@testable import app_four

struct HealthKitSampleMappingTests {
    @Test func flowMapsGradedValuesOnly() {
        #expect(HealthKitSampleMapping.flow(fromHKValue: 2) == .light)
        #expect(HealthKitSampleMapping.flow(fromHKValue: 3) == .medium)
        #expect(HealthKitSampleMapping.flow(fromHKValue: 4) == .heavy)
        #expect(HealthKitSampleMapping.flow(fromHKValue: 1) == nil)   // unspecified
        #expect(HealthKitSampleMapping.flow(fromHKValue: 5) == nil)   // none
        #expect(HealthKitSampleMapping.flow(fromHKValue: 0) == nil)   // notApplicable
        #expect(HealthKitSampleMapping.flow(fromHKValue: 99) == nil)  // unknown
    }

    @Test func sleepLevelBuckets() {
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 6.6, inBedHours: 7.0) == .deep)      // ≈0.943
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 6.3, inBedHours: 7.0) == .good)      // 0.90
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 5.8, inBedHours: 7.0) == .okay)      // ≈0.829
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 5.3, inBedHours: 7.0) == .light)     // ≈0.757
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 4.5, inBedHours: 7.0) == .restless)  // ≈0.643
    }

    @Test func sleepLevelNilWithoutInBedReference() {
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 7, inBedHours: 0) == nil)
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 7, inBedHours: -1) == nil)
    }

    @Test func sleepLevelExactThresholdsAreHalfOpen() {
        // Buckets are `..<` (lower-inclusive): a value exactly on a cut belongs to the upper bucket.
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 0.70, inBedHours: 1) == .light)  // 0.70 → light
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 0.80, inBedHours: 1) == .okay)   // 0.80 → okay
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 0.88, inBedHours: 1) == .good)   // 0.88 → good
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 0.94, inBedHours: 1) == .deep)   // 0.94 → deep
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: 1.00, inBedHours: 1) == .deep)   // 100% → deep
    }

    @Test func sleepLevelGuardsNegativeAndNonFinite() {
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: -0.5, inBedHours: 7) == nil)     // negative asleep
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: .nan, inBedHours: 7) == nil)     // NaN → non-finite
        #expect(HealthKitSampleMapping.sleepLevel(asleepHours: .infinity, inBedHours: 7) == nil)
    }
}
