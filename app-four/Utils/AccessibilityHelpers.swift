import SwiftUI

enum AccessibilityHelpers {
    /// Checks if Reduce Motion is enabled in system settings.
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    /// Formats a duration in seconds into a "M:SS" string.
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
