import Foundation
@testable import app_four

actor MockAIModelService: AIModelService {
    var stubIsDownloaded = true
    /// Mirrors `stubIsDownloaded` for the nonisolated `localPath` accessor.
    nonisolated(unsafe) var stubLocalPathEnabled = true
    var downloadProgress: [Double] = [0.5, 1.0]
    var shouldThrowOnDownload = false
    var shouldThrowOnDelete = false

    /// When set, the download stream yields its progress then terminates by
    /// throwing this specific cause — letting a test drive each failure branch.
    var downloadFailure: ModelDownloadFailure?

    /// When true, the download stream yields its progress and then suspends
    /// indefinitely (an in-flight download), so a test can exercise cancel:
    /// the stream only ends when the consumer tears it down.
    var hangsForCancel = false

    func setShouldThrowOnDownload(_ value: Bool) { shouldThrowOnDownload = value }
    func setShouldThrowOnDelete(_ value: Bool) { shouldThrowOnDelete = value }

    func setDownloadFailure(_ failure: ModelDownloadFailure?) { downloadFailure = failure }
    func setHangsForCancel(_ value: Bool) { hangsForCancel = value }

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

    func download(_ type: AIModelType) async throws -> AsyncThrowingStream<Double, Error> {
        if shouldThrowOnDownload { throw SummarizationError.inferenceFailed("Mock download error") }
        let progress = downloadProgress
        let failure = downloadFailure
        let hangs = hangsForCancel
        return AsyncThrowingStream { continuation in
            let task = Task {
                for p in progress {
                    if Task.isCancelled { break }
                    continuation.yield(p)
                }
                if let failure {
                    continuation.finish(throwing: failure)
                    return
                }
                if hangs {
                    // Stay in-flight until the consumer cancels the stream.
                    while !Task.isCancelled {
                        await Task.yield()
                    }
                    continuation.finish()
                    return
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func delete(_ type: AIModelType) async throws {
        if shouldThrowOnDelete { throw SummarizationError.inferenceFailed("Mock delete error") }
        stubIsDownloaded = false
        stubLocalPathEnabled = false
    }
}
