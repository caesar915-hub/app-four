# Implementation Plan: Paper & Pollen signal glyphs

**Branch**: `feat/signal-glyphs` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/006-signal-glyphs/spec.md`

## Summary

Replace the SF Symbols the app ships for signals (`sparkles`/`bolt.fill`/`target`/`pills.fill`/`bed`) with the canonical Paper & Pollen glyphs — **Mood = sprout, Energy = lightning, Focus = aperture** (level-driven 1→5), **Sleep = bed**, **Medication = horizontal capsule** (single icons). The glyphs are pure SwiftUI `Shape`/`View` drawing, parameterised by the existing `SignalLevel` grammar, exposed through one `SignalGlyph` view that every call site uses. Geometry is ported from the canonical generators in [design-decisions-ALL.html](../../docs/superpowers/plans/2026-06-16-design-decisions-ALL.html). Ramps and layouts are unchanged; only the icon at each call site changes.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency)
**Primary Dependencies**: SwiftUI only — **no new dependencies** (pure vector drawing via `Path`/`Shape`)
**Storage**: N/A — presentation only; reads existing `SignalLevel`/`Recording` values
**Testing**: Swift Testing (`@Test`/`#expect`) for pure helpers (clamp, accessibility-label builder, name/synonym lookup); SwiftUI glyph views verified by build + simulator render (Principle X exemption) + the grayscale gate in quickstart
**Target Platform**: iOS 26+
**Project Type**: Mobile app (single iOS SwiftUI target, `app-four/`)
**Performance Goals**: 60 fps; glyphs are lightweight static `Path`s, no per-frame work
**Constraints**: legible ~18–22px → Dynamic Type AX-XXL; light + dark; **grayscale/colorblind-safe (level distinct by shape+fill)**; VoiceOver labels; no emoji faces
**Scale/Scope**: 5 signals × ≤5 levels; **~13 production call sites** migrate off `Image(systemName:)` (see Structure Decision)

## Constitution Check

*GATE: passes before Phase 0. Re-checked after Phase 1 (unchanged).*

- [x] **I. SwiftUI-First** — pure SwiftUI `Shape`/`View`, modern APIs; HTML mockup exists (the design register + `squirl-design-system.html`). PASS.
- [x] **II. Test-Build-Ship** — plan yields a buildable, simulator-verified change; suite stays green. PASS.
- [x] **III. Correctness Over Speed** — net removal of SF Symbols, no compat shims; `Icons.energy`/`Icons.medication` are repointed/removed, not left dead. PASS.
- [x] **IV. Minimal Surface** — one `SignalGlyph` dispatcher + three level-driven Shapes + two single icons; no flags, no user-selectable set. PASS.
- [x] **V. Solo Git Discipline** — one feature on `feat/signal-glyphs`; `/code-review` before merge; `main` stays releasable. PASS.
- [x] **VI. On-Device Privacy** — pure UI; no data leaves device, no new logging. N/A→PASS.
- [x] **VII. Deterministic, Measured Extraction** — extraction untouched. N/A.
- [x] **VIII. Service-Oriented Architecture** — view layer only; no new `Services/` capability. Name/synonym lookup is static presentation data, not a service. N/A→PASS.
- [x] **IX. Pre-Release Data Posture** — no schema change. N/A.
- [x] **X. Test-First Development** — the pure helpers (level **clamp**, **accessibility-label** string, **name/synonym** lookup) are built test-first (RED→GREEN) with Swift Testing. The `Shape`/`View` drawing is a SwiftUI view → exempt, verified by build + simulator render. PASS.

No violations → **Complexity Tracking empty.**

## Project Structure

### Documentation (this feature)

```text
specs/006-signal-glyphs/
├── plan.md              # this file
├── spec.md
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── signal-glyph.md  # Phase 1 — the SignalGlyph view contract
└── checklists/requirements.md
```

### Source Code

```text
app-four/
├── DesignSystem/
│   ├── SignalGlyph.swift          # NEW — dispatcher: (signal, level?) → glyph + a11y label
│   ├── Glyphs/
│   │   ├── SproutGlyph.swift      # NEW — Mood, level-driven
│   │   ├── BoltGlyph.swift        # NEW — Energy, level-driven
│   │   ├── ApertureGlyph.swift    # NEW — Focus, level-driven
│   │   ├── BedIcon.swift          # NEW — Sleep, single
│   │   └── CapsuleGlyph.swift     # NEW — Medication, single (horizontal two-tone)
│   ├── SignalLevel.swift          # reuse (numericValue/displayLabel/color/gradientPartner)
│   ├── Palette+Signals.swift      # reuse ramps (unchanged)
│   └── Icons.swift                # EDIT — remove/repoint signal SF Symbols
├── Models/Recording+MoodDisplay.swift   # EDIT — DisplayTag → glyph
└── Views/                          # EDIT — swap Image(systemName:) → SignalGlyph at the call sites below

app-fourTests/
└── SignalGlyphTests.swift          # NEW — clamp · a11y label · name/synonym (test-first)
```

**Structure Decision**: Single iOS SwiftUI target. One new `SignalGlyph` dispatcher view backed by five glyph files under `DesignSystem/Glyphs/`, consumed at every existing signal call site so the migration is a localized `Image(systemName:)` → `SignalGlyph(...)` swap. **Migration surface (production, non-wireframe):** `Recording+MoodDisplay.swift`, `InsightsViewModel+Signals.swift`, `CheckInView.swift`, `TextCheckInComposer.swift`, `ADHDSummarySection.swift`, `MoodBanner.swift`, `SummaryCard.swift`, `TimelineChip.swift`, `ExtractionReviewView.swift`, `Insights/DailyRhythmMatrix.swift`, `Insights/SignalAverageGauges.swift`, `Insights/SignalStripsView.swift`, plus `Icons.swift`. (`wireframes/CalendarWireframe.swift` is a scaffold — out of scope.)

## Complexity Tracking

*None — Constitution Check passes with no violations.*
