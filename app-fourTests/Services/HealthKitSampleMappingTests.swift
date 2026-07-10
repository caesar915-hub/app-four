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

    // MARK: - Sleep session grouping (wake-day attribution)

    @Test func sessionAttributedToWakeDayNotSplitAcrossMidnight() {
        let cal = utcCalendar
        // A night 23:00 (Jul 1) → 07:00 (Jul 2), written as two contiguous asleep segments.
        let segments = [
            SleepSegment(start: date(7, 1, 23, 0, cal), end: date(7, 2, 0, 0, cal), asleep: true, inBed: false),
            SleepSegment(start: date(7, 2, 0, 0, cal), end: date(7, 2, 7, 0, cal), asleep: true, inBed: false),
        ]
        let sessions = HealthKitSampleMapping.sleepSessions(from: segments, calendar: cal)
        #expect(sessions.count == 1)
        #expect(sessions[0].wakeDay == cal.startOfDay(for: date(7, 2, 7, 0, cal)))  // whole night → Jul 2
        #expect(sessions[0].asleepSeconds == 8 * 3600)                              // all 8h, none on Jul 1
    }

    @Test func midnightStraddlingSegmentCountedOnceOnWakeDay() {
        let cal = utcCalendar
        // One segment 23:55 (Jul 1) → 00:10 (Jul 2): old overlap read counted it on both days.
        let segments = [
            SleepSegment(start: date(7, 1, 23, 55, cal), end: date(7, 2, 0, 10, cal), asleep: true, inBed: false),
        ]
        let sessions = HealthKitSampleMapping.sleepSessions(from: segments, calendar: cal)
        #expect(sessions.count == 1)
        #expect(sessions[0].wakeDay == cal.startOfDay(for: date(7, 2, 0, 10, cal)))  // wake day = Jul 2 only
        #expect(sessions[0].asleepSeconds == 15 * 60)
    }

    @Test func napAndOvernightAreSeparateSessionsSameWakeDay() {
        let cal = utcCalendar
        let segments = [
            SleepSegment(start: date(7, 2, 0, 0, cal), end: date(7, 2, 6, 0, cal), asleep: true, inBed: false),   // overnight
            SleepSegment(start: date(7, 2, 14, 0, cal), end: date(7, 2, 15, 0, cal), asleep: true, inBed: false), // 8h gap → nap
        ]
        let sessions = HealthKitSampleMapping.sleepSessions(from: segments, calendar: cal)
        #expect(sessions.count == 2)
        #expect(sessions.allSatisfy { $0.wakeDay == cal.startOfDay(for: date(7, 2, 0, 0, cal)) })
    }

    @Test func inBedAndAsleepAccumulateSeparatelyWithinOneSession() {
        let cal = utcCalendar
        // An inBed span with a nested asleep interval (typical HealthKit shape).
        let segments = [
            SleepSegment(start: date(7, 1, 23, 0, cal), end: date(7, 2, 7, 0, cal), asleep: false, inBed: true),
            SleepSegment(start: date(7, 2, 0, 0, cal), end: date(7, 2, 6, 0, cal), asleep: true, inBed: false),
        ]
        let sessions = HealthKitSampleMapping.sleepSessions(from: segments, calendar: cal)
        #expect(sessions.count == 1)
        #expect(sessions[0].inBedSeconds == 8 * 3600)
        #expect(sessions[0].asleepSeconds == 6 * 3600)
        #expect(sessions[0].wakeDay == cal.startOfDay(for: date(7, 2, 7, 0, cal)))
    }

    @Test func emptyInputYieldsNoSessions() {
        #expect(HealthKitSampleMapping.sleepSessions(from: [], calendar: utcCalendar).isEmpty)
    }
}

private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}

private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ cal: Calendar) -> Date {
    cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}
