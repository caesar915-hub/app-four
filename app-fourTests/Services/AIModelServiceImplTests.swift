import Testing
import SwiftData
import Foundation
@testable import app_four

@Suite(.serialized)
@MainActor
struct AIModelServiceImplTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: ModelMetadata.self, configurations: config)
    }()

    var service: AIModelServiceImpl
    var container: ModelContainer { Self.container }

    init() throws {
        try Self.container.mainContext.delete(model: ModelMetadata.self)
        service = AIModelServiceImpl(context: Self.container.mainContext)
    }

    // MARK: - status(for:)

    @Test func statusReturnsNilBeforeAnyDownload() async {
        #expect(await service.status(for: .whisper) == nil)
    }

    @Test func statusReturnsMetadataAfterInsert() async throws {
        let meta = ModelMetadata(
            modelName: "openai_whisper-small",
            modelType: AIModelType.whisper.rawValue,
            isDownloaded: true
        )
        container.mainContext.insert(meta)
        try container.mainContext.save()

        let result = await service.status(for: .whisper)
        #expect(result != nil)
        #expect(result?.isDownloaded == true)
    }

    // MARK: - delete()

    @Test func deleteResetsIsDownloadedAndCorruptedFlags() async throws {
        let meta = ModelMetadata(
            modelName: "openai_whisper-small",
            modelType: AIModelType.whisper.rawValue,
            isDownloaded: true,
            isCorrupted: true
        )
        container.mainContext.insert(meta)
        try container.mainContext.save()

        try await service.delete(.whisper)

        let updated = await service.status(for: .whisper)
        #expect(updated?.isDownloaded == false)
        #expect(updated?.isCorrupted == false)
    }

    @Test func deleteDoesNotThrowWhenFilesAbsent() async throws {
        // delete() must succeed even when no model files exist on disk.
        let meta = ModelMetadata(
            modelName: "openai_whisper-small",
            modelType: AIModelType.whisper.rawValue,
            isDownloaded: false
        )
        container.mainContext.insert(meta)
        try container.mainContext.save()

        try await service.delete(.whisper)

        #expect(await service.status(for: .whisper)?.isDownloaded == false)
    }

    // MARK: - localPath(for:) — filesystem truth

    @Test func localPathReturnsNilWhenWhisperDirectoryAbsent() {
        #expect(service.localPath(for: .whisper) == nil)
    }

    // MARK: - download stream lifecycle

    @Test func downloadCreatesMetadataOnFirstCall() async throws {
        #expect(await service.status(for: .whisper) == nil, "Precondition: no metadata yet")

        // Start the download then immediately cancel via task cancellation.
        // ensureMetadata is awaited before the stream is returned, so metadata is
        // created regardless of whether the network download proceeds.
        let downloadTask = Task {
            let stream = try await self.service.download(.whisper)
            for try await _ in stream { break }
        }
        downloadTask.cancel()
        try? await downloadTask.value

        let meta = await service.status(for: .whisper)
        #expect(meta != nil, "Metadata should be created when download begins")
    }
}
