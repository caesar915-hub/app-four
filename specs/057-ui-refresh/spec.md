# Feature Specification: UI Refresh from the Pencil design (057)

**Feature Branch**: `feat/057-ui-refresh`

**Created**: 2026-09-28

**Status**: In progress — owner accepted every recommendation of `shipaton_plan/UI_REFRESH_PLAN.md` on 2026-09-28 and asked for implementation ASAP.

**Input**: The owner's outside design `untitled.pen` (Pencil): 8 `iPhone 17` screens + a design system. Source of truth for the visual language is `DESIGN.md` (rewritten from the pen, 2026-09-28); the plan of record is `shipaton_plan/UI_REFRESH_PLAN.md`; the evidence pack (per-screen specs, verified code cross-checks, design-system spec, code maps, constraints) is `specs/057-ui-refresh/research/`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture on the new check-in flow (Priority: P1)

A user opens the Check In tab and sees the pen's hub (date, "How do you feel?", the ring with Speak / Log medications / Write notes), records against the prompt card and ⅔ ring, and lands on the saved screen with the full ring and check tile.

**Why this priority**: the app's front door; the smallest consumer of the new foundations; proves the language before the data-heavy screens.

**Independent Test**: build + simulator; start a recording from the hub, watch the chrome hide, stop, see the saved screen, tap "Go back home"; the deep link `whispernotes://checkin` still lands in the listening state.

**Acceptance Scenarios**:
1. **Given** the hub, **When** Speak check-in is tapped, **Then** the tab bar and medication bar hide, the ring reads ⅔, the prompt card shows prompt 1 of 5 and the 72-pt timer counts.
2. **Given** a recording, **When** Stop & save is tapped, **Then** the saved screen shows the full ring + check tile, "Check-in saved" and a full-width "Go back home"; Reduce Motion shows the final state without settle animation.
3. **Given** the saved screen, **When** the back pill or "Go back home" is tapped, **Then** the hub returns with the chrome visible.

### User Story 2 - Read the journal on the new Calendar tab (Priority: P1)

The Calendar root shows the medication bar card, the month header + week strip, the selected day expanded into check-in rows with mood avatars and energy/focus glyphs, and "Previous days" as tinted collapsed cards.

**Why this priority**: the launch tab and the floating chrome's first real host; ships in wave 1 with the check-in trio.

**Independent Test**: seed recordings across a month (`-mockData`); verify rows, avatars, `displayLabel` words, dose text, sleep moon + "8h sleep"; previous days are month-scoped; VoiceOver reads each row's level words.

**Acceptance Scenarios**:
1. **Given** a day with three check-ins, **When** it is selected, **Then** the expanded card shows the mint band with the day's average mood word and one row per check-in.
2. **Given** an older day in the same month, **Then** it appears as a collapsed card tinted by its mood with the pen's anatomy; days from another month do not appear under this month.

### User Story 3 - Read and correct a check-in (Priority: P2)

Day Details shows the pen's signal summary, emotion chips, medication row and the AI-summary card with the inline player; Edit is a pushed page with level tiles, chip rows, medication rows and a dirty-gated "Save changes".

**Independent Test**: open a check-in, edit mood/energy/focus/sleep/emotions/medication, save; provenance tags are written; swipe-dismissal cancels unsaved edits.

**Acceptance Scenarios**:
1. **Given** Day Details, **Then** transcript / transcribing / failed + retry states render inside the AI card; a text check-in shows no player.
2. **Given** Edit, **When** a level tile is tapped twice, **Then** the level clears; **When** nothing changed, **Then** Save is disabled.

### User Story 4 - Read the month on Insights (Priority: P2)

Bubbles, weekday glyph rows, range bars, the rhythm matrix and the connection cards in the pen's language, with canonical level words and the real unlock gates.

### User Story 5 - Settings as cards (Priority: P3)

Settings groups become the pen's cards with native toggles, radio rows and chips; the rows the pen omits but rules require (export, privacy, model rows, My Medication, disclaimer, Clear All Data, version, subscription/restore from 055) remain.

### Edge Cases & Error Handling

#### 1. Network & Connectivity Failures
- Model download rows keep their hardened state machine (specs 041/044); the refresh restyles only.

#### 2. Data Validation & Bad Input
- Out-of-range levels clamp (existing `clampedSignalLevel`); absent levels draw the dashed placeholder, never level 1; sleep without a level draws the full moon as an identity icon.

#### 3. State Restoration & Interruptions
- Chrome visibility is derived from view state (`HidesFloatingChromeKey`), never stored; a backgrounded recording returns to the same layout.

#### 4. Hardware/Permission Denials
- Unchanged: microphone, storage and memory alerts are system alerts and keep iOS Liquid Glass (DESIGN.md §9.5).

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: Every colour, size, weight, radius and shadow comes from the token package (`Surface` / `Ink` / `Accent` / `Stroke` / `Elevation` / `Typography` / `Spacing` / `Radius` / `Metrics`); no literals in views.
- **FR-002**: Text-carrying fills use green-600 and captions grey-300; `TokenContrastTests` asserts ≥ 4.5:1 text and ≥ 3:1 UI pairs in light and dark (D14).
- **FR-003**: The four signal glyphs are drawn from the pen's Frame 12 paths behind the unchanged `SignalGlyph` API; level is encoded by colour + crown growth (mood), rising fill (energy, sleep) and arc sweep (focus) — never colour alone.
- **FR-004**: Sleep is a 1→5 ramp (`SleepLevel: SignalLevel`, `displayLabel` Restless…Deep); level words come only from the level enums (Constitution VII).
- **FR-005**: The roots hide the system navigation and tab bars and overlay the floating tab bar + Add button; the Add button starts a voice check-in through `AppIntentRouter.requestCheckIn()` and is hidden on the Check In root; screens hide the chrome while capturing or editing.
- **FR-006**: Copy is normalised (sentence case for sentences; the pen's typos are never transcribed).
- **FR-007**: Pre-057 token and role names stay as aliases until the last consumer migrates (UI-49); no call site changes metrics or colour silently.
- **FR-008**: Export, privacy/terms, restore, the model rows, My Medication, the medical disclaimer, Clear All Data and the version label are never removed from Settings.

### Key Entities
- No SwiftData schema change. New state is `@AppStorage` (medication-bar taken/end time), computed (`flowProgress`, `DoseStatus`, `relativeTitle`), or `RecordingTag` rows.

## Success Criteria *(mandatory)*

### Measurable Outcomes
- **SC-001**: Full serial test suite green after every phase (baseline 544 → ≥ 552 with the new token/glyph tests).
- **SC-002**: Every token text/fill pair passes AA in both appearances (test-enforced).
- **SC-003**: Every screen renders without clipping at 402 / 393 / 375 pt and at Dynamic Type AX5 (simulator screenshot pack attached to the PR).
- **SC-004**: VoiceOver reads the tab bar as "Calendar, tab, 1 of 4, selected", each level tile as "Mood: Good, 4 of 5, selected".

## Assumptions
- The owner accepted every recommendation in `UI_REFRESH_PLAN.md` §1 (D1–D26) on 2026-09-28; the implementation follows them without re-asking.
- **Constitution I mockup waiver**: per-screen HTML mockups are replaced by SwiftUI `#Preview`s and simulator screenshots because the owner is unavailable to review mockups; the pen screens are the approved design. Recorded in `plan.md` Complexity Tracking and DEVLOG 2026-09-28.
- #44/#45 are merged by the owner; the refresh re-implements their hunks so the merge is conflict-free either way. 055 merges into the branch before the Settings step.
