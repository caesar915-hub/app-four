# Feature Specification: App-Wide New Look — Complete the Migration

**Feature Branch**: `feat/033-newlook-app-wide`

**Created**: 2026-07-11

**Status**: Draft

**Input**: User description: "Adopt the background colour and card colour from Recording Detail across the entire app; re-skin the medication bar and fix why it looks missing. Full consistency — migrate every screen including the documented exceptions (RecordingRow, Onboarding, Settings) plus the tab bar. Slice-first execution. Plan grounded in the Figma source of truth."

---

## Context

spec-032 introduced the **New Look** visual language (sage screen `#EFF2EB`, borderless white cards at radius 20 with a soft shadow, iOS ink, hairline borders, selection green, medication purple) and applied it to exactly **two** screens — Edit check-in and Recording detail — while **deliberately leaving the rest of the app on the original Paper & Pollen (`Theme`) look** as an accepted transition state ([spec-032 FR-010/FR-011](../032-newlook-screens/spec.md), contract X4). This feature **finishes the migration**: New Look becomes the single visual language across every screen, the medication bar is brought onto that language and its "missing dose" defect fixed, and the now-dead Paper & Pollen surface/ink tokens are retired. It reuses spec-032's token contract unchanged; nothing there is redesigned.

A Phase-0 reconciliation against the Figma source of truth (file **Squil-Design** `M0Meys9X89X1NLyT14qrX5`, screens a02 `308:1594` / a03 `308:1654`) confirmed the shipped New Look tokens already match the Figma variables 1:1 on all seven colours, the card radius, and the 16px gutter. Only three deltas remain (a missing groove token, a shadow-layer count, and one intentional destructive-colour deviation), all resolved in Requirements below.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every screen wears the New Look (Priority: P1) 🎯 MVP

Wherever the user navigates — Calendar, Check-in, Insights, Settings, Onboarding, every sheet and the tab bar — the app presents one coherent visual language: the sage screen ground, borderless white rounded cards with the soft shadow, and a tab bar that belongs to that ground. There is no longer a warm-paper screen sitting next to a sage one; the two screens migrated in spec-032 now look native to the whole app rather than like exceptions.

**Why this priority**: It is the change the user actually asked for and the one that removes the visible "mixed look" seam. It is also the highest-leverage slice — flipping the shared screen container and the card surfaces re-skins the entire app in one reviewable increment, giving an immediately shippable, coherent result.

**Independent Test**: Build the branch, open every tab and sheet on device in light and dark, and confirm each renders the sage ground + borderless white cards matching the a02/a03 language, with a tab bar that reads as part of that ground and no residual warm-paper surface.

**Acceptance Scenarios**:

1. **Given** any tab (Calendar, Check-in, Insights, Settings), **When** it appears, **Then** the screen background is the New Look sage and the navigation/tool bar shares that ground — no warm-paper surface anywhere.
2. **Given** any card or row (day card, recording row, insight card, settings row, med log sheet, onboarding), **When** rendered, **Then** it is a borderless white card at radius 20 with the shared soft shadow — no hairline card borders and no radius-16 Paper & Pollen cards remain.
3. **Given** the medication bar with an active dose, **When** it is shown, **Then** its container is the New Look card language (borderless, radius 20) while its dose purple, progress track and state words are unchanged.
4. **Given** dark mode, **When** any screen renders, **Then** every surface uses the derived New Look dark values with legible contrast (no dark-on-dark, no warm-loam remnants).
5. **Given** the two screens already migrated in spec-032 (Edit check-in, Recording detail), **When** the app is re-skinned, **Then** they are visually unchanged (verify-only — never reverted to Paper & Pollen).

---

### User Story 2 - One consistent typography ink across the app (Priority: P2)

Text on every migrated screen reads in the New Look ink hierarchy (primary `#1C1B1F`, secondary `#8A8A8E`) rather than the warm Paper & Pollen browns, so headings, body and captions look consistent from the calendar through settings.

**Why this priority**: Necessary for true consistency but lower-risk and less visually dramatic than the surfaces; it can ship as a second, self-contained increment after the look lands, keeping each PR small and reviewable.

**Independent Test**: On device, scan every migrated screen and confirm all primary/secondary text uses the New Look ink, with no warm-brown Paper & Pollen text remaining, and contrast holds in light and dark.

**Acceptance Scenarios**:

1. **Given** any migrated screen, **When** text renders, **Then** primary text is New Look primary ink and secondary/caption text is New Look secondary ink.
2. **Given** semantic text (destructive delete, status pills, medication state), **When** rendered, **Then** it keeps its semantic colour (warm-clay destructive, status, medication purple) — ink migration does not flatten meaning.

---

### User Story 3 - The medication bar shows the doses the user actually logged (Priority: P3)

A user who logs a real medication dose sees it appear in the medication bar. Today, on a development build the bar shows only seeded demo doses and silently hides every real dose the user logs; this story fixes that so the bar reflects the user's own data.

