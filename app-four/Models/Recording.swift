import Foundation
import SwiftData

@Model
final class Recording {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var audioFileName: String
    var duration: TimeInterval
    var fileSize: Int64
    var status: RecordingStatus
    var fullTranscriptText: String
    var title: String
    var isFavorite: Bool
    var cloudSyncStatus: String?

    // MARK: - Summarization
    var summary: String?
    var summaryStatus: String?
    var topicTagsJSON: String?
    var summaryGeneratedAt: Date?

    // MARK: - ADHD Journal
    var hasMedication: Bool = false
    var medicationInfo: String?
    var energyLevel: String?
    var focusLevel: String?
    var mood: String?
    var sleepHours: Double?
    var sleepQuality: String?
    var summaryBulletsJSON: String?
    var noteExtractionJSON: String?
    var sideEffectsJSON: String?
    var sleepEventJSON: String?
    var emotionsJSON: String?
    var sleepLevelValue: String?
    var isMockData: Bool = false

    /// Name to show in lists/headers. While transcription is in progress the real title
    /// isn't known yet, so show a temporary "Transcribing…" placeholder (feedback §4.1).
    /// A recording captured before the model was ready reads with a calm "ready shortly"
    /// affordance instead of its provisional title — never error language (FR-017).
    var displayTitle: String {
        switch status {
        case .transcribing: "Transcribing…"
        case .pendingTranscription: "Ready shortly…"
        default: title
        }
    }

    @Relationship(deleteRule: .cascade, inverse: \TranscriptionSegment.recording)
    var segments: [TranscriptionSegment]?

    @Relationship(deleteRule: .cascade, inverse: \RecordingTag.recording)
    var correctionTags: [RecordingTag]?

    @Relationship(deleteRule: .cascade, inverse: \MedicationEvent.recording)
    var medicationEvents: [MedicationEvent] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        audioFileName: String,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        status: RecordingStatus = .placeholder,
        fullTranscriptText: String = "",
        title: String = "Untitled",
        isFavorite: Bool = false,
        summary: String? = nil,
        summaryStatus: String? = nil,
        topicTagsJSON: String? = nil,
        summaryGeneratedAt: Date? = nil,
        hasMedication: Bool = false,
        medicationInfo: String? = nil,
        energyLevel: String? = nil,
        focusLevel: String? = nil,
        mood: String? = nil,
        sleepHours: Double? = nil,
        sleepQuality: String? = nil,
        summaryBulletsJSON: String? = nil,
        noteExtractionJSON: String? = nil,
        sideEffectsJSON: String? = nil,
        sleepEventJSON: String? = nil,
        emotionsJSON: String? = nil,
        sleepLevelValue: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.audioFileName = audioFileName
        self.duration = duration
        self.fileSize = fileSize
        self.status = status
        self.fullTranscriptText = fullTranscriptText
        self.title = title
        self.isFavorite = isFavorite
        self.summary = summary
        self.summaryStatus = summaryStatus
        self.topicTagsJSON = topicTagsJSON
        self.summaryGeneratedAt = summaryGeneratedAt
        self.hasMedication = hasMedication
        self.medicationInfo = medicationInfo
        self.energyLevel = energyLevel
        self.focusLevel = focusLevel
        self.mood = mood
        self.sleepHours = sleepHours
        self.sleepQuality = sleepQuality
        self.summaryBulletsJSON = summaryBulletsJSON
        self.noteExtractionJSON = noteExtractionJSON
        self.sideEffectsJSON = sideEffectsJSON
        self.sleepEventJSON = sleepEventJSON
        self.emotionsJSON = emotionsJSON
        self.sleepLevelValue = sleepLevelValue
    }
}

