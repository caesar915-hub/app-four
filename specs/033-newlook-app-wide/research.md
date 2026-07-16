# Phase 0 Research — App-Wide New Look Migration

**Date**: 2026-07-11. All decisions grounded in a live read of the codebase (`app-four-spm`) and the Figma source of truth (file Squil-Design `M0Meys9X89X1NLyT14qrX5`, screens a02 `308:1594` / a03 `308:1654`). No open `NEEDS CLARIFICATION`.

---

## D1 — Token strategy: migrate call sites, do NOT alias

**Decision**: Replace `Theme.*` surface/ink references and `.card()` with `NewLook.*` and `.newLookCard()` at each call site. Do not re-point `Theme.background`/`cardBackground` to New Look values.

**Rationale**: The New Look card is a **shape** change — `.card()` is `Radius.card` (16) + a 1px `Theme.cardStroke` border + shadow; `.newLookCard()` is `Radius.newLookCard` (20), **borderless**, soft shadow. Colour-aliasing leaves the border and radius-16 intact, so it cannot produce the target card. Aliasing would also be a compat shim over dead tokens — forbidden by Constitution III.

**Alternatives rejected**: (A) alias tokens — fails the shape requirement + leaves dead code; (C) introduce a third semantic token layer both systems feed — premature abstraction (Constitution IV), and the endgame is convergence on one system, not two runtime-selectable looks.

---

## D2 — Groove/inset token: add `NewLook.tintNeutral`

**Decision**: Add `NewLook.tintNeutral = Color(lightHex: "#ECEAE6", darkHex: "#272A22")` (scope: fills). Use it for every progress track / gauge groove / segmented fill (`SignalAverageGauges` track, `ConnectionCards` MiniBar track, med-bar `DoseTrack`, RecordingDetail level-bar).

**Rationale**: The a02 detail screen binds Figma `tint/neutral = #eceae6` for exactly these grooves — it is the source-of-truth inset colour and the New Look replacement for `Theme.surface2`. Matching it keeps code 1:1 with Figma.

