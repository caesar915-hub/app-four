# Feature Specification: Calendar / Check-in / Settings — device QA round

**Feature Branch**: `024-calendar-checkin-settings-qa`

**Created**: 2026-06-26

**Status**: Draft

**Input**: Owner's narrated on-device QA recording (`RPReplay_Final1782493673.MP4`, 2:50),
transcribed (whisper.cpp) and lined up to the screen. A round of cross-view fixes:
Calendar (stop fading days, drop the Today button, drop the entries caption), Check-in
(the crescent jumps down when recording starts — anchor it), Settings (remove the
recognize-medication toggle, add an always-expand-cards setting, remove the crashing
feedback button). Independent of the DayCard redesign on `feat/daycard-v8`.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Starting a check-in doesn't make the screen jump (Priority: P1)

When I tap to start recording a check-in, the crescent (and the controls around it)
should stay put and the crescent should simply grow in place. Today the crescent and
everything around it slide **down** when recording starts, which reads as broken /
inconsistent.

**Why this priority**: It's the most visible defect in the core capture loop — the
thing used every day — and it undermines the "calm, in-place" feel the app is built on.

**Independent Test**: On the Check-in tab, note the crescent's on-screen center while
idle, tap to record, and confirm the crescent's center does not move (it only enlarges)
and no surrounding control reflows downward.

**Acceptance Scenarios**:

1. **Given** the idle Check-in hub, **When** I tap to start recording, **Then** the
   crescent enlarges centered on its existing position — its center does not shift.
2. **Given** the recording state, **When** it renders, **Then** the timer, "Stop &
   save", and "Cancel" appear in/around the crescent without moving the crescent's
   center, and returning to idle restores the same position.
3. **Given** the idle hub, **Then** it still offers the primary speak action plus the
   "Log med" and "Type note" secondaries.

### User Story 2 — The feedback button no longer crashes the app (Priority: P1)

The floating feedback button crashes the app when used. It must be gone from the UI.

**Why this priority**: A control that crashes a shipping build is a real risk, not
cosmetic.

**Independent Test**: Navigate every tab; confirm no feedback button is present and the
crash path through it is unreachable.

**Acceptance Scenarios**:

1. **Given** any screen, **When** it renders, **Then** there is no feedback button.
2. **Given** the codebase, **Then** the feedback implementation files remain (removed
   from the UI only, not deleted) so the capability can be reinstated later.

### User Story 3 — A calmer calendar (Priority: P2)

Browsing the calendar shouldn't dim days, push a "Today" button, or show an entries
caption — just the days and their cards.

**Why this priority**: Visual-noise reduction; not a blocker but the owner called each
out explicitly.

**Independent Test**: Open the calendar, select past and future days, and confirm no
day dims, no Today button appears, and no entries caption shows.

**Acceptance Scenarios**:

1. **Given** the week/month strip, **When** any day is selected, **Then** no day
   renders faded/dimmed (no past/future or relative-to-selection de-emphasis).
2. **Given** the calendar header, **Then** there is no "Today" button/pill.
3. **Given** a day is selected, **Then** no "entries" caption/count is shown.

### User Story 4 — Settings reflects real choices (Priority: P2)

