import Foundation

/// Drives a model download through real-world network conditions, shared by the
/// launch-time background fetch (`SquirlApp`) and the explicit Settings action
/// (`SettingsViewModel`). Wraps one `AIModelService.download(_:)` attempt in an
/// attempt loop:
///
/// - **Retryable failures** (`.noNetwork`, `.cellularDisabled`, a stall): wait
///   for a permitted network interface, then re-invoke `download`. The
///   underlying downloader resumes across retries — the LLM path skips
///   completed staging files and restores byte-range resume data
///   (`ResumeStateStore`); WhisperKit's own cache skips completed files.
/// - **Stall watchdog**: no progress event for `stallTimeout` while an attempt
///   is in flight cancels the attempt and counts as a retryable failure — a
///   frozen transfer must never pin the spinner forever.
/// - **Non-retryable failures** (`.insufficientSpace`, `.other`, untyped
///   errors): rethrow immediately. Cancellation rethrows without retrying.
///
/// Everything is injected (download closure, connectivity, cellular policy,
/// watchdog interval) so tests can drive each branch without a network.
@MainActor
final class ResilientModelDownload {
    /// One download attempt: starts (or resumes) the model fetch and returns
    /// its progress stream. Called again for every retry.
    typealias DownloadAttempt = @Sendable () async throws -> AsyncThrowingStream<Double, Error>

    private let download: DownloadAttempt
    private let connectivity: any Connectivity
    private let allowsCellular: @MainActor () -> Bool
    private let stallTimeout: Duration
    private let maxAttempts: Int

    init(
        download: @escaping DownloadAttempt,
        connectivity: any Connectivity,
        allowsCellular: @escaping @MainActor () -> Bool,
        stallTimeout: Duration = .seconds(45),
        maxAttempts: Int = 8
    ) {
        self.download = download
        self.connectivity = connectivity
        self.allowsCellular = allowsCellular
        self.stallTimeout = stallTimeout
        self.maxAttempts = maxAttempts
    }

    /// Runs attempts until success, a non-retryable failure, cancellation, or
    /// the attempt cap. Progress events from each attempt are forwarded as-is
    /// (a retry re-reports completed files quickly as the Hub cache skips them).
    func run(onProgress: @escaping @MainActor (Double) -> Void = { _ in }) async throws {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            attempt += 1
            AppLogger.log("Model download attempt \(attempt)/\(maxAttempts)")
            do {
                let stream = try await download()
                try await consume(stream, onProgress: onProgress)
                // A cancelled consumer can see its stream end quietly — a
                // teardown must never read as success.
                try Task.checkCancellation()
                AppLogger.log("Model download completed (attempt \(attempt))")
                return
            } catch is CancellationError {
                // Caller tore the download down — not a failure, never retried.
                throw CancellationError()
            } catch let failure as ModelDownloadFailure {
                guard failure.isRetryable else {
                    AppLogger.log("Model download failed, not retryable: \(failure)")
                    throw failure
                }
                guard attempt < maxAttempts else {
                    AppLogger.log("Model download gave up after \(attempt) attempts: \(failure)")
                    throw failure
                }
                AppLogger.log("Model download failed (\(failure)); waiting for a permitted network (attempt \(attempt)/\(maxAttempts))")
                try await waitForPermittedNetwork()
            } catch is DownloadStalled {
                guard attempt < maxAttempts else {
                    AppLogger.log("Model download gave up after \(attempt) attempts: stalled")
                    throw ModelDownloadFailure.other("DownloadStalled")
                }
                AppLogger.log("Model download stalled; waiting for a permitted network (attempt \(attempt)/\(maxAttempts))")
                try await waitForPermittedNetwork()
            } catch {
                AppLogger.log("Model download failed, not retryable: \(error)")
                throw error
            }
        }
    }

    // MARK: - Private

    /// Marker for a watchdog-cancelled attempt; mapped to a retryable failure
    /// (or `.other` once attempts run out) so it never reaches the UI raw.
    private struct DownloadStalled: Error {}

    /// Consumes one attempt's stream, enforcing the stall watchdog: the
    /// watchdog wins the race when no progress event arrives for
    /// `stallTimeout`, which cancels the consumer (tearing down the underlying
    /// download via the stream's `onTermination`).
    private func consume(
        _ stream: AsyncThrowingStream<Double, Error>,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let monitor = StallMonitor()
        let stallTimeout = self.stallTimeout
        let stalled = try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                for try await progress in stream {
                    await monitor.beat()
                    await onProgress(progress)
                }
                return false
            }
            group.addTask {
                while true {
                    try await Task.sleep(for: stallTimeout / 4)
                    if await monitor.isStalled(after: stallTimeout) { return true }
                }
            }
            // First finisher decides: consumer done/error, or watchdog fired.
            let first = try await group.next() ?? false
            group.cancelAll()
            // Drain the loser without propagating its cancellation.
            while let _ = try? await group.next() {}
            return first
        }
        if stalled { throw DownloadStalled() }
    }

    /// Suspends until connectivity reports an interface the download may use
    /// (Wi-Fi always; cellular only when the user allowed it). The stream
    /// emits the current interface on subscription, so an already-permitted
    /// network retries immediately.
    private func waitForPermittedNetwork() async throws {
        for await interface in connectivity.interfaceChanges {
            try Task.checkCancellation()
            let permitted = NetworkConnectivity.shouldStartDownload(
                overCellular: allowsCellular(),
                interface: interface
            )
            if permitted { return }
        }
    }
}

/// Last-progress timestamp shared between an attempt's consumer and its
/// watchdog.
private actor StallMonitor {
    private var lastProgress = ContinuousClock.now

    func beat() {
        lastProgress = .now
    }

    func isStalled(after timeout: Duration) -> Bool {
        ContinuousClock.now - lastProgress >= timeout
    }
}

private extension ModelDownloadFailure {
    /// Worth waiting out the network for; everything else is surfaced as-is.
    var isRetryable: Bool {
        self == .noNetwork || self == .cellularDisabled
    }
}
