import Testing
import Foundation
@testable import app_four

@MainActor
@Suite struct SyncSettingsViewModelTests {

    @Test func offByDefaultWithAvailableAccount() async {
        let vm = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .available, startEnabled: false))
        await vm.refresh()
        #expect(vm.isOn == false)
        #expect(vm.canEnable == true)
    }

    @Test func enablingOpensConsentGateAndDoesNotEnableYet() async {
        let vm = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .available))
        await vm.refresh()
        vm.setToggle(true)
        #expect(vm.showConsent == true)
        #expect(vm.isOn == false)          // still off until confirmed (FR-003)
    }

    @Test func confirmEnableTurnsSyncOn() async {
        let vm = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .available))
        await vm.refresh()
        vm.setToggle(true)
        await vm.confirmEnable()
        #expect(vm.showConsent == false)
        #expect(vm.isOn == true)
    }

    @Test func enableBlockedWithoutAccount() async {
        let vm = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .noAccount))
        await vm.refresh()
        #expect(vm.canEnable == false)
        vm.setToggle(true)
        #expect(vm.showConsent == false)   // gate never opens without an account
        #expect(vm.isOn == false)
    }

    @Test func disableTurnsSyncOff() async {
        let vm = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .available, startEnabled: true))
        await vm.refresh()
        #expect(vm.isOn == true)
        await vm.disable()
        #expect(vm.isOn == false)
    }

    @Test func toggleOffReflectsImmediately() async {
        // Optimistic OFF: the switch flips without waiting for the network round-trip.
        let vm = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .available, startEnabled: true))
        await vm.refresh()
        #expect(vm.isOn == true)
        vm.setToggle(false)
        #expect(vm.isOn == false)
    }

    @Test func removeCallsServiceAndDisables() async {
        let mock = MockCloudSyncService(accountStatus: .available, startEnabled: true)
        let vm = SyncSettingsViewModel(service: mock)
        await vm.refresh()
        await vm.remove()
        #expect(mock.removeFromICloudCalled == true)
        #expect(vm.isOn == false)
    }

    @Test func removeFailureSurfacesHonestError() async {
        let mock = MockCloudSyncService(accountStatus: .available, startEnabled: true)
        mock.scriptedRemoveFailure = .quotaExceeded
        let vm = SyncSettingsViewModel(service: mock)
        await vm.refresh()
        await vm.remove()
        #expect(vm.errorMessage != nil)
    }

    @Test func footerReflectsState() async {
        let off = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .available, startEnabled: false))
        await off.refresh()
        #expect(off.footer.contains("stays on this device"))

        let on = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .available, startEnabled: true))
        await on.refresh()
        #expect(on.footer.contains("reopen Squirl"))

        let noAccount = SyncSettingsViewModel(service: MockCloudSyncService(accountStatus: .noAccount, startEnabled: false))
        await noAccount.refresh()
        #expect(noAccount.footer.contains("Sign in"))
    }
}
