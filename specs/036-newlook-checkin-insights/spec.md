<!-- Created: 2026-07-16 18:55 (WEST) · Updated: 2026-07-16 18:55 (WEST) -->
# Feature Specification: New Look Check-in + Insights Re-skin (a04–a07)

**Feature Branch**: `feat/036-newlook-checkin-insights`

**Created**: 2026-07-16

**Status**: Draft

**Input**: Owner: "adapt swift code to screen a04 a05 and a06. Adapt Insights Screen to a07" — Figma file Squil-Design, page Screens (v2): `447:821` (CheckIn-Idle) · `447:838` (CheckIn-Recording) · `447:855` (CheckIn-Saved) · `469:969` (Insights). Canvas screens built + adversarially verified by the 2026-07-16 Figma sessions (see DEVLOG).

**Owner rulings (2026-07-16):** (1) Insights becomes a **continuous scroll** — the 5-page snap-pager is deleted (a07's natural-height cards win over the current one-section-per-flick feel); (2) the **med bar stays** on the check-in tab in all states (the canvas omission was drawing latitude); (3) the dead Insights bead-tap → DayDetailSheet path is **deleted** in this spec.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Check-in flow speaks the New Look (Priority: P1)

The check-in tab's three states match a04–a06: idle shows the caps date + bold "How do you feel?" over the green-gradient crescent ring holding the 3-action hub as pills (white "Log meds"/"Type note", solid-green "Speak check-in"); recording shows the rotating prompt in a white card (progress bar, question, hint, dots) over the ring with timer, solid-green "Stop & save" pill and a white "Cancel" chip; saved shows the green check disc, "Captured.", subtitle, and a full-width green "Done" pill at the bottom. The meadow green→amber gradient leaves the check-in flow entirely.

**Why this priority**: The check-in tab is the app's front door and the last big surface still speaking the retired meadow language.

**Acceptance Scenarios**:
1. **Given** idle, **Then** the ring is the green New Look gradient (selection → soft green), the hub pills are white cards with the speak pill solid green, and the header is caps-date + 24pt bold title — per a04.
2. **Given** recording, **Then** the prompt block is a white card (bar + question + hint + dots, all green-accented) and the centre shows timer + green stop pill + white cancel chip — per a05; prompts still rotate on the same schedule with the same copy.
3. **Given** saved, **Then** green disc + white check, "Captured." + subtitle, and a full-width green Done pill — per a06.
4. **Given** any state, **Then** the med bar is present and positioned exactly as on other tabs; every existing interaction (hub taps, sheets, cancel, retry/discard recovery, auto-start, 8-minute landing, VoiceOver announcements) is unchanged.

### User Story 2 - Insights reads as one calm page (Priority: P2)

Insights becomes a single continuous scroll per a07: title + subtitle, month chips (New Look chip grammar), then white cards — breakdown (bubbles + legend chips), three signals (strips + sleep chip), averages (gauges), daily rhythm — then the CONNECTIONS heading with one unlocked card (purple mini-bar) and gated cards (dashed border + lock). Section content and all computed numbers are unchanged.

**Why this priority**: Depends on nothing from US1; bigger structural change but a lower-traffic screen.

**Acceptance Scenarios**:
1. **Given** the Insights tab, **When** scrolling, **Then** it scrolls continuously (no snap paging, no section dimming) with every section in a white card at natural height — per a07.
2. **Given** the month chips, **Then** selected = solid green + light label, unselected = white + hairline + ink (chip grammar); switching months re-scopes every section as today.
3. **Given** the unlocked connection card, **Then** its mini-bar fill is medication purple (was bronze); gated cards are white with a dashed hairline border and lock.
4. **Given** the gauges, **Then** the fill level shown always agrees with the label ("Okay+" etc.) — the view no longer re-derives the level from a float fraction.
5. **Given** the whole tab, **Then** bead taps/DayDetailSheet are gone (dead path deleted) with no behavioral loss (it was unreachable).

### Edge Cases
- Empty month / no data: existing empty state unchanged (canvas doesn't redesign it).
- Reduce Motion: all existing gates keep working (ring spin/breathe, prompt slide, saved pop, chip animations).
- Dynamic Type: prompt card, hub pills, and card content wrap; no truncation of the prompt question.
- Recovery (save-failed) state: not on canvas — styled New-Look-native (ink capsule "Try again" matching the stop grammar), behavior identical.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: The check-in ring gradient MUST become selection-green → soft-green (new additive `selectionSoft` token pinned from canvas `#96C19F`); meadow tokens leave CheckIn/CrescentRing.
- **FR-002**: Hub pills, stop pill, saved disc, and Done MUST use `NewLook.selection` fills with `NewLook.onSelection` labels; white pills use `NewLook.card` + card shadow + hairline-free capsule.
- **FR-003**: The recording prompt block MUST be a white New Look card; prompt bar/dots accents MUST move `Theme.accent` → `NewLook.selection`; bar height per canvas (4pt).
- **FR-004**: Prompt copy, rotation schedule, timer, cap-approach cue, recovery flow, VoiceOver announcements, and all sheets MUST be behaviorally unchanged.
- **FR-005**: The med bar MUST remain visible and positioned identically to other tabs in all check-in states.
- **FR-006**: Insights MUST become one continuous scroll: paging machinery (page-height forcing, snap behavior, active-section dimming) deleted.
- **FR-007**: Breakdown, signals, averages, and rhythm MUST each render inside a `.newLookCard()`; connections keep the existing unlocked-card treatment; gated cards = white fill + dashed hairline + lock.
- **FR-008**: Month chips and legend chips MUST use the New Look chip grammar/white-capsule treatment per a07.
- **FR-009**: The unlocked connection mini-bar fill MUST be `Palette.medication` (was `Theme.accent`).
- **FR-010**: The gauge view MUST receive the ordinal level from the view-model (test-first) instead of re-deriving it from the fraction — label and fill can never disagree.
- **FR-011**: The dead Insights tap-through (selectedDay, unreachable sheet, `calendarDay(for:)`, `DayDetailSheet`, unused `onBeadTap`) MUST be deleted; the tested `signalStrips` VM property stays.
- **FR-012**: Zero new style literals outside named tokens; all values map to existing tokens (verified: canvas variables are 1:1 with NewLook/Palette/Radius/shadow tokens) except `selectionSoft`.
- **FR-013**: All view-model computed data (shares, strips, averages, rhythm, connections, gating copy) MUST be unchanged except the additive gauge-level field.

## Success Criteria *(mandatory)*
- **SC-001**: Side-by-side with a04–a07 (light mode), each state/section matches the canvas 1:1 in structure, palette, and type hierarchy.
- **SC-002**: Zero meadow/accent (`Theme.meadowGradient`/`meadowGreen`/`meadowAmber`/`accent`) references remain in CheckIn/ and Insights/ view files.
- **SC-003**: Full test suite green; the new gauge-level test is RED before the VM change.
- **SC-004**: Every existing check-in interaction and every Insights number is unchanged on device (owner QA).
- **SC-005**: Dark mode renders correctly via existing adaptive tokens (canvas is light-only; dark values are the derived ones already in the system).

## Assumptions
- The canvas omission of the tab bar on a04–a06 is drawing latitude — the app keeps its tab bar (like every tab).
- Recovery state and empty states keep current behavior, styled New-Look-native (no canvas reference).
- a07 card inner padding (14 on canvas) maps to the standard `.newLookCard()` inset (16) — within the established mapping tolerance.
- Gauge track height stays at the current 280pt (canvas 220 is a canvas-fit choice; the fill *proportions* are what matter).
- Branch stacks on `feat/035-calendar-scroll-collapse` (owner's no-waiting-for-GitHub ruling); retargets onto main when the PR tower lands.
