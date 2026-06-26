import SwiftUI

/// Standard animation curves. Use these instead of inline `.animation(.spring())`
/// so motion feels consistent. SwiftUI automatically honors Reduce Motion for
/// these system curves when applied to value-driven animations.
public enum Motion {
    /// Quick, responsive — selections, toggles, small state changes
    public static let snappy: Animation = .snappy(duration: 0.3)
    /// Duration of `smooth`, exposed so timing-dependent guards can track it (no magic numbers).
    public static let smoothDuration: Double = 0.4
    /// Gentle — larger transitions, content appearance
    public static let smooth: Animation = .smooth(duration: smoothDuration)
}
