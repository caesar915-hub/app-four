import Foundation
import Observation
import SwiftData

/// Orchestrates the post-transcription pipeline: model download (if needed) → ADHD summarization → save.
/// Created by CheckInViewModel after transcription completes. Progress is reflected on the persisted
/// `Recording.summaryStatus` (the single source of truth the UI observes), not on in-memory state.
@Observable
@MainActor
final class ProcessingViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let summarizationService: SummarizationService
    @ObservationIgnored private let store: RecordingStore
    @ObservationIgnored private(set) var activeTask: Task<Void, Never>?
    
    var showMemoryError: Bool = false

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
    }

    // MARK: - Private

    private func run(rawText: String, audioFileName: String, fillOnly: Bool = false) async {
        guard !Task.isCancelled else { return }

        var descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.audioFileName == audioFileName }
        )
        descriptor.fetchLimit = 1
        let fetched: [Recording]
        do {
            fetched = try store.context.fetch(descriptor)
        } catch {
            AppLogger.log("ProcessingViewModel: fetch failed for \(audioFileName): \(error)")
            return
        }
        guard let recording = fetched.first else {
            AppLogger.log("ProcessingViewModel: could not locate Recording with audioFileName \(audioFileName)")
            return
        }

        recording.summaryStatus = SummaryStatus.generating.rawValue
        store.save()

        let result: SummaryResult
        do {
            result = try await summarizationService.summarize(rawTranscription: rawText)
        } catch SummarizationError.insufficientMemory {
            showMemoryError = true
            result = ExtractionValidator.fallbackResult(rawTranscript: rawText)
            AppLogger.log("ProcessingViewModel: insufficient memory, applying fallback result.")
        } catch {
            // Surface a clear failure ("Tap to retry") instead of echoing the transcript.
            recording.summaryStatus = SummaryStatus.failed.rawValue
            store.save()
            AppLogger.log("ProcessingViewModel: summarization failed: \(error)")
            return
        }

        guard !Task.isCancelled else { return }

        recording.applySummary(result, fillOnly: fillOnly)
        recording.setMedicationEvents(
            from: result.medications,
            durationHours: result.noteExtraction?.durationHours,
            context: store.context
        )
        store.save()
        AppLogger.log("ProcessingViewModel: pipeline complete for \(audioFileName)")
    }

}
