# Phase 1 — Data Model: Paper & Pollen signal glyphs

This feature is **presentation-only** — no SwiftData / persistence change. The "model" here is the small value types and lookup tables the glyph layer needs.

## SignalKind (new enum)

| Case | Varies by level? | Color source | Glyph |
|------|------------------|--------------|-------|
| `mood` | yes (1–5) | `SignalLevel.color` (Meadow·Burnt ramp) | sprout |
| `energy` | yes (1–5) | `SignalLevel.color` (Lemon ramp) | lightning |
| `focus` | yes (1–5) | `SignalLevel.color` (Voltage-blue ramp) | aperture |
| `sleep` | no (single) | `Palette.sleepIndigo` (new token) | bed |
| `medication` | no (single) | `Palette.medication` (existing) | horizontal capsule |

## Level

- Type: `Int?` (absent allowed). Valid domain **1…5** for the self-state signals.
- `nil` → empty/placeholder glyph (FR-015). Out-of-range → `clampedSignalLevel(_:)` clamps to 1…5.
- Sleep / Medication ignore level entirely (single icon).

## Names + synonyms (static, per signal — picker labels, FR-010)

Ported from the canonical design system. `name` already exists as `SignalLevel.displayLabel`; `synonym` is new static data.

| Lvl | Mood (name / synonym) | Energy | Focus |
|-----|----------------------|--------|-------|
| 1 | Low / heavy, muted | Sluggish / slow | Foggy / hazy |
| 2 | Flat / dull, flat | Tired / drained | Distracted / restless |
| 3 | Okay / steady, fine | Steady / even | Present / grounded |
| 4 | Good / light, warm | Alert / ready | Sharp / keen |
| 5 | Great / bright, thriving | Charged / electric | Locked In / flowing |

## Pure helpers (Principle X — test-first)

- `clampedSignalLevel(_ raw: Int?) -> Int?` — nil passes through; ints clamp to 1…5.
- `signalAccessibilityLabel(_ kind: SignalKind, level: Int?) -> String` — e.g. `"Energy: Alert, 4 of 5"`; Sleep/Medication → `"Sleep"` / `"Medication"`.
- `signalSynonym(_ kind: SignalKind, level: Int) -> String` — table lookup above.

## Reused (unchanged)

- `SignalLevel` protocol (`numericValue` / `displayLabel` / `color` / `gradientPartner` / `fillGradient`).
- `Palette+Signals` ramps. New: `Palette.sleepIndigo`.
