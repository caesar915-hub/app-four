import SwiftUI

/// Standard animation curves (DESIGN.md §10). Use these instead of inline springs so motion
/// feels consistent; every animated view also honours Reduce Motion explicitly.
public enum Motion {
    /// Quick, responsive — selections, toggles, chip and toggle fills
    public static let snappy: Animation = .snappy(duration: 0.3)
    /// Gentle — larger transitions, content appearance
    public static let smooth: Animation = .smooth(duration: 0.4)
    /// Card expand/collapse, chevron rotation — a quiet ease (no spring overshoot)
    public static let expand: Animation = .easeInOut(duration: 0.25)
    /// Settle — the ring completing, the check tile landing (spring, gentle damping)
    public static let settle: Animation = .spring(duration: 0.45, bounce: 0.15)
}
