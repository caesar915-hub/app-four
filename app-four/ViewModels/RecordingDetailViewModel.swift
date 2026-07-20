import Foundation
import Observation

@Observable
@MainActor
final class RecordingDetailViewModel {
    let recording: Recording

    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private let summarizationService: SummarizationService
    @ObservationIgnored private let transcriptionService: TranscriptionService
    // Both stay @ObservationIgnored: no view observes them, and `deinit` is nonisolated —
    // an @Observable-tracked property becomes a MainActor-isolated computed accessor,
    // which a nonisolated deinit cannot legally read.
    @ObservationIgnored private(set) var retryTask: Task<Void, Never>?
    @ObservationIgnored private(set) var summaryTask: Task<Void, Never>?

    /// Captured at init so the lifecycle guards never have to read a property off a
    /// possibly-freed @Model just to learn which row to look up.
    @ObservationIgnored private let recordingID: UUID

    init(recording: Recording, store: RecordingStore, services: AppServices) {
        self.recording = recording
        self.recordingID = recording.id
        self.store = store
        self.summarizationService = services.summarizationService
        self.transcriptionService = services.transcriptionService
    }

    deinit {
        retryTask?.cancel()
        summaryTask?.cancel()
    }

    func toggleFavorite() {
        store.toggleFavorite(recording)
    }

    func delete() {
        // Stop in-flight retry/summarization first: both write to `recording` across
        // long awaits, and mutating a deleted @Model traps in SwiftData. The
        // `store.exists` guards below are the backstop for work already past its
        // own cancellation check when this fires.
        retryTask?.cancel()
        summaryTask?.cancel()
        store.deleteRecording(recording)
    }

    func generateSummary() async {
        guard store.exists(recordingID), !recording.fullTranscriptText.isEmpty else {
            return
        }

        await performSummarization()
    }

    func regenerateSummary() async {
        guard store.exists(recordingID) else { return }
        recording.summary = nil
        recording.topicTagsJSON = nil
        recording.summaryStatus = SummaryStatus.notGenerated.rawValue
        store.save()
        await generateSummary()
    }

    func startRegenerate() {
        summaryTask?.cancel()
        summaryTask = Task { await self.regenerateSummary() }
    }

    func updateTitle(_ newTitle: String) {
        recording.title = newTitle
        recording.updatedAt = Date()
        store.save()
    }

    func updateDate(_ newDate: Date) {
        recording.createdAt = newDate
        recording.updatedAt = Date()
        store.save()
    }

    func updateMood(_ newMood: String) {
        recording.mood = newMood.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        recording.updatedAt = Date()
        store.save()
    }

    // MARK: - Retry transcription

    /// Re-runs transcription for a recording that previously failed or timed out, bounded by a
    /// human-scale timeout, then refreshes the summary from the new transcript (feedback §4.2).
    func retryTranscription() {
        guard recording.status == .failed else { return }
        recording.status = .transcribing
        recording.fullTranscriptText = ""
        store.save()

        retryTask?.cancel()
        // Read the URL while the model is provably alive; the task must not have to
        // touch `recording` before its own existence guard runs.
        let audioURL = recording.audioURL
        // `[weak self]` breaks the self→task→self cycle that made `deinit`'s cancel
        // unreachable for the whole 90 s the stream was running.
        retryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let stream = try await transcriptionService.transcribe(audioURL: audioURL)
                try await consumeTranscription(stream, timeoutSeconds: 90)
                guard store.exists(recordingID) else { return }
                recording.status = .completed
                store.save()
                await regenerateSummary()
            } catch is CancellationError {
                finishFailed("Transcription cancelled. Tap Retry to try again.")
            } catch RecordingError.timeout {
                await transcriptionService.cancelTranscription()
                finishFailed("Transcription timed out. Tap Retry to try again.")
            } catch {
                finishFailed("Transcription failed: \(error.localizedDescription)")
            }
        }
    }

    private func finishFailed(_ message: String) {
        guard store.exists(recordingID) else { return }
        recording.status = .failed
        recording.fullTranscriptText = message
        store.save()
    }

    private func consumeTranscription(
        _ stream: AsyncStream<TranscriptionSegmentDTO>,
        timeoutSeconds: UInt64
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                for await segment in stream {
                    // The user can delete this recording mid-stream (confirm → dismiss →
                    // onDisappear → delete()); never write into a freed @Model.
                    guard self.store.exists(self.recordingID) else { return }
                    if segment.isError {
                        throw AudioConverterError.conversionFailed(segment.text)
                    }
                    self.recording.fullTranscriptText = segment.text
                    self.recording.status = .transcribing
                    self.store.save()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw RecordingError.timeout
            }
            try await group.next()
            group.cancelAll()
        }
    }

    // MARK: - Private

    private func performSummarization() async {
        guard store.exists(recordingID) else { return }
        recording.summaryStatus = SummaryStatus.generating.rawValue

        do {
            // Use the same ADHD/Journal path as the automatic post-transcription summary,
            // so Regenerate refreshes the Journal the user actually sees (not stale fields).
            let result = try await summarizationService.summarize(rawTranscription: recording.fullTranscriptText)

            guard store.exists(recordingID) else { return }
            recording.applySummary(result)
            AppLogger.log("Summary generated for \(recordingID)")
            store.save()
        } catch {
            guard store.exists(recordingID) else { return }
            recording.summaryStatus = SummaryStatus.failed.rawValue
            AppLogger.log("Summary failed: \(error.localizedDescription)")
            store.save()
        }
    }
}
