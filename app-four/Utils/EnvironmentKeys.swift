import SwiftUI

// MARK: - DiagnosticsStore

/// Makes `DiagnosticsStore` (an actor, so not directly @Observable) available
/// through the SwiftUI environment without wrapping it in an observable shim.
private struct DiagnosticsStoreKey: EnvironmentKey {
    static let defaultValue: DiagnosticsStore = DiagnosticsStore()
}

extension EnvironmentValues {
    var diagnosticsStore: DiagnosticsStore {
        get { self[DiagnosticsStoreKey.self] }
        set { self[DiagnosticsStoreKey.self] = newValue }
    }
}
