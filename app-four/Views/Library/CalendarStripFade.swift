import Foundation

/// Pure scroll→fade math for the calendar strip collapse (spec-035). Stateless by design:
/// the view feeds it raw scroll geometry and applies the returned values, so every rule is
/// unit-testable without a scroll view (Constitution X; contract C1–C8).
///
/// The constants are gesture metrics for this one screen — deliberately NOT `Spacing`/`Metrics`
/// tokens (research D9). Owner-tunable on device without re-speccing (spec Assumptions).
enum CalendarStripFade {
    /// Scroll travel absorbed before any fade begins — kills flicker on accidental nudges.
    static let deadZone: CGFloat = 24
    /// Floor for the fade band. Guards the pre-measurement frame (`stripHeight == 0`)
    /// against divide-by-zero / instant collapse.
    static let minFadeDistance: CGFloat = 44
    /// Collapse progress at which the compact nav title snap-fades in — just before the
    /// strip is fully gone, the native large-title-handoff feel (research D5).
    static let titleReveal: CGFloat = 0.8

    /// `offset` is `contentOffset.y + contentInsets.top` — exactly 0 at rest by documented
    /// contract, negative during rubber-band pull-down, positive scrolling up (research D2).
    /// The band scales with the strip's measured height so the week strip and the expanded
    /// month grid both finish fading exactly as they clear (FR-002). Result ∈ [0, 1],
    /// FLOOR-quantized to 1/100: dedupe granularity for Equatable state churn, without ever
    /// reporting full collapse early (nearest-rounding would hit 1.0 half a quantum before
    /// the strip actually clears — contract C4).
    static func progress(offset: CGFloat, stripHeight: CGFloat) -> CGFloat {
        let band = max(stripHeight - deadZone, minFadeDistance)
        let raw = (offset - deadZone) / band
        return (min(max(raw, 0), 1) * 100).rounded(.down) / 100
    }

    static func stripOpacity(progress: CGFloat) -> CGFloat { 1 - progress }

    static func showsTitle(progress: CGFloat) -> Bool { progress >= titleReveal }
}
