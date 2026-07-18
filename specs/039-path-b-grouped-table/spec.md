<!-- Created: 2026-07-18 19:18 (WEST) · Updated: 2026-07-18 19:55 (WEST) -->
# Feature Specification: Path B — Native iOS Grouped-Table Redesign (Figma)

**Feature Branch**: `039-path-b-grouped-table`

**Created**: 2026-07-18

**Status**: Draft

**Scope note**: This is a **Figma design specification** — the deliverable is the redesigned screens in the Figma file **Squil-Design** ("Screens v3", frozen backup page created 2026-07-18). SwiftUI implementation is a **separate downstream spec**, not covered here. The project constitution (code-era) is explicitly out of scope per owner.

**Input**: Convert the app's "New Look" borderless-card visual language (spec 033, app-wide) to native iOS grouped-table grammar, driven by the 4-lens design audit (`design-database/perceptual-audit.csv`, rules R29–R32) which found the New Look reads as web/Material rather than native iOS. Also resolve the audit's cross-cutting root causes (emphasis/spacing hierarchy R29, overloaded green R30, Insights chart vocabulary R32) within that grammar.

---

## User Scenarios & Testing *(mandatory)*

> "User" below = the person using the Squirl app, experiencing the redesigned screens. Each story is an independently reviewable Figma deliverable.

### User Story 1 — Recording detail reads as native iOS (a02 pilot) (Priority: P1)

A user opening a recording's detail sees a screen that reads like a native iOS detail view: the signal summary, medications, sleep, emotions, side effects, transcript, and audio content sit in shadowless inset-grouped sections inside rounded containers, each group introduced by a gray uppercase caption *above and outside* the group, related single-line facts gathered as separator-divided rows within one group (not one floating card per fact), with footnote captions where explanation is needed. Controls are native idioms, and the destructive "Delete recording" action sits in its own group styled the iOS way.

**Why this priority**: a02 is the pilot (owner-designated 2026-07-18) because it tests the grouped-table grammar on *rich mixed content* — data summary + rows + long-form transcript + an audio player — which is harder than settings toggles, and it carries multiple audit findings (mismatched section icons, card-per-fact soup, hairline signal bars, medication-purple audio player) so FR-018 remediation is proven in the same pass. Converting it fully proves (or disproves) the language before rollout; it is the MVP. **Pilot gate rule: iterate until pass** — a02 is reworked until it passes review; all other screen conversions remain blocked meanwhile.

**Independent Test**: Rebuild a02 in Figma to grouped-table grammar and place it beside the frozen New Look a02; a reviewer can confirm it reads as a native iOS detail screen and that no information from the original was lost.

**Acceptance Scenarios**:

1. **Given** the redesigned a02, **When** a reviewer compares it to iOS grouped-table grammar, **Then** every content group uses an inset rounded container with a caption header outside it and hairline row separators — no drop-shadowed floating cards, and no card-per-single-fact.
2. **Given** the section headers, **When** inspected, **Then** their icons (if kept) share one style, weight, and tint — or are dropped consistently.
3. **Given** the audio player, **When** inspected, **Then** its controls use a neutral/native color, not medication purple.
4. **Given** the original a02 content inventory, **When** compared to the redesign, **Then** every row, value, and control from the original is present.
5. **Given** the mini signal bars, **When** inspected, **Then** signal values are conveyed with legible marks, not ~2px hairlines (per FR-018 / audit rank-17).

---

### User Story 2 — Color communicates a single meaning per role (Priority: P1)

A user can tell at a glance what a colored element *means*, because each color role is distinct: the primary green marks the primary action / on-state only; a "selected" state is shown without reusing that green; and mood data keeps its own ramp, never borrowed for UI chrome.

**Why this priority**: R30 (green means 5–7 things) was flagged by 3 of 4 audit lenses as a root cause of the "feels off" quality; it is foundational because it affects every screen, and grouped-table grammar alone does not fix it.

**Independent Test**: Produce the semantic color-role token set and apply it to the a02 pilot; a reviewer can confirm no single color token serves more than one semantic role on the screen.

**Acceptance Scenarios**:

1. **Given** the redesigned screens, **When** a green element appears, **Then** it means exactly one thing in that context (action, or on-state, or — never simultaneously — selection or mood).
2. **Given** a selected chip/option, **When** inspected, **Then** "selected" is signaled without a fill that collides with the primary-action or mood greens.
3. **Given** a mood value and a UI control on the same screen, **When** compared, **Then** they do not share a color.

---

### User Story 3 — Content is ranked, not a flat mat of equal tiles (Priority: P2)

A user's eye is led to what matters on each screen: primary content is visually weightier than secondary detail, groups are separated by clearly larger space than items within a group, and the persistent medication bar reads as global chrome rather than just another content row.

