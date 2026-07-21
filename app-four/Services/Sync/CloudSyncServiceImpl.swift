import Foundation
import CloudKit

/// Live `CloudSyncService` backed by CloudKit + the off-by-default `SyncFlags` toggle
/// (spec 038). An `actor` so all CloudKit/account work runs off the main actor
/// (Constitution VIII).
///
/// Pattern A: `setSyncEnabled` only persists the flag — the actual local↔CloudKit
/// mirroring is (dis)engaged when `AppModelContainer` is next built (app relaunch),
/// because SwiftData has no supported live container hot-swap. The Settings UI states
/// "relaunch to apply".
///
/// Honest status only: because this actor does NOT perform the mirroring (SwiftData's
/// container does), it reports on/off + iCloud-account availability and never a
/// fabricated "synced" timestamp (FR-013). Real last-synced / stalled / quota status
/// requires observing `NSPersistentCloudKitContainer.eventChangedNotification` — a
/// deferred follow-up (see tasks.md).
actor CloudSyncServiceImpl: CloudSyncService {
    private let containerID: String
    private var currentState: SyncState
    private var subscribers: [UUID: AsyncStream<SyncState>.Continuation] = [:]

    init(containerID: String = "iCloud.Rythm-App.app-four") {
        self.containerID = containerID
        currentState = SyncState(
            enabled: SyncFlags.iCloudSyncEnabled,
            accountStatus: .couldNotDetermine,
            phase: .idle,
            lastSyncedAt: nil
        )
    }

    /// Fresh multicast stream: replays `currentState`, then delivers updates.
    var state: AsyncStream<SyncState> {
        let (stream, continuation) = AsyncStream.makeStream(of: SyncState.self)
        let id = UUID()
        continuation.yield(currentState)
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    func accountStatus() async -> SyncAccountStatus {
        do {
            return SyncAccountStatus(from: try await CKContainer(identifier: containerID).accountStatus())
        } catch {
            return .couldNotDetermine
        }
    }

    var isSyncEnabled: Bool { get async { SyncFlags.iCloudSyncEnabled } }

    func setSyncEnabled(_ enabled: Bool) async throws {
        // Enabling requires an available iCloud account (FR — off-by-default + gating).
        if enabled {
            let status = await accountStatus()
            guard status == .available else { throw SyncFailure.notAuthenticated }
        }
        SyncFlags.setICloudSyncEnabled(enabled)
        await refresh()
    }

    func removeFromICloud() async throws {
        // FR-011: disable first (Pattern A — next launch rebuilds `.none`), then purge
        // ONLY the cloud copy. Deleting the private-database custom zone(s) removes all
        // mirrored records; other devices' LOCAL stores are untouched (this is not a
        // record-level delete that propagates as entry deletions).
        SyncFlags.setICloudSyncEnabled(false)
        let db = CKContainer(identifier: containerID).privateCloudDatabase
        do {
            let zones = try await db.allRecordZones()
            for zone in zones where zone.zoneID != CKRecordZone.default().zoneID {
                try await db.deleteRecordZone(withID: zone.zoneID)
            }
        } catch let error as CKError where
            error.code == .zoneNotFound || error.code == .userDeletedZone || error.code == .notAuthenticated {
            // Nothing to remove (no zone, already gone, or signed out) — treat as success.
        } catch {
            await refresh()
            throw SyncFailure(from: error)
        }
        await refresh()
    }

    /// Recomputes `currentState` from what the actor can honestly know and multicasts it.
    private func refresh() async {
        let status = await accountStatus()
        let enabled = SyncFlags.iCloudSyncEnabled
        let phase: SyncPhase = enabled && status != .available ? .unavailable(status) : .idle
        currentState = SyncState(enabled: enabled, accountStatus: status, phase: phase, lastSyncedAt: nil)
        for continuation in subscribers.values {
            continuation.yield(currentState)
        }
    }
}
