<!-- Created: 2026-07-20 19:05 (WEST) · Updated: 2026-07-20 20:45 (WEST) -->
# Feature Specification: Path A — Refine the New Look In Place (Figma)

**Feature Branch**: `040-path-a-refine`

**Created**: 2026-07-20

**Status**: Archived (shelved by owner 2026-07-20 — current design retained)

**Scope note**: This is a **Figma design specification** — the deliverable is refined screens in the Figma file **Squil-Design** ("Screens v3"; frozen backup page from 2026-07-18 remains untouched). SwiftUI implementation is a separate downstream spec. The project constitution and DESIGN.md are non-gating per the owner's standing rulings (carried from 039); DESIGN.md is updated *from* the outcome.

**Input**: Successor to the killed Path B (spec 039). The owner rejected wholesale grouped-table conversion as identity loss at the 039 pilot gate, then **accepted the refine-in-place pilot `a02-a` (node `638:1465`, 2026-07-20)** as the reference standard. Path A keeps the "New Look" card identity — r20 white cards on sage ground, brand voice, colored signal glyphs and words, lowercase vocabulary — and fixes only the 4-lens audit's root causes (R29 hierarchy, R30 green overload, R32 chart vocabulary, plus the 18 ranked findings) inside that language, applying the recipe the accepted pilot proved.

---

## The accepted reference standard (a02-a recipe)

Every refined screen applies these moves where its content triggers them — this is the contract the accepted pilot established:

