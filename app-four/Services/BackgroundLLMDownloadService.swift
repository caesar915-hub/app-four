import Foundation
import os

/// Out-of-process background download service for large Hugging Face model snapshots.
///
/// Uses a `URLSessionConfiguration.background` session so `nsurlsessiond` owns the
/// transfer and continues it while the app is suspended or terminated. Each file is
/// downloaded to a staging directory; completed files are skipped on resume; and
/// the whole staging directory is atomically moved to the final model directory when
/// every file is complete.
public final class BackgroundLLMDownloadService: NSObject, Sendable {
    public static let shared = BackgroundLLMDownloadService()

    /// Identifier wired into `AppDelegate.handleEventsForBackgroundURLSession`.
    public static let sessionIdentifier = "com.squirl.app.llm.background-download"

    private var session: URLSession!
    /// Foreground session for the lightweight repo-tree metadata request.
    /// Background sessions forbid data tasks, so the tree fetch must not use `session`.
    private let treeSession = URLSession(configuration: .ephemeral)
    private let state = DownloadState()
    /// Task identifier → staging URL for downloads whose payload was moved into
    /// place. Written synchronously in `didFinishDownloadingTo` and consumed in
    /// `didCompleteWithError`: the session's delegate queue is serial, so the
    /// write is always visible to the later callback — an async hop through the
    /// actor would race it (found on-device after a suspend/resume flush).
    private let movedURLs = OSAllocatedUnfairLock(initialState: [Int: URL]())
    private let fileManager = FileManager.default

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 7 * 24 * 60 * 60
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// Downloads every file from a Hugging Face model repo snapshot.
    /// - Parameters:
    ///   - repoID: Repository in `namespace/name` form (e.g. `mlx-community/Qwen2.5-1.5B-Instruct-4bit`).
    ///   - revision: Git revision to download (default `main`).
    ///   - stagingBase: Directory that will hold the in-progress snapshot. Must be on the same volume as `finalBase` for atomic moves.
    ///   - finalBase: Directory where the completed snapshot is moved.
    ///   - resumeStore: Persistent resume state store for byte-range recovery.
    ///   - progress: Called on an arbitrary queue; throttled to 1% aggregate increments.
    public func downloadSnapshot(
        repoID: String,
        revision: String = "main",
        stagingBase: URL,
        finalBase: URL,
        resumeStore: ResumeStateStore,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let (namespace, name) = try parseRepoID(repoID)
        let entries = try await fetchTreeEntries(namespace: namespace, name: name, revision: revision)
        let fileEntries = entries.filter { $0.type == "file" && !$0.path.hasPrefix(".") }
        guard !fileEntries.isEmpty else {
            throw BackgroundLLMDownloadError.noFilesFound
        }

        let stagingRepoDir = stagingBase.appendingPathComponent(repoID, isDirectory: true)
        let finalRepoDir = finalBase.appendingPathComponent(repoID, isDirectory: true)
        try fileManager.createDirectory(at: stagingRepoDir, withIntermediateDirectories: true)

        // If the final directory already looks complete, skip all work.
        if isCompleteDirectory(finalRepoDir, expectedFiles: fileEntries) {
            progress(1.0)
            return
        }

        let totalBytes = fileEntries.reduce(Int64(0)) { $0 + Int64($1.size ?? 0) }
        let progressTracker = DownloadProgressTracker(totalBytes: totalBytes, progress: progress)
        AppLogger.log("LLM snapshot tree: \(fileEntries.count) files, \(totalBytes) bytes total")

        for entry in fileEntries {
            let sourceURL = resolveURL(namespace: namespace, name: name, revision: revision, path: entry.path)
            let destinationURL = stagingRepoDir.appendingPathComponent(entry.path, isDirectory: false)
            let fileKey = "\(repoID)/\(entry.path)"
            let fileSize = Int64(entry.size ?? 0)

            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if isCompleteFile(destinationURL, expectedSize: fileSize) {
                AppLogger.log("LLM file already staged, skipping: \(entry.path) (\(fileSize) bytes)")
                progressTracker.advance(by: fileSize)
                continue
            }

            let _ = try await downloadFile(
                sourceURL: sourceURL,
                destinationURL: destinationURL,
                fileKey: fileKey,
                fileSize: fileSize,
                resumeStore: resumeStore,
                progress: { delta in progressTracker.advance(by: delta) }
            )
        }

        // Atomic promotion: move the completed staging directory to the final location.
        try promote(stagingDirectory: stagingRepoDir, to: finalRepoDir)
        await resumeStore.removeAll()
        progressTracker.finish()
    }

