import SwiftUI

extension View {
    /// Records the screen name in `ScreenTracker` whenever this view appears.
    /// Replaces scattered `.onAppear { AppDependencies.screenTracker.currentScreen = … }` calls.
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenTrackingModifier(name: name))
    }
}

private struct ScreenTrackingModifier: ViewModifier {
    let name: String
    @Environment(ScreenTracker.self) private var tracker

    func body(content: Content) -> some View {
        content
            .onAppear { tracker.currentScreen = name }
    }
}
