import Testing
import Foundation
import SwiftData
@testable import app_four

@Suite(.serialized)
@MainActor
struct SettingsViewModelTests {
    private static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Recording.self, AppSettings.self, configurations: config)
    }()

    var viewModel: SettingsViewModel
    var mocks: MockAppServices
    var store: RecordingStore

    init() throws {
        let context = Self.container.mainContext
        try context.delete(model: Recording.self)
        try context.delete(model: AppSettings.self)
        context.autosaveEnabled = true   // a prior test's makeSettingsVM() may have disabled it
        store = RecordingStore(context: context)
        mocks = MockAppServices()

        viewModel = SettingsViewModel(store: store, services: mocks.services)
    }

    @Test func storageCalculationReflectsMockBytes() async {
        await viewModel.updateStorage()
        let expectedMB = 1024.0 / 1_048_576.0
        #expect(abs(viewModel.storageUsedMB - expectedMB) < 0.0001, "Storage MB should match mock bytes")
    }

    @Test func checkModelsReflectsMockState() async {
        await viewModel.checkModels()
        #expect(viewModel.whisperModelInstalled == true)
    }

    @Test func checkModelsWhenNotInstalled() async {
        await mocks.aiModel.setStubIsDownloaded(false)
        await viewModel.checkModels()
        #expect(viewModel.whisperModelInstalled == false)
    }

    @Test func recordingCountMatchesStore() throws {
        #expect(viewModel.recordingCount == 0)
        store.addRecording(Recording(audioFileName: "a.m4a", title: "Test"))
        #expect(viewModel.recordingCount == 1)
    }

    // US1 (017): the in-app Reduce-Motion control was a dead store — nothing read it;
    // every animated view gates on @Environment(\.accessibilityReduceMotion). The VM
    // must own no reduceMotion state and must not read/write a "reduceMotion" default.
    @Test func exposesNoReduceMotionProperty() {
        let names = Mirror(reflecting: viewModel).children.compactMap(\.label)
        #expect(!names.contains { $0.localizedCaseInsensitiveContains("reduceMotion") })
    }

    @Test func constructingDoesNotTouchReduceMotionDefault() throws {
        let key = "reduceMotion"
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)

        let store = RecordingStore(context: Self.container.mainContext)
        _ = SettingsViewModel(store: store, services: MockAppServices().services)

        #expect(defaults.object(forKey: key) == nil, "Constructing the VM must not write a reduceMotion default")
    }

    // US4 (017): the medical-vocabulary control is renamed "Recognize medication names"
    // and relocated from Accessibility to Check-in. This is a LABEL/PLACEMENT move only —
    // it stays backed by `UserDefaults.medicalPromptEnabled` (FR-022, no value migration).
    // Locks that behaviour so the UI move can't silently rebind the toggle to a new key.
    @Test func medicalPromptIsBackedByUserDefaultsKey() throws {
        let key = SettingsKeys.medicalPromptEnabled
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) }
        }

        // Default is `true` with no value written (matches existing-user opt-out semantics).
        defaults.removeObject(forKey: key)
        let store = RecordingStore(context: Self.container.mainContext)
        let vm = SettingsViewModel(store: store, services: MockAppServices().services)
        #expect(vm.medicalPromptEnabled == true, "Medical prompt defaults to true")

        // Toggling the VM flips exactly the `medicalPromptEnabled` key.
        vm.medicalPromptEnabled = false
        #expect(defaults.medicalPromptEnabled == false, "VM setter must write UserDefaults.medicalPromptEnabled")
        #expect(defaults.object(forKey: key) as? Bool == false, "The exact key is the backing store")

        vm.medicalPromptEnabled = true
        #expect(defaults.medicalPromptEnabled == true, "VM setter round-trips the key back on")
    }

    // MARK: - US2 (017): model-download recovery — cause surfacing, copy mapping, cancel/retry

    // T017: the engine reports a typed cause; the VM must capture it as `downloadError`
    // and expose the no-connection copy (not a swallowed log).
    @Test func downloadSurfacesNoNetworkCauseToViewModel() async {
        await mocks.aiModel.setStubIsDownloaded(false)
        await mocks.aiModel.setDownloadFailure(.noNetwork)

        await viewModel.downloadModel(.whisper)

        #expect(viewModel.downloadError == .noNetwork, "VM must capture the engine's no-network cause")
        #expect(viewModel.isDownloadingWhisper == false)
        #expect(viewModel.whisperModelInstalled == false, "A failed download leaves nothing installed")
        let message = viewModel.message(for: .noNetwork)
        #expect(message.localizedCaseInsensitiveContains("connection") ||
                message.localizedCaseInsensitiveContains("offline") ||
                message.localizedCaseInsensitiveContains("internet"),
                "No-network copy must name the missing connection")
    }

    // T018: cause→copy is exhaustive AND distinct; each cause carries the right remedy framing.
    @Test func causeMessagesAreDistinctAndAppropriate() {
        let noNetwork = viewModel.message(for: .noNetwork)
        let space = viewModel.message(for: .insufficientSpace)
        let cellular = viewModel.message(for: .cellularDisabled)
        let other = viewModel.message(for: .other("URLError.-1"))

        let all = [noNetwork, space, cellular, other]
        #expect(Set(all).count == all.count, "Every cause must map to a distinct message")
        #expect(all.allSatisfy { !$0.isEmpty }, "No cause may map to an empty message")
    }

    @Test func insufficientSpaceMessageNamesSpaceNotRetry() {
        let space = viewModel.message(for: .insufficientSpace)
        #expect(space.localizedCaseInsensitiveContains("space") ||
                space.localizedCaseInsensitiveContains("room") ||
                space.localizedCaseInsensitiveContains("storage"),
                "Insufficient-space copy must name the cause (space)")
        #expect(!space.localizedCaseInsensitiveContains("tap to retry"),
                "Space failure must not imply a pointless immediate retry as the sole remedy")
    }

    @Test func cellularDisabledExposesAllowCellularAffordance() async {
        let cellular = viewModel.message(for: .cellularDisabled)
        #expect(cellular.localizedCaseInsensitiveContains("cellular") ||
                cellular.localizedCaseInsensitiveContains("mobile data") ||
                cellular.localizedCaseInsensitiveContains("Wi-Fi"),
                "Cellular-disabled copy must reference the cellular/Wi-Fi condition")

        // The allow-cellular affordance is offered only while the active error is
        // the cellular-metered block — drive that state through the real path.
        #expect(viewModel.canAllowCellular == false, "No affordance before any cellular failure")
        await mocks.aiModel.setStubIsDownloaded(false)
        await mocks.aiModel.setDownloadFailure(.cellularDisabled)
        await viewModel.downloadModel(.whisper)
        #expect(viewModel.downloadError == .cellularDisabled)
        #expect(viewModel.canAllowCellular == true,
                "Cellular-disabled cause must offer the allow-cellular affordance")
    }

    @Test func otherCauseMessageIsGenericAndNonAlarming() {
        let other = viewModel.message(for: .other("URLError.-1009"))
        #expect(!other.isEmpty)
        // The raw error tag must never leak into user-facing copy.
        #expect(!other.contains("URLError"), "Generic copy must not leak the raw error tag")
        #expect(!other.contains("-1009"))
    }

    // T019: state machine — cancel returns to a clean "not installed", clearing progress.
    @Test func cancelDownloadReturnsToCleanNotInstalled() async {
        await mocks.aiModel.setStubIsDownloaded(false)
        await mocks.aiModel.setHangsForCancel(true)

        let download = Task { await viewModel.downloadModel(.whisper) }
        // Wait until the download is in-flight before cancelling.
        while !viewModel.isDownloadingWhisper { await Task.yield() }

        viewModel.cancelDownload()
        await download.value

        #expect(viewModel.isDownloadingWhisper == false, "Cancel stops the in-flight download")
        #expect(viewModel.whisperDownloadProgress == 0, "Cancel clears progress")
        #expect(viewModel.whisperModelInstalled == false,
                "Cancel leaves no partial/installed model (filesystem truth)")
        #expect(viewModel.downloadError == nil, "A user cancel is not an error state")
    }

    // T019: a successful retry after a failure installs the model and clears the error.
    @Test func retryAfterFailureInstallsAndClearsError() async {
        await mocks.aiModel.setStubIsDownloaded(false)
        await mocks.aiModel.setDownloadFailure(.noNetwork)
        await viewModel.downloadModel(.whisper)
        #expect(viewModel.downloadError == .noNetwork, "First attempt fails with the cause")
        #expect(viewModel.whisperModelInstalled == false)

        // Conditions recover: the model now installs cleanly.
        await mocks.aiModel.setDownloadFailure(nil)
        await mocks.aiModel.setStubIsDownloaded(true)
        await viewModel.downloadModel(.whisper)

        #expect(viewModel.whisperModelInstalled == true, "Retry success installs the model")
        #expect(viewModel.downloadError == nil, "A successful retry clears the prior error")
    }

    // MARK: - 030 App Intents settings (T014 / T030): sync round-trips via injected context

    private func makeSettingsVM() throws -> (SettingsViewModel, ModelContainer) {
        // Autosave off so the round-trips prove the sync methods' EXPLICIT save();
        // a stray autosave firing mid-test would mask a dropped save() call.
        Self.container.mainContext.autosaveEnabled = false
        let vm = SettingsViewModel(
            store: RecordingStore(context: Self.container.mainContext),
            services: MockAppServices().services,
            context: Self.container.mainContext
        )
        return (vm, Self.container)
    }

    /// Reload through a FRESH context, never `mainContext`: the writing context
    /// returns its own registered in-memory objects (unsaved mutations included),
    /// so reusing it keeps every round-trip green even with the `save()` calls
    /// deleted. A fresh context only sees what was durably persisted.
    private func reloadedVM(_ container: ModelContainer) -> SettingsViewModel {
        SettingsViewModel(
            store: RecordingStore(context: ModelContext(container)),
            services: MockAppServices().services,
            context: ModelContext(container)
        )
    }

    @Test func myMedicationSyncRoundTrips() throws {
        let (vm, container) = try makeSettingsVM()
        vm.defaultMedicationName = "Elvanse"
        vm.medicationDidChange()
        #expect(vm.defaultMedicationDose == nil, "Picking a medication never auto-commits a dose — it takes an explicit tap (T011 mockup)")
        vm.defaultMedicationDose = "30 mg"
        vm.syncMyMedication()

        let reloaded = reloadedVM(container)
        #expect(reloaded.defaultMedicationName == "Elvanse")
        #expect(reloaded.defaultMedicationDose == "30 mg")
    }

    @Test func clearingMedicationClearsDose() throws {
        let (vm, container) = try makeSettingsVM()
        vm.defaultMedicationName = "Concerta"
        vm.medicationDidChange()
        vm.defaultMedicationDose = "18 mg"
        vm.syncMyMedication()
        vm.defaultMedicationName = nil
        vm.medicationDidChange()
        #expect(vm.defaultMedicationDose == nil)

        let reloaded = reloadedVM(container)
        #expect(reloaded.defaultMedicationName == nil)
        #expect(reloaded.defaultMedicationDose == nil)
    }

    @Test func changingMedicationClearsDose() throws {
        let (vm, container) = try makeSettingsVM()
        vm.defaultMedicationName = "Elvanse"; vm.medicationDidChange()
        vm.defaultMedicationDose = "70 mg"; vm.syncMyMedication()
        vm.defaultMedicationName = "Ritalin"; vm.medicationDidChange()
        #expect(vm.defaultMedicationDose == nil, "A switched medication must be re-confirmed with an explicit dose tap")
        #expect(reloadedVM(container).defaultMedicationDose == nil, "The cleared dose persists — hands-free stays not-configured until the tap")
    }

    @Test func nameInConfirmationsDefaultsDiscreetAndSyncs() throws {
        let (vm, container) = try makeSettingsVM()
        #expect(vm.nameMedicationInConfirmations == false, "Discreet by default")
        vm.nameMedicationInConfirmations = true
        vm.syncNameInConfirmations()
        #expect(reloadedVM(container).nameMedicationInConfirmations == true)
    }

    @Test func doseGuardSyncRoundTrips() throws {
        let (vm, container) = try makeSettingsVM()
        #expect(vm.doseGuardMode == .off, "Guard off by default")
        #expect(vm.doseGuardWindowHours == 2, "Default window is 2h")
        vm.doseGuardMode = .window
        vm.doseGuardWindowHours = 4
        vm.syncDoseGuard()

        let reloaded = reloadedVM(container)
        #expect(reloaded.doseGuardMode == .window)
        #expect(reloaded.doseGuardWindowHours == 4)
    }

    @Test func doseGuardTotalModeRoundTrips() throws {
        let (vm, container) = try makeSettingsVM()
        vm.doseGuardMode = .total
        vm.syncDoseGuard()
        #expect(reloadedVM(container).doseGuardMode == .total)
    }

    @Test func invalidPersistedGuardRawDecodesToOff() throws {
        let (_, container) = try makeSettingsVM()
        let settings = try #require(try container.mainContext.fetch(FetchDescriptor<AppSettings>()).first)
        settings.doseGuardModeRaw = "someFutureMode"
        try container.mainContext.save()
        #expect(reloadedVM(container).doseGuardMode == .off, "Unknown persisted raw is forward-safe")
    }
}