    /// Reconnects the OS background completion handler passed from `AppDelegate`.
    public func setBackgroundCompletionHandler(_ handler: @escaping @Sendable () -> Void) {
        Task {
            await state.setBackgroundCompletionHandler(handler)
        }
    }

    // MARK: - Private

    private func isCompleteDirectory(_ directory: URL, expectedFiles: [TreeEntry]) -> Bool {
        guard fileManager.fileExists(atPath: directory.path) else { return false }
        for entry in expectedFiles where entry.type == "file" {
            let fileURL = directory.appendingPathComponent(entry.path)
            guard isCompleteFile(fileURL, expectedSize: Int64(entry.size ?? 0)) else { return false }
        }
        return true
    }

    private func isCompleteFile(_ fileURL: URL, expectedSize: Int64) -> Bool {
        guard fileManager.fileExists(atPath: fileURL.path),
              let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64 else { return false }
        return expectedSize > 0 ? size == expectedSize : size > 0
    }

    private func fetchTreeEntries(namespace: String, name: String, revision: String) async throws -> [TreeEntry] {
        let url = URL(string: "https://huggingface.co/api/models/\(namespace)/\(name)/tree/\(revision)?recursive=true")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Squirl-BackgroundLLM/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await treeSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BackgroundLLMDownloadError.treeFetchFailed
        }
        do {
            return try JSONDecoder().decode([TreeEntry].self, from: data)
        } catch {
            throw BackgroundLLMDownloadError.treeDecodeFailed(error)
        }
    }

    private func resolveURL(namespace: String, name: String, revision: String, path: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/\(namespace)/\(name)/resolve/\(revision)/\(path)"
        return components.url!
    }

    private func downloadFile(
        sourceURL: URL,
        destinationURL: URL,
        fileKey: String,
        fileSize: Int64,
        resumeStore: ResumeStateStore,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> URL {
        await resumeStore.load()
        var hasRetriedStaleResume = false
        while true {
            let resumeState = await resumeStore.state(for: fileKey)
            do {
                return try await runDownloadAttempt(
                    sourceURL: sourceURL,
                    destinationURL: destinationURL,
                    fileKey: fileKey,
                    fileSize: fileSize,
                    resumeState: resumeState,
                    resumeStore: resumeStore,
                    progress: progress
                )
            } catch BackgroundLLMDownloadError.badStatus(let status)
                where (status == 412 || status == 416) && !hasRetriedStaleResume {
                // Server rejected the resume (precondition failed / range not
                // satisfiable). State was already cleared in `complete`; retry
                // once as a clean download without surfacing an error (FR-008).
                hasRetriedStaleResume = true
                AppLogger.log("HTTP \(status) for \(fileKey) — stale resume discarded, restarting clean")
            }
        }
    }

    private func runDownloadAttempt(
        sourceURL: URL,
        destinationURL: URL,
        fileKey: String,
        fileSize: Int64,
        resumeState: ResumeState?,
        resumeStore: ResumeStateStore,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> URL {
        let task: URLSessionDownloadTask
        if let resumeState = resumeState {
            AppLogger.log("Resuming \(fileKey) from persisted resume state (\(resumeState.resumeData.count) bytes resumeData)")
            task = session.downloadTask(withResumeData: resumeState.resumeData)
        } else {
            AppLogger.log("Starting fresh download: \(fileKey) (\(fileSize) bytes)")
            var request = URLRequest(url: sourceURL)
            request.setValue("Squirl-BackgroundLLM/1.0", forHTTPHeaderField: "User-Agent")
            task = session.downloadTask(with: request)
        }
        task.taskDescription = destinationURL.path

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    // Register BEFORE resuming: delegate callbacks can only fire after
                    // `task.resume()`, so awaiting registration here closes the race
                    // where a fast completion could reach `state.complete` first.
                    await state.register(
                        task: task,
                        continuation: continuation,
                        progress: progress,
                        resumeStore: resumeStore,
                        fileKey: fileKey,
                        usedResumeState: resumeState != nil
                    )
                    task.resume()
                }
            }
        } onCancel: {
            Task {
                await state.cancel(taskIdentifier: task.taskIdentifier)
            }
        }
    }

    private func promote(stagingDirectory: URL, to finalDirectory: URL) throws {
        // moveItem requires the destination PARENT to exist; on a first-ever
        // install `models/` has never been created (only `staging/` was), so
        // create it here — otherwise promotion always fails (found on-device).
        try fileManager.createDirectory(
            at: finalDirectory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: finalDirectory.path) {
            try fileManager.removeItem(at: finalDirectory)
        }
        try fileManager.moveItem(at: stagingDirectory, to: finalDirectory)
        AppLogger.log("Promoted staged LLM snapshot to \(finalDirectory.lastPathComponent)/\(finalDirectory.deletingLastPathComponent().lastPathComponent)")
    }

    private func parseRepoID(_ repoID: String) throws -> (namespace: String, name: String) {
        let parts = repoID.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            throw BackgroundLLMDownloadError.invalidRepoID(repoID)
        }
        return (String(parts[0]), String(parts[1]))
    }

    private func headerValue(from response: URLResponse?, field: String) -> String? {
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: field)
    }
}

