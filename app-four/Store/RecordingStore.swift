import Foundation
import SwiftData

@Observable
@MainActor
class RecordingStore {
    var recordings: [Recording] = []
    private let modelContext: ModelContext
    var context: ModelContext { modelContext }
    
    init(context: ModelContext) {
        self.modelContext = context
        loadRecordings()
        recoverOrphanedTranscriptions()
    }

    /// A recording still marked `.transcribing` at launch cannot have a live task —
    /// the app was killed or relaunched mid-transcription (e.g. its transcription was
    /// cancelled by a second recording and never finalized). Recover it to `.failed`
    /// so the detail view stops showing a permanent "Transcribing…" and offers retry.
    ///
    /// Scoped to `.transcribing` only: a `.pendingTranscription` recording (captured
    /// before the model was ready) is legitimately waiting and MUST NOT be swept — it
    /// drains via `PendingTranscriptionService` once the model lands (FR-016).
    private func recoverOrphanedTranscriptions() {
        let orphaned = recordings.filter { $0.status == .transcribing }
        guard !orphaned.isEmpty else { return }
        for recording in orphaned {
            recording.status = .failed
            if recording.fullTranscriptText.isEmpty {
                recording.fullTranscriptText = "Transcription was interrupted. Tap to retry in the recording detail view."
            }
        }
        try? modelContext.save()
        AppLogger.log("Recovered \(orphaned.count) orphaned .transcribing recording(s) → .failed")
    }

    func loadRecordings() {
        do {
            let mockMode = UserDefaults.standard.bool(forKey: "debugMockMode")
            let descriptor = FetchDescriptor<Recording>(
                predicate: #Predicate { $0.isMockData == mockMode },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            self.recordings = try modelContext.fetch(descriptor)
            AppLogger.log("Loaded \(recordings.count) recordings from SwiftData")
        } catch {
            AppLogger.log("Failed to load recordings: \(error)")
        }
    }
    
    func addRecording(_ recording: Recording) {
        modelContext.insert(recording)
        try? modelContext.save()
        loadRecordings()
    }
    
    func deleteRecording(_ recording: Recording) {
        // AudioFileStorageService handles the actual file deletion
        modelContext.delete(recording)
        try? modelContext.save()
        loadRecordings()
    }
    
    func save() {
        try? modelContext.save()
        // No re-fetch needed: SwiftData reflects mutations to in-memory objects automatically.
        // Notify the shared MedicationBarViewModel so the bar updates across all screens.
        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
    }

    func toggleFavorite(_ recording: Recording) {
        recording.isFavorite.toggle()
        recording.updatedAt = Date()
        try? modelContext.save()
    }

    func updateTitle(_ recording: Recording, newTitle: String) {
        recording.title = newTitle
        recording.updatedAt = Date()
        try? modelContext.save()
    }

    func addCorrectionTags(_ tags: [RecordingTag], for recording: Recording) {
        for tag in tags {
            modelContext.insert(tag)
            tag.recording = recording
        }
    }

    /// Creates a Recording from the text check-in composer. User-picked values are
    /// written directly as the authoritative scalars; the optional note becomes the
    /// transcript for gap-filling extraction (`applySummary(fillOnly: true)`).
    @discardableResult
    func createCheckInNote(_ draft: CheckInDraft) -> Recording {
        let recording = buildAndInsertCheckInNote(draft)
        save()
        loadRecordings()
        return recording
    }

    /// Throwing sibling of `createCheckInNote` for the capture flow: propagates a
    /// persistence failure so the view-model can surface a non-alarming retry surface
    /// instead of silently dropping the draft (FR-009). Overridable (the type is not
    /// final) so a test can force the throw — the SwiftData layer can't be made to
    /// fail on demand otherwise.
    @discardableResult
    func persistCheckInNote(_ draft: CheckInDraft) throws -> Recording {
        let recording = buildAndInsertCheckInNote(draft)
        try modelContext.save()
        // Match save(): a meds-only text check-in must refresh the medication bar,
        // which only updates on this notification.
        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
        loadRecordings()
        return recording
    }

    private func buildAndInsertCheckInNote(_ draft: CheckInDraft) -> Recording {
        let signalParts = [
            draft.mood?.displayLabel, draft.energy?.displayLabel, draft.focus?.displayLabel,
        ].compactMap { $0 }
        let noteWords = draft.trimmedNote.split(separator: " ").prefix(5)
        let title = !signalParts.isEmpty ? signalParts.joined(separator: " · ")
            : !noteWords.isEmpty ? noteWords.joined(separator: " ")
            : "Check-in"

        let recording = Recording(
            audioFileName: "text-\(UUID().uuidString)",
            duration: 0,
            status: .completed,
            fullTranscriptText: draft.trimmedNote,
            title: title,
            hasMedication: !draft.meds.isEmpty,
            energyLevel: draft.energy?.rawValue,
            focusLevel: draft.focus?.rawValue,
            mood: draft.mood?.rawValue,
            sleepQuality: draft.sleepQuality
        )
        modelContext.insert(recording)

        for med in draft.meds {
            let event = MedicationEvent(
                name: med.name,
                dose: med.dose,
                takenAt: med.takenAt,
                taken: true,
                durationHours: med.durationHours,
                source: .manual
            )
            modelContext.insert(event)
            event.recording = recording
        }

        return recording
    }
}
