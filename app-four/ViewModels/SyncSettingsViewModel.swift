import Foundation

/// Drives the Settings ▸ iCloud Sync section (spec 038, US1). `@MainActor @Observable`,
/// holds no persistence logic — it consumes the injected `CloudSyncService` seam
/// (Constitution VIII). Off by default (FR-001); enabling is gated behind a consent
/// sheet (FR-003).
@MainActor
@Observable
final class SyncSettingsViewModel {
    private let service: any CloudSyncService

    private(set) var state: SyncState = .off
    /// Presents the pre-enable consent sheet (FR-003) before sync is actually turned on.
    var showConsent = false
    /// Cause-specific, honest error for the alert (FR-013); never a false success.
    var errorMessage: String?

    init(service: any CloudSyncService = AppDependencies.cloudSyncService) {
        self.service = service
    }

    /// Load current on/off + account availability. Call from the view's `.task`.
    func refresh() async {
        let enabled = await service.isSyncEnabled
        let status = await service.accountStatus()
        let phase: SyncPhase = enabled && status != .available ? .unavailable(status) : .idle
        state = SyncState(enabled: enabled, accountStatus: status, phase: phase, lastSyncedAt: nil)
    }

    // MARK: - Intents
    // The async methods are awaitable (for tests + the view's `Task {}`); `setToggle`
    // is the sync entry point the `Toggle` binding calls.

    /// Toggle intent. Turning ON opens the consent gate first (FR-003); the flag is only
    /// written after `confirmEnable()`. Turning OFF applies immediately (FR-010).
    func setToggle(_ on: Bool) {
        if on {
            guard canEnable else { return }
            showConsent = true
        } else {
            // Optimistic OFF: reflect the switch immediately so it doesn't visibly hang
            // on a `CKContainer.accountStatus()` round-trip; `disable()` then persists +
            // reconciles.
            state = SyncState(enabled: false, accountStatus: state.accountStatus, phase: .idle, lastSyncedAt: nil)
            Task { await disable() }
        }
    }

    func confirmEnable() async {
        showConsent = false
        await applyEnabled(true)
    }

    func cancelConsent() {
        showConsent = false   // toggle snaps back to off — `isOn` still reflects `state`
    }

    func disable() async {
        await applyEnabled(false)
    }

    func remove() async {
        do { try await service.removeFromICloud() }
        catch { errorMessage = Self.message(for: error) }
        await refresh()
    }

    private func applyEnabled(_ enabled: Bool) async {
        do { try await service.setSyncEnabled(enabled) }
        catch { errorMessage = Self.message(for: error) }
        await refresh()
    }

    // MARK: - Derived UI

    var isOn: Bool { state.enabled }
    var canEnable: Bool { state.accountStatus == .available }

    /// State-specific section footer. Honest per FR-013 — no fabricated "last synced".
    var footer: String {
        if isOn {
            return "End-to-end encrypted when Advanced Data Protection is on. Squirl can’t read your journal. Audio stays on the device it was recorded on. Changes apply after you reopen Squirl."
        }
        switch state.accountStatus {
        case .noAccount:
            return "Sign in to iCloud in Settings to turn on Sync."
        case .restricted:
            return "iCloud is restricted on this device."
        default:
            return "Off. Your journal stays on this device. Turn it on to keep it on all your Apple devices, in your own iCloud."
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? SyncFailure {
        case .notAuthenticated: "Sign in to iCloud to turn on Sync."
        case .quotaExceeded: "iCloud storage is full. Free up space to keep syncing."
        case .network: "Couldn’t reach iCloud. Check your connection and try again."
        case .rateLimited: "iCloud is busy. Try again in a moment."
        case .other, .none: "Something went wrong. Please try again."
        }
    }
}