// MARK: - Supporting types

private struct TreeEntry: Codable {
    let path: String
    let type: String
    let size: Int?
}

public enum BackgroundLLMDownloadError: Error, CustomStringConvertible, Sendable {
    case invalidRepoID(String)
    case noFilesFound
    case treeFetchFailed
    case treeDecodeFailed(Error)
    case fileDownloadFailed(String, Error)
    case badStatus(Int)
    case resumeDataMissing
    case promotionFailed(Error)

    public var description: String {
        switch self {
        case .invalidRepoID(let id): return "Invalid repo ID: \(id)"
        case .noFilesFound: return "No files found in snapshot tree"
        case .treeFetchFailed: return "Failed to fetch snapshot tree"
        case .treeDecodeFailed(let error): return "Failed to decode tree: \(error)"
        case .fileDownloadFailed(let path, let error): return "Download failed for \(path): \(error)"
        case .badStatus(let status): return "Unexpected HTTP status \(status)"
        case .resumeDataMissing: return "Resume data missing after cancellation"
        case .promotionFailed(let error): return "Failed to promote staging directory: \(error)"
        }
    }
}

/// Throttles per-file byte progress into aggregate 1% progress callbacks.
private final class DownloadProgressTracker: Sendable {
    private let totalBytes: Int64
    private let progress: @Sendable (Double) -> Void
    private let lock = OSAllocatedUnfairLock(initialState: Int64(0))
    private let lastReportedLock = OSAllocatedUnfairLock(initialState: 0.0)

    init(totalBytes: Int64, progress: @escaping @Sendable (Double) -> Void) {
        self.totalBytes = totalBytes
        self.progress = progress
    }

    func advance(by delta: Int64) {
        let (fraction, shouldReport) = lock.withLock { value -> (Double, Bool) in
            value += delta
            let fraction = totalBytes > 0 ? Double(value) / Double(totalBytes) : 0.0
            let last = lastReportedLock.withLock { $0 }
            if fraction - last >= 0.01 || fraction >= 1.0 {
                lastReportedLock.withLock { $0 = fraction }
                return (fraction, true)
            }
            return (fraction, false)
        }
        if shouldReport { progress(fraction) }
    }

    func finish() {
        progress(1.0)
    }
}

// MARK: - Actor-isolated download state

