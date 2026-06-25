# Feature Specification: Day-card mood-block redesign (Paper & Pollen #4)

**Feature Branch**: `019-daycard-mood-block`

**Created**: 2026-06-24

**Status**: Draft

**Input**: Owner decision on the finalized `mockups/summary/index.html` day card ("#4 Divided · Cream disc"), reached through this session's mockup iteration (unfolded-header proposals → Slim Tinted Rail colour study → Meadow folded + glyph-badge matrix). This is the deferred **A4** follow-up that [018-qa-review-fixes](../018-qa-review-fixes/spec.md) explicitly scoped out ("the in-app expanded DayCard interior lags the latest mockup… gets its own spec after a mockup-vs-code diff").

---

## Overview

The in-app calendar day card (built in [014-daily-card](../014-daily-card/spec.md)) no longer matches the design system. The 2026-06-24 QA walkthrough confirmed it: the folded and expanded card still use full-width per-check-in **colored mood bands** and a tall tinted **wash header with a 58 pt mood-glyph disc**, while the design has moved on. The owner re-decided the card visually this session and approved **"#4 Divided · Cream disc"** in the mockup.

This feature ports that mockup into the SwiftUI `DayCard`. It is a **visual / layout redesign only** — it changes how the card looks, not what it does. The fold/expand state machine, the filter-above selection, the auto-expand toggle, the day-summary derivation, and all check-in / medication logic are **unchanged**.

The new card, per the approved mockup:

