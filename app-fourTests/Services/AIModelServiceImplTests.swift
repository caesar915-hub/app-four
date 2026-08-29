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
        service.whisperDownloadBaseForTests = temporaryDownloadBase()
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

    // MARK: - Pre-flight storage check

    @Test func downloadThrowsStorageErrorIfInsufficientSpace() async throws {
        // We will simulate insufficient space by injecting a mock closure
        service.freeSpaceProvider = { 100_000_000 } // 100MB (less than the 600MB buffer)
        
        await #expect(throws: ModelDownloadFailure.insufficientSpace) {
            let stream = try await service.download(.whisper)
            for try await _ in stream {}
        }
    }

    // MARK: - LLM model lifecycle

    @Test func llmRequiresMoreFreeSpaceThanWhisper() {
        #expect(AIModelServiceImpl.requiredFreeSpace(for: .llm)
                > AIModelServiceImpl.requiredFreeSpace(for: .whisper))
    }

    @Test func downloadThrowsStorageErrorForLLMWhenTight() async throws {
        service.freeSpaceProvider = { 200_000_000 } // too small for either model; exercises the LLM path
        await #expect(throws: ModelDownloadFailure.insufficientSpace) {
            let stream = try await service.download(.llm)
            for try await _ in stream {}
        }
    }

    @Test func localPathReturnsNilWhenLLMDirectoryAbsent() {
        service.llmDownloadBaseForTests = temporaryDownloadBase()
        #expect(service.localPath(for: .llm) == nil)
    }

    private func temporaryDownloadBase() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("aimodel-test-\(UUID().uuidString)")
    }

    @Test func findLLMModelDirectoryRequiresAllCriticalFiles() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }

        // HubApi layout, scoped to the configured repo:
        // models/<repo-id>/snapshots/<hash>/
        let repoDir = base
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(ModelConstants.llmHubRepoID, isDirectory: true)

        // Partial download: config only → nil.
        let partial = repoDir.appendingPathComponent("snapshots/abc123")
        try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        try "{}".write(to: partial.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        #expect(AIModelServiceImpl.findLLMModelDirectory(in: base) == nil)

        // Complete: config + tokenizer + weights → found.
        try "{}".write(to: partial.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try Data().write(to: partial.appendingPathComponent("model.safetensors"))
        let found = try #require(AIModelServiceImpl.findLLMModelDirectory(in: base))
        #expect(found.lastPathComponent == "abc123")
        #expect(found.deletingLastPathComponent().lastPathComponent == "snapshots")

        // A complete snapshot of a DIFFERENT repo must never be picked up.
        try FileManager.default.removeItem(at: repoDir)
        let stale = base
            .appendingPathComponent("models/mlx-community/Llama-3.2-1B-Instruct-4bit/snapshots/old", isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        try "{}".write(to: stale.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        try "{}".write(to: stale.appendingPathComponent("tokenizer.json"), atomically: true, encoding: .utf8)
        try Data().write(to: stale.appendingPathComponent("model.safetensors"))
        #expect(AIModelServiceImpl.findLLMModelDirectory(in: base) == nil)
    }
}
