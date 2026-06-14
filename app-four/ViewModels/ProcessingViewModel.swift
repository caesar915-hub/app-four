import Foundation
import Observation

/// Orchestrates the post-transcription pipeline: model download (if needed) → ADHD summarization → save.
/// Created by CheckInViewModel after transcription completes and exposed for progress observation.
@Observable
@MainActor
final class ProcessingViewModel {

    // MARK: - State

    enum ProcessingState {
        case idle
        case summarizing
        case saving
        case completed(Recording)
        case failed(String)
    }

    var state: ProcessingState = .idle

    // MARK: - Dependencies

    @ObservationIgnored private let summarizationService: SummarizationService
    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private(set) var activeTask: Task<Void, Never>?

    init(store: RecordingStore, summarizationService: SummarizationService) {
        self.store = store
        self.summarizationService = summarizationService
    }

    // MARK: - Public

    /// Entry point called by CheckInViewModel once transcription text is ready.
    @discardableResult
    func processRawTranscription(
        _ rawText: String,
        duration: TimeInterval,
        language: String?,
        audioFileName: String,
        fillOnly: Bool = false
    ) -> Task<Void, Never> {
        activeTask?.cancel()
        let task = Task {
            await run(rawText: rawText, audioFileName: audioFileName, fillOnly: fillOnly)
        }
        activeTask = task
        return task
    }

    func cancelProcessing() {
        activeTask?.cancel()
        activeTask = nil
        state = .idle
    }

    @discardableResult
    func retry(
        rawText: String,
        duration: TimeInterval,
        language: String?,
        audioFileName: String
    ) -> Task<Void, Never> {
        processRawTranscription(rawText, duration: duration, language: language, audioFileName: audioFileName)
    }

    // MARK: - Private

    private func run(rawText: String, audioFileName: String, fillOnly: Bool = false) async {
        guard !Task.isCancelled else { return }

        // Locate the recording up front so we can record both success and failure on it.
        guard let recording = store.recordings.first(where: { $0.audioFileName == audioFileName }) else {
            state = .failed("Recording not found for file: \(audioFileName)")
            AppLogger.log("ProcessingViewModel: could not locate Recording with audioFileName \(audioFileName)")
            return
        }

        state = .summarizing
        recording.summaryStatus = SummaryStatus.generating.rawValue
        store.save()

        let result: SummaryResult
        do {
            result = try await summarizationService.summarize(rawTranscription: rawText)
        } catch {
            // Surface a clear failure ("Tap to retry") instead of echoing the transcript.
            recording.summaryStatus = SummaryStatus.failed.rawValue
            store.save()
            state = .failed(error.localizedDescription)
            AppLogger.log("ProcessingViewModel: summarization failed: \(error)")
            return
        }

        guard !Task.isCancelled else { return }

        state = .saving
        recording.applySummary(result, fillOnly: fillOnly)
        recording.setMedicationEvents(
            from: result.medications,
            durationHours: result.noteExtraction?.durationHours,
            context: store.context
        )
        store.save()
        state = .completed(recording)
        AppLogger.log("ProcessingViewModel: pipeline complete for \(audioFileName)")
    }

}
