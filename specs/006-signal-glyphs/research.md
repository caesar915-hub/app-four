# Phase 0 — Research: Paper & Pollen signal glyphs

No `NEEDS CLARIFICATION` remained in the spec (geometry is fixed by the canonical generators). Research here records the porting + structure decisions.

## D1 — Glyph unit: `View` composing `Path`s, not a single `Shape`

**Decision**: Each glyph is a small SwiftUI `View` taking `(level, color)`, composing multiple `Path`/`Circle`/`Capsule` layers (stem + crown, bolt fill + stroke, aperture's stacked rings + dashed low state, etc.).
**Rationale**: A SwiftUI `Shape` returns exactly one `Path`; our glyphs layer separate fills, strokes, dashes, and per-element opacity — that maps cleanly to a `View`, not one `Path`. Internal sub-paths may still be private `Shape`s where convenient.
**Alternatives**: One giant `Shape` per glyph (rejected — can't express multi-fill/opacity); image assets (rejected — not level-parametric, not Dynamic-Type-crisp).

## D2 — One dispatcher: `SignalGlyph(signal:level:size:)`

**Decision**: A single `SignalGlyph` view maps `(SignalKind, level?)` to the correct glyph view, resolves the color from the existing `SignalLevel` grammar, and owns the accessibility label. Every call site swaps `Image(systemName:)` → `SignalGlyph(...)`.
**Rationale**: One swap point per call site; centralizes color + a11y so the ~13 sites stay thin and consistent.

## D3 — Color from the existing ramps (unchanged)

**Decision**: Mood/Energy/Focus colors come from `SignalLevel.color` (per level) / `Palette+Signals` — unchanged. Sleep uses a new `Palette.sleepIndigo` token (`#5566A6` light / `#8090C8` dark). Medication uses the existing medication purple.
**Rationale**: FR-009 forbids ramp changes; reuse the single source. Only one new token (Sleep indigo).

## D4 — Port the level formulas verbatim from the approved mockup

**Decision**: The size/fill-opacity/stroke/dash formulas per level are ported directly from the `gMood` / `gEnergy` / `gFocus` generators in `design-decisions-ALL.html` (and `squirl-design-system.html`), so the SwiftUI output matches the approved visual.
**Rationale**: The owner approved that exact rendering; divergence would re-open a closed decision.

## D5 — Accessibility model

**Decision**: `SignalGlyph` exposes `.accessibilityLabel("{Signal}: {name}, {n} of 5")` (Sleep/Medication: signal name only) and is one a11y element. When the glyph sits inside an already-labeled row/chip, the call site passes `decorative: true` → `.accessibilityHidden(true)` to avoid double-reads.
**Rationale**: FR-012; avoids VoiceOver repeating the word that already sits beside the glyph.
**Test-first helper**: `signalAccessibilityLabel(_:level:)` is pure logic → Swift Testing first.

## D6 — Out-of-range + absent level

**Decision**: Level is `Int?`. `nil` → a defined empty/placeholder rendering (FR-015), never a level-1 glyph. Out-of-range ints clamp to 1…5 via a pure `clampedSignalLevel(_:)` helper.
**Rationale**: FR-015; defensive against bad extraction data.
**Test-first helper**: `clampedSignalLevel(_:)` → Swift Testing first.

## D7 — Name + synonym table (picker)

**Decision**: The picker label ("5 · Great — bright, thriving") is driven by a static per-signal `names`/`synonyms` table (the 5×3 set from the design system). `displayLabel` (name) already exists on `SignalLevel`; **synonyms are new static presentation data**.
**Rationale**: FR-010. Static data, not a service (Principle VIII N/A).
**Test-first helper**: `signalSynonym(_:level:)` lookup → Swift Testing first.

## D8 — Grayscale / colorblind gate is a real risk to verify (not assumed)

**Decision**: SC-001 (every level distinct by shape+fill in grayscale at ~22px) is verified in `quickstart.md` against the *ported* glyphs, not assumed.
**Rationale / open risk**: The reverted set includes the **aperture (Focus) low levels** (faint dashed rings) and **lightning (Energy) low levels** (faint, small) — the very glyphs the owner first felt "don't transmit separately." The owner chose to revert anyway; honoring that is correct, but the accessibility gate stays real. **If a level pair fails grayscale distinctness at 22px, raise to the owner before shipping** (do not silently degrade). Mitigation already in the formulas: low Focus uses a dashed ring (shape cue) and Energy/Mood grow in size with level (size cue), so shape/size — not only opacity — carry the level.
