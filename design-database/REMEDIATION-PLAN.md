<!-- Created: 2026-07-18 19:12 (WEST) · Updated: 2026-07-18 19:12 (WEST) -->
# Design Remediation Plan — Screens v3 (a01–a08)

Derived from the 4-lens perceptual audit (`perceptual-audit.csv`, R29–R32) + audits №1–3 (`token-consistency-audit.csv`, `accessibility-audit.csv`, `design-conformance-audit.csv`). Every action below cites the finding it closes. **Nothing here is applied yet** — this is the sequenced proposal.

Guiding principle: **foundation before screens.** You cannot fix "green means five things" per-screen; you fix it once in the token layer, then every screen inherits it. So the order is tokens → components → screens → verify → code.

---

## Phase 0 — The one decision that gates everything

The HIG lens says the design "reads as web/Material, not iOS." That points at two very different plans:

- **Path A — Keep the New Look, add discipline** *(recommended).* The borderless-card-on-sage look was a deliberate, app-wide decision (spec 033) and matches the reference apps (Tiimo, Gentler Streak) which are *also* non-standard iOS. The problem isn't that it's non-native — it's that it's **undisciplined**: no hierarchy, overloaded color, drifting components. Fix those and it reads as *crafted*, not templated. Keeps the identity; ~80% of the audit findings still apply and get fixed.
- **Path B — Convert to iOS grouped-table grammar.** Chase native-iOS correctness: inset toned fills, caption headers outside groups, hairline separators, no card shadows. More "correct" per HIG, but it effectively **abandons the New Look** you invested in. Bigger blast radius, and re-opens a settled decision.

**Recommendation: Path A.** The audit's top-3 root causes (hierarchy, color-semantics, consistency) are all fixable *inside* the New Look — they're what separate a crafted non-standard design from a templated one. The HIG "grammar" finding becomes "add elevation/spacing hierarchy so cards rank," not "delete the cards." Path B is only right if you've decided the New Look itself was a mistake.

Everything below assumes **Path A** (noted where B would differ).

---

## Phase 1 — Foundation (Figma variables + component library)

### 1.1 Color semantics — split the overloaded green *(closes R30, state-clarity, native-controls)*
One green currently means brand + CTA + on-toggle + chip-selection + status + mood. Split into distinct **roles**, each its own token:
| New role | Value | Used for | Replaces |
|---|---|---|---|
| `action/primary` | meadow green (one green only) | primary buttons, primary ring | CTA uses of selection/checkInGreen |
| `state/on` | **system green** | toggles only | brand-green toggle tint |
| `state/selected` | **neutral** — `tint/neutral` fill + check/border, NOT a green fill | selected chips/pills | green chip fills |
| mood data | the **mood ramp** (untouched) | mood values only | any UI reuse of mood green |
| `status/ok` | action green, used sparingly | "Installed" dots etc | — |
Rule: **a green fill means exactly one thing per context.** `checkInGreen == mood-4 bead` collision is resolved because UI state stops borrowing the ramp.

### 1.2 Spacing scale + section tiers *(closes R29 spacing half, R24, consistency spacing-families)*
Adopt one scale as Figma FLOAT variables (already scaffolded in Squirl Tokens `spacing/*`): **4 · 8 · 12 · 16 · 24 · 32 · 48**. Apply as tiers:
- 12 = intra-card element gap · 16 = card-internal group gap · 24–32 = between top-level sections · 48 = major breaks.
- Kills the two "spacing families" (detail 10/12 vs browse 12/14) → one module. Normalize off-grid 2.5/7/9 gaps.

### 1.3 Elevation / surface tiers *(closes R29 hierarchy half, R31 partial)*
Define **3 surfaces**, not one: **hero** (larger title, stronger shadow — the screen's primary content), **standard card** (current r20), **inset row** (flat/toned, for settings/detail line items). This is what makes the eye rank things. The persistent **med bar becomes distinct pinned chrome** (thinner/tinted), not a content card *(closes safe-area/layering)*.

### 1.4 Component unification *(closes card-title-role, chip-component, glyph-fill, iconography)*
- **One card-title role** (Semi Bold 17) + a separate, consistently-applied eyebrow role — never lead a card with an eyebrow where siblings lead with a title.
- **One chip component**: single height, pill radius, single padding. The a01 square display-chips either adopt the pill or become a distinctly-named element.
- **One icon system**: one style (all outline or all filled per tier), one stroke weight, one muted tint. The **aperture glyph gets equal fill weight** to tree/bolt so focus stops receding.
- Radius tiers tokenized: `radius/field=14`, `radius/chip=18→pill`, `radius/badge=22` (the deferred R19 tokens).

---

## Phase 2 — Apply the system per screen

Each screen rebuilt against the Phase-1 tokens/components, plus its specific fixes:
- **a08 Settings** *(R31, rank 3):* apply hero + inset-row tiers so it reads as ranked groups (Path B: full grouped-table).
- **a07 Insights** *(R32, rank 4):* pick **one chart vocabulary** (recommend the glyph-strip + a single bar form), make energy one yellow everywhere, replace overlapping bubbles with a stacked bar or donut.
- **a04/a05 Check-in** *(rank 8):* resize/re-job the ring (hug content or give it a real progress/record function), tighten title→control rhythm, drop the redundant carousel indicator.
- **a01 Calendar** *(rank 14):* differentiate expanded vs collapsed day cards (the duplicate-green "GREAT·MON" reads as a bug), consistent mood-disc encoding, strengthen tinted-surface edges.
- **a02 Recording detail** *(iconography, color-reserve):* unify header icons, give the audio player a neutral color (stop reusing medication purple), give the hairline signal bars real weight.
- **Global** *(safe-area, touch-targets):* uniform status bar on all 8 frames; ≥44pt touch targets via hit-area padding without inflating the visual pill.

---

## Phase 3 — Verify & propagate

1. **Re-run the 4-lens audit** on the revised screens (regression check — the workflow is reusable).
2. **Update DESIGN.md** with the new color-semantic tokens, spacing/elevation tiers, and component rules + Decisions Log rows.
3. **Then code** — SwiftUI implementation via Spec Kit (`NewLook.swift` token additions, view changes), owner-gated, **needs device QA**. This is a separate build effort, not part of the Figma work.

---

## Sequencing & gates
- **Do first (unblocks everything):** 1.1 color split + 1.2 spacing + 1.3 elevation — the three root causes.
- **Owner-gated decisions:** Phase 0 (A vs B); the exact green for `action/primary`; the a07 chart vocabulary; the ring's new job.
- **Non-visual / safe now:** the deferred token work (radius tiers, spacing tokens) can land immediately once the scale is chosen.
- **Code is downstream:** no Swift changes until the Figma system is settled and you approve — per house rules I write no app code unasked.

## What this closes
Root causes R29/R30/R31/R32 + the deferred R19 (radius tokens), R24 (spacing tokens), R25 (type roles), and the un-actioned half of R20. Leaves genuinely-out-of-scope items (dark-mode derivations, 10pt micro-text) as separate owner calls.