private actor DownloadState {
    struct Entry {
        let task: URLSessionDownloadTask
        let continuation: CheckedContinuation<URL, Error>
        let progress: @Sendable (Int64) -> Void
        let resumeStore: ResumeStateStore
        let fileKey: String
        let usedResumeState: Bool
    }

    private var entries: [Int: Entry] = [:]
    private var backgroundCompletionHandler: (@Sendable () -> Void)?

    func register(
        task: URLSessionDownloadTask,
        continuation: CheckedContinuation<URL, Error>,
        progress: @escaping @Sendable (Int64) -> Void,
        resumeStore: ResumeStateStore,
        fileKey: String,
        usedResumeState: Bool
    ) {
        entries[task.taskIdentifier] = Entry(
            task: task,
            continuation: continuation,
            progress: progress,
            resumeStore: resumeStore,
            fileKey: fileKey,
            usedResumeState: usedResumeState
        )
    }

    func setBackgroundCompletionHandler(_ handler: @escaping @Sendable () -> Void) {
        backgroundCompletionHandler = handler
    }

    /// Cancels a task, capturing byte-range resume data so the next attempt
    /// continues from the interruption point, then resumes the awaiting caller.
    func cancel(taskIdentifier: Int) async {
        guard let entry = entries.removeValue(forKey: taskIdentifier) else { return }
        let data = await entry.task.cancelByProducingResumeData()
        if let data {
            let state = ResumeState(
                fileKey: entry.fileKey,
                resumeData: data,
                totalBytesExpected: entry.task.countOfBytesExpectedToReceive,
                downloadedBytes: entry.task.countOfBytesReceived,
                etag: nil,
                lastModified: nil
            )
            await entry.resumeStore.setState(state)
            AppLogger.log("Captured \(data.count) bytes resumeData on cancel for \(entry.fileKey)")
        }
        entry.continuation.resume(throwing: CancellationError())
        // `didCompleteWithError` fires afterwards with NSURLErrorCancelled, but the
        // entry is already removed, so `complete` no-ops.
    }

    func reportProgress(taskIdentifier: Int, delta: Int64) {
        entries[taskIdentifier]?.progress(delta)
    }

    func complete(
        taskIdentifier: Int,
        error: Error?,
        resumeData: Data?,
        movedURL: URL?,
        clearResumeState: Bool,
        totalBytesExpected: Int64,
        downloadedBytes: Int64,
        etag: String?,
        lastModified: String?
    ) async {
        guard let entry = entries.removeValue(forKey: taskIdentifier) else { return }
        if let error {
            if let resumeData {
                let state = ResumeState(
                    fileKey: entry.fileKey,
                    resumeData: resumeData,
                    totalBytesExpected: totalBytesExpected,
                    downloadedBytes: downloadedBytes,
                    etag: etag,
                    lastModified: lastModified
                )
                await entry.resumeStore.setState(state)
                AppLogger.log("Persisted resume state for \(entry.fileKey) (\(downloadedBytes)/\(totalBytesExpected) bytes)")
            } else if clearResumeState || entry.usedResumeState {
                // A resume attempt that fails without producing fresh resumeData
                // leaves stale state behind — drop it so the next attempt starts
                // clean instead of looping on the same dead resume (FR-008).
                await entry.resumeStore.removeState(for: entry.fileKey)
            }
            entry.continuation.resume(throwing: error)
        } else if let url = movedURL {
            entry.continuation.resume(returning: url)
        } else {
            entry.continuation.resume(throwing: BackgroundLLMDownloadError.resumeDataMissing)
        }
    }

    func takeBackgroundCompletionHandler() -> (@Sendable () -> Void)? {
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        return handler
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundLLMDownloadService: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task {
            await state.reportProgress(taskIdentifier: downloadTask.taskIdentifier, delta: bytesWritten)
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 206 else {
            // An HTTP error body must never be moved into staging as if it were
            // model bytes. 412/416 mean the resume precondition/range was
            // rejected: clear the stored state so the retry starts clean (FR-008).
            AppLogger.log("LLM download task \(downloadTask.taskIdentifier) returned HTTP \(status) — body discarded")
            Task {
                await state.complete(
                    taskIdentifier: downloadTask.taskIdentifier,
                    error: BackgroundLLMDownloadError.badStatus(status),
                    resumeData: nil,
                    movedURL: nil,
                    clearResumeState: status == 412 || status == 416,
                    totalBytesExpected: downloadTask.countOfBytesExpectedToReceive,
                    downloadedBytes: downloadTask.countOfBytesReceived,
                    etag: nil,
                    lastModified: nil
                )
            }
            return
        }
        guard let destinationPath = downloadTask.taskDescription else { return }
        let destinationURL = URL(fileURLWithPath: destinationPath)

        do {
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            movedURLs.withLock { $0[downloadTask.taskIdentifier] = destinationURL }
        } catch {
            Task {
                await state.complete(
                    taskIdentifier: downloadTask.taskIdentifier,
                    error: error,
                    resumeData: nil,
                    movedURL: nil,
                    clearResumeState: false,
                    totalBytesExpected: 0,
                    downloadedBytes: 0,
                    etag: nil,
                    lastModified: nil
                )
            }
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let taskIdentifier = task.taskIdentifier
        let nsError = error as? NSError
        let resumeData = nsError?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        if let error = error {
            AppLogger.log("LLM download task \(taskIdentifier) failed (HTTP \(status), \(task.countOfBytesReceived)/\(task.countOfBytesExpectedToReceive) bytes, resumeData \(resumeData?.count ?? 0) bytes): \(error.localizedDescription)")
        } else {
            AppLogger.log("LLM download task \(taskIdentifier) finished (HTTP \(status), \(task.countOfBytesReceived) bytes)")
        }
        Task {
            await state.complete(
                taskIdentifier: taskIdentifier,
                error: error,
                resumeData: resumeData,
                movedURL: movedURLs.withLock { $0.removeValue(forKey: taskIdentifier) },
                clearResumeState: false,
                totalBytesExpected: task.countOfBytesExpectedToReceive,
                downloadedBytes: task.countOfBytesReceived,
                etag: headerValue(from: task.response, field: "ETag"),
                lastModified: headerValue(from: task.response, field: "Last-Modified")
            )
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        AppLogger.log("Background session events finished — invoking OS completion handler")
        Task { @MainActor in
            let handler = await state.takeBackgroundCompletionHandler()
            handler?()
        }
    }
}
