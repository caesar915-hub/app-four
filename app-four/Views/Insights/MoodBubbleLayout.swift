import CoreGraphics

/// Bubble geometry for the mood breakdown (DESIGN.md §8.13, D-I2): the pen's linear rule — the
/// diameter grows 1.3 pt per percentage point from a 60 pt floor — clamped so the largest share
/// still fits the card. Deliberately not area-proportional: the chart reads left-to-right as a
/// ramp and the number inside carries the exact value.
enum MoodBubbleLayout {
    static let minDiameter: CGFloat = 60
    static let maxDiameter: CGFloat = 110
    static let chartHeight: CGFloat = 180
    /// Each level's bubble rests 13 pt higher than the one before (the rising baseline).
    static let baselineStep: CGFloat = 13
    static let baselineInset: CGFloat = 8

    static func diameter(fraction: Double) -> CGFloat {
        let percent = min(1, max(0, fraction)) * 100
        return min(maxDiameter, minDiameter + 1.3 * percent)
    }

    /// Centre of a level's (1–5) bubble inside a chart of `size`: five equal columns, bottoms on
    /// the rising baseline.
    static func center(level: Int, diameter: CGFloat, in size: CGSize) -> CGPoint {
        let column = size.width / 5
        let x = column * (CGFloat(level) - 0.5)
        let y = size.height - baselineInset - baselineStep * CGFloat(level - 1) - diameter / 2
        return CGPoint(x: x, y: y)
    }
}
