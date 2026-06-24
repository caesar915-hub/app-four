import Testing
import Foundation
import SwiftData
@testable import app_four

@MainActor
struct SettingsViewModelTests {
    var viewModel: SettingsViewModel
    var mocks: MockAppServices
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, AppSettings.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
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

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Recording.self, AppSettings.self, configurations: config)
        let store = RecordingStore(context: container.mainContext)
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
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Recording.self, AppSettings.self, configurations: config)
        let store = RecordingStore(context: container.mainContext)
        let vm = SettingsViewModel(store: store, services: MockAppServices().services)
        #expect(vm.medicalPromptEnabled == true, "Medical prompt defaults to true")

        // Toggling the VM flips exactly the `medicalPromptEnabled` key.
        vm.medicalPromptEnabled = false
        #expect(defaults.medicalPromptEnabled == false, "VM setter must write UserDefaults.medicalPromptEnabled")
        #expect(defaults.object(forKey: key) as? Bool == false, "The exact key is the backing store")

        vm.medicalPromptEnabled = true
        #expect(defaults.medicalPromptEnabled == true, "VM setter round-trips the key back on")
    }
}