extension Recording {
    /// Formatted duration string (e.g., "4:32")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Relative date string (e.g., "Today", "2 days ago")
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Local URL for the audio file
    var audioURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents
            .appendingPathComponent("Recordings", isDirectory: true)
            .appendingPathComponent(audioFileName)
    }

    // MARK: - UI Compatibility Properties
    var transcriptText: String { fullTranscriptText }
    var durationString: String { formattedDuration }

    // MARK: - ADHD Helpers
    var summaryBullets: [String] {
        guard let json = summaryBulletsJSON,
              let data = json.data(using: .utf8),
              let bullets = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return bullets
    }

    @MainActor var decodedSleepEvent: SleepEvent? {
        guard let json = sleepEventJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SleepEvent.self, from: data)
    }

    var decodedSideEffects: [String] {
        guard let json = sideEffectsJSON,
              let data = json.data(using: .utf8),
              let effects = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return effects
    }

    var decodedSleepLevel: SleepLevel? {
        sleepLevelValue.flatMap { SleepLevel(rawValue: $0) }
    }

    var decodedEmotions: [String] {
        guard let json = emotionsJSON,
              let data = json.data(using: .utf8),
              let emotions = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return emotions
    }

    @MainActor var decodedNoteExtraction: NoteExtraction? {
        guard let json = noteExtractionJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NoteExtraction.self, from: data)
    }

    @MainActor var decodedActivities: [String] {
        decodedNoteExtraction?.activities ?? []
    }

    // MARK: - Summarization Helpers
    var topicCategories: [TopicCategory] {
        guard let json = topicTagsJSON,
              let data = json.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return strings.compactMap { TopicCategory(rawValue: $0) }
    }

    /// Single source of truth for writing an ADHD `SummaryResult` onto the model.
    /// Used by both the automatic post-transcription path (CheckInViewModel)
    /// and the manual Regenerate path (RecordingDetailViewModel) so they stay in sync
    /// and always populate the Journal fields the UI actually renders.
    ///
    /// When `fillOnly` is true (text check-in path) only nil scalar columns are filled;
    /// values already set by the user in the composer are never overwritten.
    @MainActor func applySummary(_ result: SummaryResult, fillOnly: Bool = false) {
        if fillOnly {
            if energyLevel == nil { energyLevel = result.energyLevel }
            if focusLevel == nil { focusLevel = result.focusLevel }
            if mood == nil { mood = result.mood }
            if sleepHours == nil { sleepHours = result.sleepHours }
            if sleepQuality == nil { sleepQuality = result.sleepQuality }
            if sleepLevelValue == nil { sleepLevelValue = result.sleepLevel }
            if medicationInfo == nil {
                let medStr = Self.medicationSummary(result.medications)
                medicationInfo = medStr.isEmpty ? nil : medStr
            }
        } else {
            var nameParts: [String] = []
            if let mood = result.mood { nameParts.append(mood.capitalized) }
            if let energy = result.energyLevel { nameParts.append(energy.capitalized) }
            if let focusRaw = result.focusLevel {
                nameParts.append(FocusLevel(rawValue: focusRaw)?.displayLabel ?? focusRaw.capitalized)
            }
            title = nameParts.isEmpty ? result.generatedTitle : nameParts.joined(separator: " · ")
            energyLevel = result.energyLevel
            focusLevel = result.focusLevel
            mood = result.mood
            sleepHours = result.sleepHours
            sleepQuality = result.sleepQuality
            sleepLevelValue = result.sleepLevel
            let medStr = Self.medicationSummary(result.medications)
            medicationInfo = medStr.isEmpty ? nil : medStr
        }

        // The blocks below run in both modes: the user-authoritative values are the
        // scalars above. Bullets, emotions, side effects, sleep event and topics are
        // never set by the composer, so they always reflect the latest extraction.
        if let data = try? JSONEncoder().encode(result.bullets),
           let json = String(data: data, encoding: .utf8) {
            summaryBulletsJSON = json
        }

        // Persist ONLY the fields that have no scalar column. mood/energy/focus/
        // emotions/sideEffects/sleepHours live in dedicated columns (the source of
        // truth); duplicating them in the JSON is the drift class we remove here.
        if var extraction = result.noteExtraction {
            extraction.mood = nil
            extraction.energy = nil
            extraction.focus = nil
            extraction.emotions = []
            extraction.sideEffects = []
            extraction.sleepHours = nil
            if let data = try? JSONEncoder().encode(extraction),
               let json = String(data: data, encoding: .utf8) {
                noteExtractionJSON = json
            }
        }

        if !result.sideEffects.isEmpty,
           let data = try? JSONEncoder().encode(result.sideEffects),
           let json = String(data: data, encoding: .utf8) {
            sideEffectsJSON = json
        }

        if let event = result.sleepEvent,
           let data = try? JSONEncoder().encode(event),
           let json = String(data: data, encoding: .utf8) {
            sleepEventJSON = json
        }

        if !result.emotions.isEmpty,
           let data = try? JSONEncoder().encode(result.emotions),
           let json = String(data: data, encoding: .utf8) {
            emotionsJSON = json
        }

        if !result.topics.isEmpty,
           let data = try? JSONEncoder().encode(result.topics),
           let json = String(data: data, encoding: .utf8) {
            topicTagsJSON = json
        }

        summary = result.bullets.map { "- \($0)" }.joined(separator: "\n")
        summaryStatus = SummaryStatus.completed.rawValue
        summaryGeneratedAt = Date.now
        updatedAt = Date.now
    }

    private static func medicationSummary(_ meds: [MedEvent]) -> String {
        meds.map { med in
            var parts = [med.name]
            if let change = med.change, change != .regular { parts.append(change.rawValue) }
            if let dose = med.dose { parts.append(dose) }
            if let label = med.timeLabel { parts.append("at \(label)") }
            if !med.taken { parts.append("missed") }
            return parts.joined(separator: " ")
        }.joined(separator: "; ")
    }

    /// Replaces this recording's transcript-sourced `MedicationEvent` rows with fresh ones
    /// derived from `meds`. Manual events (`source == .manual`) are never touched and
    /// beat the extractor when the same name appears in the note.
    /// Call this immediately after `applySummary` and before `store.save()`.
    @MainActor func setMedicationEvents(
        from meds: [MedEvent],
        durationHours: Double?,
        context: ModelContext
    ) {
        // A manually logged dose on this check-in beats the extractor finding the
        // same name in the note — skip those to avoid duplicates.
        let manualNames = Set(
            medicationEvents.filter { $0.source == .manual }.map { $0.name.lowercased() }
        )

        medicationEvents
            .filter { $0.source == .transcript }
            .forEach { context.delete($0) }

        for med in meds where !manualNames.contains(med.name.lowercased()) {
            let takenAt = MedicationEvent.resolvedTakenAt(
                time: med.time,
                timeLabel: med.timeLabel,
                recordingDate: createdAt
            )
            let event = MedicationEvent(
                name: med.name,
                dose: med.dose,
                takenAt: takenAt,
                taken: med.taken,
                quantity: med.quantity,
                // Per-med duration (Edit sheet) wins, else the call-site default, else 10h.
                // No catalog step here — the Edit-sheet VM seeds the catalog default into
                // med.durationHours, so the voice/transcript path stays byte-identical.
                durationHours: med.durationHours ?? durationHours ?? 10.0,
                change: med.change,
                timeLabel: med.timeLabel,
                source: .transcript
            )
            context.insert(event)
            event.recording = self
        }

        // Computed from inputs, not `medicationEvents`: SwiftData keeps just-deleted
        // rows in the relationship until the next save, so reading the array here would
        // report stale `true` when a reprocess clears all meds (`from: []`).
        hasMedication = !meds.isEmpty || !manualNames.isEmpty
    }
}