**Why this priority**: It is a real correctness defect (a medication tracker that hides logged medication is broken), but it is scoped to the medication data path and is independent of the visual migration, so it can be delivered and verified on its own.

**Independent Test**: In the mode the app runs in, log a dose within its active window and confirm it appears in the medication bar; delete it and confirm it disappears; confirm seeded demo doses still behave correctly.

**Acceptance Scenarios**:

1. **Given** the app in its default running mode, **When** the user logs a dose whose active window includes now, **Then** the medication bar shows that dose (name, progress, state, times).
2. **Given** a logged dose whose active window has fully elapsed, **When** the bar refreshes, **Then** that dose is no longer shown.
3. **Given** no dose is currently within its active window, **When** any screen renders, **Then** the medication bar reserves no space and shows nothing (unchanged empty-state behaviour).
4. **Given** the medication-bar visibility setting is turned off, **When** any screen renders, **Then** no bar appears regardless of dose data.

---

### User Story 4 - A single design system, no dead styling (Priority: P4)

After the migration, the codebase carries one surface/ink design language, not two. The retired Paper & Pollen surface and ink tokens no longer exist, so future screens cannot accidentally reintroduce the old look.

**Why this priority**: Maintainability and constitution compliance (no dead code), valuable but strictly internal; it must come last because it can only happen once every consumer has moved.

**Independent Test**: Search the codebase for the retired surface/ink tokens and the old card modifier and confirm zero references remain; the app builds and the full suite passes.

**Acceptance Scenarios**:

1. **Given** the migration is complete, **When** the codebase is searched for the retired Paper & Pollen surface/ink tokens and the bordered card modifier, **Then** there are zero references and the design system exposes one surface/ink language.
2. **Given** the retired tokens are deleted, **When** the app and design package build, **Then** they compile clean and the full test suite passes.

---

### Edge Cases

