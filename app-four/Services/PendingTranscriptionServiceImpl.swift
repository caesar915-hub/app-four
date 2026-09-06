import Foundation
import SwiftData

/// Drains recordings captured before the transcription model was ready (US3).
///
/// A recording finished while the model is not installed is persisted
/// `.pendingTranscription` by the Check-in stop path. This actor fetches those in
/// capture order and, once the model lands, runs each through the EXACT existing
/// transcribe → `applySummary`/`setMedicationEvents` path — adding a serialized queue
/// around that path, never changing it.
///
/// Serialization: the single WhisperKit engine cannot run two inferences at once, so
/// draining is one-recording-at-a-time. `isDraining` coalesces concurrent or re-entrant
/// `drainIfModelReady()` calls (launch, foreground, download-completion) into a single
/// pass — the actor's reentrancy at `await` points would otherwise let a second pass
/// start an overlapping inference.
actor PendingTranscriptionServiceImpl: PendingTranscriptionService {
    private let store: RecordingStore
    private let transcriptionService: TranscriptionService
    private let summarizationService: SummarizationService

    private var isDraining = false

    init(
        store: RecordingStore,
        transcriptionService: TranscriptionService,
        summarizationService: SummarizationService
    ) {
        self.store = store
        self.transcriptionService = transcriptionService
        self.summarizationService = summarizationService
    }

    func drainIfModelReady() async {
        // SpeechAnalyzer assets are system-managed: attempt an install, then gate on
        // whether the engine can transcribe now (asset installed for the resolved locale).
        try? await transcriptionService.loadModel()
        guard await transcriptionService.isModelReady() else { return }
        guard !isDraining else { return }
        isDraining = true
        defer { isDraining = false }

        let ids = await pendingRecordingIDsOldestFirst()
        guard !ids.isEmpty else { return }
        AppLogger.log("PendingTranscriptionService: draining \(ids.count) pending recording(s)")

        for id in ids {
            // Readiness can change between recordings (asset reclaimed); re-check.
            guard await transcriptionService.isModelReady() else { return }
            await drain(id)
        }
    }

    /// Identifies `.pendingTranscription` recordings in capture order by their stable
    /// `id` (UUID). The id (not the `@Model`) crosses the actor hop so we re-resolve each
    /// on the MainActor at drain time — a recording deleted meanwhile simply isn't found.
    @MainActor
    private func pendingRecordingIDsOldestFirst() -> [UUID] {
        store.recordings
            .filter { $0.status == .pendingTranscription }
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.id)
    }

    /// Drains one recording through the existing transcribe → extract path. Serialized
    /// by the actor: this returns before the next recording starts, so the single engine
    /// never runs two inferences at once.
    private func drain(_ id: UUID) async {
        guard let audioURL = await resolveAudioURL(id) else { return }  // deleted meanwhile

        do {
            let text = try await transcribe(audioURL: audioURL, id: id)
            try Task.checkCancellation()
            let result = try await summarizationService.summarize(rawTranscription: text)
            await applyResult(result, to: id)
        } catch is CancellationError {
            AppLogger.log("PendingTranscriptionService: drain cancelled for \(id)")
        } catch {
            AppLogger.log("PendingTranscriptionService: drain failed for \(id): \(error)")
            await markFailed(id, message: "Transcription failed: \(error.localizedDescription)")
        }
    }

    /// Runs transcription and writes streamed text onto the recording, mirroring
    /// `CheckInViewModel.transcribeInBackground`'s stream consumption (status `.transcribing`
    /// while in flight, guard on each segment that the recording still exists).
    private func transcribe(audioURL: URL, id: UUID) async throws -> String {
        let stream = try await transcriptionService.transcribe(audioURL: audioURL)
        var lastText = ""
        for await segment in stream {
            if segment.isError { throw AudioConverterError.conversionFailed(segment.text) }
            let stillPresent = await writeSegment(segment.text, to: id)
            guard stillPresent else { throw CancellationError() }
            lastText = segment.text
        }
        return lastText
    }

    @MainActor
    private func resolveAudioURL(_ id: UUID) -> URL? {
        store.recordings.first { $0.id == id }?.audioURL
    }

    /// Writes one transcript segment; returns false if the recording was deleted so the
    /// caller stops (no crash on a vanished `@Model`).
    @MainActor
    private func writeSegment(_ text: String, to id: UUID) -> Bool {
        guard let recording = store.recordings.first(where: { $0.id == id }) else {
            return false
        }
        recording.fullTranscriptText = text
        recording.status = .transcribing
        return true
    }

    /// Applies extraction exactly as the normal post-recording path does
    /// (`ProcessingViewModel.run`): `applySummary` then `setMedicationEvents`, then
    /// `.completed`. Skips a recording deleted meanwhile.
    @MainActor
    private func applyResult(_ result: SummaryResult, to id: UUID) {
        guard let recording = store.recordings.first(where: { $0.id == id }) else {
            return
        }
        recording.applySummary(result)
        recording.setMedicationEvents(
            from: result.medications,
            durationHours: result.noteExtraction?.durationHours,
            context: store.context
        )
        recording.status = .completed
        store.save()
        AppLogger.log("PendingTranscriptionService: completed \(id)")
    }

    @MainActor
    private func markFailed(_ id: UUID, message: String) {
        guard let recording = store.recordings.first(where: { $0.id == id }) else {
            return
        }
        recording.status = .failed
        recording.fullTranscriptText = message
        store.save()
    }
}
