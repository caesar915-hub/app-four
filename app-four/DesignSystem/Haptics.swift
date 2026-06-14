import UIKit

/// Semantic haptic feedback. One call site for each meaning so feedback is
/// consistent and easy to audit. Call on the main actor (UI events).
@MainActor
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
