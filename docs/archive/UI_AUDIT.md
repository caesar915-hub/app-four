> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# Whisper Notes — SwiftUI UI Audit

Audited against the project's own `swiftui-pro` and `swiftui-design-principles` skills (`.agents/skills/`).
Scope: the `app-two/Views`, `app-two/Utils`, and supporting view-model/model layers.

---

## TL;DR

Your instinct is right that the UI is not production-level — but **a full rewrite from scratch is the wrong move.** The data, service, and view-model layers are actually sound (proper `@Observable` + `@MainActor`, SwiftData `@Model`, protocol-based services, real unit tests). The rot is concentrated in **the View layer and the (missing) design system.** Rewrite the UI on top of the existing logic; don't throw away the engine.

Three findings explain everything you're seeing:

1. **There are two competing "Library" screens.** `RootTabView` shows `MoodLibraryView`; `LibraryView` (the "Whisper Notes" one with the `RecordingCell` list) is **dead code** wired to nothing but its own `#Preview`. That's literally why you "see whisper notes in the library view but not on the RootTab."
2. **There is no design system, despite two attempts at one.** A `GlassTypography` enum and `glassCard()` modifiers exist but are bypassed everywhere by raw values: 13+ distinct font sizes, 9 corner-radius values, mixed `.rounded`/`.monospaced`, hardcoded `.white.opacity(...)`.
3. **The same component is placed differently on every screen.** `MedicationBarView` appears as a floating overlay on two screens, an inline `VStack` child on a third, and a `safeAreaInset` on a fourth — different margins each time. That is the "same component in different shapes and sizes" you noticed.

---

## 1. Architecture & dead code (highest impact)

### `RootTabView.swift` + `LibraryView.swift` — duplicate, divergent screens

The "Library" tab renders `MoodLibraryView` (calendar/mood grouping). `LibraryView` (week-grouped `List` of `RecordingCell`, title "Whisper Notes") is **never referenced** outside its own file:

```
grep "LibraryView(" → only MoodLibraryView + LibraryView.swift's own #Preview
```

This drags along an entire dead stack: `LibraryView` → `LibraryViewModel` (`weekGroups`) → `RecordingCell` → `FilterChip`. Both view models wrap the same `RecordingStore` and re-implement date grouping. **You're maintaining two libraries and previewing the one that isn't shipped.**

> **Fix:** Decide which library is canonical. Delete the other view *and* its view model. If `RecordingCell`'s list style is the one you want, port it into `MoodLibraryView` and delete `MoodDaySection`'s duplicate; otherwise delete `RecordingCell`.

### Global singleton service-locator instead of injection

16 files reach directly into `AppDependencies.store` / `AppDependencies.screenTracker`. View models default to the global:

```swift
// Now — hidden global dependency, hard to preview/test in isolation
init(store: RecordingStore? = nil) {
    self.store = store ?? AppDependencies.store
}
```

```swift
// Better — inject through the SwiftUI Environment
@Environment(RecordingStore.self) private var store
```

This also creates **two parallel data paths**: `RootContainerView` reads settings via SwiftData `@Query`, while the screens read recordings via the custom `RecordingStore` singleton. Pick one ownership model for data flow.

### `RecordView` has no `NavigationStack`

Every other tab (`MoodLibraryView`, `InsightsView`, `SettingsView`) is wrapped in `NavigationStack`; `RecordView` is a bare `VStack`. Result: the Record tab has no nav bar, a different top inset, and a different background than its siblings — visible inconsistency when switching tabs.

### Misleading type name `RecordingMock`

```swift
typealias RecordingMock = Recording   // Models/Recording.swift:4
```

Production views (`RecordingCell`, `RecordingDetailView`, `AudioPlayerView`) take `RecordingMock` as their parameter type. It's the real model, but every reader has to learn that. Rename to `Recording`.

### Parallel UI surface: `AppTwoUIPlayground`

There's a second target with its own mock services and `ComponentGalleryView` / `StateGalleryView` / `ScreenGalleryView`. Useful in principle, but it's another place components can drift from the app. When you "preview," confirm whether you're seeing the app target or the playground.

---

## 2. Design system — there isn't one (high impact)

The `swiftui-design-principles` skill's whole thesis is *restraint and consistency*. The code violates it quantitatively:

| Dimension | Skill says | This codebase | Evidence |
|---|---|---|---|
| Font sizes | ≤ 5 distinct | **13+** | sizes 80, 72, 60, 32, 28, 20, 18, 16, 15, 14, 13, 12, 11 |
| Font design | pick ONE | **mixed** | `.rounded` ×7, `.monospaced` ×2 |
| Corner radius | 10pt standard | **9 values** | 40, 24, 20, 16, 12, 10, 8, 4, 2, 1 |
| Colors | semantic system | **hardcoded** | `.white.opacity(...)` in 5 files |
| Card pattern | one | **two** | `GlassCard` view *and* `glassCard()` modifier |

### Two card systems that look different

`GlassCard<Content>` (a wrapper view) **adds internal `.padding()`**; `GlassCardModifier` / `.glassCard()` **does not**. Same name, same material, different geometry depending on which the author reached for. Both hardcode `cornerRadius: 24` and a white stroke:

```swift
// Utils/View+Glass.swift — breaks in light mode, off the radius grid
.overlay(RoundedRectangle(cornerRadius: 24)
    .stroke(.white.opacity(0.15), lineWidth: 1))   // white-on-white in light mode
```

