import CoreFoundation
import Testing
@testable import app_four

struct CalendarHeaderScrollFadeTests {

    // MARK: - C1: offset 0 → opacity 1.0

    @Test func opacityAtTopIsOne() {
        #expect(CalendarLibraryView.headerOpacity(scrollOffset: 0, headerHeight: 100) == 1.0)
    }

    // MARK: - C2: offset >= height → opacity 0.0

    @Test func opacityAtFullScrollIsZero() {
        #expect(CalendarLibraryView.headerOpacity(scrollOffset: 100, headerHeight: 100) == 0.0)
    }

    @Test func opacityBeyondHeightClampsToZero() {
        #expect(CalendarLibraryView.headerOpacity(scrollOffset: 200, headerHeight: 100) == 0.0)
    }

    // MARK: - C3: mid-scroll → intermediate opacity

    @Test func opacityAtHalfScrollIsHalf() {
        let result = CalendarLibraryView.headerOpacity(scrollOffset: 50, headerHeight: 100)
        #expect(abs(result - 0.5) < 0.001)
    }

    // MARK: - C3: monotonically non-increasing

    @Test func opacityIsMonotonicallyNonIncreasing() {
        let height: CGFloat = 120
        var previous = CalendarLibraryView.headerOpacity(scrollOffset: 0, headerHeight: height)
        for offset in stride(from: CGFloat(1), through: height + 20, by: 1) {
            let current = CalendarLibraryView.headerOpacity(scrollOffset: offset, headerHeight: height)
            #expect(current <= previous, "Opacity rose from \(previous) to \(current) at offset \(offset)")
            previous = current
        }
    }

    // MARK: - C15: negative offset (rubber-band) clamps to 1.0

    @Test func negativeOffsetClampsToOne() {
        #expect(CalendarLibraryView.headerOpacity(scrollOffset: -20, headerHeight: 100) == 1.0)
    }

    // MARK: - guard: zero/negative height → 1.0 (avoids divide-by-zero)

    @Test func zeroHeightReturnsOne() {
        #expect(CalendarLibraryView.headerOpacity(scrollOffset: 50, headerHeight: 0) == 1.0)
    }

    @Test func negativeHeightReturnsOne() {
        #expect(CalendarLibraryView.headerOpacity(scrollOffset: 50, headerHeight: -10) == 1.0)
    }

    // MARK: - C6: interactivity threshold at 0.05

    @Test func interactiveWhenOpacityAboveThreshold() {
        let opacity = CalendarLibraryView.headerOpacity(scrollOffset: 90, headerHeight: 100)
        // offset=90, height=100 → opacity=0.10, which is > 0.05 → should be interactive
        #expect(opacity > 0.05)
    }

    @Test func notInteractiveWhenOpacityAtOrBelowThreshold() {
        let opacity = CalendarLibraryView.headerOpacity(scrollOffset: 96, headerHeight: 100)
        // offset=96, height=100 → opacity=0.04, which is <= 0.05 → should not be interactive
        #expect(opacity <= 0.05)
    }

    @Test func interactivityFlipsAtThreshold() {
        let height: CGFloat = 100
        // Find boundary: threshold is 0.05 → scrollOffset = height * (1 - 0.05) = 95
        let justBelow = CalendarLibraryView.headerOpacity(scrollOffset: 94, headerHeight: height)
        let justAbove = CalendarLibraryView.headerOpacity(scrollOffset: 96, headerHeight: height)
        #expect(justBelow > 0.05, "Expected interactive at offset 94")
        #expect(justAbove <= 0.05, "Expected non-interactive at offset 96")
    }
}
