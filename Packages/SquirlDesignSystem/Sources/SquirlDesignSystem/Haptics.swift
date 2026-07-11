import UIKit

/// Semantic haptic feedback. One call site for each meaning so feedback is
/// consistent and easy to audit. Call on the main actor (UI events).
@MainActor
public enum Haptics {
    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    public static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
