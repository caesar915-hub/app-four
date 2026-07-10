import Foundation

/// One sleep-analysis segment reduced to primitives (no HealthKit types) so the session
/// grouping below stays unit-testable. `asleep`/`inBed` are mutually exclusive per sample;
/// an "awake" segment is both false but still participates in grouping.
struct SleepSegment: Sendable, Equatable {
    let start: Date
    let end: Date
    let asleep: Bool
    let inBed: Bool
}

/// Asleep + in-bed seconds for one sleep session, attributed to the calendar day it ends.
struct SleepSessionTotals: Sendable, Equatable {
    let wakeDay: Date
    let asleepSeconds: TimeInterval
    let inBedSeconds: TimeInterval
}

/// Pure value mapping for HealthKit reads. Deliberately imports no HealthKit types so it
/// is unit-testable; the actor converts samples to these primitive inputs.
enum HealthKitSampleMapping {
    /// Segments closer than this (a brief night waking) stay in one session; a multi-hour
    /// gap (an afternoon nap vs. the overnight) starts a new one.
    static let sleepSessionGap: TimeInterval = 3 * 3600

    /// Groups sleep segments into sessions and attributes each to its WAKE day — the
    /// calendar day its last segment ends. Apple Health's convention: a night that starts
    /// before midnight belongs wholly to the morning you wake, never split across two
    /// calendar days. Replaces the prior per-day overlap sum, which credited a
    /// midnight-spanning night to both days.
    static func sleepSessions(
        from segments: [SleepSegment],
        gapThreshold: TimeInterval = sleepSessionGap,
        calendar: Calendar
    ) -> [SleepSessionTotals] {
        let sorted = segments.sorted { $0.start < $1.start }
        var sessions: [SleepSessionTotals] = []
        var asleep: TimeInterval = 0
        var inBed: TimeInterval = 0
        var sessionEnd: Date?   // running max end of the open session

        func flush() {
            guard let end = sessionEnd else { return }
            sessions.append(SleepSessionTotals(
                wakeDay: calendar.startOfDay(for: end),
                asleepSeconds: asleep,
                inBedSeconds: inBed
            ))
            asleep = 0; inBed = 0; sessionEnd = nil
        }

        for seg in sorted {
            if let end = sessionEnd, seg.start.timeIntervalSince(end) > gapThreshold { flush() }
            let duration = seg.end.timeIntervalSince(seg.start)
            if seg.asleep { asleep += duration }
            if seg.inBed { inBed += duration }
            sessionEnd = max(sessionEnd ?? seg.end, seg.end)
        }
        flush()
        return sessions
    }

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
