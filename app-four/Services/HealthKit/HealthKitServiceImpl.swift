import Foundation
import HealthKit

/// The ONLY type that imports HealthKit. Reads samples and maps them to Sendable DTOs;
/// no `HKObject` ever escapes. An `actor` so access to the shared `HKHealthStore`
/// serializes. Read-only — never writes to Apple Health.
actor HealthKitServiceImpl: HealthDataReading {
    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// (identifier, tag) for the cycle symptoms we surface. The identifiers are
    /// presence/severity category types; we record the tag when any sample exists that day.
    private let symptomMap: [(HKCategoryTypeIdentifier, String)] = [
        (.abdominalCramps, "cramps"),
        (.headache, "headache"),
        (.moodChanges, "mood changes"),
        (.fatigue, "fatigue"),
        (.lowerBackPain, "back pain")
    ]

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.menstrualFlow)
        ]
        for (id, _) in symptomMap { types.insert(HKCategoryType(id)) }
        return types
    }

    func authorizationState() async -> HealthAuthorizationState {
        HKHealthStore.isHealthDataAvailable() ? .authorized : .unavailable
    }

    func requestAuthorization() async throws -> HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        return .authorized
    }

    func readSignals(from startDay: Date, to endDay: Date) async throws -> [DaySignalsDTO] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        var results: [DaySignalsDTO] = []
        var cursor = calendar.startOfDay(for: startDay)
        let last = calendar.startOfDay(for: endDay)
        while cursor <= last {
            try Task.checkCancellation()
            let day = cursor
            let dto = DaySignalsDTO(
                dayStart: day,
                sleep: try await readSleep(on: day),
                activity: try await readActivity(on: day),
                heart: try await readHeart(on: day),
                cycle: try await readCycle(on: day)
            )
            results.append(dto)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            cursor = next
        }
        return results
    }

    // MARK: - Per-signal reads (nil when no samples)

    private func dayInterval(_ day: Date) -> (start: Date, end: Date) {
        let end = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return (day, end)
    }

    private func readSleep(on day: Date) async throws -> SleepDTO? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        guard !samples.isEmpty else { return nil }

        var asleep: TimeInterval = 0
        var inBed: TimeInterval = 0
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .inBed: inBed += duration
            case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified: asleep += duration
            default: break
            }
        }
        let asleepHours = asleep / 3600
        guard asleepHours > 0 else { return nil }
        let inBedHours = inBed / 3600
        let level = HealthKitSampleMapping.sleepLevel(asleepHours: asleepHours, inBedHours: inBedHours)
        return SleepDTO(hours: (asleepHours * 10).rounded() / 10, level: level)
    }

    private func sumQuantity(_ type: HKQuantityType, unit: HKUnit, day: Date) async throws -> Double? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        return try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit)
    }

    private func averageQuantity(_ type: HKQuantityType, unit: HKUnit, day: Date) async throws -> Double? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .discreteAverage
        )
        return try await descriptor.result(for: store)?.averageQuantity()?.doubleValue(for: unit)
    }

    private func readActivity(on day: Date) async throws -> ActivityDTO? {
        let steps = try await sumQuantity(HKQuantityType(.stepCount), unit: .count(), day: day)
        let energy = try await sumQuantity(HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), day: day)
        let exercise = try await sumQuantity(HKQuantityType(.appleExerciseTime), unit: .minute(), day: day)
        if steps == nil, energy == nil, exercise == nil { return nil }
        return ActivityDTO(
            steps: steps.map { Int($0.rounded()) },
            activeEnergyKcal: energy.map { ($0 * 10).rounded() / 10 },
            exerciseMinutes: exercise.map { Int($0.rounded()) }
        )
    }

    private func readHeart(on day: Date) async throws -> HeartDTO? {
        let resting = try await averageQuantity(
            HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()), day: day
        )
        let hrv = try await averageQuantity(
            HKQuantityType(.heartRateVariabilitySDNN),
            unit: .secondUnit(with: .milli), day: day
        )
        if resting == nil, hrv == nil { return nil }
        return HeartDTO(
            restingHeartRate: resting.map { ($0 * 10).rounded() / 10 },
            hrvSDNN: hrv.map { ($0 * 10).rounded() / 10 }
        )
    }

    private func readCycle(on day: Date) async throws -> CycleDTO? {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let flowDescriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.menstrualFlow), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        // Read `.value` as a raw Int and map it (2/3/4 → light/medium/heavy). The raw
        // integers are stable across the `menstrualFlow` category's value enum and its
        // iOS-18 successor, so we never reference the enum type directly. Take the latest
        // sample of the day (sorted by endDate desc) for a deterministic result.
        let flowSamples = try await flowDescriptor.result(for: store)
        let flow = flowSamples.first.flatMap { HealthKitSampleMapping.flow(fromHKValue: $0.value) }

        var symptoms: [String] = []
        for (id, label) in symptomMap {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.categorySample(type: HKCategoryType(id), predicate: predicate)],
                sortDescriptors: []
            )
            do {
                if try await descriptor.result(for: store).isEmpty == false {
                    symptoms.append(label)
                }
            } catch {
                // One symptom query failing shouldn't drop the whole day — but log it so a
                // systematic failure is visible (was a silent `try?`).
                AppLogger.log("HealthKit symptom read failed (\(label)): \(error)")
            }
        }
        if flow == nil, symptoms.isEmpty { return nil }
        return CycleDTO(flow: flow, symptoms: symptoms)
    }
}
