# Feature Specification: New Look Screens — Edit Check-in & Recording Detail Re-skin

**Feature Branch**: `feat/032-newlook-screens`

**Created**: 2026-07-10

**Status**: Draft

**Input**: User description: "New Look re-skin of the Edit check-in and Recording Detail screens (Calendar timeline phase-gated behind spec-029). Implement the approved Figma a-screens (file Squil-Design, 'Screens (v2)': a03 Edit check-in, a02 Recording Detail, a01 Calendar Timeline gated) as the New Look visual language: sage screen background #EFF2EB, white cards radius 20 + soft shadow, iOS ink (#1C1B1F/#8A8A8E), hairline borders #DBDDDE, selection accent #54B492, medication purple #7E5CA8, native SF typography mapped from the Figma Inter ramp. Tokens extend the shared design system 1:1 with the Figma variables; DESIGN.md gains a New Look section. Figma trio is the binding mockup. Mascot tab bar and status bar chrome out of scope."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit check-in in the New Look (Priority: P1)

When the user opens the Edit check-in sheet (from a recording's detail or the calendar), the entire screen renders in the New Look: sage background, white rounded cards with a soft shadow (no hairline card borders), a navigation row with a truly centered title between a back pill and a Save pill, chip/pill option rows with hairline outlines, selected options filled in the selection green — except medication chips, which fill in medication purple. All behavior (selecting signals, sleep, medications, emotions, side effects; saving; cancelling) is unchanged.

**Why this priority**: It is the most self-contained screen (a single sheet, no unmerged branch touches it), so it proves the token set and the New Look card/chip language end-to-end with the lowest risk. Everything later reuses what this story establishes.

**Independent Test**: Open Edit check-in on a device, compare side-by-side against Figma a03, exercise every selector and Save/Cancel; no functional change, visual parity per the mockup.

**Acceptance Scenarios**:

1. **Given** a recording with extracted signals, **When** the user opens Edit check-in, **Then** the screen shows the sage background, white radius-20 cards with the shared shadow, and bold sentence-case card headers (Signals, Sleep, Medications, Emotions, Side effects) matching Figma a03.
2. **Given** the Edit check-in sheet is open, **When** the user selects a non-medication option chip, **Then** the chip fills with the selection green and its label becomes white; deselecting restores the white chip with hairline outline and dark label.
3. **Given** the Medications card, **When** a medication or dose chip is selected, **Then** it fills with medication purple (never the selection green).
4. **Given** the navigation row, **When** the sheet is displayed at any width, **Then** the title is centered on the screen's vertical axis (equal left/right margins) between the back pill and Save pill.
5. **Given** any edit flow (change mood level, change dose, save), **When** performed on the re-skinned screen, **Then** the resulting stored data is identical to what the previous design produced.

---

### User Story 2 - Recording detail in the New Look (Priority: P2)

When the user opens a recording's detail screen, it renders in the New Look: a signal hero strip (three columns — mood/energy/focus with glyph, level word, micro-label, and level bar), followed by white info cards with bold sentence-case headers (Medications, Sleep, Emotions, Side effects, Transcript), the audio player card, and the delete action. All behavior (playback, edit entry point, delete) is unchanged.

**Why this priority**: Highest-traffic read surface after the calendar; depends on the same tokens and card language as US1 but touches a screen that was restyled recently (spec-027), so it goes second, after the language is proven.

**Independent Test**: Open any recording's detail on a device, compare against Figma a02, play audio, navigate to edit, delete a recording; visual parity, zero behavioral change.

**Acceptance Scenarios**:

1. **Given** a recording with all signal types, **When** detail opens, **Then** the hero strip shows three equal columns with glyph, level word, micro-label and level bar, matching Figma a02.
2. **Given** the info cards, **When** rendered, **Then** each shows a bold sentence-case header with its leading icon and body text per the mockup (headers match US1's card-header language and category naming).
3. **Given** the delete action, **When** tapped, **Then** the existing confirmation/delete behavior runs unchanged (visual restyle only).
4. **Given** a recording whose transcript is long, **When** detail renders, **Then** the transcript card wraps its full text without clipping or overlap.

---

### User Story 3 - Calendar timeline in the New Look (Priority: P3 — GATED)

The calendar day timeline (expanded day card with per-entry rows, medication bar, week strip, folded day summary) renders in the New Look per Figma a01.

**Why this priority**: Largest surface and highest conflict risk — the same views are being modified by the unmerged spec-029 branch (calendar day context). **This story MUST NOT start until the 029 branch's fate (merge or abandon) is decided.** It ships in a follow-up PR even if 032's US1/US2 are merged.

**Independent Test**: Not applicable until un-gated; when un-gated, side-by-side against Figma a01 with existing calendar interaction tests green.

**Acceptance Scenarios**:

1. **Given** the gate is open (029 resolved), **When** the calendar day view renders, **Then** it matches Figma a01's timeline language (band header, entry rows with glyph column, chips, folded summary card).

---

### Edge Cases

- Dark mode: New Look dark values are derived, not mocked (FR-009) — both screens must never render illegible (no dark-on-dark or white-on-white text); contrast verified in both appearances at device QA.
- Dynamic Type at accessibility sizes: card headers, chip labels, and the hero strip must scale without truncation or overlapping chips (chips may wrap to more rows).
- Long content: many medications/emotions selected → chip rows wrap; transcript of several paragraphs → card grows, screen scrolls.
- Smallest supported device (iPhone 12 class): 16px gutter and chip wrap must hold without horizontal clipping.
- Mixed-look transition: while only these two screens are re-skinned, the rest of the app remains Paper & Pollen — accepted transition state per FR-010; shared chrome (tab bar, sheets presentation) must not visually break at the boundary.
- Reduce Motion: no new motion is introduced; existing transitions respect the system setting as today.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The shared design token set MUST gain the New Look values, one-to-one with the approved Figma variables: screen background #EFF2EB, card surface white, primary ink #1C1B1F, secondary ink #8A8A8E, hairline border #DBDDDE, selection accent #54B492, card corner radius 20, and the shared card shadow. Medication purple continues to use the existing token (#7E5CA8).
- **FR-002**: The Edit check-in screen MUST match Figma a03 (node `308:1654`) in layout, color, and type hierarchy: 16px screen gutter, white radius-20 shadow cards without borders, centered nav title between back/Save pills, hairline-outlined chips, selection-green selected states, medication-purple medication chips, and the a03 card-header set (Signals, Sleep, Medications, Emotions, Side effects).
- **FR-003**: The Recording detail screen MUST match Figma a02 (node `308:1594`): 16px gutter, signal hero strip (three equal columns: glyph, level word, micro-label, level bar), info cards with bold sentence-case headers + leading icons (Medications, Sleep, Emotions, Side effects, Transcript), audio card, destructive delete row.
- **FR-004**: Typography on the re-skinned screens MUST use native system typography; the Figma Inter ramp is a stand-in and MUST be mapped to equivalent system text styles (hierarchy by size/weight per the mockups), supporting Dynamic Type.
- **FR-005**: The re-skin MUST be purely visual: every existing interaction, navigation path, and persisted value on both screens behaves identically to the current release.
- **FR-006**: Every color, spacing, radius, and shadow on the re-skinned screens MUST come from the shared token set — zero one-off literals in the screen code (the spec-008 "no literals" discipline).
- **FR-007**: DESIGN.md MUST gain a New Look section recording the palette, radius, card language, and its relationship to Paper & Pollen (which screens use which), so the source-of-truth file matches the shipped UI.
- **FR-008**: The signal glyph language (sprout/bolt/aperture, bed, capsule) MUST remain the existing shared glyph components; the New Look restyles their containers and colors context, not the glyph shapes.
- **FR-009**: Dark mode: the New Look token set MUST include derived dark values (dark sage surfaces, light ink, same hairline/selection/medication roles) so both re-skinned screens fully support dark appearance from day one; the derivation follows platform conventions (the Figma mockups are light-only) and is validated at owner device QA. *(Clarified 2026-07-10: option A — derive now.)*
- **FR-010**: Transition posture: the mixed look (New Look on these two screens, Paper & Pollen elsewhere) is ACCEPTED as a visible transition state on main/TestFlight; no developer toggle or dual style path is introduced. *(Clarified 2026-07-10: ship the mix.)*
- **FR-011**: The mascot tab bar, status-bar chrome, and root navigation MUST NOT change in this feature.
- **FR-012**: User Story 3 (calendar timeline) MUST NOT begin until the spec-029 branch is merged or abandoned; its tasks are excluded from the US1/US2 delivery.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Side-by-side review of each shipped screen against its Figma mockup (a03, a02) finds zero unapproved deviations in layout, color, or type hierarchy (owner sign-off checklist, light appearance).
- **SC-002**: The full test suite passes on the branch with zero regressions, and a manual pass of every existing flow on both screens (select/save/cancel, play, edit, delete) shows behavior identical to the previous release.
- **SC-003**: A style-literal audit of the re-skinned screens returns zero hardcoded color/spacing/radius/shadow values — 100% token usage.
- **SC-004**: Owner device QA (light + the Q1-resolved dark behavior, default and accessibility text sizes) approves both screens without a blocking finding.
- **SC-005**: Users can complete an edit-and-save round trip on the re-skinned Edit check-in with no more taps than the current design (interaction cost unchanged).

## Assumptions

- The approved Figma trio (a01/a02/a03 on "Screens (v2)", file Squil-Design) is the **binding mockup** for this feature and satisfies the Constitution's mockup-before-implementation gate (these are restyles of existing views, and the Figma set is higher-fidelity than an HTML mockup: token-bound, pixel-measured, adversarially QA'd on 2026-07-09).
- Inter in the Figma file is a rendering stand-in; the product uses native system typography (per the spec-023 typography reversal recorded in DESIGN.md on main).
- Demo content in the mockups (names, times, values) is not binding — only structure, tokens, and states are.
- Medication purple #7E5CA8 already exists in the shared token set and is reused, not redefined.
- The feature is developed on the `app-four-spm` worktree, branch `feat/032-newlook-screens` off `origin/main`; one PR delivers US0-foundation + US1 + US2, and US3 ships separately after its gate opens.
- The empty-state, error-state, and loading behaviors of both screens are unchanged by this feature (visual restyle applies to their existing presentation).
- iPhone 12-class hardware is the performance/size floor (existing project constraint).