/// Helper for providing mock data to unmodified SwiftUI Previews.
enum PreviewData {
    static let recordings: [Recording] = [
        Recording(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-3600),
            audioFileName: "preview1.m4a",
            duration: 272,
            status: .completed,
            fullTranscriptText: "This is a detailed transcript of the morning standup. We discussed the roadmap for iOS 26 and the transition to @Observable macros across all view models.",
            title: "Meeting Notes",
            isFavorite: true,
            summary: "**Medications & Times:**\n• None discussed\n\n**Symptoms & Health:**\n• General wellness\n\n**Other Topics:**\n• iOS 26 roadmap",
            summaryStatus: SummaryStatus.completed.rawValue,
            topicTagsJSON: "[\"General\", \"Appointments\"]"
        ),
        Recording(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-7200),
            audioFileName: "preview2.m4a",
            duration: 45,
            status: .completed,
            fullTranscriptText: "Idea: Use Liquid Glass styling for the new recording app. It should feel lightweight and native to the latest OS version.",
            title: "Quick Thought",
            isFavorite: false
        ),
        Recording(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-86400),
            audioFileName: "preview3.m4a",
            duration: 130,
            status: .recorded,
            fullTranscriptText: "This is the full text of a longer recording that was made yesterday. It should test the multi-line scrolling capabilities of the detail view.",
            title: "Untitled",
            isFavorite: false
        )
    ]
}
