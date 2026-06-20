import Foundation
import Observation

/// Manual view/edit of one day's signals. A group is flipped to `.manual` only when
/// the user actually changes one of its values (sticky against future HealthKit
/// syncs); clearing all of a group's values resets it to `.none` so HealthKit may
/// refill it (Assumption A5). Groups the user does not touch keep their existing
/// provenance (FR-009).
@Observable
@MainActor
final class DaySignalsEditorViewModel {
    let dayStart: Date
    @ObservationIgnored private let store: SignalsStore

    // Sleep
    var sleepHours: Double?
    var sleepLevel: SleepLevel?
    private(set) var sleepSource: SignalSource = .none

    // Activity
    var steps: Int?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Int?
    private(set) var activitySource: SignalSource = .none

    // Heart
    var restingHeartRate: Double?
    var hrvSDNN: Double?
    private(set) var heartSource: SignalSource = .none

    // Cycle
    var menstrualFlow: MenstrualFlow?
    var cycleSymptoms: [String] = []
    private(set) var cycleSource: SignalSource = .none

    init(dayStart: Date, store: SignalsStore) {
        self.dayStart = dayStart
        self.store = store
        load()
    }

    /// Pulls the persisted row (if any) into the editable fields.
    func load() {
        guard let row = store.fetch(dayStart: dayStart) else { return }
        sleepHours = row.sleepHours
        sleepLevel = row.sleepLevel
        sleepSource = row.sleepSource
        steps = row.steps
        activeEnergyKcal = row.activeEnergyKcal
        exerciseMinutes = row.exerciseMinutes
        activitySource = row.activitySource
        restingHeartRate = row.restingHeartRate
        hrvSDNN = row.hrvSDNN
        heartSource = row.heartSource
        menstrualFlow = row.menstrualFlow
        cycleSymptoms = row.cycleSymptoms
        cycleSource = row.cycleSource
    }

    /// Writes changed groups onto the day row. A group's source becomes `.manual`
    /// when it changed and still has a value, `.none` when changed and fully cleared,
    /// and is left untouched when the user did not change it.
    func save() throws {
        let row = store.upsert(dayStart: dayStart)

        if row.sleepHours != sleepHours || row.sleepLevel != sleepLevel {
            row.sleepHours = sleepHours
            row.sleepLevel = sleepLevel
            row.sleepSource = (sleepHours == nil && sleepLevel == nil) ? .none : .manual
        }

        if row.steps != steps || row.activeEnergyKcal != activeEnergyKcal || row.exerciseMinutes != exerciseMinutes {
            row.steps = steps
            row.activeEnergyKcal = activeEnergyKcal
            row.exerciseMinutes = exerciseMinutes
            row.activitySource = (steps == nil && activeEnergyKcal == nil && exerciseMinutes == nil) ? .none : .manual
        }

        if row.restingHeartRate != restingHeartRate || row.hrvSDNN != hrvSDNN {
            row.restingHeartRate = restingHeartRate
            row.hrvSDNN = hrvSDNN
            row.heartSource = (restingHeartRate == nil && hrvSDNN == nil) ? .none : .manual
        }

        if row.menstrualFlow != menstrualFlow || row.cycleSymptoms != cycleSymptoms {
            row.menstrualFlow = menstrualFlow
            row.cycleSymptoms = cycleSymptoms
            row.cycleSource = (menstrualFlow == nil && cycleSymptoms.isEmpty) ? .none : .manual
        }

        row.updatedAt = Date()
        try store.save()

        // Reflect the persisted provenance back into the VM.
        sleepSource = row.sleepSource
        activitySource = row.activitySource
        heartSource = row.heartSource
        cycleSource = row.cycleSource
    }
}
