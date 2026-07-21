import Foundation
import Observation

@MainActor
@Observable
final class ExtractionReviewViewModel: Identifiable {
    let id = UUID()

    // MARK: - Editable fields
    var name: String {
        didSet {
            // Any change away from the title the sheet opened with is a user edit.
            if name != originalTitle { userDidSetTitle = true }
        }
    }
    /// True once the user has typed a title different from the one the sheet
    /// opened with. Gates the auto "Mood · Energy · Focus" title so a user-set
    /// name is never clobbered on confirm.
    private(set) var userDidSetTitle = false
    var date: Date
    var mood: String
    var energy: EnergyLevel?
    var focus: FocusLevel?
    var sleepLevel: SleepLevel?
    var sleepHours: Double?
    var medications: [MedEvent]
    var emotions: Set<String>
    var sideEffects: Set<String>

    let originalResult: SummaryResult
    let recording: Recording

    private let store: RecordingStore
    private let originalTitle: String          // used to detect user-edited name
    private var editedFields: Set<TagCategory> = []
    var onComplete: (Recording) -> Void

    init(
        result: SummaryResult,
        recording: Recording,
        store: RecordingStore,
        onComplete: @escaping (Recording) -> Void
    ) {
        self.originalResult = result
        self.recording = recording
        self.store = store
        self.onComplete = onComplete
        self.originalTitle = recording.title
        self.name = recording.title
        self.date = recording.createdAt
        self.mood = result.mood ?? ""
        self.energy = result.energyLevel.flatMap { EnergyLevel(rawValue: $0) }
        self.focus = result.focusLevel.flatMap { FocusLevel(rawValue: $0) }
        self.sleepLevel = result.sleepLevel.flatMap { SleepLevel(rawValue: $0) }
        self.sleepHours = result.sleepHours
        self.medications = result.medications
        self.emotions = Set(result.emotions)
        self.sideEffects = Set(result.sideEffects)
    }

    convenience init(
        recording: Recording,
        store: RecordingStore,
        onComplete: @escaping (Recording) -> Void
    ) {
        // Map persisted MedicationEvent rows back to the transient MedEvent DTO
        // so the review UI works with the same value type the extractor emits.
        let existingMeds: [MedEvent] = (recording.medicationEvents ?? [])
            .filter { $0.source == .transcript }
            .sorted { $0.takenAt < $1.takenAt }
            .map { event in
                let cal = Calendar.current
                let comps = cal.dateComponents([.hour, .minute], from: event.takenAt)
                let timeString = String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
                return MedEvent(
                    name: event.name,
                    dose: event.dose,
                    time: timeString,
                    timeLabel: event.timeLabel,
                    taken: event.taken,
                    quantity: event.quantity,
                    change: event.change,
                    durationHours: event.durationHours  // carry persisted duration so a re-edit + Save preserves it
                )
            }
        let result = SummaryResult(
            bullets: recording.summaryBullets,
            medications: existingMeds,
            generatedTitle: recording.title,
            energyLevel: recording.energyLevel,
            focusLevel: recording.focusLevel,
            mood: recording.mood,
            sleepHours: recording.sleepHours,
            sleepQuality: recording.sleepQuality,
            sleepEvent: recording.decodedSleepEvent,
            sleepLevel: recording.sleepLevelValue,
            sideEffects: recording.decodedSideEffects,
            emotions: recording.decodedEmotions,
            topics: recording.topicCategories.map(\.rawValue),
            noteExtraction: nil
        )
        self.init(result: result, recording: recording, store: store, onComplete: onComplete)
    }

    // MARK: - Setters

    func setMood(_ newMood: String) {
        mood = newMood
        editedFields.insert(.mood)
    }

    func setEnergy(_ level: EnergyLevel?) {
        energy = level
        editedFields.insert(.energy)
    }

    func setFocus(_ level: FocusLevel?) {
        focus = level
        editedFields.insert(.focus)
    }

    func setSleepLevel(_ level: SleepLevel?) {
        sleepLevel = level
    }

    func setSleepHours(_ hours: Double?) {
        sleepHours = hours
    }

    func toggleEmotion(_ emotion: String) {
        if emotions.contains(emotion) { emotions.remove(emotion) } else { emotions.insert(emotion) }
        editedFields.insert(.emotions)
    }

    func toggleSideEffect(_ effect: String) {
        if sideEffects.contains(effect) { sideEffects.remove(effect) } else { sideEffects.insert(effect) }
    }

    // Look up the row by its stable per-row identity (`editRowID`), not by name or value:
    // name collides when the same med is logged twice (two doses), and value equality
    // breaks the moment any field on the row is edited (stale capture → dropped edit).
    func toggleMedTaken(_ med: MedEvent) {
        guard let index = medications.firstIndex(where: { $0.editRowID == med.editRowID }) else { return }
        medications[index].taken.toggle()
        editedFields.insert(.medication)
    }

