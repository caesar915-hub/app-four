import Foundation
import CloudKit

// MARK: - Opt-in iCloud Sync seam (spec 038)
//
// The sync capability sits behind a `Services/` protocol injected via
// `AppDependencies` (Constitution VIII), mockable at the seam. All types here are
// transient and content-free — they name the *condition*, never any transcript or
// medication content (Constitution VI). See specs/038-icloud-sync/contracts/.

/// Availability of the user's iCloud account, mapped from `CKAccountStatus`.
/// `nonisolated` (project default isolation is `MainActor`) so its `Equatable`
/// conformance is usable from any context — e.g. nonisolated tests.
nonisolated enum SyncAccountStatus: Sendable, Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    /// Pure mapping from CloudKit's account status — testable without an account.
    init(from ckStatus: CKAccountStatus) {
        switch ckStatus {
        case .available: self = .available
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        case .couldNotDetermine: self = .couldNotDetermine
        @unknown default: self = .couldNotDetermine
        }
    }
}

/// Why a sync operation could not complete, carried to the UI so it can show a
/// cause-specific, honest message (never a false "synced"). Content-free per VI.
nonisolated enum SyncFailure: Error, Sendable, Equatable {
    case quotaExceeded
    case network
    case notAuthenticated
    case rateLimited(retryAfterSeconds: Double?)
    case other(String)

    /// Pure mapping from a CloudKit error — testable without live CloudKit.
    /// The `.other` payload carries only the error's *code/type name*, never a
    /// server message that could echo user content (Principle VI).
    init(from error: Error) {
        guard let ck = error as? CKError else {
            self = .other(String(describing: type(of: error)))
            return
        }
        switch ck.code {
        case .quotaExceeded:
            self = .quotaExceeded
        case .networkUnavailable, .networkFailure:
            self = .network
        case .notAuthenticated:
            self = .notAuthenticated
        case .requestRateLimited, .zoneBusy, .serviceUnavailable:
            self = .rateLimited(retryAfterSeconds: ck.retryAfterSeconds)
        default:
            self = .other(String(describing: ck.code))
        }
    }
}

/// Current sync activity, driving the Settings status rows (FR-009/FR-013).
nonisolated enum SyncPhase: Sendable, Equatable {
    case idle
    case syncing
    case stalled(SyncFailure)
    case unavailable(SyncAccountStatus)
}

/// Snapshot of sync state for the UI. Never reports a success that did not happen.
nonisolated struct SyncState: Sendable, Equatable {
    var enabled: Bool
    var accountStatus: SyncAccountStatus
    var phase: SyncPhase
    var lastSyncedAt: Date?

    /// The off-by-default state (FR-001): sync disabled, nothing transmitted.
    static let off = SyncState(enabled: false, accountStatus: .couldNotDetermine, phase: .idle, lastSyncedAt: nil)
}

/// Opt-in iCloud sync (CloudKit private database) behind a mockable seam.
/// Off by default (FR-001); the real implementation lands in US1.
protocol CloudSyncService: Sendable {
    /// Current iCloud account availability (off-main; maps `CKContainer.accountStatus()`).
    func accountStatus() async -> SyncAccountStatus

    /// Whether the user has opted sync on. Persisted locally, NEVER synced
    /// (so a device's own toggle can't be flipped by sync).
    var isSyncEnabled: Bool { get async }

    /// Persist the opt-in choice. Enabling requires an available account.
    /// (Pattern A: the effect applies at the next container build.)
    func setSyncEnabled(_ enabled: Bool) async throws

    /// Remove the user's journal from iCloud (FR-011): disable sync, then purge
    /// ONLY the cloud copy. Never a fan-out delete — other devices keep their
    /// local journals, and the initiating device's local store is untouched.
    func removeFromICloud() async throws

    /// Live status for Settings. Each access returns a FRESH stream that replays the
    /// current state immediately, then delivers updates — safe for multiple subscribers
    /// and re-subscription (unlike a single stored `AsyncStream`).
    var state: AsyncStream<SyncState> { get async }
}
