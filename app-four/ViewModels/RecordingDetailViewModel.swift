import Foundation
import Observation

@Observable
@MainActor
final class RecordingDetailViewModel {
    let recording: Recording

    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private let calendarCoordinator: any CalendarContextCoordinator
    @ObservationIgnored private let summarizationService: SummarizationService
    @ObservationIgnored private let transcriptionService: TranscriptionService
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    private(set) var summaryTask: Task<Void, Never>?

    init(recording: Recording, store: RecordingStore, services: AppServices) {
        self.recording = recording
        self.store = store
        self.calendarCoordinator = services.calendarCoordinator
        self.summarizationService = services.summarizationService
        self.transcriptionService = services.transcriptionService
    }

    deinit {
        retryTask?.cancel()
    }

    func toggleFavorite() {
        store.toggleFavorite(recording)
    }

    func delete() {
        let dayKey = DayKey.make(for: recording.createdAt)
        store.deleteRecording(recording)
        // The coordinator re-derives whether the day still has a check-in at execution
        // time (reentrancy-safe), so no snapshot is passed.
        Task { await calendarCoordinator.checkInDeleted(dayKey: dayKey) }
    }

    func generateSummary() async {
        guard !recording.fullTranscriptText.isEmpty else {
            return
        }

        await performSummarization()
    }

    func regenerateSummary() async {
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
        let oldDay = DayKey.make(for: recording.createdAt)
        recording.createdAt = newDate
        recording.updatedAt = Date()
        store.save()
        let newDay = DayKey.make(for: newDate)
        if oldDay != newDay {
            Task { await calendarCoordinator.checkInDateChanged(from: oldDay, to: newDay) }
        }
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
        retryTask = Task { @MainActor in
            do {
                let stream = try await transcriptionService.transcribe(audioURL: recording.audioURL)
                try await consumeTranscription(stream, timeoutSeconds: 90)
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
        recording.summaryStatus = SummaryStatus.generating.rawValue

        do {
            // Use the same ADHD/Journal path as the automatic post-transcription summary,
            // so Regenerate refreshes the Journal the user actually sees (not stale fields).
            let result = try await summarizationService.summarize(rawTranscription: recording.fullTranscriptText)

            recording.applySummary(result)
            AppLogger.log("Summary generated for \(recording.id)")
            store.save()
        } catch {
            recording.summaryStatus = SummaryStatus.failed.rawValue
            AppLogger.log("Summary failed: \(error.localizedDescription)")
            store.save()
        }
    }
}
