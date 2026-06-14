# Medication Bar — Plan of Action

> **Superseded 2026-06-10:** The bar is now a floating Liquid Glass capsule (`.glassEffect`, rounded, with side margins), matching the iOS 26 floating tab bar family. The "solid, no material" rule below is historical context only.

Goal: one medication bar, solid (no material), shown on top of the content, in the exact same position on every screen.

---

## What the code does now

- `MedicationBarView` already has a **solid** background (`secondarySystemBackground`) + thin border. Good.
- The **translucent material** comes from a `.background(.bar)` wrapper added *around* the bar in 3 places:
  - `DesignSystem/ScreenContainer.swift` (line ~76)
  - `Views/RecordingDetailView.swift` (line ~40)
  - `Views/Components/MedicationBarHeader.swift` (line ~19)
- Placement is **not** the same everywhere:
  - Calendar, Record, Insights, Settings → bar comes from `ScreenContainer` as a `safeAreaInset(.top)` (pushes content **down**, bar is not on top of content).
  - `RecordingDetailView` → does its **own** `safeAreaInset(.top)`, separate copy. This is the split.
- `MedicationBarHeader` is a third, unused-ish copy of the placement.

So: 3 material wrappers to remove, 2 different placement paths to merge into 1, "push down" to change to "on top".

---

## Target

1. **No material.** The bar uses its own solid background only.
2. **On top of the content.** The bar floats over the top of the scroll content (content scrolls under it), not a gap that pushes content down.
3. **One placement, used by all 5 screens** (Calendar, Record, Insights, Settings, Detail).
4. **Exact same position** on every screen: pinned at the top under the nav bar, same side padding, same height.

---

## Steps

### Step 1 — Make one shared placement modifier
**File:** new `DesignSystem/MedicationBarOverlay.swift`

- Create one `View` modifier, e.g. `.medicationBarOverlay()`.
- It puts `MedicationBarView` at the **top** using `.overlay(alignment: .top)` so the bar sits **on top of** the content.
- The bar keeps its own solid background (no `.background(.bar)`).
- It adds top content inset equal to the bar height + `Spacing.s`, so the first item is not hidden behind the bar when not scrolled.
- Fixed side padding: `Spacing.l`. Fixed vertical padding: `Spacing.s`.

This becomes the **only** place the bar is positioned.

### Step 2 — Remove the material wrappers
**Files:** `ScreenContainer.swift`, `RecordingDetailView.swift`, `MedicationBarHeader.swift`

- Delete every `.background(.bar)` that wraps the medication bar.
- The bar's own solid background stays.

### Step 3 — Make `ScreenContainer` use the shared modifier
**File:** `DesignSystem/ScreenContainer.swift`

- Remove the current `safeAreaInset(.top)` med-bar code.
- Apply `.medicationBarOverlay()` to the content instead (only when `showsMedicationBar` is true).
- Now Calendar, Record, Insights, Settings all get the bar from one path.

### Step 4 — Make Detail use the same path
**File:** `Views/RecordingDetailView.swift`

- Remove its own `safeAreaInset(.top)` med-bar block.
- Apply the same `.medicationBarOverlay()` to its `ScrollView`.
- Result: Detail bar is identical in look and position to the other screens.

### Step 5 — Delete the dead copy
**File:** `Views/Components/MedicationBarHeader.swift`

- After Steps 1–4, this helper is no longer needed. Delete it (and its preview), so there is only one placement path left.

### Step 6 — Handle the Calendar month header
**File:** `Views/Library/CalendarLibraryView.swift`

- The pinned month selector also uses `.background(.bar)`. That is a **different** element (a sticky section header), not the med bar.
- Make sure the month selector sits **below** the med bar, not under it.
- Give it a solid background too (`systemBackground`) so the med bar and the month header do not blur into each other.

---

## Consistency checklist (verify on every screen)

- [ ] Bar background is solid. No see-through / blur.
- [ ] Bar is on top of the content (content scrolls under it).
- [ ] Same distance from the top (just under the nav bar) on all 5 screens.
- [ ] Same side padding (`Spacing.l`) on all 5 screens.
- [ ] Same height on all 5 screens.
- [ ] First content item is fully visible at rest (not hidden behind the bar).
- [ ] Looks correct in light mode and dark mode.
- [ ] When the medication bar is turned off in Settings, no empty space is left.

---

## Files touched

| File | Action |
|---|---|
| `DesignSystem/MedicationBarOverlay.swift` | new — single placement modifier |
| `DesignSystem/ScreenContainer.swift` | use the modifier, remove `.background(.bar)` + old inset |
| `Views/RecordingDetailView.swift` | use the modifier, remove its own inset + `.background(.bar)` |
| `Views/Components/MedicationBarHeader.swift` | delete |
| `Views/Library/CalendarLibraryView.swift` | give month header a solid bg, keep it below the bar |
| `Views/Components/MedicationBarView.swift` | no change (already solid) — confirm only |

---

## Order
Step 1 → 2 → 3 → 4 → 5 → 6 → run the checklist.