    func setMedDose(_ med: MedEvent, dose: String?) {
        guard let index = medications.firstIndex(where: { $0.editRowID == med.editRowID }) else { return }
        medications[index].dose = dose
        editedFields.insert(.medication)
    }

    func setMedDuration(_ med: MedEvent, hours: Double?) {
        guard let index = medications.firstIndex(where: { $0.editRowID == med.editRowID }) else { return }
        medications[index].durationHours = hours
        editedFields.insert(.medication)
    }

    func addMedication(_ name: String) {
        guard !medications.contains(where: { $0.name == name }) else { return }
        // Seed dose + duration from the catalog so the inline-expand opens populated, and
        // so the saved duration matches the box (the shared resolver no longer adds catalog).
        let entry = MedicationCatalog.entry(matching: name)
        medications.append(MedEvent(name: name, dose: entry?.doseOptions.first, durationHours: entry?.durationHours))
        editedFields.insert(.medication)
    }

    /// Remove one specific dose row (the × on its inline-expand card).
    func removeMedication(id: String) {
        medications.removeAll(where: { $0.editRowID == id })
        editedFields.insert(.medication)
    }

    /// Remove every dose of a med (the catalog add/remove grid chip toggling off).
    func removeMedication(_ name: String) {
        medications.removeAll(where: { $0.name == name })
        editedFields.insert(.medication)
    }

    // MARK: - Confirm / Cancel

    func confirm() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rebuild the noteExtraction from the (possibly edited) scalars so the
        // persisted JSON can never disagree with the columns (Bug 12). Carry over
        // the fields the review UI doesn't expose (valence, triage arrays, …).
        var correctedExtraction = originalResult.noteExtraction
        correctedExtraction?.mood = mood.isEmpty ? nil : mood
        correctedExtraction?.energy = energy
        correctedExtraction?.focus = focus
        correctedExtraction?.medications = medications
        correctedExtraction?.emotions = Array(emotions)
        correctedExtraction?.sideEffects = Array(sideEffects)

        let correctedResult = SummaryResult(
            bullets: originalResult.bullets,
            medications: medications,
            generatedTitle: originalResult.generatedTitle,
            energyLevel: energy?.rawValue,
            focusLevel: focus?.rawValue,
            mood: mood.isEmpty ? nil : mood,
            sleepHours: sleepHours,
            sleepQuality: originalResult.sleepQuality,
            sleepEvent: originalResult.sleepEvent,
            sleepLevel: sleepLevel?.rawValue,
            sideEffects: Array(sideEffects),
            emotions: Array(emotions),
            topics: originalResult.topics,
            noteExtraction: correctedExtraction
        )

        // Set the new date BEFORE materializing med events so each event's
        // takenAt resolves against the corrected day, not the old one (Bug 5).
        recording.createdAt = date
        recording.applySummary(correctedResult)
        recording.setMedicationEvents(
            from: correctedResult.medications,
            durationHours: correctedExtraction?.durationHours,
            context: store.context
        )

        // User-set titles always win: only let the auto "Mood · Energy · Focus"
        // title stand when the user did not edit the name.
        if userDidSetTitle && !trimmedName.isEmpty {
            recording.title = trimmedName
        }
        recording.updatedAt = Date()

        // Write provenance tags
        var tags: [RecordingTag] = []
        if !mood.isEmpty {
            tags.append(RecordingTag(name: mood, category: .mood,
                                     source: editedFields.contains(.mood) ? .userCorrected : .nlp))
        }
        if let e = energy {
            tags.append(RecordingTag(name: e.rawValue, category: .energy,
                                     source: editedFields.contains(.energy) ? .userCorrected : .nlp))
        }
        if let f = focus {
            tags.append(RecordingTag(name: f.rawValue, category: .focus,
                                     source: editedFields.contains(.focus) ? .userCorrected : .nlp))
        }
        for med in medications {
            tags.append(RecordingTag(name: med.name, category: .medication,
                                     source: editedFields.contains(.medication) ? .userCorrected : .nlp))
        }
        for emotion in emotions {
            tags.append(RecordingTag(name: emotion, category: .emotions,
                                     source: editedFields.contains(.emotions) ? .userCorrected : .nlp))
        }
        store.addCorrectionTags(tags, for: recording)
        store.save()
        onComplete(recording)
    }

    func cancel() {
        if recording.summaryStatus != SummaryStatus.completed.rawValue {
            recording.summaryStatus = SummaryStatus.failed.rawValue
            store.save()
        }
    }
}

extension MedEvent {
    /// Stable per-row identity for the Edit-sheet medication list. Distinguishes two doses
    /// of the same med (which differ by time) and is invariant under dose/duration/taken
    /// edits — so list diffing and the row-keyed setters always target exactly one row.
    var editRowID: String { "\(name)|\(time ?? "")|\(timeLabel ?? "")|\(quantity ?? 1)" }
}
