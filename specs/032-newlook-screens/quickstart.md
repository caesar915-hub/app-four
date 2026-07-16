# Quickstart / Validation Guide: New Look Screens (Spec 032)

**Date**: 2026-07-10 · **Branch**: `feat/032-newlook-screens` · **Worktree**: `~/Projects/app-four-spm`

How to build, run, and prove the re-skin works end-to-end. No implementation code here — see
[data-model.md](data-model.md), [contracts/newlook-tokens.md](contracts/newlook-tokens.md), and
`tasks.md` (after `/speckit-tasks`).

## Prerequisites

- Work in the worktree `~/Projects/app-four-spm` on `feat/032-newlook-screens`.
- Owner builds/runs on device (no simulator per project rule); Claude writes code + runs the suite.
- Binding mockups open for side-by-side: Figma Squil-Design → "Screens (v2)" → a03 (`308:1654`),
  a02 (`308:1594`).

## Build & test (regression gate)

```
# design package compiles standalone
swift build --package-path Packages/SquirlDesignSystem

# app build + full suite (via ios-debugger-agent / XcodeBuildMCP)
#   – must be GREEN before any screen is reported done (Constitution II)
#   – ExtractionReviewViewModelTests + RecordingDetailViewModelTests are the
#     behavior regression gate (they must not change and must stay green — SC-002)
```

## Validate US0 — Foundation

1. `NewLook.swift` compiles; `NewLook.screen/card/inkPrimary/inkSecondary/hairline/selection` and
   `Radius.newLookCard == 20` exist; `Palette.medication` reused (not redefined).
2. `.card()`, `Theme.*`, `Typography.*` unchanged — `git diff` touches no P&P token values.
3. DESIGN.md has a "New Look" section (palette + radius + which screens use it) — FR-007.
4. **Expected**: package builds; app builds; suite green; no visual change anywhere yet.

## Validate US1 — a03 Edit check-in

Run the app → open a recording → Edit check-in. Check against a03 and
[contracts](contracts/newlook-tokens.md) C1–C9:
- Sage background, 16px gutter; white radius-20 shadow cards, **no borders**.
- Nav title centered between back/Save pills at any width.
- Headers bold sentence-case incl. **Side effects** (not SYMPTOMS).
- Tap a standard chip → solid green + white label; tap again → white + hairline.
- Tap a medication/dose chip → solid **purple** (never green).
- Save / Cancel → stored data identical to before (spot-check a value round-trip).
- **Expected**: visual parity with a03; zero behavior change; VM suite green.

## Validate US2 — a02 Recording detail

Run the app → open any recording detail. Check against a02 and C10–C17:
- Sage background, 16px gutter; 3-column hero (glyph · word · micro-label · bar).
- Info cards bold sentence-case + leading icon; one body text size.
- Audio plays; play control is medication purple; delete row is warm-clay danger.
- Long transcript wraps with no clip/overlap (bump text size to an accessibility size to confirm).
- **Expected**: visual parity with a02; playback/edit/delete unchanged; VM suite green.

## Cross-cutting acceptance (before PR)

- [ ] Style-literal audit of both view files = zero hardcoded color/radius/shadow (X1, SC-003):
      `grep -nE 'Color\(|#[0-9A-Fa-f]{6}|cornerRadius\([0-9]|\.padding\([0-9]' app-four/Views/ExtractionReviewView.swift app-four/Views/RecordingDetailView.swift` → only token references.
- [ ] Owner device QA: both screens in **light and dark**, at **default and an accessibility text
      size** — no illegible text, no clipping (X2, SC-004).
- [ ] Non-target screens spot-checked unchanged (Calendar, Insights, Settings) — mixed look is
      expected and intended (X4, FR-010/FR-011).
- [ ] Full suite green on branch → `/code-review` → PR to `main`.

## Gated — US3 (a01 Calendar timeline)

Do **not** run/validate until spec-029 is merged or abandoned (FR-012). Ships in a separate PR.

## Definition of done (this PR = US0 + US1 + US2)

Build green · full suite green (VM regression gate) · both screens match a03/a02 in light+dark ·
zero style literals · non-target screens unchanged · DESIGN.md New Look section · `/code-review`
clean · owner device QA sign-off.
