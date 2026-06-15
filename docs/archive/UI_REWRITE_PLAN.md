> **⚠️ HISTORICAL SNAPSHOT — superseded.** Frozen 2026-06-15. Pre-app-four (WhisperNotes/app-two era); does not reflect current project state. Current architecture lives in the Notion `app-two` DB, [docs/BACKLOG.md](../BACKLOG.md), and [docs/DEVLOG.md](../DEVLOG.md). Any "Gemma" mention is historical — Gemma was removed before the app-four fork.

# Whisper Notes — UI Rewrite Plan

Companion to `UI_AUDIT.md`. This is the full, task-level plan. **No code is changed by this document** — it's the blueprint to review first.

### Decisions locked (from the audit follow-up)
1. **Two library tabs, reconciled.** Keep both the mood/calendar library and the week-grouped notes list, but make them share one row component and one card style. (Tab count goes 4 → 5.)
2. **Native iOS / system-default design.** Semantic colors, system fonts + Dynamic Type, `.secondarySystemBackground` cards, system `Divider`. Minimum custom code; automatic light/dark + accessibility.
3. **Plan only.** No deletions or refactors yet.

---

## 0. Guardrails & non-goals

- **Do not touch business logic.** `Models/`, `Services/`, `Store/`, and the *logic* inside `ViewModels/` stay as-is. The only VM change is the dependency-injection seam (Phase 5).
- **Tests stay green** at every phase boundary. Run the existing `app-twoTests` suite before merging each phase.
- **One phase = one PR.** Each phase compiles and ships on its own; no half-migrated `main`.
- **No new third-party dependencies.**
- **Delete as you replace.** A component is removed in the same PR that makes it unreferenced — never leave a second orphan like today's `LibraryView`.

---

## 1. Target architecture

```
app-two/
  DesignSystem/                ← NEW: the single source of visual truth
    Spacing.swift              ← grid constants
    Radius.swift               ← corner-radius constants
    Typography.swift           ← Dynamic-Type text-style helpers
    Theme.swift                ← semantic color roles (thin wrapper over system)
    Card.swift                 ← the ONE .card() modifier
    ScreenContainer.swift      ← standard NavigationStack + margins + top bar
  Views/
    Components/                ← shared, token-built widgets only
      RecordingRow.swift       ← the ONE recording cell (both libraries use it)
      Chip.swift               ← replaces TopicChip + FilterChip
      MedicationBarHeader.swift← the ONE placement of MedicationBarView
    Library/
      CalendarLibraryView.swift  (was MoodLibraryView)
      NotesLibraryView.swift     (was LibraryView)
    Record/ RecordView.swift
    Insights/ ...
    Settings/ ...
```

**Three pillars** every screen is rebuilt on:

- **Tokens** (`DesignSystem/`) — no raw `.font(.system(size:))`, no raw radii, no `.white.opacity`.
- **`ScreenContainer`** — one wrapper that owns `NavigationStack`, outer margins, and the medication header, so every tab has identical chrome.
- **Shared components** — `RecordingRow`, `Chip`, `Card`, `MedicationBarHeader` defined once.

---

## 2. Design tokens — concrete spec (native)

### Spacing (`Spacing.swift`)
```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 8
    static let m:  CGFloat = 12
    static let l:  CGFloat = 16   // standard outer margin
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let section: CGFloat = 32
}
```
Rule: outer content margin = `Spacing.l` (16) on **every** screen. No more 20-vs-24 drift.

### Radius (`Radius.swift`)
```swift
enum Radius {
    static let card: CGFloat = 12   // cards, sheets-content
    static let control: CGFloat = 10 // chips, buttons
}
```
That's it — two values. (Circular elements use `.circle`, not a radius.)

