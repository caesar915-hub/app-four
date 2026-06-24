import Foundation
import AVFoundation
import SwiftData

// MARK: - Connectivity

/// The active network interface class, used only to honor `downloadOverCellular`
/// when deciding whether a background model download may start.
enum NetworkInterface: Sendable, Equatable {
    case wifi
    case cellular
    case other
    case unsatisfied
}

/// A live, on-device connectivity check (no permission, no user data) behind a
/// protocol so the download decision is mockable.
protocol Connectivity: Sendable {
    /// The current interface class at the moment of the call.
    var currentInterface: NetworkInterface { get async }

    /// A stream of interface changes so a deferred download can resume when
    /// Wi-Fi returns. The current value is emitted on subscription.
    var interfaceChanges: AsyncStream<NetworkInterface> { get }
}

// MARK: - Pending-Transcription Queue

/// Drains recordings captured before the transcription model was ready.
/// Driven on app launch/foreground and on background-download completion.
/// (Seam only — the draining implementation lands with the queue story.)
protocol PendingTranscriptionService: Sendable {
    /// Fast-path hint that a recording is awaiting the model. Draining also
    /// discovers pending recordings via a fetch, so this is best-effort.
    func enqueue(_ recordingID: PersistentIdentifier) async

    /// Fetch `.pendingTranscription` recordings in capture order; if the model
    /// is ready, transcribe + extract each, serialized on the single engine.
    func drainIfModelReady() async
}

/// Data Transfer Object for transcription segments, ensuring Sendable compliance for Swift 6.
struct TranscriptionSegmentDTO: Sendable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isFinal: Bool
    let confidence: Double?
    let isError: Bool

    nonisolated init(id: UUID = UUID(), text: String, startTime: TimeInterval, endTime: TimeInterval, isFinal: Bool = true, confidence: Double? = nil, isError: Bool = false) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.isFinal = isFinal
        self.confidence = confidence
        self.isError = isError
    }
}

/// Protocol for transcribing audio data into text using Whisper.
protocol TranscriptionService: Sendable {
    /// Transcribes an audio file at the given URL.
    /// - Parameter url: The local URL of the audio file.
    /// - Returns: An async stream of transcription segment DTOs.
    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO>

    /// Cancels any ongoing transcription process.
    func cancelTranscription() async

    /// Preloads the model so it's ready before transcription starts.
    /// Default implementation is a no-op for services that don't require preloading.
    func loadModel() async throws
}

extension TranscriptionService {
    func loadModel() async throws {
        // Default no-op
    }
}

/// Protocol for managing audio recording state and hardware.
protocol AudioRecordingService: Sendable {
    /// Stream of normalized audio power levels (0.0 to 1.0).
    var audioLevelStream: AsyncStream<Float> { get }

    /// Requests microphone permissions.
    func requestPermission() async -> Bool

    /// Starts recording audio to a file.
    /// - Returns: The URL where the recording is being saved.
    func startRecording() async throws -> URL

    /// Pauses the current recording session.
    func pauseRecording() async

    /// Resumes a paused recording session.
    func resumeRecording() async throws

    /// Stops the current recording session and saves the file.
    /// - Returns: Metadata about the finished recording.
    func stopRecording() async throws -> (fileURL: URL, duration: TimeInterval)

    /// Cancels and deletes the current recording.
    func cancelRecording() async
}

/// Protocol for managing audio files in the local filesystem.
protocol AudioFileStorageService: Sendable {
    /// Saves a temporary audio file to the permanent recordings directory.
    @MainActor func saveRecording(from temporaryURL: URL, duration: TimeInterval) throws -> Recording

    /// Deletes a recording file from storage.
    @MainActor func deleteRecording(_ recording: Recording) throws

    /// Returns the full local URL for a given recording filename.
    @MainActor func getAudioURL(for recording: Recording) -> URL?

    /// Exports a transcript to a file.
    @MainActor func exportTranscript(_ recording: Recording, format: ExportFormat) async throws -> URL

    /// Calculates the total storage used by all recordings.
    @MainActor func calculateTotalStorageUsed() async -> Int64

    /// Returns the available disk space.
    func availableStorage() async -> Int64
}

// MARK: - AI Model Management

/// Why a model download could not finish, carried to the UI so it can show a
/// cause-specific message and the right recovery action. Transient (never
/// persisted) and content-free — it names the *condition*, never any
/// transcript or medication data (Principle VI).
enum ModelDownloadFailure: Error, Sendable, Equatable {
    case noNetwork
    case insufficientSpace
    case cellularDisabled
    case other(String)
}

protocol AIModelService: Sendable {
    /// Checks the current metadata for a given model type.
    func status(for type: AIModelType) async -> ModelMetadata?

    /// Downloads the specified AI model.
    /// - Returns: A throwing stream of download progress (0.0 to 1.0). A
    ///   mid-download failure terminates the stream by throwing a
    ///   `ModelDownloadFailure` so the caller learns the cause.
    func download(_ type: AIModelType) async throws -> AsyncThrowingStream<Double, Error>

    /// Deletes the local model to free up space.
    func delete(_ type: AIModelType) async throws

    /// Returns the local file path for the model, if it exists.
    nonisolated func localPath(for type: AIModelType) -> URL?
}

// MARK: - Summarization

struct SummaryResult: Sendable {
    let bullets: [String]
    let medications: [MedEvent]
    let generatedTitle: String
    let energyLevel: String?
    let focusLevel: String?
    let mood: String?
    let sleepHours: Double?
    let sleepQuality: String?
    let sleepEvent: SleepEvent?
    let sleepLevel: String?
    let sideEffects: [String]
    let feelings: [String]
    let topics: [String]
    let noteExtraction: NoteExtraction?

    var hasMedication: Bool { !medications.isEmpty }
}

protocol SummarizationService: Sendable {
    func summarize(rawTranscription: String) async throws -> SummaryResult
}

enum SummarizationError: Error, Sendable {
    case modelNotInstalled
    case contextTooLong
    case timeout
    case parsingFailed
    case inferenceFailed(String)
}
