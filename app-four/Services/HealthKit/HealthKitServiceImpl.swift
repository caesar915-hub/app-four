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
            HKCategoryType(.menstrualFlow),
            // Nutrition + exercise (spec 031).
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCaffeine),
            HKObjectType.workoutType()
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

    // MARK: - Nutrition + exercise events (spec 031)

    func readNutritionEvents(from startDay: Date, to endDay: Date) async throws -> [NutritionEventDTO] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        var results: [NutritionEventDTO] = []
        var cursor = calendar.startOfDay(for: startDay)
        let last = calendar.startOfDay(for: endDay)
        while cursor <= last {
            try Task.checkCancellation()
            results.append(contentsOf: try await readFoodEvents(on: cursor))
            results.append(contentsOf: try await readWorkouts(on: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return results
    }

    /// Food correlations become named meals; dietary samples not in any correlation are
    /// bucketed per clock hour by the pure `NutritionEventGrouping` mapper.
    private func readFoodEvents(on day: Date) async throws -> [NutritionEventDTO] {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let energyType = HKQuantityType(.dietaryEnergyConsumed)
        let proteinType = HKQuantityType(.dietaryProtein)
        let caffeineType = HKQuantityType(.dietaryCaffeine)
        let caffeineUnit = HKUnit.gramUnit(with: .milli)

        // 1. Correlations → one event per logged meal, named from HKMetadataKeyFoodType.
        let corrDescriptor = HKSampleQueryDescriptor(
            predicates: [.correlation(type: HKCorrelationType(.food), predicate: predicate)],
            sortDescriptors: []
        )
        var claimed = Set<UUID>()
        var events: [NutritionEventDTO] = []
        for correlation in try await corrDescriptor.result(for: store) {
            func sum(_ type: HKQuantityType, _ unit: HKUnit) -> Double? {
                let samples = correlation.objects(for: type).compactMap { $0 as? HKQuantitySample }
                samples.forEach { claimed.insert($0.uuid) }
                guard !samples.isEmpty else { return nil }
                return samples.reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
            }
            let kcal = sum(energyType, .kilocalorie())
            let protein = sum(proteinType, .gram())
            let caffeine = sum(caffeineType, caffeineUnit)
            guard kcal != nil || protein != nil || caffeine != nil else { continue }
            events.append(NutritionEventDTO(
                kind: .food, startDate: correlation.startDate, endDate: nil,
                name: correlation.metadata?[HKMetadataKeyFoodType] as? String,
                kcal: kcal.map { ($0 * 10).rounded() / 10 },
                proteinGrams: protein.map { ($0 * 10).rounded() / 10 },
                caffeineMg: caffeine.map { $0.rounded() },
                durationMinutes: nil
            ))
        }

        // 2. Loose samples (not claimed by a correlation) → hourly food events.
        var loose: [LooseDietarySample] = []
        loose += try await looseSamples(energyType, unit: .kilocalorie(), predicate: predicate, claimed: claimed)
            .map { LooseDietarySample(startDate: $0.date, kcal: ($0.value * 10).rounded() / 10, proteinGrams: nil, caffeineMg: nil) }
        loose += try await looseSamples(proteinType, unit: .gram(), predicate: predicate, claimed: claimed)
            .map { LooseDietarySample(startDate: $0.date, kcal: nil, proteinGrams: ($0.value * 10).rounded() / 10, caffeineMg: nil) }
        loose += try await looseSamples(caffeineType, unit: caffeineUnit, predicate: predicate, claimed: claimed)
            .map { LooseDietarySample(startDate: $0.date, kcal: nil, proteinGrams: nil, caffeineMg: $0.value.rounded()) }
        events += NutritionEventGrouping.hourlyFoodEvents(loose: loose, calendar: calendar)
        return events
    }

    private func looseSamples(_ type: HKQuantityType, unit: HKUnit, predicate: NSPredicate,
                              claimed: Set<UUID>) async throws -> [(date: Date, value: Double)] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        return try await descriptor.result(for: store).compactMap { sample in
            guard !claimed.contains(sample.uuid) else { return nil }
            return (sample.startDate, sample.quantity.doubleValue(for: unit))
        }
    }

    private func readWorkouts(on day: Date) async throws -> [NutritionEventDTO] {
        let (start, end) = dayInterval(day)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store).map { workout in
            // Modern API: per-workout statistics, NOT the deprecated `totalEnergyBurned`.
            let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            return NutritionEventDTO(
                kind: .exercise, startDate: workout.startDate, endDate: workout.endDate,
                name: workout.workoutActivityType.squirlName,
                kcal: kcal.map { ($0 * 10).rounded() / 10 },
                proteinGrams: nil, caffeineMg: nil,
                durationMinutes: (workout.duration / 60 * 10).rounded() / 10
            )
        }
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

private extension HKWorkoutActivityType {
    /// A short, human name for the common activities; everything else reads "Workout".
    /// HealthKit has no built-in display name, so we map only what the demo surfaces.
    var squirlName: String {
        switch self {
        case .running: "Run"
        case .walking: "Walk"
        case .cycling: "Cycling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Strength"
        case .highIntensityIntervalTraining: "HIIT"
        case .yoga: "Yoga"
        case .swimming: "Swim"
        default: "Workout"
        }
    }
}
