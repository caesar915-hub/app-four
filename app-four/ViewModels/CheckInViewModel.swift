import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class CheckInViewModel {
    var state: RecordingState = .idle
    var elapsedTime: TimeInterval = 0
    let maxDuration: TimeInterval = LayoutConstants.maxRecordingDuration

    var permissionDenied: Bool = false
    var lowDiskSpace: Bool = false

    @ObservationIgnored private let audioService: AudioRecordingService
    @ObservationIgnored private let storageService: AudioFileStorageService
    @ObservationIgnored private let transcriptionService: TranscriptionService
    @ObservationIgnored private let store: RecordingStore
    private(set) var processingViewModel: ProcessingViewModel

    private var timerTask: Task<Void, Never>?
    private var levelTask: Task<Void, Never>?
    private(set) var transcriptionTask: Task<Void, Never>?

    var timeString: String {
        AccessibilityHelpers.formatDuration(elapsedTime)
    }

    var maxTimeString: String {
        AccessibilityHelpers.formatDuration(maxDuration)
    }

    init(store: RecordingStore, services: AppServices) {
        self.store = store
        self.audioService = services.audioService
        self.storageService = services.storageService
        self.transcriptionService = services.transcriptionService
        self.processingViewModel = ProcessingViewModel(
            store: store,
            summarizationService: services.summarizationService
        )
    }

    @discardableResult
    func startRecording() -> Task<Void, Never> {
        return Task {
            let available = await storageService.availableStorage()
            guard available > LayoutConstants.minDiskSpaceForRecordingBytes else {
                AppLogger.log("Disk space too low: \(available) bytes")
                self.lowDiskSpace = true
                return
            }

            let hasPermission = await audioService.requestPermission()
            guard hasPermission else {
                AppLogger.log("Microphone permission denied.")
                self.permissionDenied = true
                return
            }

            do {
                _ = try await audioService.startRecording()
                self.state = .recording
                UIApplication.shared.isIdleTimerDisabled = true
                self.elapsedTime = 0
                self.promptInterval = Self.loadPromptInterval()

                self.startTimer()
                self.startLevelMonitoring()

                // Preload model off the main actor while the user records
                // so post-recording transcription doesn't need to reload.
                Task.detached(priority: .utility) { [transcriptionService] in
                    do {
                        try await transcriptionService.loadModel()
                    } catch {
                        AppLogger.log("Model preload failed (will retry on stop): \(error)")
                    }
                }
            } catch {
                AppLogger.log("Failed to start recording: \(error)")
            }
        }
    }

    @discardableResult
    func stopRecording() -> Task<Void, Never> {
        // Keep any prior recording's transcription running — we chain after it below.
        self.stopTasks(cancelTranscription: false)
        UIApplication.shared.isIdleTimerDisabled = false
        self.state = .processing

        // The prior in-flight transcription (if any). The new one waits for it so the
        // single WhisperKit actor isn't asked to run two inferences at once, and so a
        // back-to-back recording never cancels the previous one's transcription.
        let priorTranscription = self.transcriptionTask

        return Task {
            do {
                let result = try await audioService.stopRecording()
                let recording = try storageService.saveRecording(from: result.fileURL, duration: result.duration)
                self.store.addRecording(recording)
                self.lastSavedRecording = recording

                // Immediately show done; transcribe in background
                self.state = .done

                self.transcriptionTask = Task {
                    // Let the prior transcription finish first (serialize on the single
                    // Whisper instance). It's never cancelled here, so its work is kept.
                    await priorTranscription?.value
                    await self.transcribeInBackground(recording)
                }
            } catch {
                AppLogger.log("Failed to stop/save: \(error)")
                self.state = .idle
            }
        }
    }

    /// Runs transcription in the background with a timeout so the UI never hangs.
    private func transcribeInBackground(_ recording: Recording) async {
        do {
            let stream = try await transcriptionService.transcribe(audioURL: recording.audioURL)
            try await consumeStreamWithTimeout(stream, for: recording, timeoutSeconds: 300)

            recording.status = .completed
            store.save()
            AppLogger.log("Transcription completed for \(recording.id)")
            processingViewModel.processRawTranscription(
                recording.fullTranscriptText,
                duration: recording.duration,
                language: nil,
                audioFileName: recording.audioFileName
            )
        } catch is CancellationError {
            AppLogger.log("Transcription cancelled for \(recording.id)")
            // The enclosing task is itself cancelled here, so any `await` (incl. an
            // actor hop) may be skipped — finalize the persisted status in a fresh,
            // uncancelled MainActor task so the recording never stays stuck on
            // `.transcribing`. The service was already torn down by the caller's
            // `cancelInFlightServices()`, so no extra cancel call is needed.
            Task { @MainActor [store] in
                recording.status = .failed
                recording.fullTranscriptText = "Transcription cancelled. Tap to retry in the recording detail view."
                store.save()
            }
        } catch RecordingError.timeout {
            AppLogger.log("Transcription timed out for \(recording.id)")
            await transcriptionService.cancelTranscription()
            recording.status = .failed
            recording.fullTranscriptText = "Transcription timed out. Tap to retry in the recording detail view."
            store.save()
        } catch {
            AppLogger.log("Transcription failed for \(recording.id): \(error)")
            recording.status = .failed
            recording.fullTranscriptText = "Transcription failed: \(error.localizedDescription)"
            store.save()
        }
    }

    /// Consumes the transcription stream, racing against a timeout.
    private func consumeStreamWithTimeout(
        _ stream: AsyncStream<TranscriptionSegmentDTO>,
        for recording: Recording,
        timeoutSeconds: UInt64
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Stream consumer — must run on MainActor because Recording is @Model.
            // Guard on each segment: the user may delete this recording via
            // multi-select while transcription is still streaming.
            group.addTask { @MainActor in
                for await segment in stream {
                    guard self.store.recordings.contains(where: { $0.id == recording.id }) else { return }
                    if segment.isError {
                        throw AudioConverterError.conversionFailed(segment.text)
                    }
                    recording.fullTranscriptText = segment.text
                    recording.status = .transcribing
                    self.store.save()
                }
            }

            // Timeout guard
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw RecordingError.timeout
            }

            // Wait for whichever finishes first
            try await group.next()
            group.cancelAll()
        }
    }

    @discardableResult
    func cancelRecording() -> Task<Void, Never> {
        self.stopTasks()
        UIApplication.shared.isIdleTimerDisabled = false
        return Task {
            await audioService.cancelRecording()
            await self.cancelInFlightServices()
            self.state = .idle
            self.elapsedTime = 0
            self.lastSavedRecording = nil
        }
    }

    func reset() {
        UIApplication.shared.isIdleTimerDisabled = false
        state = .idle
        elapsedTime = 0
        lastSavedRecording = nil
    }

    private static func loadPromptInterval() -> TimeInterval {
        let context = AppModelContainer.container.mainContext
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try? context.fetch(descriptor).first {
            return PromptPace(rawValue: settings.promptPaceSeconds)?.interval ?? PromptPace.relaxed.interval
        }
        return PromptPace.relaxed.interval
    }

    // MARK: - Nudges (voice)

    struct NudgePrompt: Equatable {
        let question: String
        let hint: String
    }

    static let nudgePrompts: [NudgePrompt] = [
        NudgePrompt(question: "How's your mood?",       hint: "Heavy, light, flat, bright — whatever fits."),
        NudgePrompt(question: "What's your energy like?", hint: "Wired, steady, or running low."),
        NudgePrompt(question: "Able to focus?",          hint: "Locked in, scattered, somewhere between."),
        NudgePrompt(question: "How did you sleep?",      hint: "Hours, and how rested you feel."),
        NudgePrompt(question: "Any strong feelings?",    hint: "Something sitting with you right now."),
    ]

    /// Seconds per prompt — read from AppSettings on startRecording(), stays stable during a session.
    private(set) var promptInterval: TimeInterval = PromptPace.relaxed.interval

    var currentPromptIndex: Int {
        // Epsilon nudges the boundary so the 0.1s-accumulated elapsedTime lands on
        // the interval mark on time rather than one tick late from float drift.
        Int((elapsedTime + 1e-6) / promptInterval) % Self.nudgePrompts.count
    }

    var currentPrompt: NudgePrompt { Self.nudgePrompts[currentPromptIndex] }

    /// 0.0 → 1.0 progress within the current prompt window (drives the countdown bar).
    var promptProgress: Double {
        (elapsedTime.truncatingRemainder(dividingBy: promptInterval)) / promptInterval
    }

    // MARK: - Text check-in

    private(set) var lastSavedRecording: Recording?

    func saveTextCheckIn(_ draft: CheckInDraft) {
        guard !draft.isEmpty else { return }
        let recording = store.createCheckInNote(draft)
        if !draft.trimmedNote.isEmpty {
            processingViewModel.processRawTranscription(
                draft.trimmedNote,
                duration: 0,
                language: nil,
                audioFileName: recording.audioFileName,
                fillOnly: true
            )
        }
        lastSavedRecording = recording
        state = .done
    }

    // MARK: - Composer support

    var recentMedicationNames: [String] {
        var descriptor = FetchDescriptor<MedicationEvent>(
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        let events = (try? store.context.fetch(descriptor)) ?? []
        var seen = Set<String>()
        var names: [String] = []
        for event in events where seen.insert(event.name.lowercased()).inserted {
            names.append(event.name)
        }
        return Array(names.prefix(4))
    }

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                self.elapsedTime += 0.1
                if self.elapsedTime >= self.maxDuration {
                    self.stopRecording()
                    break
                }
            }
        }
    }

    private func startLevelMonitoring() {
        levelTask = Task {
            for await level in audioService.audioLevelStream {
                if Task.isCancelled { break }
                _ = level
            }
        }
    }

    /// Cancels the local consumer task handles. Synchronous — the async
    /// service-level teardown is handled by `cancelInFlightServices()` from the
    /// structured Task bodies of `stopRecording()` / `cancelRecording()`.
    ///
    /// `cancelTranscription`: discarding a recording (`cancelRecording`) must kill any
    /// in-flight transcription; finishing one to record again (`stopRecording`) must
    /// NOT — the prior recording's transcription is left running and the new one
    /// chains after it, so back-to-back check-ins don't throw away each other's work.
    private func stopTasks(cancelTranscription: Bool = true) {
        timerTask?.cancel()
        timerTask = nil
        levelTask?.cancel()
        levelTask = nil
        if cancelTranscription {
            transcriptionTask?.cancel()
            transcriptionTask = nil
        }
    }

    /// Tears down any in-flight transcription at the service level. Awaited from
    /// structured contexts so cancellation isn't dropped on the floor.
    private func cancelInFlightServices() async {
        await transcriptionService.cancelTranscription()
    }
}
