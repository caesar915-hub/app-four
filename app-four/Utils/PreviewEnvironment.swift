import SwiftUI

extension View {
    /// Injects the full production environment into SwiftUI previews.
    /// Use this instead of referencing `AppDependencies` directly in `#Preview` blocks
    /// inside the Views/ directory.
    func withPreviewEnvironment() -> some View {
        self
            .environment(AppDependencies.store)
            .environment(AppDependencies.medicationBarViewModel)
            .environment(AppDependencies.screenTracker)
            .environment(AppDependencies.services)
            .environment(\.diagnosticsStore, AppDependencies.diagnosticsStore)
    }
}