**Alternatives rejected**: reuse `NewLook.hairline` (#DBDDDE) — Figma uses a distinct token; RecordingDetailView's current use of `hairline` for its level-bar groove is a small deviation to *correct* toward `tintNeutral`. Reuse `NewLook.card` (white) — invisible on a white card. `Palette.medication.opacity(0.15)` — tints every groove purple. Dark value derived per the New Look cool-dark convention, validated at device QA.

---

## D3 — Card shadow: two-layer to match Figma

**Decision**: `.newLookCard()` uses the two-layer `Tiimo/Shadow/Card`: `#0000000D` (offset 0,2, radius 8) + `#00000008` (offset 0,1, radius 2).

**Rationale**: The shipped modifier uses a single-layer approximation (`.black.opacity(0.06)`, r8, y2). The two-layer spec is the Figma card effect; adopting it is exact parity at trivial cost (FR-002). Because `.newLookCard()` is shared, this also upgrades the two spec-032 screens (verify they read correctly — FR-013).

**Alternatives rejected**: keep single-layer — a visible fidelity gap once every card is New Look.

---

## D4 — Medication-bar data fix: tag the logged dose to the active mode

**Decision**: `MedicationBarViewModel.logManualDose` sets `event.isMockData = UserDefaults.standard.bool(forKey: "debugMockMode")` when creating the dose, so a dose logged in the current mode passes the `isMockData == mockMode` filter and appears. Delivered **test-first**.

**Rationale**: Root cause — `refresh()` filters `isMockData == mockMode`; `logManualDose` never set `isMockData` (defaults `false`), and `debugMockMode` defaults `true` in dev builds → real logged doses are silently hidden (Release inverts it). Tagging the new dose to the active partition is the minimal fix that preserves the Constitution-IX mock/real partition. It is logic in an `@Observable` VM → Principle X requires a failing test first.

**Alternatives rejected**: (A) show real doses regardless of mode — collapses the demo/real partition (violates IX intent, larger blast radius); (B) remove the `isMockData` filter — same problem; (C) flip the `debugMockMode` default — hides seeded demo data instead, doesn't fix the general case.

**Open dark corner (noted, out of scope)**: `refresh()` filter #4 uses strict `> now`, so `progress` caps at 1.0 and the `"worn off"` state word is unreachable — a pre-existing cosmetic dead branch, not this feature's concern.

---

## D5 — Tab-bar appearance for the sage ground

**Decision**: Give the tab bar (and nav bars not already covered by `ScreenContainer.toolbarBackground`) an explicit New Look appearance so it reads as part of the sage ground. Prefer SwiftUI (`.toolbarBackground(NewLook.screen, for: .tabBar)` on iOS 26) where it fully controls the material; fall back to a scoped `UITabBarAppearance`/`UINavigationBarAppearance` configured once at app launch if SwiftUI cannot set the resting material.

**Rationale**: `RootTabView` sets only `.tint(Theme.meadowGreen)` — no bar appearance exists, so the bar falls back to system material and will not match sage (FR-007, reverses spec-032 FR-011). This is the one place a UIKit appearance proxy may be required; Constitution I permits UIKit where SwiftUI has no equivalent, and it is isolated to app launch.

**Alternatives rejected**: leave the system default — visible chrome mismatch on sage.

---

## D6 — Delivery: slice-first, four PRs

**Decision**: PR-0 Foundations (invisible) → PR-1 The Look (ground + cards + tab bar + med-bar re-skin) → PR-2 Ink (text tokens) → PR-3 Cleanup (delete dead tokens). One PR per increment; med-bar data fix (US3) rides PR-1 or lands standalone.

**Rationale**: `ScreenContainer` + the card surfaces are the highest-leverage change — PR-1 alone flips the whole app to a coherent look, giving an immediately shippable result and the largest, most reviewable visual diff first. Small revertable PRs keep `main` releasable (V); the interim mixed state between PRs is already sanctioned (spec-032 FR-010).

**Alternatives rejected**: one big-bang PR — unreviewable, breaks releasability (V).

---

## D7 — Mockup gate for shape-changing screens

**Decision**: The a-screens satisfy Constitution I for the mechanical colour/card swap. For the two surfaces whose card *shape* changes non-trivially — Insights cards (`ConnectionCardsView` unlocked/gated dashed cards, gauges) and Settings — either produce a Figma New Look mockup before implementing, or (Settings default) recolour the system inset-grouped rows to `NewLook.card` keeping the system radius, deferring a full r20 card treatment.

**Rationale**: Principle I wants a mockup before new view shapes; a pure token swap of an already-designed language does not, but a genuine layout/shape change does.

**Alternatives rejected**: skip mockups everywhere — risks unspecified Insights/Settings shapes; full r20 Settings rebuild now — larger, unmocked, lower priority.

---

## D8 — Keep semantic colours on `Theme`; chip selection green

**Decision**: `Theme` is **not** fully deleted. It retains `accent`, `meadowGreen/Amber`, `meadowGradient`, `statusDone/InProgress`, `danger`. Only surface/ink tokens are deleted (D10). Filter chips that currently select with `Theme.accent` (bronze) move to `NewLook.selection` (green) for New Look consistency; the destructive colour stays warm-clay `Theme.danger`, NOT Figma `ink/destructive #e0443a` (FR-015, spec-032 C15).

**Rationale**: New Look defines no accent/status/gradient tokens (only `selection`); those roles have no New Look equivalent and must stay. Green selection matches the a03 chip grammar; warm clay is a locked, intentional deviation.

**Alternatives rejected**: delete all of Theme — breaks accent/status/danger; adopt Figma red destructive — reverses a locked decision.

---

## D9 — Calendar timeline stays gated

**Decision**: The Calendar day timeline (spec-032 US3 / Figma a01) is excluded until `feat/029-calendar-day-context` is merged or abandoned; migrate it under this spec only after the gate opens.

**Rationale**: spec-029 rewrites the same views; migrating now creates a large merge-conflict surface (FR-018, mirrors spec-032 FR-012).

---

## D10 — Verify-only migrated screens; deletion gate

**Decision**: `RecordingDetailView`, `ExtractionReviewView`, `ADHDSummarySection` are verify-only (already New Look) — never re-Themed, only confirmed correct on the consolidated tokens (esp. the D3 shadow, D2 groove). The Theme surface/ink token deletion (PR-3) is gated on a full-repo grep (including `SandboxApp/` and tests) returning zero references, then a clean rebuild.

**Rationale**: A `Theme.*` grep is structurally blind to these already-migrated files; re-migrating them would regress. Deleting a token with a live reference breaks the build — the grep gate prevents it (Constitution II/III).

---

## Resolved deltas summary (code ↔ Figma)

| Delta | Resolution | Requirement |
|---|---|---|
| Missing groove token | Add `NewLook.tintNeutral = #ECEAE6` | FR-001 |
| Single- vs two-layer card shadow | Adopt 2-layer `Tiimo/Shadow/Card` | FR-002 |
| Figma `ink/destructive` vs code warm clay | Keep warm-clay `Theme.danger` (locked) | FR-015 |
| Real logged doses hidden | Tag `isMockData` on log (test-first) | FR-009 |
| No tab-bar appearance | Add sage/white appearance | FR-007 |
