# Quickstart — validate Paper & Pollen signal glyphs

Proves the feature end-to-end. Run after implementation (`/speckit-tasks` → implement).

## Prerequisites

- Xcode, iPhone 17 simulator (the project's verified sim).
- Branch `feat/signal-glyphs` checked out.

## Build + unit tests (the test-first helpers)

```bash
# Build + run the Swift Testing suite (serial — see project test notes)
xcodebuild test -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

**Expect**: green, including `SignalGlyphTests` (clamp · accessibility label · synonym lookup).

## Run + visual validation (the SwiftUI views — Principle X exemption)

Launch on the simulator, then walk the surfaces:

1. **Calendar timeline** — open a day with check-ins.
   - ✅ Each entry shows sprout / lightning / aperture (not `sparkles`/`bolt.fill`/`target`); a dose shows the **horizontal capsule** chip (SC-003, US1).
   - ✅ A high-level entry's glyph visibly differs in *shape* from a low-level one.
2. **Type-note + Edit sheet** — open the signal pickers.
   - ✅ A tappable 1→5 row per signal; current level ringed in bronze; label shows "n · Name — synonym" (US2, FR-010).
   - ✅ Tapping a level moves the ring and changes the glyph form.
3. **Insights → signals** — ✅ Mood/Energy/Focus show 1→5 glyph ramps; Sleep shows the bed icon + "not tracked yet" (US3).

## Accessibility gate (SC-001/004/005)

4. **Grayscale** (Settings → Accessibility → Display → Color Filters → Grayscale): on the Insights ramps and a timeline at normal size, **every level stays distinguishable from its neighbors by shape + fill** (SC-001). _If any adjacent pair is indistinguishable at ~22px, STOP and raise to the owner (see research D8) — do not ship._
5. **Dynamic Type** (AX-XXL): glyphs scale, nothing clips (SC-004).
6. **VoiceOver**: focusing a non-decorative glyph announces "Energy, Alert, 4 of 5" etc. (SC-005).
7. **Dark mode**: glyphs use dark-variant hues, legible on loam (FR-014).

## Done = all boxes above check + no SF Symbol remains for the five signals (`grep` the migration surface).