**Why this priority**: R29 (no emphasis/spacing hierarchy) was the rank-1 finding across all four lenses. Native grouped-table grammar delivers much of this for list screens, but the spacing tiers and the medication-bar chrome treatment must be specified explicitly.

**Independent Test**: Apply the spacing/emphasis system to the pilot; a reviewer can confirm section-level spacing is visibly larger than intra-group spacing and that primary content outweighs secondary.

**Acceptance Scenarios**:

1. **Given** any long screen, **When** measured, **Then** between-group spacing is a distinctly larger tier than within-group spacing (not the single uniform gap of the New Look).
2. **Given** a screen with the medication bar, **When** viewed, **Then** the bar is visually distinct from content (pinned chrome), not an identical card.

---

### User Story 4 — Remaining list-grammar screens converted (Priority: P2)

The edit-check-in (a03) and Settings (a08) screens — which are fundamentally lists of fields/sections — adopt the same grouped-table grammar and token system proven on the a02 pilot.

**Why this priority**: a03/a08 are the other screens where grouped-table grammar applies natively; converting them completes the "list" family and makes the app read as one system. a08 additionally validates the grammar against the strongest native mental model (Settings.app).

**Independent Test**: Convert a03 and a08; a reviewer confirms they share the a02 grammar, tokens, and spacing tiers.

**Acceptance Scenarios**:

1. **Given** a03 and a08, **When** compared to a02, **Then** they use the same row/group/header/separator grammar and the same semantic color tokens.
2. **Given** a08's toggles and multi-option controls, **When** inspected, **Then** switches use the system-green on-state and multi-option choices are a single segmented control, not detached pills.

---

### User Story 5 — Non-list screens get native-appropriate treatment (Priority: P3)

The screens that are **not** lists — a01 Calendar (a timeline), a04–a06 Check-in (single-focus "moments"), a07 Insights (data visualization) — are made to feel native **without** being forced into literal grouped-table grammar, and adopt the shared token system, spacing tiers, and (for a07) a single chart vocabulary.

**Why this priority**: grouped-table is a list pattern; applying it literally to a timeline, a moment, or a chart would be wrong. These screens still need the color/spacing discipline and native controls, and a07 specifically needs R32 (one chart idiom) resolved. Lower priority because it's the most design-exploratory and least mechanical.

**Independent Test**: Redesign a07 with a single chart vocabulary and the shared tokens; a reviewer confirms the three signals are charted one consistent way and the screen reads as native without grouped-table rows.

**Acceptance Scenarios**:

1. **Given** a07 Insights, **When** inspected, **Then** the three signals (mood/energy/focus) are visualized with one consistent mark/scale across all sections, not 3–5 different chart idioms.
2. **Given** the non-list screens, **When** compared to the list screens, **Then** they share the same margins, spacing tiers, color tokens, and control styles.

---

### Edge Cases