```swift
// Target: one card. Semantic, on-grid, adapts to light/dark.
extension View {
    func card() -> some View {
        self.padding(16)
            .background(Color(.secondarySystemBackground),
                        in: .rect(cornerRadius: 12))
    }
}
```

> Pick the modifier form (composes onto any view) **or** the wrapper form — not both. Delete `GlassCard.swift` or `View+Glass.swift`.

### The typography enum exists but is ignored

`GlassTypography` defines `hero/title/headline/body/...`, yet views write raw `.font(.system(size: 32))`, `.font(.body)`, `.font(.caption)` right next to `GlassTypography.headline`. A centralized scale that 80% of the code bypasses is worse than none — it implies a system that isn't enforced.

### Conflicting design docs = no source of truth

`DESIGN.md` describes an **"Origin Financial"** system (editorial **serif** headlines, dusk-sky dark theme, achromatic). The app implements a **Daylio-style liquid-glass** look with **`.rounded`** fonts. There are also `daylio-design.md`, `design-daylio.html`, and `design-exploration.html`. The design itself has never been decided, so the code couldn't converge even in principle. **Resolve this first — code can't be consistent against contradictory specs.**

---

## 3. Component placement drift (this is your "different shapes and sizes")

`MedicationBarView` — one component, four layouts:

| Screen | Placement | Horizontal margin |
|---|---|---|
| `MoodLibraryView` | floating `ZStack` overlay + `barHeight` geometry + `edgeFadeMask` | 20 |
| `InsightsView` | floating `ZStack` overlay + `barHeight` geometry + `edgeFadeMask` | 20 |
| `RecordView` | inline `VStack` child | 24 |
| `SettingsView` | `.safeAreaInset(edge: .top)` | 24 |

Two screens duplicate a non-trivial floating-overlay + geometry-measurement pattern by copy-paste; the other two each invent their own. Same with outer content margins (20 on two screens, 24 on two others). **The eye reads this as the component "changing size" between tabs.**

> **Fix:** Wrap it once. A single `MedicationBarHeader` (or a `.screenScaffold()` container) that owns the placement, the safe-area behavior, and the margin — applied identically on every tab.

### `RecordView` — `glassCard` on a `Circle`

```swift
Circle().fill(...).frame(width: 80, height: 80)
    .glassCard(cornerRadius: 40)   // lays a rounded-RECT material+stroke over a circle
```

A rounded-rectangle card modifier on a circular button overlays a mismatched stroke. Use a circular treatment (`.background(.ultraThinMaterial, in: .circle)` or an `overlay(Circle().stroke(...))`) instead.

---

## 4. Smaller `swiftui-pro` items

- **`TopicChip` / `FilterChip`** (`TopicChip.swift`) — near-identical chips with hardcoded radius 16 and `.opacity(0.15)/0.1/0.2` magic numbers. Unify into one `Chip` with a `selected` style.
- **`RootTabView`** uses an `Int` tag for `selectedTab`. An enum (`case library, record, insights, settings`) removes magic numbers (`selectedTab = 1` in the deep-link handler) and is self-documenting.
- **Hardcoded `.white` text** on accent buttons (`RecordView`, `RecordingCell` avatar) won't follow accent-color contrast changes; prefer a semantic on-accent style.
- **`minimumScaleFactor` / fixed heights** — none egregious yet, but watch `frame(height:)` on `TimeOfDayBars`/`WeeklyBars` paired with hardcoded font sizes; verify Dynamic Type doesn't clip.

---

## Recommendation: rebuild the UI layer, not the app

**Don't start from zero.** Keep `Models/`, `Services/`, `Store/`, `ViewModels/`, and the test suite — they're the parts that look production-level. Rewrite the View + design layer in place. This gets you the "clean rewrite" feeling without re-deriving working business logic or risking data-layer regressions.

Suggested order:

**Phase 0 — Decide the design (blocking).** Reconcile `DESIGN.md` vs the Daylio docs into ONE spec: type scale (≤5 sizes), one font design, spacing grid (4/8/12/16/20/24/32), corner radius (10–12), semantic colors. Archive the losing docs.

**Phase 1 — Delete dead code.** Remove the non-canonical library (`LibraryView` + `LibraryViewModel`, or `MoodLibraryView` + `MoodLibraryViewModel`) and one of the two card systems. Rename `RecordingMock` → `Recording`. This alone shrinks the surface area and kills the "whisper notes only in preview" confusion.

**Phase 2 — Build the token layer.** A `Theme` (or `DesignSystem`) enum for spacing/typography/color, one `.card()` modifier, one `Chip`, one `MedicationBarHeader`, one `.screenScaffold()` container that standardizes `NavigationStack` + top inset + margins for all four tabs.

**Phase 3 — Rebuild each screen against tokens.** One tab at a time, deleting raw `.font(.system(size:))` / hardcoded radii / `.white.opacity` as you go. Add `RecordView`'s missing `NavigationStack`.

**Phase 4 — Inject dependencies via Environment** instead of `AppDependencies.*`, so previews and tests construct screens with controlled stores.

If you'd like, I can start on Phase 1 (safe deletions) and scaffold the Phase 2 `Theme` + `.card()` + `.screenScaffold()` so every screen finally shares one source of truth.
