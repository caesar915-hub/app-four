import Foundation
import Observation

/// Tracks the currently visible screen so diagnostic snapshots and feedback
/// reports can attribute issues to the correct UI context.
@Observable
@MainActor
final class ScreenTracker {
    var currentScreen: String = "unknown"

    init() {}
}