- **Non-list screens and grouped-table**: grouped-table grammar is a list pattern. For a01/a04–a06/a07 it MUST be interpreted as "native-appropriate composition + shared tokens/controls," not literal inset rows (see US5). The spec must not force list rows onto a timeline or a chart.
- **The medication bar** overlays multiple screens; its native treatment (pinned chrome vs inline) must be consistent across all screens that show it.
- **Status bar** is currently rendered on only 5 of 8 frames; the redesign MUST render it uniformly on all frames so clearance and consistency are verifiable.
- **Identity loss**: if grouped-table conversion strips too much character, the design risks reading as a generic system-settings app rather than Squirl — this is the core tradeoff being tested (see Assumptions / Q&A).
- **Inter stand-in**: the Figma canvas renders Inter for SF; the redesign judges layout/hierarchy, not the typeface (SF Pro remains the production target).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The redesigned **list screens** (a08 Settings, a02 Recording detail, a03 Edit check-in) MUST use inset-grouped rows inside shadowless rounded containers — no floating drop-shadowed cards for list content.
- **FR-002**: Each group on a list screen MUST be introduced by a caption-style header positioned *outside and above* the group, and MAY carry a footnote caption below.
- **FR-003**: Rows within a group MUST be separated by hairline separators, not by inter-card gaps.
- **FR-004**: Interactive controls MUST use native iOS idioms: system-green toggles, chevron disclosure on navigable rows, and a single segmented control for multi-option choices (no detached selection pills).
- **FR-005**: List screens MUST use the native navigation treatment appropriate to their presentation: **large-title nav for pushed/root screens (a02, a08); native sheet grammar (inline title + Cancel/Save bar) for the a03 edit modal** — large titles do not apply inside sheets. *(Corrected during clarify 2026-07-18: the original blanket large-title mandate would itself have broken native grammar on a03.)*
- **FR-006**: The design system MUST define **semantic color-role tokens** that split the currently-overloaded green so that no token serves more than one role: primary-action/on-state, selection, and mood-data MUST be distinct. Per clarification (2026-07-18): the merged **primary-action/on-state role is iOS system green `#34C759`**; brand greens (meadow `#5F8A4C`, selection `#54B492`, checkInGreen `#5FB36E`) are retired from action/control roles on converted screens, and the mood ramp remains data-only.
- **FR-007**: Selection state MUST use the **iOS-standard treatment** — checkmark or neutral tint, no colored fill — and MUST NOT reuse the primary-action green or the mood ramp (per Q3).
- **FR-008**: The design system MUST define **spacing tiers** such that between-group / between-section spacing is a distinctly larger step than within-group spacing.
- **FR-009**: The persistent medication bar MUST be styled as visually distinct global chrome, not as an identical content card.
- **FR-010**: The status bar MUST be rendered uniformly across all 8 frames.
- **FR-011**: Insights (a07) MUST visualize the three signals with **one consistent chart vocabulary** (single mark family + shared scale) across its sections, and MUST NOT use overlapping-bubble marks for part-to-whole composition.
- **FR-012**: Non-list screens (a01 Calendar, a04–a06 Check-in, a07 Insights) MUST adopt the shared tokens, spacing tiers, native controls, and uniform status bar, but MUST NOT be forced into literal grouped-table rows.
- **FR-013**: A component library MUST be produced for the reused grammar (at minimum: grouped-list-row, section caption header, hairline separator, native toggle row, segmented control) so screens are assembled from instances, not one-off frames.
- **FR-014**: The redesign MUST be additive/non-destructive to the frozen "Screens v3 — Backup" page; the working "Screens v3" page is where conversion happens.
- **FR-015**: For every converted screen, all content (rows, values, controls, labels) from the pre-Path-B version MUST be preserved — conversion changes grammar, not information.
- **FR-016**: The **a02 Recording-detail pilot** MUST be delivered and reviewed **before** any other screen is converted (pilot gate). Gate rule (clarified 2026-07-18): **iterate until pass** — a02 is reworked until it passes review; all other conversions stay blocked meanwhile.
- **FR-017**: The borderless card MUST be retired for list content but MAY be **retained as a refined secondary surface** for genuinely non-list content (Insights panels, calendar day cards) per Q2 — it MUST NOT be used for settings/detail list groups.
- **FR-018**: Every screen 039 touches MUST also remediate **all applicable `perceptual-audit.csv` findings** that land on it (per clarification 2026-07-18: all 18 findings, opportunistic scope) — including glyph fill-weight discipline (rank-5; fill weight only, the sprout/bolt/aperture shape language is unchanged), ≥44pt touch targets (rank-7), and the a04/a05 ring recomposition + duplicate-indicator removal (rank-8). A finding is out of scope only if its screen is untouched.
- **FR-019**: The redesigned screens are a **new AA-compliant baseline**: secondary text and grouped-table caption headers MUST meet WCAG AA (4.5:1 normal text) on their surfaces — the 2026-07-12/16 Figma-fidelity contrast waivers do NOT carry over (per clarification 2026-07-18).

### Key Entities *(design artifacts, not code)*

- **Semantic color-role token set**: the split of the overloaded green into distinct roles (primary-action/on-state, selection, status, mood-ramp-reserved), each a Figma variable.
- **Spacing & emphasis system**: the tier scale (intra-group / inter-group / section / major) as Figma variables.
- **Grouped-table component library**: grouped-list-row, section caption header, hairline separator, toggle row, segmented control, disclosure row.
- **Screen inventory**: the 8 canonical screens, each tagged list-grammar vs native-composition, with its content inventory preserved.
- **Chart vocabulary (a07)**: the single chosen mark family + scale for the three signals.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Re-running the 4-lens design audit on the converted screens returns **zero** high-severity HIG "reads as web/Material, not iOS" findings for the list screens (was: R31 high).
- **SC-002**: **No color token serves more than one semantic role** on any converted screen (was: one green across 5–7 roles, R30).
- **SC-003**: On every converted long screen, between-group spacing is a **measurably larger tier** than within-group spacing (was: single uniform gap, R29).
- **SC-004**: Insights presents the three signals with **one** chart mark family across all its sections (was: 3–5 idioms, R32).
- **SC-005**: 100% of pre-Path-B content (rows, values, controls) is present on each converted screen (no information lost).
- **SC-006**: A reviewer shown the a02 pilot beside a native iOS grouped detail screen judges the grammar as native-consistent.
- **SC-007**: All 8 frames render a uniform status bar and a consistently-styled medication bar.
- **SC-008**: Re-running the 4-lens audit on converted screens returns **zero high-severity findings of any lens** on those screens (was: 8 high-severity across lenses).