### Typography (`Typography.swift`)
Use **Dynamic Type text styles**, not fixed sizes — this is the native, accessible default and removes the 13-sizes problem by construction:
```swift
// Roles, mapped to system text styles (system font, no .rounded/.monospaced)
.largeTitle  → screen hero (rare)
.title2      → section titles
.headline    → row titles
.subheadline → group/section headers
.body        → primary text
.callout     → secondary text
.caption     → metadata / timestamps
```
Single justified exception: timers/durations use `.body.monospacedDigit()` (digit alignment), **not** a full `.monospaced` design. Delete `GlassTypography` (the `.rounded` enum that's bypassed today).

### Color (`Theme.swift`)
Thin semantic wrapper — no hardcoded values:
```swift
Color.primary / .secondary / .tertiary        // text
Color(.systemBackground)                        // screen background
Color(.secondarySystemBackground)               // cards/groups
Color(.separator)                               // dividers
Color.accentColor                               // single accent (set in asset catalog)
// status: .green (done), .orange (in-progress) — semantic, 2 values max
```
Removes all `.white.opacity(...)` and `Color.black` usage (5 files today).

### The one card (`Card.swift`)
```swift
extension View {
    func card(padding: CGFloat = Spacing.l) -> some View {
        self.padding(padding)
            .background(Color(.secondarySystemBackground),
                        in: .rect(cornerRadius: Radius.card))
    }
}
```
Replaces **both** `GlassCard` (view) and `glassCard()`/`floatingCard()` (modifiers). Delete `View+Glass.swift` and `Components/GlassCard.swift`.

### Acceptance test for the token layer
A repo-wide grep after the rewrite should return ~0 hits in `Views/`:
```
.font(.system(size:        → 0
cornerRadius: <not Radius.> → 0
.white.opacity / Color.black→ 0
glassCard / GlassCard       → 0
```

---

## 3. Tab structure after rewrite

`RootTabView` goes from 4 → 5 tabs, keyed by an **enum** instead of `Int`:
```swift
enum Tab: Hashable { case calendar, notes, record, insights, settings }
```
| Tab | Icon | Screen |
|---|---|---|
| Calendar | `calendar` | `CalendarLibraryView` (was MoodLibraryView) |
| Notes | `list.bullet` | `NotesLibraryView` (was LibraryView) |
| Record | `waveform.circle.fill` | `RecordView` |
| Insights | `chart.bar.fill` | `InsightsView` |
| Settings | `gear` | `SettingsView` |

> Note: 5 is iOS's max before a "More" tab appears — this sits right at the limit, which is fine but leaves no room to grow. Flagged, not blocking. The deep-link handler's `selectedTab = 1` becomes `selectedTab = .record`.

---

## 4. Component inventory — keep / merge / delete

| Current | Action | Becomes |
|---|---|---|
| `LibraryView` | **Keep, rewire** | `NotesLibraryView` (now in a tab) |
| `MoodLibraryView` | **Keep, rename** | `CalendarLibraryView` |
| `LibraryViewModel` / `MoodLibraryViewModel` | **Keep both** | unchanged logic; injected store |
| `RecordingCell` + `MoodDaySection` row | **Merge** | one `RecordingRow` used by both libraries |
| `GlassCard` (view) + `glassCard()`/`floatingCard()` | **Merge → delete both** | `.card()` modifier |
| `GlassTypography` | **Delete** | `Typography` text-style roles |
| `TopicChip` + `FilterChip` | **Merge** | one `Chip(style:)` |
| `MedicationBarView` placements (×4) | **Centralize** | `MedicationBarHeader` via `ScreenContainer` |
| `RecordingMock` typealias | **Delete** | use `Recording` directly |
| `View+Glass.swift`, `Components/GlassCard.swift` | **Delete** | — |

---

## Phase 1 — Token layer (no visual change)

**Goal:** land `DesignSystem/` with zero screens consuming it yet. Pure addition, trivially safe.

- Add `Spacing`, `Radius`, `Typography`, `Theme`, `Card.swift`, `ScreenContainer.swift`.
- Set a single `AccentColor` in the asset catalog (replace scattered `Color.accentColor` assumptions).
- `ScreenContainer` API sketch:
  ```swift
  struct ScreenContainer<Content: View>: View {
      let title: String
      var showsMedicationBar = true
      @ViewBuilder let content: () -> Content
      // owns NavigationStack + .navigationTitle + Spacing.l margins + MedicationBarHeader
  }
  ```

**Files:** +7 new under `DesignSystem/`. No deletions.
**Acceptance:** project builds; new files have `#Preview`s; no existing screen imports them yet.
**Verify:** build succeeds; previews render in light **and** dark.

---

## Phase 2 — Shared components

**Goal:** build the reusable widgets every screen will consume.

- `RecordingRow` — merge `RecordingCell` + `MoodDaySection`'s row. Built from `Typography.headline` (title), `.caption` (date), status pill, topic dots, `.card()`. Takes `Recording`.
- `Chip` — one view with `enum Style { case filter(selected: Bool), topic(TopicCategory) }`, on `Radius.control`.
- `MedicationBarHeader` — wraps `MedicationBarView` with one fixed placement/margin; consumed only via `ScreenContainer`.

**Files:** +`RecordingRow.swift`, +`Chip.swift`, +`MedicationBarHeader.swift`. (Old ones still present; deleted as each consumer migrates.)
**Acceptance:** each has a `#Preview` showing empty/loading/done states.
**Verify:** build; preview the three states; VoiceOver label reads correctly on `RecordingRow`.

---

## Phase 3 — Reconcile the two libraries

**Goal:** both library tabs render through `ScreenContainer` and share `RecordingRow`.

- Rename `MoodLibraryView` → `CalendarLibraryView`; replace its bespoke floating-overlay + `barHeight` geometry with `ScreenContainer(showsMedicationBar:)`. Day-group rows now use `RecordingRow`.
- Rewire `LibraryView` → `NotesLibraryView`; keep search + filter chips (now `Chip`) + week grouping; rows use `RecordingRow`. Remove its dead `#Preview`-only status.
- Update `RootTabView`: enum-keyed, add the second library tab (see §3).

**Files:** rename ×1, edit ×2, edit `RootTabView`. Delete `RecordingCell.swift` and the inline row in `MoodDaySection` once unreferenced.
**Acceptance:** both tabs visible and navigable; same row look in both; delete/edit still works in Notes; calendar navigation still works.
**Verify:** build; run on simulator, tab through both; run `LibraryViewModelTests`.

---

## Phase 4 — Rebuild remaining screens against tokens

**Goal:** Record / Insights / Settings adopt `ScreenContainer` + tokens.

- **`RecordView`:** wrap in `ScreenContainer` (**fixes the missing `NavigationStack`**). Replace `.glassCard(cornerRadius: 40)` on the record circle with a circular treatment. Route all fonts through `Typography`, spacing through `Spacing`.
- **`InsightsView`:** swap the floating-overlay pattern for `ScreenContainer`; chart frames keep fixed heights but verify against Dynamic Type XL.
- **`SettingsView`:** replace the local `horizontalMargin/innerPadding` constants with `Spacing`; sections use `.card()`.

**Files:** edit `RecordView`, `InsightsView`, `SettingsView`, `Insights/*` as needed.
**Acceptance:** all four tabs share identical margins, top chrome, and medication-bar placement.
**Verify:** build; screenshot all tabs at default + accessibility XL text size; confirm no clipping.

---

## Phase 5 — Dependency injection via Environment

**Goal:** remove the global service-locator from the UI layer.

- Inject `RecordingStore` (and `ScreenTracker`) through `.environment(...)` at `WhisperNotesApp`.
- View models take the store explicitly; drop the `?? AppDependencies.store` fallback.
- Screen tracking moves to a single `.trackScreen("…")` modifier instead of 5 copies of `AppDependencies.screenTracker.currentScreen = …` in `.onAppear`.

**Files:** edit `WhisperNotesApp`, all 5 VMs, all top-level screens (remove direct `AppDependencies.*`).
**Acceptance:** `grep AppDependencies\\. Views ViewModels` → 0 hits.
**Verify:** build; full test suite; previews construct screens with an in-memory store.

---

## Phase 6 — Cleanup & final verification

- Delete: `View+Glass.swift`, `Components/GlassCard.swift`, `GlassTypography.swift`, `RecordingMock` typealias, `RecordingMock.swift`, any now-dead VM.
- Reconcile design docs: pick `DESIGN.md` as the home of the **native** spec (this plan's §2), archive `daylio-design.md` / `design-*.html` to `/docs/archive`.
- Run the token-layer grep acceptance tests from §2.
- Decide the fate of `AppTwoUIPlayground`: update its galleries to the new components, or mark it clearly as a scratch target.

**Acceptance:** all §2 greps return ~0; suite green; app builds clean with no warnings from removed symbols.

---

## Sequencing, risk, rollback

- **Order matters:** 1 → 2 → 3 → 4 → 5 → 6. Tokens and shared components exist *before* any screen depends on them, so no phase is half-migrated.
- **Lowest risk first** (pure additions in 1–2), highest-touch last (injection in 5).
- **Rollback unit = the phase PR.** Because logic is untouched and each phase compiles independently, reverting one PR never corrupts data or the model layer.
- **Biggest risk:** the 5-tab decision crowds the tab bar and removes growth room — revisit if a 6th destination ever appears (would force a "More" tab or a combined library with a segmented control).

---

## What I'd want confirmed before Phase 1

- Tab labels/icons for the two libraries (proposed: **Calendar** `calendar`, **Notes** `list.bullet`).
- Accent color value for the asset catalog (or keep system blue).
- Whether `AppTwoUIPlayground` should be kept and updated, or retired.
