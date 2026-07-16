import Testing
import Foundation
@testable import app_four

/// Test-first (Constitution Principle X) for the pure scroll→fade math behind the calendar
/// strip collapse (spec-035, FR-002/003/004/014). Pins contract rows C1–C8 of
/// `specs/035-calendar-scroll-collapse/contracts/strip-fade-behavior.md`. `CalendarStripFade`
/// is a stateless enum so every rule is verifiable without a SwiftUI host or scroll view.
@Suite struct CalendarStripFadeTests {

    /// Measured strip heights from the plan: collapsed week ≈130pt, expanded month ≈290pt.
    private let week: CGFloat = 130
    private let month: CGFloat = 290

    // MARK: - C1/C2: rest + dead zone (incl. rubber-band) are bit-exact zero

    @Test func restIsExactlyZeroProgressAndFullOpacity() {
        let p = CalendarStripFade.progress(offset: 0, stripHeight: week)
        #expect(p == 0)
        #expect(CalendarStripFade.stripOpacity(progress: p) == 1)
    }

    @Test func deadZoneAbsorbsScrollWithoutAnyFade() {
        for offset: CGFloat in [1, 12, 23.9, CalendarStripFade.deadZone] {
            #expect(CalendarStripFade.progress(offset: offset, stripHeight: week) == 0,
                    "offset \(offset) is within the dead zone — must be bit-exact 0 (anti-flicker)")
        }
    }

    @Test func rubberBandNegativeOffsetsClampToZero() {
        for offset: CGFloat in [-0.5, -40, -300] {
            #expect(CalendarStripFade.progress(offset: offset, stripHeight: week) == 0,
                    "pull-down past the top must never brighten past opacity 1")
        }
    }

    // MARK: - C3: linear mid-band

    @Test func midBandIsHalfProgress() {
        // band = stripHeight − deadZone; midpoint offset = deadZone + band/2.
        let band = week - CalendarStripFade.deadZone
        let p = CalendarStripFade.progress(offset: CalendarStripFade.deadZone + band / 2,
                                           stripHeight: week)
        #expect(abs(p - 0.5) <= 0.01)   // quantization tolerance (C6)
        #expect(abs(CalendarStripFade.stripOpacity(progress: p) - 0.5) <= 0.01)
    }

    // MARK: - C4/C8: completion exactly at the strip's own height, for BOTH heights

    @Test func fadeCompletesExactlyAtStripHeight() {
        for height in [week, month] {
            #expect(CalendarStripFade.progress(offset: height, stripHeight: height) == 1,
                    "strip (h=\(height)) must be fully faded exactly as it finishes clearing")
            #expect(CalendarStripFade.progress(offset: height - 1, stripHeight: height) < 1)
            #expect(CalendarStripFade.progress(offset: height + 200, stripHeight: height) == 1)
        }
    }

    @Test func bandScalesWithMeasuredHeight() {
        // The same absolute offset that fully fades the week strip must NOT fully fade the month grid.
        let p = CalendarStripFade.progress(offset: week, stripHeight: month)
        #expect(p < 1)
        #expect(p > 0)
    }

    // MARK: - C5: zero-height guard (pre-measurement frame)

    @Test func zeroHeightFloorsBandAtMinFadeDistance() {
        // No div-by-zero, no instant collapse: just past the dead zone must still be partial.
        let justPast = CalendarStripFade.progress(offset: CalendarStripFade.deadZone + 1,
                                                  stripHeight: 0)
        #expect(justPast > 0)
        #expect(justPast < 0.05)   // 1pt into a ≥44pt band — nowhere near collapsed
        let full = CalendarStripFade.progress(
            offset: CalendarStripFade.deadZone + CalendarStripFade.minFadeDistance,
            stripHeight: 0)
        #expect(full == 1)
    }

    // MARK: - C6: clamp + quantization contract

    @Test func progressIsAlwaysClampedAndQuantized() {
        for offset: CGFloat in [-100, 0, 17, 31.37, 77.7, 129, 130, 500] {
            let p = CalendarStripFade.progress(offset: offset, stripHeight: week)
            #expect(p >= 0 && p <= 1)
            #expect((p * 100).rounded() == p * 100,
                    "progress must be quantized to 1/100 so Equatable dedupe stops state churn")
        }
    }

    // MARK: - C7: title reveal boundary

    @Test func titleRevealBoundaryIsExact() {
        #expect(!CalendarStripFade.showsTitle(progress: 0))
        #expect(!CalendarStripFade.showsTitle(progress: 0.79))
        #expect(CalendarStripFade.showsTitle(progress: 0.80))
        #expect(CalendarStripFade.showsTitle(progress: 1))
    }

    // MARK: - Opacity is the exact complement of progress (FR-002)

    @Test func opacityIsOneMinusProgress() {
        for p: CGFloat in [0, 0.25, 0.5, 0.8, 1] {
            #expect(CalendarStripFade.stripOpacity(progress: p) == 1 - p)
        }
    }
}
