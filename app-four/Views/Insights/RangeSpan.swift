/// Which segments the "Where you averaged" bracket spans (DESIGN.md §8.15): a whole-number
/// average brackets one segment, any other average the pair it falls between. `nil` when
/// nothing was logged (level 0).
enum RangeSpan {
    static func segments(level: Int, isWhole: Bool) -> ClosedRange<Int>? {
        guard (1...5).contains(level) else { return nil }
        if isWhole || level == 5 { return level...level }
        return level...(level + 1)
    }
}
