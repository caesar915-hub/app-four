import Foundation

/// Shared helpers for deterministic test setup.
enum TestSupport {
    /// Pins the debug "mock mode" flag OFF before a suite builds its store.
    ///
    /// `RecordingStore.loadRecordings()`, `MoodLibraryViewModel`, and `MedicationBarViewModel`
    /// fetch persisted rows with `#Predicate { $0.isMockData == UserDefaults["debugMockMode"] }`.
    /// Tests run in the host-app process and share `UserDefaults.standard`, so a simulator left
    /// in mock mode (toggled on to view seeded data for QA) makes every suite that inserts real
    /// (`isMockData == false`) recordings fetch nothing. Call this first in any suite `init` that
    /// builds one of those stores so the suite is deterministic regardless of simulator state.
    ///
    /// We *remove* the key rather than persist `false`: under XCTest `SquirlApp.init` deliberately
    /// does not register the DEBUG mock default, so an absent key reads `false` here — yet the
    /// domain is left clean, so it does not clobber the dev "mock-data always on" default on the
    /// next non-test launch.
    static func useRealData() {
        UserDefaults.standard.removeObject(forKey: "debugMockMode")
    }
}
