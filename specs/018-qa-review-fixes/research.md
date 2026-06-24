# Phase 0 Research: QA fixes (018)

The spec carries zero `[NEEDS CLARIFICATION]` markers; the only genuine unknowns are *how* to implement A2's measured top fade and A2's `List` mask, plus the small confirmations for A1 and A3. Each is resolved below.

---

## D1 — How to size the A2 top fade to the medication bar (FR-003)

**Problem**: `EdgeFadeMask` draws its top gradient over a frame that `.ignoresSafeArea()`, so the fade region is measured from the *physical top of the scroll frame* (under the nav/status bar). The fade must reach down to the **bottom edge of the floating medication bar**, whose height grows with Dynamic Type. The naïve read fails: the bar is a `safeAreaInset(edge: .top)`, which *consumes* the content's top inset — so reading `proxy.safeAreaInsets.top` from inside the content returns ~0, not the bar height.

**Decision**: Measure the medication bar's rendered height where it is actually laid out (in `MedicationBarOverlay`), via `onGeometryChange(for: CGFloat.self) { $0.size.height }` on the bar, and surface that height to the masking screen (preference key or a bound `@State` on the shared container). The screen passes `topFade = measuredBarHeight + topGap` to `edgeFadeMask(top:)`. When the bar is hidden, the measured height is 0 → no top fade (FR-004).

**Rationale**: Measuring the bar directly is the one source that is correct across Dynamic Type and the with/without-bar cases, and it keeps the fade height derived *once per layout* (not per scroll frame), satisfying the 60 fps constraint. It reuses `EdgeFadeMask` unchanged.

**Alternatives considered**:
- *Hardcode a constant* (today's `top: 0`, or a magic `~60`): rejected — drifts under Dynamic Type, the exact defect FR-003 forbids.
- *Read scroll `contentInsets.top` via `onScrollGeometryChange`*: viable (it includes the consumed inset) but couples the fade to a scroll callback firing each frame, and that API isn't currently used anywhere in the tree (the Calendar header fade was reworked off it). More moving parts than measuring the bar once.
- *Re-introduce the Calendar header-style opacity fade*: rejected — that's a different mechanism for a different screen; A2 is specifically the edge mask the bottom already uses.

**On-sim validation required**: the exact `topGap` and whether the mask frame's origin sits above or below the nav bar must be eyeballed on the simulator (light/dark, default + an AX text size) before "done" — the decision fixes the *approach*, the pixel offset is tuned in implementation.

---

## D2 — Applying the top fade to Settings' native `List` (FR-002, FR-005)

**Problem**: Settings uses `ScreenContainer(scrollable: false)` + its own `List` ([SettingsView.swift#L43-L45](../../app-four/Views/SettingsView.swift#L43)), so it has no `edgeFadeMask` at all today. A `.mask` over a `List` can interfere with separators, scroll indicators, selection, and the tab-reselect scroll-to-top.

**Decision**: Apply the same `edgeFadeMask(top: measuredBarHeight, bottom:)` modifier to the `List` (the modifier is content-agnostic — it masks whatever view it wraps). Verify on-sim that separators, row tap/selection, and `ScrollViewReader` scroll-to-top still behave.

**Rationale**: One mechanism for both screens (Minimal Surface); `List` is a scrollable view and accepts `.mask` like any other. The mask only affects rendering, not hit-testing or scroll position, so interaction should survive — but this is the highest-risk item, hence the explicit on-sim check (FR-005).

**Alternatives considered**:
- *Convert Settings to a `ScrollView`+`LazyVStack`*: rejected — discards native grouped-`List` chrome the 017 spec deliberately keeps, and is far more than this fix needs.
- *Top gradient overlay instead of a mask*: rejected — an opaque-to-clear overlay tinted to the background works only on a flat background and would smear over the bar's glass; the mask dissolves to true transparency, matching the bottom edge.

---

## D3 — A1: keep the marker dot, dimmed (FR-007, FR-008, FR-011)

**Decision**: In `CalendarDayCell.marker` ([CalendarDayCell.swift#L52-L62](../../app-four/Views/Components/CalendarDayCell.swift#L52)), remove the `if isAboveSelection { Color.clear }` branch so the normal `.mood`/`.neutral`/`.none` marker renders for above-selection days too. The cell already applies `.opacity(Opacity.deEmphasis)` to the whole `VStack` ([#L36](../../app-four/Views/Components/CalendarDayCell.swift#L36)), so number + dot dim together automatically — no per-marker opacity needed. The `a11yLabel` already reports "has check-ins"/"has entries" from `cell.marker` and is unaffected by the visual change, so FR-011 holds without extra work.

**Rationale**: Smallest possible change that satisfies the owner's decision; the de-emphasis cue becomes "the whole cell is dimmer," which is what the parent opacity already does. The empty-day case (`.none` → `Color.clear`) is unchanged (FR-010).

**Tradeoff (must be recorded in 014, FR-009)**: 014's FR-011/FR-014 dropped the dot as a *non-colour, greyscale-safe* second cue; dimming-by-opacity is a weaker cue for users who can't perceive the opacity delta (Reduce Transparency / low-vision). The owner accepted this. Mitigation already in place: the VoiceOver label distinguishes registered days regardless of the visual.

**Alternatives considered**: hollow/outline dot (preserves greyscale-safety AND shows data) — the recommended option, but the owner chose dim-the-filled-dot for simplicity; recorded and not re-litigated.

---

## D4 — A3: tokenise the Log-Dose sheet (FR-012, FR-013, FR-014)

**Decision**: Treat A3 as a design-system audit of `MedicationLogSheet`. Before editing, reproduce Check-in → Log meds on-sim and screenshot to pin the exact flagged element (Assumptions). Then: give the `Form`/sheet the app's surface treatment (`Theme.background` / scoped `.scrollContentBackground`), and replace the chips' `Color.secondary.opacity(0.15)` / `Palette.medication.opacity(0.25)` with the design-system's defined selected/unselected medication-chip tokens (matching the chips used elsewhere, e.g. the ExtractionReview/med picker chips). Verify light + dark.

**Rationale**: The walkthrough couldn't pin the exact element, but the systemic cause is clear (untokenised `Form`). An audit-and-tokenise pass corrects the flagged colour and any sibling drift in one go, and matching existing chip styling keeps it consistent rather than inventing a new look.

**Alternatives considered**:
- *Spot-fix only the one colour the owner saw*: rejected — leaves the rest of the sheet off-system; the sheet is small enough to bring fully in line.
- *Defer until repro*: the repro is folded into the implementation task (it's a 1-minute on-sim step), so no need to block the plan.

**Dependency**: the exact tokens come from `DESIGN.md` / existing chip components; if `DESIGN.md` lacks a Log-Dose-specific spec, reuse the established med-chip tokens (no new tokens invented — Minimal Surface).

---

## Cross-cutting confirmations

- **No data model / no schema / no persistence** touched (FR-015) → `data-model.md` records "none."
- **No new services or view-model logic** → no Principle VIII/X test obligations; verification is build + on-sim.
- **Existing tests** (`CalendarHeaderScrollFadeTests`, calendar/insights/medication suites) must stay green; none should need editing because the changed surfaces are view-presentation, but if any snapshot/preview asserts the dropped dot it is updated to match D3.