- **Folded** — the whole card is a soft **mood-tinted block** (the day's mood colour, light, over surface), not a band per check-in. The mood glyph sits in a **cream-disc badge** at the leading edge; to its right, the **mood word + weekday** on one line; a **hairline divider**; then the day's **summary signals** (energy · focus · medication name) on the line below.
- **Unfolded** — the mood-tinted **strip stays as the header** (same badge + mood word + weekday + a disclosure chevron); the **check-in rows drop onto the cream surface** below. Each row: the medication-phase **ring around the mood glyph** with the dose **% beneath it**, the **mood word with the timestamp inline** right after it, **energy + focus ramp glyphs**, and a **details chevron** on the trailing edge.
- The fold↔unfold transition animates the **card background colour** and the **body height**, and is **instant under Reduce Motion**.

The design **generalises across all five moods** — every day (and every check-in row) tints by its own mood colour, not just the green "Good" demo.

**Out of scope (separate specs / not this change):**
- The calendar week-row greying of registered days (**QA A1** — owned by [018](../018-qa-review-fixes/spec.md)).
- The medication-bar top scroll-fade regression (**QA A2** — owned by 018).
- The Log-Dose sheet colour mismatch (**QA A3** — owned by 018).
- Any change to data, schema, the `ExpandedDayCards` fold/expand state machine, filter-above selection, auto-expand behaviour, the day-summary derivation, or any check-in / medication logic. This feature only restyles the presentation those systems already drive.
- The standalone check-in detail component and the calendar week row themselves (only the day card's own rows change).

**Coordination with 014:** this supersedes 014's expanded-card visual treatment (the colored mood bands + wash header). 014's *behaviour* (independent fold, select-collapses-others, filter-above, auto-expand, the `DayCardSummary` derivation) is reused as-is. The visual-only FRs of 014 that this replaces MUST be marked superseded in 014's spec so code and spec stay in agreement.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Read the day at a glance from a folded mood block (Priority: P1)

A user opens the Calendar and scans the list of days without expanding anything. Each day is a single, calm, **mood-coloured block**: the colour alone signals how the day went, reinforced by the sprout glyph in its cream badge and the mood word. Below the title, one quiet line summarises the day — energy, focus, and which medication was taken. The user understands the shape of a day in well under a second, and a glance down the list reads as a colour gradient of good and hard days.

**Why this priority**: **P1** — this is the headline change and the whole point of the redesign; it is the state users see most (folded), and it is independently shippable (the folded card can be redesigned before the expanded body is touched, falling back to the existing expansion).

**Independent Test**: On Calendar, view several days with different moods folded; confirm each card is one mood-tinted block with a cream-disc glyph badge, mood word + weekday on one line, a divider, and an energy · focus · medication-name summary line — matching the approved mockup across all five moods, in light and dark.

**Acceptance Scenarios**:

1. **Given** a day with at least one check-in, **When** the card is folded, **Then** the entire card is filled with that day's mood colour (one block, no per-check-in bands), with the mood glyph in a cream-disc badge, the mood word + weekday on one line, a divider, and the energy · focus · medication-name summary beneath.
2. **Given** five days logged at five different mood levels, **When** the list is folded, **Then** each card tints by its own mood colour (no hardcoded green), and the moods are distinguishable from one another by block colour, glyph shape, and word.
3. **Given** a day whose representative check-in logged no energy or focus, **When** folded, **Then** the summary line shows only the signals that exist (no empty placeholders) and the card still reads as complete.

---

### User Story 2 - Open a day to its check-ins under a persistent mood header (Priority: P1)

A user taps a folded day card. It opens: the mood-tinted strip stays at the top as the day's header (badge + mood word + weekday + an up-chevron), and the day's check-ins appear below on a clean cream surface. Each check-in shows its medication-phase ring around the mood glyph with the dose percentage beneath, the mood word with the time right beside it, the energy and focus signals, and a details chevron to open more. The header colour anchors the day while the rows carry the detail.

**Why this priority**: **P1** — the expanded state is half the card and the place detail is read; it must match the mockup's row layout (inline time, details chevron, ring) for the redesign to be coherent. Depends on US1's header but is independently testable once expansion is wired.

**Independent Test**: Expand a day card; confirm the mood strip persists as the header and the check-in rows render on the surface below with: med-phase ring + dose % under the mood glyph, mood word with time inline beside it (not right-aligned), energy + focus ramp glyphs, and a trailing details chevron — matching the mockup.

**Acceptance Scenarios**:

1. **Given** a folded card, **When** the user taps the header, **Then** the card expands keeping the mood-tinted strip as the header and revealing the check-in rows on the cream surface below.
2. **Given** an expanded card, **When** a check-in row is read, **Then** it shows the medication-phase ring around the mood glyph with the dose % beneath, the mood word with the timestamp inline immediately after it, energy + focus as ramp glyphs (only what was logged), and a details chevron on the trailing edge.
3. **Given** an expanded card, **When** the user taps the header again, **Then** it folds back to the mood block with the summary line, with no change to which other cards are open (existing state machine unchanged).

---

### User Story 3 - The card stays legible for every accessibility setting (Priority: P2)

A user with large Dynamic Type, Reduce Motion enabled, or colour-vision differences uses the card. The text scales and wraps without clipping (the mood word is never truncated). The fold/unfold is instant rather than animated. In greyscale the day's mood and each signal are still distinguishable by glyph shape and fill, because colour is never the only cue. Tap targets are comfortable.

**Why this priority**: **P2** — non-negotiable for this audience (an ADHD tool, anti-shame, accessible by design) but layered on top of the visual US1/US2; the card is shippable to sighted default users first and hardened here. Independently testable via the iOS accessibility settings.

**Independent Test**: With the largest Dynamic Type, confirm no card text clips or ellipsises (mood word fully visible, layout reflows). With Reduce Motion on, confirm fold/unfold is instant. In greyscale, confirm each signal and the day's mood remain distinguishable by shape. Confirm the header and row-disclosure tap targets are each ≥44 pt.

**Acceptance Scenarios**:

1. **Given** the largest accessibility Dynamic Type size, **When** a card is folded or expanded, **Then** all text scales and wraps, and no text — especially the mood word — is clipped or ellipsised.
2. **Given** Reduce Motion is on, **When** the user folds/unfolds a card, **Then** the state changes instantly with no colour or height animation; **and** with Reduce Motion off the colour + height transition plays.
3. **Given** a greyscale / colour-blind simulation, **When** the user reads a card, **Then** the mood (glyph shape) and each signal (shape + fill) remain distinguishable without relying on hue.

---

### Edge Cases

- **Day logged but with zero check-in rows** (a registered day with no detail): the folded mood block and summary still render; expanding shows an empty-but-valid body (no exposed square corners, no crash) — reuse 014's empty handling.
- **Single check-in** vs. **many check-ins**: the expanded body grows with content; the header strip height is stable.
- **Partial signals**: a check-in with mood only (no energy/focus/med) shows just what was logged in both the summary line and the row.
- **Very long medication name** (e.g. "Methylphenidate XR 54 mg"): the summary line and row wrap rather than truncate.
- **Largest Dynamic Type**: badge, title, divider, and summary reflow; the cream-disc badge does not crowd the wrapped title.
- **Mid-tint contrast**: the mood word's deepened colour stays legible on its own block tint across all five moods, in light and dark.
- **Reduce Transparency / increased contrast**: the mood block and cream disc remain distinct from the surface (the divider and badge edge still read).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The folded day card MUST render as a single **mood-tinted block** filled with the day's representative mood colour (light tint over surface) — one block for the whole card, NOT a colored band per check-in.
- **FR-002**: The card MUST show the mood glyph inside a **cream-disc badge** (a light mood-tint circle) at the leading edge, in both folded and unfolded states.
- **FR-003**: To the right of the badge the card MUST show the **mood word followed by the weekday** on one line; the mood word MUST use a **deepened mood colour** that stays legible on the block tint in light and dark.
- **FR-004**: The folded card MUST show a **hairline divider** between the title line and the summary line.
- **FR-005**: The folded summary line MUST show the day's **energy, focus, and medication name** (name only, no dose), derived from the existing `DayCardSummary` (representative check-in) — reused, not re-derived.
- **FR-006**: Tapping the card header MUST toggle folded/unfolded using the **existing fold/expand state machine**; selection, auto-expand, filter-above, and collapse-others behaviour MUST be unchanged.
- **FR-007**: The unfolded card MUST keep the **mood-tinted strip as the header** (badge + mood word + weekday + a disclosure chevron) and render the check-in rows on the **surface (cream)** below.
- **FR-008**: Each check-in row MUST show the **medication-phase ring** around the mood glyph with the **dose % beneath** it (reuse the existing phase-ring + percentage).
- **FR-009**: Each check-in row MUST show the **mood word with the timestamp inline immediately after it** (not right-aligned to the row edge).
- **FR-010**: Each check-in row MUST show **energy and focus as ramp glyphs** (shape + hue + fill encoding level), displaying only the signals that were logged.
- **FR-011**: Each check-in row MUST show a **details / disclosure affordance on the trailing edge**.
- **FR-012**: The design MUST **generalise across all five mood levels** — each day's block and each row tints by its own mood colour; no hardcoded single-mood colour.
- **FR-013**: All card text MUST **scale with Dynamic Type and wrap** rather than clip or ellipsise; the **mood word MUST never be truncated**.
- **FR-014**: The fold/unfold transition MUST animate the **card background colour and the body height**, and MUST be **instant when Reduce Motion is enabled**.
- **FR-015**: Every signal (mood, energy, focus, medication) MUST remain **legible by shape + fill in greyscale** — colour MUST NOT be the only cue.
- **FR-016**: The card **header tap target** and each **row disclosure** MUST be **≥44 pt**.
- **FR-017**: All new visual constants — block tint level, cream-disc tint level, deepened-word colour level, badge/disc sizes, divider, corner radius, spacing, typography — MUST resolve through **DesignSystem tokens**; no magic-number literals in the views.
- **FR-018**: The redesign MUST **fully replace** the prior expanded-card colored-mood-band + wash-header treatment — no dead/obsolete styling left behind (per Constitution III).
- **FR-019**: The card MUST render correctly in **light and dark**.
- **FR-020**: This feature MUST NOT change data, schema, the fold/expand state machine, filter-above, auto-expand, the summary derivation, or any check-in / medication logic — it is presentation-only.

### Key Entities *(reused — no new data)*

- **Day card summary** *(reused, `DayCardSummary` from 014)*: the representative mood, energy, focus, and medication name shown on the folded card. This feature changes how it is *displayed*, not how it is derived.
- **Check-in** *(reused)*: time, mood, energy, focus, medication, and dose-phase percentage rendered per row. No new attributes.
- **Mood level** *(reused, 1–5)*: drives the block tint, cream-disc tint, deepened-word colour, and glyph — all derived from the existing mood-colour ramp; this feature adds the tint/badge presentation tokens, not new mood data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can identify a day's overall mood from the **folded card alone** (block colour + glyph + word), without expanding, for all five mood levels.
- **SC-002**: The rendered card matches the approved mockup (`mockups/summary/index.html`, "#4 Divided · Cream disc") for all five moods in **both light and dark** — confirmed by a side-by-side parity review.
- **SC-003**: At the **largest Dynamic Type** size, **no card text is clipped or ellipsised** on any card, and the mood word is always fully visible.
- **SC-004**: With **Reduce Motion on**, fold/unfold completes **instantly** with no animation; with it off, the colour + height transition plays.
- **SC-005**: In **greyscale**, every signal remains distinguishable by shape, and the day's mood is still readable (glyph shape + word) — verified by a colour-vision simulation.
- **SC-006**: **No magic-number visual constants** remain in the changed day-card views — every radius, spacing, size, tint level, and type style resolves through a design token (verified by a token audit, as in 007/008/014).
- **SC-007**: **No behavioural regression** — existing 014 logic tests (fold/expand state machine, filter-above date filter, `DayCardSummary` derivation) stay green, and selection / auto-expand / collapse-others behave exactly as before.

## Assumptions

- The approved mockup `mockups/summary/index.html` ("#4 Divided · Cream disc"), finalized with the owner this session, is the **source of truth** for layout, the mood-tint block, the cream-disc badge, the divider, the persistent strip header, and the row layout. Its captured screenshots are the parity reference.
- The card's block tint uses the **same representative mood the folded summary already uses** (the `DayCardSummary` mood from 014 — the most-recent / representative check-in), tinted per-day. It is NOT a per-check-in or averaged tint. If the owner later wants "dominant" or "average" mood instead, that is a follow-up, not this spec.
- The exact tint percentages from the mockup (block ~24 %, cream disc ~50 %, deepened word ~72 % toward ink) and badge/disc sizes are the **design intent** and will be **tokenised**; precise values MAY be tuned on-device within that intent without re-speccing.
- The fold/unfold motion reuses 014's existing animation + Reduce-Motion gating; this feature adds the **background-colour cross-fade** to the existing height change.
- This is **mockup-first per Constitution I** (the HTML mockup precedes the SwiftUI), and **presentation-only** — no new persisted data, so the schema and CloudKit-compatibility posture (Principle IX) are untouched.
- Testable logic introduced is limited to **pure presentation helpers** (e.g. mapping a mood level → block tint / deepened-word colour, and selecting the summary signals to show); per Constitution X these get test-first unit coverage. The SwiftUI views themselves are exempt (verified by build + on-simulator run + the mockup).

## Dependencies

- **DesignSystem tokens** (`Palette` / `Theme` / `Spacing` / `Radius` / `Typography`) — extended with the new mood-tint, cream-disc, deepened-word, badge-size, and divider tokens.
- **014-daily-card** — reuses `DayCardSummary`, the `ExpandedDayCards` state machine, filter-above, and auto-expand; this feature restyles the views those drive and supersedes their colored-band visual.
- **Signal glyph system** (006/014) — the sprout/lightning/aperture ramp glyphs and the medication-phase ring, reused unchanged.
- **018-qa-review-fixes** — independent; 018 explicitly deferred this (A4). No shared files are expected to conflict, but both touch the calendar/day-card area, so they SHOULD be sequenced or rebased to avoid drift.
