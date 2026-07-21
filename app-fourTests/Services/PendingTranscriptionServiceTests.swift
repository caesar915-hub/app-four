import Foundation
import Testing
import SwiftData
@testable import app_four

/// US3 / T019 — the record-before-model-ready queue. Recordings captured while the
/// transcription model is not yet installed are persisted `.pendingTranscription` and
/// drained automatically, in capture order, serialized on the single engine, through
/// the EXACT existing transcribe → applySummary/setMedicationEvents path.
@MainActor
struct PendingTranscriptionServiceTests {
    var store: RecordingStore
    var container: ModelContainer
    let aiModel = MockAIModelService()
    let summarization = MockSummarizationService()

    init() throws {
        let config = ModelConfiguration(schema: Schema(versionedSchema: SquirlSchemaV1.self), isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Schema(versionedSchema: SquirlSchemaV1.self),
            migrationPlan: SquirlMigrationPlan.self,
            configurations: [config]
        )
        store = RecordingStore(context: container.mainContext)
    }

    private func makePending(_ name: String, createdAt: Date) -> Recording {
        let r = Recording(
            createdAt: createdAt,
            audioFileName: name,
            duration: 10,
            status: .pendingTranscription
        )
        store.addRecording(r)
        return r
    }

    private func makeService(
        transcription: TranscriptionService
    ) -> PendingTranscriptionServiceImpl {
        PendingTranscriptionServiceImpl(
            store: store,
            transcriptionService: transcription,
            summarizationService: summarization,
            aiModelService: aiModel
        )
    }

    // MARK: Model not ready → untouched

    @Test func drainWithModelNotReadyLeavesPendingUntouched() async throws {
        await aiModel.setStubIsDownloaded(false)  // localPath == nil
        let pending = makePending("a.m4a", createdAt: Date())

        let service = makeService(transcription: MockTestTranscriptionService())
        await service.drainIfModelReady()

        #expect(pending.status == .pendingTranscription)  // not transcribed, not failed
        #expect(pending.fullTranscriptText.isEmpty)
    }

    // MARK: Model ready → drains, completes, applies extraction

    @Test func drainWithModelReadyTranscribesAllAndAppliesExtraction() async throws {
        await aiModel.setStubIsDownloaded(true)
        let older = makePending("older.m4a", createdAt: Date(timeIntervalSince1970: 100))
        let newer = makePending("newer.m4a", createdAt: Date(timeIntervalSince1970: 200))

        let service = makeService(transcription: MockTestTranscriptionService())
        await service.drainIfModelReady()

        #expect(older.status == .completed)
        #expect(newer.status == .completed)
        // Transcript text written from the transcription stream.
        #expect(older.fullTranscriptText == "This is a mock transcript.")
        // Extraction applied via the same applySummary path: the stub summary yields
        // mood "positive"/energy "high"/focus "high" → title "Positive · High · High",
        // and the signal columns are populated (FR-014).
        #expect(older.title == "Positive · High · High")
        #expect(older.mood == "positive")
        #expect(older.energyLevel == "high")
        #expect(older.focusLevel == "high")
        // Medication extracted from the stub (Concerta) reaches the model.
        #expect(older.hasMedication == true)
    }

    @Test func drainTranscribesInCaptureOrderOldestFirst() async throws {
        await aiModel.setStubIsDownloaded(true)
        // Insert out of chronological order to prove the service sorts by createdAt.
        let newer = makePending("newer.m4a", createdAt: Date(timeIntervalSince1970: 300))
        let oldest = makePending("oldest.m4a", createdAt: Date(timeIntervalSince1970: 100))
        let middle = makePending("middle.m4a", createdAt: Date(timeIntervalSince1970: 200))

        let recorder = OrderRecordingTranscriptionService()
        let service = makeService(transcription: recorder)
        await service.drainIfModelReady()

        let order = await recorder.order
        #expect(order == ["oldest.m4a", "middle.m4a", "newer.m4a"])
        #expect(oldest.status == .completed)
        #expect(middle.status == .completed)
        #expect(newer.status == .completed)
    }

    // MARK: Deleted-meanwhile recording is skipped (no crash)

    @Test func drainSkipsRecordingDeletedMeanwhile() async throws {
        await aiModel.setStubIsDownloaded(true)
        let keep = makePending("keep.m4a", createdAt: Date(timeIntervalSince1970: 100))
        let doomed = makePending("doomed.m4a", createdAt: Date(timeIntervalSince1970: 200))

        // Delete one before the model-ready check captures the queue, mirroring a user
        // deleting a pending recording via multi-select before it drains.
        store.deleteRecording(doomed)

        let service = makeService(transcription: MockTestTranscriptionService())
        await service.drainIfModelReady()  // must not crash on the missing recording

        #expect(keep.status == .completed)
        #expect(!store.recordings.contains { $0.audioFileName == "doomed.m4a" })
    }

    // MARK: Serialization — no overlapping inference

    @Test func drainSerializesNoOverlappingInference() async throws {
        await aiModel.setStubIsDownloaded(true)
        _ = makePending("s1.m4a", createdAt: Date(timeIntervalSince1970: 100))
        _ = makePending("s2.m4a", createdAt: Date(timeIntervalSince1970: 200))
        _ = makePending("s3.m4a", createdAt: Date(timeIntervalSince1970: 300))

        let concurrencyProbe = ConcurrencyProbeTranscriptionService()
        let service = makeService(transcription: concurrencyProbe)
        await service.drainIfModelReady()

        let maxConcurrent = await concurrencyProbe.maxConcurrent
        #expect(maxConcurrent == 1)  // never two inferences at once on the single engine
        let totalCalls = await concurrencyProbe.totalCalls
        #expect(totalCalls == 3)
    }
}

// MARK: - Test doubles

/// Records the order in which audio files are transcribed.
private actor OrderRecordingTranscriptionService: TranscriptionService {
    private(set) var order: [String] = []

    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        order.append(url.lastPathComponent)
        return AsyncStream { continuation in
            continuation.yield(TranscriptionSegmentDTO(
                text: "This is a mock transcript.",
                startTime: 0, endTime: 10
            ))
            continuation.finish()
        }
    }

    func cancelTranscription() async {}
}

/// Detects whether two transcriptions ever run concurrently. Each call increments a
/// live counter, holds across an await, then decrements — so an overlap would push the
/// observed peak above 1. Filenames here are recording.audioURL.lastPathComponent.
private actor ConcurrencyProbeTranscriptionService: TranscriptionService {
    private var inFlight = 0
    private(set) var maxConcurrent = 0
    private(set) var totalCalls = 0

    func transcribe(audioURL url: URL) async throws -> AsyncStream<TranscriptionSegmentDTO> {
        inFlight += 1
        totalCalls += 1
        maxConcurrent = max(maxConcurrent, inFlight)
        // Yield the actor so a non-serialized caller could interleave a second entry.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 5_000_000)
        inFlight -= 1
        return AsyncStream { continuation in
            continuation.yield(TranscriptionSegmentDTO(
                text: "This is a mock transcript.",
                startTime: 0, endTime: 10
            ))
            continuation.finish()
        }
    }

    func cancelTranscription() async {}
}