## Assumptions

- **Figma-first**: the deliverable is the Figma redesign only. SwiftUI implementation, `NewLook.swift` token changes, and device QA are a separate downstream effort not specified here.
- **Non-destructive**: "Screens v3" is the working page; the "Screens v3 — Backup (pre Path B)" page (created 2026-07-18) is the frozen reference and is never modified.
- **Inter stands in for SF Pro** on the canvas; layout/hierarchy is judged, not the typeface.
- **This supersedes spec-033's app-wide New Look decision** for the list screens; the borderless card is retained for non-list content (Q2), so New Look is narrowed rather than fully retired. The tradeoff (native correctness vs the app's distinctive card identity — noting the reference apps Tiimo and Gentler Streak are custom-card, not grouped-table) is deliberately accepted by pursuing Path B, subject to the pilot review.
- **Constitution is out of scope** (owner: it's a code-era artifact); no Constitution Check gate applies to this Figma spec.
- **DESIGN.md is out of scope as a constraint for the entire 039 pipeline** — spec, plan, tasks, and implementation (owner 2026-07-18, stated twice): it neither gates nor vetoes any 039 decision (incl. its Calendar protection, nav/back-button rulings, and contrast waivers). It is historical reference; it will be updated *from* the 039 outcome.
- The mood/energy/focus signal ramps themselves (colors) are retained as data encoding; only their reuse as UI chrome is removed.

## Clarifications *(resolved 2026-07-18)*

- **Q1 (scope split) → List screens only.** Literal grouped-table grammar applies to **a02 / a03 / a08** (the list screens). The non-list screens — **a01 Calendar, a04–a06 Check-in, a07 Insights** — get native-appropriate composition + the shared tokens/controls, **not** forced list rows. (Confirms US5 / FR-012.)
- **Q2 (card identity) → Retain for non-list content.** The borderless card is **retired for list content** but **kept as a refined secondary surface** for genuinely non-list content (Insights panels, calendar day cards). Squirl keeps some card character where it's native-appropriate; it goes grouped-table only where users expect a list. (See FR-017.)
- **Q3 (selection state) → iOS-standard.** Selection is signaled the native way — **checkmark / neutral tint, no colored fill** — never the action green or mood ramp. (Refines FR-007.)

### Session 2026-07-18 (clarify — Fable cross-check)

- Q: Which green is the primary-action token on converted screens? → A: **iOS system green — one merged primary-action/on-state token (`#34C759`)**. Brand greens (meadow, selection, checkInGreen) are retired from action and control roles on converted screens; the mood ramp keeps its data role untouched. (Updates FR-006; FR-004's system-green toggles now share this token.)
- Q: Beyond root causes R29–R32, which perceptual-audit findings must the converted screens also fix? → A: **All 18 findings, opportunistically** — any `perceptual-audit.csv` finding that lands on a screen 039 touches is in scope for that screen's conversion (incl. rank-5 glyph fill weight, rank-7 44pt touch targets, rank-8 a04/a05 ring recomposition). (Adds FR-018, SC-008.)
- Q: Does DESIGN.md's Calendar protection ("Unchanged — do not redesign without explicit ask") constrain a01 work in 039? → A: **DESIGN.md is not a gating authority for the entire 039 pipeline** — spec, plan, tasks, implementation (owner 2026-07-18: "ignore design.md", confirmed "for all the plan"). The a01 protection is void; a01 receives the full US5 treatment (shared tokens, spacing tiers, day-card fixes incl. rank-14, status bar). DESIGN.md remains historical reference only; it gets updated *from* the 039 outcome.
- Q: Do the 2026-07-12/16 contrast waivers (inkSecondary 3.0–3.4:1, selection green 2.52:1, kept 1:1 with the old Figma) carry into the redesigned screens? → A: **No — resolved by the DESIGN.md ruling above.** The waivers were DESIGN.md rulings whose sole rationale was fidelity to a Figma that 039 replaces. The redesign is a **new AA-compliant baseline**: secondary text and the grouped-table caption headers use compliant values (e.g. ~`#6C6C70` for captions on light surfaces). (Adds FR-019.)
- Q: Pilot screen and pilot-gate decision rule? → A: **Pilot = a02 Recording detail** (owner-designated, replacing a08), **iterate until pass** — a02 is reworked until it passes review; all other screen conversions stay blocked meanwhile. Rationale: a02 is a list-grammar screen with rich mixed content (signal summary, med/sleep/emotion rows, transcript, audio) plus several audit findings (icon mismatch, card-per-fact, hairline bars, purple audio player), so it tests both the grouped-table grammar and FR-018 remediation harder than the settings-only a08. a08 becomes a regular US4 list conversion. (Rewrites US1, US4, FR-016, SC-006.)