- **Dark mode**: New Look dark values are derived (not mocked); every migrated surface, the new groove token, and hairline-on-sage contrast must be legible in dark — verified at device QA.
- **Dynamic Type at accessibility sizes**: headers, chips, rows, and the medication bar must scale without truncation or overlap.
- **Tab bar on sage**: the tab bar must read as part of the sage ground, not a floating system-material chrome, in both appearances.
- **Groove/track contrast**: slim progress tracks (gauges, mini-bars, dose track, level bars) must stay visible on white cards using the neutral tint, not disappear.
- **The two already-migrated screens**: must not regress or be reverted while their tokens are shared and later consolidated.
- **Calendar timeline**: remains on its current look until its gate opens (see Assumptions) — a temporary, bounded seam, not a regression.
- **No active dose / mock-vs-real**: the medication bar's empty-state and mode partition behaviour stays correct after the data fix.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The shared design-token set MUST gain a neutral inset/track token (`tint/neutral`, `#ECEAE6` light + a derived dark value) — the New Look replacement for the Paper & Pollen inset used by progress tracks, gauge grooves, and segmented fills — matching the Figma variable 1:1.
- **FR-002**: The New Look card treatment MUST match the Figma card shadow exactly: a two-layer soft drop shadow (per `Tiimo/Shadow/Card`), replacing the current single-layer approximation.
- **FR-003**: Every screen's background and its navigation/tool bar MUST use the New Look screen ground (sage), replacing the Paper & Pollen background across all tabs and sheets.
- **FR-004**: Every card and row surface MUST use the New Look borderless card language (white, radius 20, soft shadow, no border), replacing all Paper & Pollen bordered/radius-16 card usages and manual card-background fills.
- **FR-005**: Every track/groove/segmented fill MUST use the FR-001 neutral tint (never the white card colour, which would render it invisible; never a card border colour).
- **FR-006**: All primary and secondary text on migrated screens MUST use the New Look ink tokens; semantic text colours (destructive, status, medication) MUST be preserved.
- **FR-007**: The tab bar MUST be given an explicit New Look appearance so it reads as part of the sage ground (reversing spec-032 FR-011's "tab bar unchanged"); any incidental system-material surface (e.g. a translucent feedback control) MUST be given an explicit New Look surface.
- **FR-008**: The medication bar MUST be re-skinned to the New Look card language (borderless card, ink text, neutral-tint dose track) while keeping the medication purple, the dose progress semantics, the state words, and the glyph unchanged.
- **FR-009**: The medication bar MUST display the doses the user logs in the app's current data mode: logging a dose MUST tag it to the active mock/real partition so it is visible in that mode, fixing the defect where real logged doses are hidden. The `isMockData` partition (Constitution IX) MUST be preserved, not removed. This is a logic change and MUST be delivered test-first (Constitution X).
- **FR-010**: The migration MUST be purely visual EXCEPT for FR-009: every other interaction, navigation path, and persisted value MUST behave identically to the current release.
- **FR-011**: Every colour, radius, and shadow on migrated screens MUST come from the shared token set — zero one-off literals (the spec-008 "no literals" discipline).
- **FR-012**: Both appearances MUST be supported from day one: every migrated surface and token legible in light AND dark (derived dark values, validated at device QA).
- **FR-013**: The two screens migrated in spec-032 (Edit check-in, Recording detail, and `ADHDSummarySection`) MUST be verify-only — confirmed still correct on the consolidated tokens, never reverted to Paper & Pollen.
- **FR-014**: The medication-bar re-skin MUST NOT change the settings toggles, the empty-state (zero space when no active dose), or the mock/real mode behaviour beyond FR-009.
- **FR-015**: The one intentional deviation from Figma MUST be preserved: the destructive/delete colour stays the warm-clay `Theme.danger`, NOT the Figma `ink/destructive` red (locked by spec-032 contract C15).
- **FR-016**: Semantic, non-surface colours MUST remain on the existing tokens (accent, meadow green/amber, meadow gradient, status, danger, medication purple, signal ramps, mood tints, category/tag colours); glyph shapes and non-colour tokens (spacing, typography, motion) MUST be unchanged.
- **FR-017**: After all consumers have migrated, the now-unused Paper & Pollen surface/ink tokens and the bordered card modifier MUST be deleted (no dead code, Constitution III); the design system MUST then expose one surface/ink language.
- **FR-018**: The Calendar day timeline MUST remain out of scope until the spec-029 branch is merged or abandoned (it rewrites the same views); it is migrated under this spec only after that gate opens.
- **FR-019**: The token strategy MUST be call-site migration, NOT aliasing the old tokens to new values — because the card change is a shape change (bordered radius-16 → borderless radius-20), which colour aliasing cannot produce.

### Key Entities

- **Medication dose event**: an individual logged or seeded medication dose with a taken-time, a duration window, and a mock/real partition flag. The only data entity this feature touches — and only via FR-009 (tagging a newly logged dose to the active partition). No schema change; no new attributes.
- **New Look token set**: the shared surface/ink/hairline/selection/card-radius/card-shadow design tokens (extended by FR-001/FR-002). The contract every migrated screen binds to.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the app's screens and sheets render the New Look ground + borderless cards (no screen still shows the Paper & Pollen warm-paper background or a bordered radius-16 card), verified by an owner walkthrough of every tab and sheet against the a02/a03 language.
- **SC-002**: A codebase search for the retired Paper & Pollen surface/ink tokens and the bordered card modifier returns zero references after the cleanup increment.
- **SC-003**: A style-literal audit of migrated screens returns zero hardcoded colour/radius/shadow values (100% token usage).
- **SC-004**: Logging a dose within its active window makes it appear in the medication bar in the app's running mode (the pre-fix behaviour of hiding real logged doses no longer occurs), demonstrated on device and covered by a test.
- **SC-005**: The full test suite passes on the branch with zero regressions, and a manual pass of every existing flow (calendar, check-in, insights, settings, onboarding, playback, edit, delete, dose log/delete) shows behaviour identical to the previous release except the SC-004 fix.
- **SC-006**: Owner device QA approves every migrated screen in light AND dark at default and one accessibility text size, with no blocking contrast or truncation finding (including tab bar, grooves, and hairlines).

## Assumptions

- The spec-032 Figma a-screens (file Squil-Design, "Screens (v2)") plus the confirmed 1:1 token reconciliation are the **binding design language** for this migration; because the migration applies an already-approved, token-bound language mechanically, per-screen HTML mockups are not required for the colour-swap surfaces (Constitution I mockup gate satisfied by the a-screens). Screens whose card **shape** changes non-trivially (Insights cards, Settings rows) get a Figma mockup before implementation if the owner wants to preview the shape.
- **Execution is slice-first** (owner decision 2026-07-11): an invisible token-foundation increment, then a single "look" increment (ground + cards + tab bar + medication-bar re-skin) that flips the whole app, then an ink-typography increment, then a cleanup increment that deletes the dead tokens — one PR per increment, each with `/code-review` and owner device QA, keeping `main` releasable (Constitution V).
- **Full consistency** (owner decision 2026-07-11): the spec-032 documented exceptions (calendar recording row, onboarding, settings) and the tab bar ARE migrated — the "leave them Paper & Pollen" carve-outs of spec-032 are explicitly overridden here.
- **Medication-bar data fix depth**: the minimal, partition-preserving fix (tag a newly logged dose to the current mode so it is visible) is assumed; a broader "always show real doses regardless of mode" redesign is out of scope unless the minimal fix proves insufficient in use.
- **Settings card language**: the reasonable default is to recolour the system inset-grouped rows to the New Look card colour (keeping the system corner radius), not to rebuild Settings as radius-20 borderless cards; the fuller card treatment is a follow-up if desired.
- The Calendar day timeline stays gated on the unmerged spec-029 branch (dependency), consistent with spec-032 FR-012.
- Owner builds and QAs on a physical device (no simulator in this workflow); iPhone 12-class hardware is the size/performance floor.
- Development continues on the `app-four-spm` worktree; a `feat/033-newlook-app-wide` branch is cut from the branch carrying the spec-032 New Look foundations.