1. **Tiered spacing** replaces the uniform 12pt stack gap: ~20pt base rhythm between cards, ~32pt breaks before major sections (exact values fixed in the plan's contract; measured, not eyeballed).
2. **Card-per-fact merges**: runs of single-fact cards consolidate into one card of icon + kicker + verbatim-fact rows. Icons are kept.
3. **One soft shadow** per card (the second shadow layer is removed everywhere).
4. **Legible data marks**: signal bars ≥6pt on visible rounded tracks; glyph ink-weight unified across the sprout/bolt/aperture set (shapes unchanged); data marks keep their ramp colors.
5. **Purple = medication identity only**: any non-medication use of the purple (e.g. the old audio player) goes neutral ink.
6. **Med bar = slim tinted inset chrome** (~44pt, medication-tint wash, no shadow), visually distinct from content cards, styled identically on every frame that shows it (a01, a02, a07, a08).
7. **Status bar on all 8 frames** (closes the 5-of-8 gap).
8. **Green-role discipline within the brand palette**: the mood ramp is data-only; each screen context has exactly one interactive green (the app's shipped per-context assignment stands — capture flow `checkInGreen`, elsewhere `selection`); no green simultaneously means action + selection + data in one context. System green is NOT mandated (that was Path B).
9. **AA text baseline**: text ≥4.5:1 on its resolved surface; the pre-039 contrast waivers stay dead.
10. **Content parity 100%**: refinement changes presentation, never information — verified against the 039 inventories.

## User Scenarios & Testing *(mandatory)*

> "User" = the person using Squirl, experiencing the refined screens. Each story is an independently reviewable Figma deliverable, built as `a0N-a` beside its original. a02 is already delivered and accepted (reference standard).

### User Story 1 — Settings reads as ranked, breathing Squirl (a08) (Priority: P1)

A user scrolling Settings sees the same warm card language, but sections now rank: runs of single-setting cards are consolidated, related settings share a card as icon/kicker rows, section breaks are visibly larger than intra-section rhythm, toggles and chips use one interactive green, and the medication bar reads as chrome.

**Why this priority**: a08 is the worst card-per-fact offender (12 separate r20 cards) and the only screen dense with real controls (toggles, chips, destructive actions) — it stress-tests the merge recipe and the green discipline harder than any remaining screen.

**Independent Test**: `a08-a` beside frozen a08 — reviewer confirms identical content (inventory parity), visibly tiered spacing, consolidated cards, one interactive green, AA text.

**Acceptance Scenarios**:

1. **Given** `a08-a`, **When** cards are counted, **Then** runs of single-fact/single-setting cards are consolidated (fewer, richer cards) with zero settings lost.
2. **Given** the toggles and selected chips, **When** inspected, **Then** they use exactly one interactive green, distinct from any mood-ramp value on screen.
3. **Given** section boundaries, **When** measured, **Then** between-section space is a visibly larger tier than within-section rhythm.
4. **Given** the Dose Guard choice (Off / Total / Time-window), **When** inspected, **Then** the three options read as ONE choice control, not three unrelated presentations (rank-13).

---

### User Story 2 — Edit check-in is dense but tappable (a03) (Priority: P1)

A user editing a check-in keeps the familiar carded sections (When, Signals, Sleep, Medications, Emotions, Side effects), but every chip is a comfortable target (≥44pt effective), selected state is unambiguous (one treatment, no green-vs-purple confusion), and the sheet's sections breathe in tiers.

**Why this priority**: a03 carries the touch-target finding (rank-7, dozens of sub-44pt chips) and the selection-ambiguity finding (rank-13) — the two highest user-harm findings still open.

**Independent Test**: `a03-a` beside frozen a03 — all chips measure ≥44pt effective target, one selected-chip treatment throughout, content parity 100%.

**Acceptance Scenarios**:

1. **Given** any chip grid (sleep quality, durations, meds, doses, emotions, side effects), **When** measured, **Then** each chip's effective target is ≥44pt and chip anatomy is one consistent shape/height family (rank-12).
2. **Given** a selected chip, **When** compared across sections, **Then** selection is signaled one way everywhere, and never with a color that also encodes mood data or medication identity.

---

### User Story 3 — Calendar day card ranks its story (a01) (Priority: P2)

A user's calendar keeps its timeline personality; the day card drops its duplicate mood indicator and green-on-green header collision (rank-14), entry rows get breathing room (rank-11 density), chips take one shape (rank-12), and the med bar + status bar match the accepted chrome.

**Independent Test**: `a01-a` beside frozen a01 — day-card header shows one mood indicator, expanded and collapsed states both present, tiered spacing measured, chrome matches a02-a.

**Acceptance Scenarios**:

1. **Given** the day-card header, **When** inspected, **Then** the mood word appears with exactly one visual mood indicator (no duplicate disc/word/tint stack) and header elements pass AA on their tinted ground.
2. **Given** both day-card states (expanded, collapsed), **When** compared, **Then** both apply the refined language consistently.

---

### User Story 4 — Insights charts speak one language (a07) (Priority: P2)

A user reading Insights sees the same carded sections, but the three signals are charted with **one primary mark family** across sections (plus at most one part-to-whole exception; overlapping bubbles are out), gated/empty content uses one native empty-state pattern instead of dashed ambiguity (rank-18), and density relaxes into the spacing tiers.

**Independent Test**: `a07-a` beside frozen a07 — count distinct mark families ≤2 with the second used only for part-to-whole; no overlapping-bubble chart; parity 100%.

**Acceptance Scenarios**:

1. **Given** `a07-a`, **When** its sections are surveyed, **Then** signal-over-time/comparison sections share one mark family and scale, and the breakdown uses a single part-to-whole form (not bubbles).
2. **Given** gated connections and the untracked-sleep strip, **When** inspected, **Then** locked/empty states share one clear treatment that cannot be mistaken for data.

---

### User Story 5 — Check-in moments get the light touch (a04–a06) (Priority: P3)

The capture trio keeps its single-focus calm; the ring loses its duplicate progress indicator (rank-8 recomposition), a06's composition rebalances (rank-18), spacing joins the tiers, and the status bar/AA rules apply. These screens have the least audit debt — the recipe applies gently.

**Independent Test**: The three `a0N-a` frames beside originals — ring shows one progress encoding, a06 composition balanced, parity 100%.

**Acceptance Scenarios**:

1. **Given** `a04-a`/`a05-a`, **When** the ring is inspected, **Then** progress/state is encoded once (no duplicate indicator), in the capture flow's own green.
2. **Given** `a06-a`, **When** viewed, **Then** the confirmation composition is visually balanced (no large dead zones) while keeping its copy verbatim.

---

### Edge Cases

- **a02 is done**: `a02-a` is accepted; it is the standard other screens are checked against, not a work item. If a later cross-cutting fix (e.g. a chip-shape decision) contradicts a02-a, a02-a is updated to match and re-shown to the owner.
- **Original frames are auto-layouts with uniform gaps**: the tier system must be applied without breaking each frame's existing auto-layout structure (proven feasible on a02-a).
- **Merging cards must not orphan section identities**: category names survive as kickers/captions inside merged cards (parity rule).
- **The trio (a04–a06) has no med bar by design** (dose state isn't shown during capture) — chrome consistency means "identical where present", not "present everywhere".
- **Identity guard**: if any refinement makes a screen read less like Squirl than its original, identity wins and that delta is dropped — the 039 lesson, now a standing rule.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every refined screen MUST keep the New Look card identity: r20 white cards on the sage ground, existing brand palette and voice, colored signal glyphs/words, lowercase fixed vocabulary.
- **FR-002**: Every refined screen MUST replace uniform stack gaps with the tiered spacing system (base card rhythm + larger major-section breaks), measurable on the canvas.
- **FR-003**: Runs of single-fact/single-setting cards MUST be consolidated into merged cards of icon + kicker + fact/control rows; category identities survive as kickers; icons are kept.
- **FR-004**: Every card MUST carry at most one soft shadow.
- **FR-005**: Data marks MUST be legible: signal bars ≥6pt on visible rounded tracks; the sprout/bolt/aperture glyph set carries unified ink-weight (shapes unchanged); ramp colors remain data-only.
- **FR-006**: Medication purple MUST appear only on medication-identity elements; all other controls/marks use neutral ink or the context's interactive green.
- **FR-007**: The med bar MUST be the accepted chrome treatment (slim ~44pt tinted inset bar, unshadowed) identically styled on a01/a02/a07/a08; the status bar MUST render on all 8 frames.
- **FR-008**: Each screen context MUST have exactly one interactive green (shipped per-context assignment: capture flow `checkInGreen`, elsewhere `selection`); no green may simultaneously encode interaction and mood data in one context; the mood ramp stays data-only.
- **FR-009**: Selection state MUST use one treatment per screen, never a color that also encodes mood data or medication identity (kills rank-13 on a03/a08).
- **FR-010**: All interactive chips/targets on refined screens MUST have ≥44pt effective touch targets and one chip anatomy family per screen (kills rank-7/12).
- **FR-011**: a07 MUST use one primary chart mark family across signal sections plus at most one part-to-whole form; overlapping-bubble composition is prohibited; locked/empty states share one non-data treatment (kills rank-4/18-dashed).
- **FR-012**: a01's day card MUST show exactly one mood indicator in its header (no duplicates), in both expanded and collapsed states (kills rank-14); a04/a05's ring MUST encode progress once (kills rank-8); a06's composition MUST be rebalanced (kills rank-18).
- **FR-013**: All text on refined screens MUST meet WCAG AA 4.5:1 on its resolved surface; the pre-039 waivers do not apply.
- **FR-014**: Every perceptual-audit finding (1–18) that lands on a refined screen MUST be addressed on that screen (opportunistic scope, carried from 039).
- **FR-015**: Content parity MUST be 100% per screen against the 039 inventories — refinement changes presentation, never information; every original string survives (case/joiner grammar transforms documented).
- **FR-016**: Work MUST be additive: each screen built as `a0N-a` beside its untouched original on Screens v3; the frozen backup page is never modified; originals are removed only after full-set owner acceptance.
- **FR-017**: Each refined screen MUST pass owner review (side-by-side vs its original, a02-a as the standard); identity wins over any individual refinement if they conflict.

### Key Entities *(design artifacts)*

- **The a02-a reference standard**: the accepted pilot frame; the visual contract source for tiers, merge anatomy, chrome, and mark treatments.
- **Spacing-tier system**: the base/section tier values as reusable canvas values (exact numbers fixed in the plan contract).
- **Merged-card row anatomy**: icon + kicker + fact/control row, the repeatable unit for consolidation.
- **Chrome pair**: status bar + slim tinted med bar.
- **Screen inventory set**: the 8 content inventories from 039 (parity baselines).
- **Chart vocabulary (a07)**: one primary mark family + one part-to-whole exception.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Re-running the 4-lens audit on the refined set returns **zero high-severity findings** on refined screens (baseline: 8 highs across lenses).
- **SC-002**: On every refined screen, between-section spacing is a **measurably larger tier** than card rhythm (baseline: single 12pt gap).
- **SC-003**: Single-fact card count drops measurably on card-soup screens (consolidation happened) with **100% content parity** per the inventories on all 8 screens.
- **SC-004**: a07 presents its signals with **≤2 mark families** (second = part-to-whole only, no bubbles).
- **SC-005**: **Zero sub-44pt** interactive targets on refined screens (baseline: ~37 flagged).
- **SC-006**: **Zero non-medication purple** and **one interactive green per context** on every refined screen (variable/paint scan).
- **SC-007**: All 8 frames show the status bar; every med-bar frame shows the identical chrome treatment.
- **SC-008**: Text contrast sampling on refined screens shows **100% AA (≥4.5:1)** (baseline: 155/342 failing).
- **SC-009**: Owner accepts each refined screen side-by-side against its original ("still Squirl, now ranked") — the per-screen gate; full acceptance removes the originals.

## Assumptions

- **Figma-first**: deliverable is the Figma redesign only; SwiftUI, token/code changes, and device QA are a downstream spec.
- **a02-a is accepted and closed** — it defines the recipe; it is revisited only if a cross-cutting decision contradicts it.
- **Interactive-green assignment follows shipped code** (capture flow `checkInGreen` #5FB36E, other surfaces `selection` #54B492) — the discipline enforced here is one-green-per-context and data/chrome separation, not a new palette decision. Re-tinting is out of scope unless the owner asks.
- **Spacing-tier exact values** proven on a02-a (20 base / 32 section) are the default; the plan may tune per screen family but must keep ≥1.5× separation between tiers.
- **Constitution and DESIGN.md are non-gating** (owner's standing rulings, carried from 039); DESIGN.md gets rewritten from the accepted outcome at the end.
- **Parked 039 assets are inputs**: the 8 inventories, the 4-lens audit harness, and the `iOS Semantic` AA color values (usable as reference values; Path A screens keep binding to the existing brand collections).
- **Per-screen owner review may be batched** at the owner's convenience; build order follows story priority (a08 → a03 → a01 → a07 → trio).
- The mood/energy/focus ramps themselves are retained as data encoding; where a pale ramp step is illegible as a mark, the mark may use a darker step of the same ramp (a02-a precedent: energy base-2, focus base-3) — hue identity preserved.

## Clarifications

- None open. Three would-be questions were resolved by standing owner rulings and the accepted pilot: green assignment (shipped code stands, one-per-context), spacing values (a02-a's 20/32 as default), review cadence (per-screen, batchable). Each is recorded under Assumptions and can be re-opened by the owner at any gate.
