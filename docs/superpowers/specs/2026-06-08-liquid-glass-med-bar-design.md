# Liquid Glass Medication Bar + Scroll Edge Fades

**Date:** 2026-06-08  
**Branch:** insights-redesign  
**Scope:** Two independent visual changes — MedicationBarView material redesign, and soft scroll-edge fade on three ScrollViews.

---

## 1. MedicationBarView — Liquid Glass Redesign

### What changes
Replace the current flat `systemGray5` background track and opaque purple `LinearGradient` fill with a **glass shell + semi-transparent colored fill** pattern, matching the iOS 26 liquid glass design language already used elsewhere in the app (see `View+Glass.swift`, `GlassCard.swift`).

### Visual outcome
- The bar container becomes a frosted glass capsule that refracts the wallpaper behind it.
- A semi-transparent purple rectangle fills from the left edge, growing with `viewModel.progress`.
- White labels remain on top, unchanged.
- The bar keeps its existing 28pt height and 14pt corner radius.
- A hairline white stroke (matching `GlassCardModifier`) defines the edge of the glass shape.

### SwiftUI API
Target is iOS 26.4+, so the native `glassEffect` API is available:

```swift
// Outer container gets glass material
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
```

The progress fill uses a plain `Color.purple.opacity(0.42)` rectangle clipped to `geo.size.width * viewModel.progress`. This is intentionally not glass-on-glass — the fill is a colored overlay sitting inside the glass container, which is the correct usage per Apple's guidance (glass cannot sample other glass without a `GlassEffectContainer`).

### Files changed
- `app-two/Views/Components/MedicationBarView.swift`
  - `medicationBarContent(dose:)`: replace `ZStack` background and fill with glass + colored fill

### What stays the same
- Height (28pt), corner radius (14pt), padding (.horizontal 20, .vertical 12)
- Label text, font, weight, line limit
- `Button` wrapper with `.buttonStyle(.plain)`
- Accessibility label
- `@AppStorage` show/hide flags
- `MedicationLogSheet` presentation

---

## 2. Scroll Edge Top Fade

### What changes
Add `.scrollEdgeEffectStyle(.soft, for: .top)` to the primary `ScrollView` in three views. iOS 26 already applies a bottom soft fade automatically; this enables the matching top fade so content blurs and fades as it scrolls toward the top edge.

### Files changed

| View | File | Scroll position of med bar |
|------|------|---------------------------|
| `InsightsView` | `Views/InsightsView.swift` | Pinned above ScrollView |
| `MoodLibraryView` | `Views/MoodLibraryView.swift` | Pinned above ScrollView |
| `RecordingDetailView` | `Views/RecordingDetailView.swift` | Inside ScrollView (scrolls away) |

### What does NOT change
- `RecordView` — its main layout is a fixed `VStack`, no primary `ScrollView`. The small inline transcript `ScrollView` (120pt, live recording only) is left untouched.
- No layout or hierarchy changes to any of the three target views — just one modifier added to the existing `ScrollView` in each.

### Note on RecordingDetailView
The `MedicationBarView` in `RecordingDetailView` is the first child inside the `ScrollView`, so it scrolls away with the content. The top fade softens content against the navigation bar as the user scrolls. This is intentional — no layout restructuring needed.

---

## Acceptance criteria

1. `MedicationBarView` renders with a glass capsule background that shows the wallpaper/background through it, with a semi-transparent purple fill growing left-to-right as `viewModel.progress` increases.
2. White labels remain readable over the glass surface.
3. The bar's glass material looks coherent alongside the app's other glass surfaces (cards, settings toggles). Note: the bar uses the native iOS 26 `glassEffect` API (which includes lensing), not the older `ultraThinMaterial` pattern — this is intentional.
4. Scrolling down in `InsightsView`, `MoodLibraryView`, and `RecordingDetailView` produces a soft fade at the top scroll edge.
5. No change to RecordView's layout or behavior.
6. All existing `@AppStorage` show/hide flags continue to work.
7. Accessibility label is unchanged.