Remove the recognize-medication toggle (it's effectively always on), and add a setting
that keeps every day card expanded; keep auto-expand-selected-day.

**Why this priority**: Removes a confusing/no-op control and adds a requested
preference.

**Independent Test**: Open Settings; confirm "Recognize medication names" is gone,
"Auto-expand selected day" remains, and a new "Always expand cards" toggle drives the
calendar.

**Acceptance Scenarios**:

1. **Given** Settings, **Then** there is no "Recognize medication names" toggle, and
   medication recognition still runs in extraction (always on).
2. **Given** Settings, **Then** a new "Always expand cards" toggle exists; **When** on,
   **Then** every day card in the calendar renders expanded.
3. **Given** Settings, **Then** "Auto-expand selected day" remains.

### Edge Cases

- **Reduce Motion**: the crescent's grow-in-place still works (no/limited motion).
- **Always expand ON + Auto-expand selected day**: their interaction/precedence must be
  defined (see clarification).
- **Removing day-fade vs greyscale safety**: future/unavailable days currently use
  opacity *plus* a dropped marker dot as a non-colour cue; removing the fade must not
  remove the only remaining distinction if one is still needed.
- **Empty day with Always-expand ON**: an empty day "expanded" shows its calm
  no-check-ins copy (no empty rows).

## Requirements *(mandatory)*

### Functional Requirements

**Calendar**
- **FR-001**: All calendar days MUST render at full opacity — remove the past/future
  (and relative-to-selected) de-emphasis.
- **FR-002**: The calendar header MUST NOT show a "Today" button/pill.
- **FR-003**: The "Entries up to <day>" filter caption (shown when a past day is
  selected) MUST be removed entirely. *(Confirmed by owner: this is the "entries"
  element; there is no per-day count.)*

**Check-in**
- **FR-004**: Transitioning idle → recording MUST keep the crescent's on-screen center
  fixed; the crescent enlarges in place rather than moving down, and surrounding
  controls do not reflow downward.
- **FR-005**: The recording controls (elapsed timer, Stop & save, Cancel) MUST render
  within/around the crescent at the anchored position.
- **FR-006**: The idle hub MUST keep the primary speak action plus "Log med" and "Type
  note".

**Settings**
- **FR-007**: The "Recognize medication names" toggle MUST be removed; medication
  recognition MUST remain always-on in extraction.
- **FR-008**: A new "Always expand cards" setting MUST exist; when enabled, every day
  card in the calendar renders expanded.
- **FR-009**: The "Auto-expand selected day" setting MUST remain.
- **FR-010**: The feedback button MUST be removed from all UI; its implementation files
  MUST be retained (not deleted).

**Quality**
- **FR-011**: Removing the day-fade MUST preserve a non-colour cue for any day state
  that still needs distinguishing (greyscale/colourblind-safe), or confirm none is
  needed.

### Key Entities *(include if feature involves data)*

- **Settings flags**: `medicalPromptEnabled` (UI removed; behaviour pinned on),
  `autoExpandOnSelection` (kept), and a NEW `alwaysExpandCards` (`@AppStorage`).
- **Check-in state**: idle vs recording crescent (currently different sizes *and*
  positions — `Metrics.CheckIn.idleCrescent` 200 / `recordingCrescent` 260).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: No calendar day renders below full opacity in any selection state.
- **SC-002**: No "Today" button exists anywhere in the calendar.
- **SC-003**: No "entries" caption/count renders.
- **SC-004**: Tapping record does not change the crescent's on-screen center (0px shift).
- **SC-005**: No feedback button is reachable; the prior crash path is gone; feedback
  source files still present.
- **SC-006**: The recognize-medication toggle is absent; extraction still recognises
  medications.
- **SC-007**: The "Always expand cards" toggle is present and, when on, expands all day
  cards.
- **SC-008**: Full test suite stays green; the new always-expand flag behaviour and any
  touched logic are covered test-first (Principle X). Views verified by the owner on
  device (no simulator in this workflow).

## Assumptions & Clarifications

- **[RESOLVED — entries]** Owner confirmed: FR-003 removes the single
  `"Entries up to <selected day>"` filter caption; there is no per-day count.
- **[RESOLVED — expand precedence]** When "Always expand cards" is ON, it overrides:
  every card opens and the selected-day auto-expand is moot (the simpler model).
- **[RESOLVED — crescent anchor]** The crescent is anchored at its **idle** centre;
  recording grows around that point (idle is the canonical position).
- Medication recognition default is already `true`; FR-007 removes the control and pins
  the behaviour on (does not change extraction logic — Principle VII untouched).
- The feedback feature is the DebugBridge issue-report flow; "keep code" = leave the
  `Views/Feedback/*` files, remove only its mounting in the UI.
- This feature is **independent of the DayCard redesign** (`feat/daycard-v8`); it does
  not modify the redesigned card body/header.
- Out of scope: the Check-in capture pipeline, transcription/extraction behaviour, the
  Insights tab, and the DayCard redesign itself.
