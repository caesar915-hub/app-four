# Contract — `SignalGlyph` view

The single UI surface every call site uses. The "contract" for a SwiftUI app is the view's public API + guaranteed behavior.

## API

```
SignalGlyph(
    _ kind: SignalKind,         // mood | energy | focus | sleep | medication
    level: Int? = nil,          // 1…5 for self-state signals; ignored for sleep/medication
    size: CGFloat = .signalGlyphDefault,  // scales with Dynamic Type by default
    decorative: Bool = false    // true → accessibilityHidden (row already announces)
)
```

## Guarantees

1. **Correct glyph per kind** — sprout / lightning / aperture / bed / horizontal capsule (FR-001…006).
2. **Level form** — for mood/energy/focus, the glyph's shape + fill change per level so adjacent levels differ by shape, not only hue (FR-004); ported from the approved generators.
3. **Color** — pulled from `SignalLevel`/`Palette` for the kind+level; never hard-coded; ramps unchanged (FR-009). Renders in light + dark (FR-014).
4. **Absent / out-of-range level** — `nil` → empty placeholder; out-of-range → clamped (FR-015). Never crashes, never draws a misleading level-1.
5. **Accessibility** — unless `decorative`, exposes one a11y element labeled `signalAccessibilityLabel(kind, level)` (FR-012). `decorative: true` → `.accessibilityHidden(true)`.
6. **No emoji faces** (FR-013). No SF Symbol fallback for these five signals (FR-007).
7. **Sizing** — legible from ~18px through Dynamic Type AX sizes without clipping (FR-011).

## Call-site usage (replaces `Image(systemName:)`)

| Surface | Before | After |
|---------|--------|-------|
| Timeline chip | `Image(systemName: "bolt.fill")` | `SignalGlyph(.energy, level: n, decorative: true)` |
| Mood/summary banner | `sparkles` / `bolt.fill` / `target` | `SignalGlyph(.mood/.energy/.focus, level:)` |
| Signal picker (Type-note, Edit) | SF Symbol row | `SignalGlyph(kind, level: l)` ×5 + ringed current + name/synonym |
| Insights ramps / gauges / matrix | SF Symbols | `SignalGlyph(kind, level:)` |
| Medication chip | `pills.fill` | `SignalGlyph(.medication)` |
| Sleep | `bed` | `SignalGlyph(.sleep)` |

## Out of scope

- The medication dose-progress bar (`MedicationBarOverlay`) — separate component, unchanged.
- The Sleep 1→5 ramp — deferred (single bed icon).
