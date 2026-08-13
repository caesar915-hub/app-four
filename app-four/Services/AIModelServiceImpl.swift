import SwiftData
import UIKit
import WhisperKit
import Hub

@MainActor
final class AIModelServiceImpl: AIModelService {
    private let context: ModelContext
    private let fileManager = FileManager.default
    
    // For testing storage limits
    var freeSpaceProvider: () -> Int64? = {
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return attrs?[.systemFreeSize] as? Int64
    }
    
    private(set) var isDownloading: Bool = false

    init(context: ModelContext) {
        self.context = context
    }

    func status(for type: AIModelType) async -> ModelMetadata? {
        let typeString = type.rawValue
        let descriptor = FetchDescriptor<ModelMetadata>(
            predicate: #Predicate { $0.modelType == typeString }
        )
        return try? context.fetch(descriptor).first
    }

    func download(_ type: AIModelType) async throws -> AsyncThrowingStream<Double, Error> {
        AppLogger.log("Starting download for \(type.rawValue)")
        isDownloading = true
        let metadata = try await ensureMetadata(for: type)
        metadata.isDownloaded = false
        try? context.save()

        return AsyncThrowingStream { continuation in
            var bgTask: UIBackgroundTaskIdentifier = .invalid
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "WhisperDownload") {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
            
            let task = Task { @MainActor in
                defer {
                    if bgTask != .invalid {
                        UIApplication.shared.endBackgroundTask(bgTask)
                    }
                }
                do {
                    // Pre-flight check
                    if let freeSpace = self.freeSpaceProvider(), freeSpace < Self.requiredFreeSpace(for: type) {
                        throw ModelDownloadFailure.insufficientSpace
                    }

                    switch type {
                    case .whisper:
                        try await self.downloadWhisperModel { continuation.yield($0) }
                    case .llama:
                        try await self.downloadLlamaModel { continuation.yield($0) }
                    }
                    // A cancelled download must not write back: `metadata` may belong to a
                    // ModelContext that has already been torn down (e.g. the owning screen
                    // was dismissed, or a test finished), which would crash on access.
                    guard !Task.isCancelled else { continuation.finish(); return }
                    metadata.isDownloaded = true
                    metadata.isCorrupted = false
                    try? context.save()
                    AppLogger.log("Download completed for \(type.rawValue)")
                    continuation.yield(1.0)
                    continuation.finish()
                } catch {
                    // A cancellation is the caller tearing the stream down, not a failure to
                    // report: finish quietly so the row settles to filesystem truth.
                    defer { self.isDownloading = false }
                    
                    guard !Task.isCancelled else { continuation.finish(); return }
                    metadata.isCorrupted = true
                    try? context.save()
                    let cause = Self.classify(error)
                    AppLogger.log("Download failed for \(type.rawValue): \(cause)")
                    continuation.finish(throwing: cause)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Maps a raw download error to a content-free, user-messageable cause. Only
    /// the *condition* is derived (connectivity / disk / metered policy); no
    /// payload from the error is forwarded except a short type tag for `.other`.
    nonisolated static func classify(_ error: Error) -> ModelDownloadFailure {
        if let failure = error as? ModelDownloadFailure { return failure }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .dataNotAllowed:
                return .cellularDisabled
            case .notConnectedToInternet, .networkConnectionLost,
                 .cannotConnectToHost, .timedOut:
                return .noNetwork
            default:
                return .other("URLError.\(urlError.code.rawValue)")
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileWriteOutOfSpaceError || nsError.code == NSFileWriteVolumeReadOnlyError {
            return .insufficientSpace
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOSPC) {
            return .insufficientSpace
        }
        return .other(String(describing: Swift.type(of: error)))
    }

    func delete(_ type: AIModelType) async throws {
        let metadata = try await ensureMetadata(for: type)
        switch type {
        case .whisper:
            if fileManager.fileExists(atPath: ModelConstants.whisperDownloadBase.path) {
                try fileManager.removeItem(at: ModelConstants.whisperDownloadBase)
            }
        case .llama:
            if fileManager.fileExists(atPath: ModelConstants.llamaDownloadBase.path) {
                try fileManager.removeItem(at: ModelConstants.llamaDownloadBase)
            }
        }
        metadata.isDownloaded = false
        metadata.isCorrupted = false
        try? context.save()
        AppLogger.log("Deleted model \(type.rawValue)")
    }

    /// Returns a path only if all critical files for the model exist on disk.
    /// Filesystem is the source of truth — SwiftData `isDownloaded` mirrors it.
    nonisolated func localPath(for type: AIModelType) -> URL? {
        switch type {
        case .whisper:
            return Self.findWhisperModelFolder(in: ModelConstants.whisperDownloadBase)
        case .llama:
            return Self.findLlamaModelDirectory(in: ModelConstants.llamaDownloadBase)
        }
    }

    /// Disk headroom required before starting a download: the model payload
    /// plus working room for partial files and unpacking.
    nonisolated static func requiredFreeSpace(for type: AIModelType) -> Int64 {
        switch type {
        case .whisper: return 150_000_000      // ~150 MB
        case .llama:  return 1_500_000_000     // ~740 MB model + slack
        }
    }

    // MARK: - Private

    private func ensureMetadata(for type: AIModelType) async throws -> ModelMetadata {
        if let existing = await status(for: type) { return existing }
        let metadata: ModelMetadata
        switch type {
        case .whisper:
            metadata = ModelMetadata(
                modelName: "openai_whisper-small",
                modelType: type.rawValue,
                modelSize: 74_000_000
            )
        case .llama:
            metadata = ModelMetadata(
                modelName: ModelConstants.llamaHubRepoID,
                modelType: type.rawValue,
                modelSize: 740_000_000
            )
        }
        context.insert(metadata)
        try context.save()
        return metadata
    }

    private func downloadWhisperModel(progress: @escaping @Sendable (Double) -> Void) async throws {
        _ = try await WhisperKit.download(
            variant: "openai_whisper-small",
            downloadBase: ModelConstants.whisperDownloadBase,
            progressCallback: { p in progress(min(p.fractionCompleted, 0.99)) }
        )
    }

    /// Downloads the Llama snapshot into the managed base directory (HubApi cache
    /// layout) so the app owns the model's lifecycle: settings row, delete,
    /// progress, and a stable local path for `MLXJournalService` to load from.
    private func downloadLlamaModel(progress: @escaping @Sendable (Double) -> Void) async throws {
        let hub = HubApi(downloadBase: ModelConstants.llamaDownloadBase)
        _ = try await hub.snapshot(from: ModelConstants.llamaHubRepoID) { p in
            progress(min(p.fractionCompleted, 0.99))
        }
    }

    /// Locates the downloaded Llama snapshot directory (the one that actually
    /// holds the model files) inside the HubApi cache layout. Returns nil for a
    /// missing or partial download — an incomplete directory must never be
    /// handed to the MLX loader.
    nonisolated static func findLlamaModelDirectory(in base: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else { continue }
            let config = url.appendingPathComponent("config.json")
            let tokenizer = url.appendingPathComponent("tokenizer.json")
            let hasConfig = fm.fileExists(atPath: config.path)
            let hasTokenizer = fm.fileExists(atPath: tokenizer.path)
            let hasWeights = ((try? fm.contentsOfDirectory(atPath: url.path)) ?? [])
                .contains { $0.hasSuffix(".safetensors") }
            if hasConfig && hasTokenizer && hasWeights { return url }
        }
        return nil
    }

    nonisolated static func findWhisperModelFolder(in base: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let url as URL in enumerator {
            guard url.lastPathComponent == "openai_whisper-small",
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else { continue }
            // weights/ is only created during a successful file move, not in the skeleton.
            let encoderWeights = url.appendingPathComponent("AudioEncoder.mlmodelc/weights", isDirectory: true)
            let config         = url.appendingPathComponent("config.json")
            guard fm.fileExists(atPath: encoderWeights.path),
                  fm.fileExists(atPath: config.path)
            else { continue }
            return url
        }
        return nil
    }
}
