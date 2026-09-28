import SwiftUI

/// Raised by a screen that must hide the floating tab bar + Add button — the check-in flow
/// while capturing, the pushed Edit screen. Preferences flow up, so a pushed view can reach
/// the root container that owns the chrome (D5).
public struct HidesFloatingChromeKey: PreferenceKey {
    public static let defaultValue = false

    public static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

public extension View {
    /// Hides the floating chrome while `hidden` is true.
    func hidesFloatingChrome(_ hidden: Bool = true) -> some View {
        preference(key: HidesFloatingChromeKey.self, value: hidden)
    }
}
