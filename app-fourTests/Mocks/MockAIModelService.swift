import Foundation
@testable import app_four

actor MockAIModelService: AIModelService {
    var stubIsDownloaded = true
    /// Mirrors `stubIsDownloaded` for the nonisolated `localPath` accessor.
    nonisolated(unsafe) var stubLocalPathEnabled = true
    var downloadProgress: [Double] = [0.5, 1.0]
    var shouldThrowOnDownload = false
    var shouldThrowOnDelete = false

    func setShouldThrowOnDownload(_ value: Bool) { shouldThrowOnDownload = value }
    func setShouldThrowOnDelete(_ value: Bool) { shouldThrowOnDelete = value }

    func setStubIsDownloaded(_ value: Bool) {
        stubIsDownloaded = value
        stubLocalPathEnabled = value
    }

    func status(for type: AIModelType) async -> ModelMetadata? {
        ModelMetadata(modelName: type.rawValue, modelType: type.rawValue, isDownloaded: stubIsDownloaded)
    }

    nonisolated func localPath(for type: AIModelType) -> URL? {
        // Mirror filesystem-as-truth: localPath returns nil iff the model is not installed.
        stubLocalPathEnabled ? URL(fileURLWithPath: "/tmp/whisper-model") : nil
    }

    func download(_ type: AIModelType) async throws -> AsyncStream<Double> {
        if shouldThrowOnDownload { throw SummarizationError.inferenceFailed("Mock download error") }
        let progress = downloadProgress
        return AsyncStream { continuation in
            for p in progress { continuation.yield(p) }
            continuation.finish()
        }
    }

    func delete(_ type: AIModelType) async throws {
        if shouldThrowOnDelete { throw SummarizationError.inferenceFailed("Mock delete error") }
        stubIsDownloaded = false
        stubLocalPathEnabled = false
    }
}
