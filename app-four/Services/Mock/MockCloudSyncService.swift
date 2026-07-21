import Foundation

/// Scriptable mock for `CloudSyncService` — drives view-model and gating tests
/// without a live iCloud account. MainActor-isolated (Sendable) so tests can script
/// state synchronously.
@MainActor
final class MockCloudSyncService: CloudSyncService {
    /// Scripted account availability returned by `accountStatus()`.
    var scriptedAccountStatus: SyncAccountStatus
    /// If set, `removeFromICloud()` throws this.
    var scriptedRemoveFailure: SyncFailure?

    private(set) var enabled: Bool
    private(set) var removeFromICloudCalled = false

    private var currentState: SyncState
    private var subscribers: [UUID: AsyncStream<SyncState>.Continuation] = [:]

    init(accountStatus: SyncAccountStatus = .available, startEnabled: Bool = false) {
        self.scriptedAccountStatus = accountStatus
        self.enabled = startEnabled
        self.currentState = SyncState(
            enabled: startEnabled,
            accountStatus: accountStatus,
            phase: .idle,
            lastSyncedAt: nil
        )
    }

    var state: AsyncStream<SyncState> {
        let (stream, continuation) = AsyncStream.makeStream(of: SyncState.self)
        let id = UUID()
        continuation.yield(currentState)
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.subscribers[id] = nil }
        }
        return stream
    }

    func accountStatus() async -> SyncAccountStatus { scriptedAccountStatus }

    var isSyncEnabled: Bool { get async { enabled } }

    func setSyncEnabled(_ enabled: Bool) async throws {
        if enabled, scriptedAccountStatus != .available {
            throw SyncFailure.notAuthenticated
        }
        self.enabled = enabled
        emit()
    }

    func removeFromICloud() async throws {
        if let failure = scriptedRemoveFailure { throw failure }
        removeFromICloudCalled = true
        enabled = false          // disable first, then purge cloud (FR-011)
        emit()
    }

    private func emit() {
        let phase: SyncPhase = enabled && scriptedAccountStatus != .available
            ? .unavailable(scriptedAccountStatus)
            : .idle
        currentState = SyncState(enabled: enabled, accountStatus: scriptedAccountStatus, phase: phase, lastSyncedAt: nil)
        for continuation in subscribers.values {
            continuation.yield(currentState)
        }
    }
}
