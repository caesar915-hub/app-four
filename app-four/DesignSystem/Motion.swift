import SwiftUI

/// Standard animation curves. Use these instead of inline `.animation(.spring())`
/// so motion feels consistent. SwiftUI automatically honors Reduce Motion for
/// these system curves when applied to value-driven animations.
enum Motion {
    /// Quick, responsive — selections, toggles, small state changes
    static let snappy: Animation = .snappy(duration: 0.3)
    /// Duration of `smooth`, exposed so timing-dependent guards can track it (no magic numbers).
    static let smoothDuration: Double = 0.4
    /// Gentle — larger transitions, content appearance
    static let smooth: Animation = .smooth(duration: smoothDuration)
}
