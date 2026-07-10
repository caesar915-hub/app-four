# Phase 0 Research: New Look Screens (Spec 032)

**Date**: 2026-07-10 · **Branch**: `feat/032-newlook-screens`

The spec left no `[NEEDS CLARIFICATION]` markers (both resolved at `/speckit-specify`). This
phase resolves the **implementation unknowns** the spec deliberately did not fix: how two
screens adopt a second visual language without re-skinning the app, how the Figma Inter ramp
maps to native SF, and the exact token→component contract. Every finding is grounded in the
current code on this branch.

---

## D1 — How do two screens adopt New Look while the rest stays Paper & Pollen?

**Observation.** Both target views consume the token layer **directly and statically**:
`ExtractionReviewView` has 42 `Theme.*` references, `RecordingDetailView` 17; `Theme` is a
static `enum` of adaptive `Color`s ([Theme.swift](../../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Theme.swift)),
and `.card()` is a single hardcoded Paper & Pollen modifier ([Card.swift:18](../../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Card.swift#L18))
used by only 4 view files. There is no runtime theme indirection anywhere.

**Decision.** Add a **parallel static token namespace `NewLook`** in `SquirlDesignSystem`
(colors + radius + a `.newLookCard()` modifier + a `newLookChip`/`newLookPill` style), and
switch the two target views from `Theme.*`/`.card()` to `NewLook.*`/`.newLookCard()`. **No
runtime/environment theme system.** `Palette.medication` is reused unchanged.

**Rationale.**
- The screens are *statically* New Look — there is no runtime switching, so an environment
  theme-provider would be plumbing with zero payoff (Constitution IV: no abstraction beyond need).
- A parallel namespace mirrors the existing `Theme` / `Palette` pattern the codebase already
  uses — lowest cognitive cost, matches conventions, keeps FR-006 "no literals" trivially true.
- Reversible and revertable (Constitution V): New Look lives in its own file; if adoption goes
  app-wide it is promoted, if abandoned the file is deleted and 2 views revert.

**Alternatives rejected.**
- *Mutate `Theme.*` values* → re-skins the whole app (every screen reads `Theme`), violates
  FR-011 and the mixed-look intent. Wrong by construction.
- *Environment `@Entry` theme provider* → runtime theme-switch infrastructure for a static,
  two-screen, explicitly-temporary need. Premature abstraction (IV). Revisit **only** if New
  Look becomes app-wide AND runtime-switchable (neither is true now).
- *Per-view local color constants* → scatters token values across views, breaks FR-006 and the
  spec-008 no-literals discipline.

---

## D2 — Figma Inter ramp → native SF typography mapping

**Observation.** The Figma mockups render in Inter (a stand-in; DESIGN.md on main records the
spec-023 reversal to native SF app-wide). The existing `Typography` enum already exposes a full
SF ramp with Dynamic Type via `UIFontMetrics` ([Typography.swift](../../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Typography.swift)).

**Decision.** Map each Figma style to the **nearest existing `Typography` role** — do **not**
add near-duplicate SF sizes (Constitution IV). Hierarchy is by weight/size per the mockup.

| Figma style (a02/a03) | Role | `Typography` mapping |
|---|---|---|
| `Title-24` Bold (nav title "Edit check-in") | screen/nav title | `Typography.text(24, weight: .bold, relativeTo: .title)` (existing helper; 24pt is load-bearing and absent from the named ramp) |
| `Title-17` Semi Bold (card headers) | card header | `Typography.headline` (16 semibold) |
| `Strong-15` Semi Bold (card body) | card body | `Typography.callout` (15) at `.weight(.medium)` where the mockup bolds |
| `Small-13` Regular (chip labels) | chip / pill label | `Typography.text(13, relativeTo: .footnote)` |
| `Caption-11` Regular (field labels) | field label | `Typography.caption` (12) |
| `Micro-10` tracked caps (MOOD/ENERGY/FOCUS) | group eyebrow | `Typography.label` + `.textCase(.uppercase)` + tracking |
| level words (Great/Charged/Sharp) | hero level word | `Typography.headline` |

**Rationale.** Native SF + Dynamic Type is the constitutional rule (I); the existing ramp
already covers every size the mockup uses except the 24pt nav title, which the `text()` helper
produces without a new named role. Adding `newLookTitle24` etc. would be near-duplicate ramp
entries — rejected.

---

## D3 — New Look palette + dark derivation (FR-001, FR-009)

**Observation.** The Figma variables are light-only (`surface/screen #EFF2EB`, card white, ink
`#1C1B1F`/`#8A8A8E`, hairline `#DBDDDE`, selection `#54B492`, radius 20). Owner chose "derive
dark tokens now" (FR-009). The codebase's `Color(lightHex:darkHex:)` initializer is the
established adaptive-token mechanism.

**Decision.** Encode New Look colors as adaptive `Color(lightHex:darkHex:)` tokens, dark values
derived per iOS convention (cool-dark surfaces, light ink), validated at device QA (SC-004):

| Token | Light (Figma) | Dark (derived) | Notes |
|---|---|---|---|
| `NewLook.screen` | `#EFF2EB` | `#12140F` | cool near-black sage, not P&P warm loam |
| `NewLook.card` | `#FFFFFF` | `#1C1E19` | raised surface |
| `NewLook.inkPrimary` | `#1C1B1F` | `#F2F3EE` | |
| `NewLook.inkSecondary` | `#8A8A8E` | `#9BA09A` | |
| `NewLook.hairline` | `#DBDDDE` | `#33362F` | chip/field borders |
| `NewLook.selection` | `#54B492` | `#5FC49F` | selected chip fill; lifted for dark contrast |
| medication | `Palette.medication` | (existing) | reused, not redefined |

**Rationale.** Dark derivation is the smallest complete solution (FR-009 option A) and keeps
both screens legible in both appearances (edge-case guard). Exact dark hexes are the plan's
best derivation; owner device QA is the acceptance gate, and hexes may be nudged there without a
spec change.

**Alternatives rejected.** Locking to light (jarring inside a dark app) and reusing P&P dark
(warm-dark under cool-sage light — semantically muddled) were both weighed and declined by the
owner at clarify.

---

## D4 — Card, chip, and nav component specs (FR-002, FR-003)

**Observation.** The card modifier ships a border + radius-16 + P&P shadow; the New Look card is
**borderless, radius-20, soft shadow**. Chips today use `tint.opacity(0.16)` fill + tinted
border for selected ([ExtractionReviewView.swift:223](../../app-four/Views/ExtractionReviewView.swift#L223));
the New Look chip is **white + hairline outline**, selected = **solid selection fill + white
label** (medication chips = solid medication purple).

**Decision.** Add to `SquirlDesignSystem`:
- `Radius.newLookCard = 20` (extend `Radius`, keep `card = 16` for P&P).
- `.newLookCard()` modifier: `NewLook.card` fill, radius 20, soft shadow, **no border**.
- A `newLookChip(selected:role:)` style: white fill + `NewLook.hairline` border when unselected;
  solid `NewLook.selection` (or `Palette.medication` when `role == .medication`) + white label
  when selected.
- Nav row: back pill + Save pill at the edges, **title mathematically centered** (a03's fix) via
  a `ZStack`/overlay so the centered title is independent of pill widths.

**Rationale.** These three are the New Look's whole visual grammar; centralizing them as
modifiers keeps both screens literal-free (FR-006) and makes US2 reuse US1's work. The `.card()`
modifier is left untouched so the other 3 P&P consumers are unaffected (FR-011).

---

## D5 — Testing posture (Constitution X, II)

**Observation.** This is a **pure visual re-skin**: both view-models are presentation-only
(RecordingDetailVM 14 members, ExtractionReviewVM 31), and each already has a Swift Testing
suite (`RecordingDetailViewModelTests`, `ExtractionReviewViewModelTests`). No model, service,
or view-model **logic** changes.

**Decision.** No new test-first logic (Principle X applies to logic; SwiftUI views are exempt,
verified by build + device run). The existing VM suites are the **regression gate** — they must
stay green (SC-002). New Look tokens are static values; if any get a computed helper (unlikely),
it gets a test. Verification = build green + full suite green + owner device QA in light+dark at
default and accessibility text sizes.

**Rationale.** Matches Principle X exactly (test-first for logic, build+run for views) and the
spec-008 precedent (tokens-only re-skin verified by build + on-device visual parity).

---

## Resolved unknowns summary

| Unknown | Resolution |
|---|---|
| Two-language coexistence | Parallel `NewLook` static namespace + `.newLookCard()`; no runtime theme (D1) |
| Inter→SF typography | Map to existing `Typography` roles; only 24pt nav title via `text()` helper (D2) |
| Dark values | Derive now as adaptive `Color(lightHex:darkHex:)`, QA-validated (D3) |
| Card/chip/nav grammar | New modifiers + `Radius.newLookCard = 20`; `.card()` untouched (D4) |
| Test strategy | No new logic → existing VM suites are the regression gate; views build+QA (D5) |
