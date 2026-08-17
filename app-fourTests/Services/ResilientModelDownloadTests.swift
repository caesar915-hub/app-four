import Testing
import Foundation
@testable import app_four

@Suite(.serialized)
@MainActor
struct ResilientModelDownloadTests {

    /// Serves a scripted outcome per attempt and records how many attempts ran.
    actor AttemptScript {
        enum Outcome {
            case success
            case fail(ModelDownloadFailure)
            /// Never yields, never finishes — stall-watchdog fodder.
            case hang
        }

        private(set) var attempts = 0
        private let outcomes: [Outcome]

        init(outcomes: [Outcome]) {
            self.outcomes = outcomes
        }

        /// The outcome for the next attempt; the last one repeats if the
        /// driver tries more often than scripted.
        func next() -> Outcome {
            attempts += 1
            return outcomes[min(attempts - 1, outcomes.count - 1)]
        }
    }

    private func makeDownload(script: AttemptScript) -> ResilientModelDownload.DownloadAttempt {
        { [script] in
            let outcome = await script.next()
            return AsyncThrowingStream { continuation in
                switch outcome {
                case .success:
                    continuation.yield(1.0)
                    continuation.finish()
                case .fail(let failure):
                    continuation.finish(throwing: failure)
                case .hang:
                    break
                }
            }
        }
    }

    private func makeDriver(
        script: AttemptScript,
        connectivity: MockConnectivity,
        stallTimeout: Duration = .seconds(60)
    ) -> ResilientModelDownload {
        ResilientModelDownload(
            download: makeDownload(script: script),
            connectivity: connectivity,
            allowsCellular: { false },
            stallTimeout: stallTimeout
        )
    }

    /// A network blip mid-download must not be terminal: the driver parks on
    /// the interface stream and retries the moment a permitted network returns.
    @Test func retryableFailureWaitsForNetworkThenSucceeds() async throws {
        let script = AttemptScript(outcomes: [.fail(.noNetwork), .success])
        let connectivity = MockConnectivity(initial: .unsatisfied)
        let driver = makeDriver(script: script, connectivity: connectivity)

        async let run: Void = driver.run()
        // Wait until attempt 1 has run, then bring the network back. Whether
        // this lands before or after the driver subscribes to interfaceChanges
        // is irrelevant — the stream emits the current interface on subscribe.
        while await script.attempts < 1 { await Task.yield() }
        await connectivity.set(.wifi)

        try await run
        #expect(await script.attempts == 2, "Blip → wait for network → one retry → success")
    }

    /// A non-retryable cause surfaces after exactly one attempt — no waiting,
    /// no retry (retrying a full disk would just fail again).
    @Test func nonRetryableFailureSurfacesAfterSingleAttempt() async {
        let script = AttemptScript(outcomes: [.fail(.insufficientSpace)])
        let driver = makeDriver(script: script, connectivity: MockConnectivity(initial: .wifi))

        await #expect(throws: ModelDownloadFailure.insufficientSpace) {
            try await driver.run()
        }
        #expect(await script.attempts == 1, "Insufficient space must not be retried")
    }

    /// `.other` carries no recoverable condition — same single-attempt rule.
    @Test func otherFailureIsNotRetried() async {
        let script = AttemptScript(outcomes: [.fail(.other("URLError.2"))])
        let driver = makeDriver(script: script, connectivity: MockConnectivity(initial: .wifi))

        await #expect(throws: ModelDownloadFailure.other("URLError.2")) {
            try await driver.run()
        }
        #expect(await script.attempts == 1)
    }

    /// A frozen transfer (no bytes, no error) is cancelled by the watchdog and
    /// retried like any retryable failure — the spinner never pins forever.
    @Test func stalledAttemptIsCancelledAndRetried() async throws {
        let script = AttemptScript(outcomes: [.hang, .success])
        let driver = makeDriver(
            script: script,
            connectivity: MockConnectivity(initial: .wifi),
            stallTimeout: .milliseconds(100)
        )

        var values: [Double] = []
        try await driver.run { values.append($0) }

        #expect(await script.attempts == 2, "Stall → watchdog cancels → retry succeeds")
        #expect(values == [1.0], "Only the healthy attempt reports progress")
    }

    /// Tearing the download down mid-attempt breaks the loop without a retry
    /// and surfaces as plain cancellation, never as an error.
    @Test func cancellationStopsLoopWithoutRetrying() async {
        let script = AttemptScript(outcomes: [.hang, .success])
        let driver = makeDriver(script: script, connectivity: MockConnectivity(initial: .wifi))

        let task = Task { try await driver.run() }
        while await script.attempts < 1 { await Task.yield() }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await script.attempts == 1, "Cancellation must not trigger a retry")
    }
}
