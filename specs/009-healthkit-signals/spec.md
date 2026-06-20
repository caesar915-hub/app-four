# Feature Specification: HealthKit Signals

**Feature Branch**: `feat/healthkit-signals`

**Created**: 2026-06-19

**Status**: Draft

**Input**: User description: "HealthKit signals (sleep, activity, heart, menstrual cycle) — read passively from Apple Health, mirror into a day-keyed store the user can also edit by hand, including when Apple Health has no data." Sourced from `docs/superpowers/specs/2026-06-13-healthkit-signals-design.md` (design) and `docs/superpowers/plans/2026-06-13-healthkit-signals-implementation.md` (TDD plan).

## Clarifications

### Session 2026-06-20

- Q: How many of the four signal groups should this feature ship end-to-end (import + manual + display)? → A: All four (sleep, activity, heart, menstrual cycle) — confirms assumption A8.
- Q: Include the optional check-in→sleep bridge (A2: a check-in note's sleep seeds an empty day)? → A: Exclude from this feature; defer to a later spec.
- Q: Which signals render through the existing 5-step bead visual grammar (A6)? → A: Sleep only; activity, heart, and cycle render as plain values.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record and review a day's health signals by hand (Priority: P1)

A person logging their day wants to capture four health signals — **sleep**, **activity**, **heart**, and **menstrual cycle** — for a given calendar day and see them later, even if they have no Apple Health data or decline to connect it. They open a day, enter the values they know (e.g. hours slept, a sleep-quality rating, steps, resting heart rate, flow + symptoms), save, and see those values when they return to that day.

**Why this priority**: This is the irreducible MVP. The signals have value as a manual daily record on their own; everything else (automatic import, provenance) layers on top. It is also the only slice guaranteed to work for every user regardless of device, Apple Health adoption, or permission choice.

**Independent Test**: With Apple Health never connected, open a day, enter values for all four signal groups, save, reopen the day, and confirm the values persist. Enter values for a second day and confirm the two days are independent.

**Acceptance Scenarios**:

1. **Given** a day with no signals recorded, **When** the user opens that day's signals editor, **Then** all four groups show empty, editable fields.
2. **Given** the user has entered sleep hours and quality for a day, **When** they save and reopen that day, **Then** the entered sleep values are shown.
3. **Given** the user enters values for one calendar day, **When** they open a different calendar day, **Then** the second day shows no values from the first.
4. **Given** a day already has values, **When** the user changes one field and saves, **Then** only that field changes and the others are preserved.

---

### User Story 2 - Automatically fill signals from Apple Health (Priority: P2)

A person who tracks health data in Apple Health wants their daily signals to appear automatically rather than re-typing them. They grant the app read access once; thereafter, opening the app populates recent days' signals from Apple Health, and a manual refresh re-pulls the latest. Days with no Apple Health data simply stay empty and remain manually fillable.

**Why this priority**: This is the headline convenience that makes the feature passive rather than another data-entry chore — but it is only meaningful once the manual record (P1) exists to receive the data. It depends on P1's storage and view.

**Independent Test**: With seeded/available Apple Health data for several days, grant access and confirm those days' signals populate without manual entry; confirm a day with no Apple Health data remains empty; confirm a manual refresh re-runs the import.

**Acceptance Scenarios**:

1. **Given** Apple Health read access has not been requested, **When** the user first reaches the signals feature, **Then** they are shown a plain-language explanation of what is read and that it stays on the device, before the system permission prompt appears.
2. **Given** access is granted and Apple Health has data for recent days, **When** the app opens, **Then** those days' signals are populated from Apple Health without manual entry.
3. **Given** access is granted, **When** the user triggers a manual refresh, **Then** signals are re-read from Apple Health for the recent range.
4. **Given** access is denied, or Apple Health is unavailable, or a day has no data, **When** the user opens that day, **Then** the signals appear empty and fully manually editable, with no error or broken state.
5. **Given** access is granted for the first time, **When** the initial import runs, **Then** the most recent 30 days of available signals are backfilled.

---

### User Story 3 - Trust whose value is shown: manual edits stick, sources are visible (Priority: P3)

A person who both imports from Apple Health and corrects values by hand needs confidence that their hand-entered values are never silently overwritten by a later import, and needs to see, per value, where it came from ("From Apple Health" vs "Added by you"). If they clear a value they previously entered, that signal becomes eligible to be filled from Apple Health again.

**Why this priority**: This is the trust layer. It only applies once both manual entry (P1) and import (P2) coexist and can disagree. Without it the feature still works; with it the feature is safe to rely on.

**Independent Test**: Hand-enter a value for a signal group, then run an import that has different data for that day; confirm the hand-entered value is unchanged and labeled "Added by you." Clear that value, re-run import, and confirm the group now takes the Apple Health value.

**Acceptance Scenarios**:

1. **Given** a signal group was entered by hand, **When** an import brings different values for that day, **Then** the hand-entered values are preserved and still labeled as user-entered.
2. **Given** a signal group was filled from Apple Health, **When** a later import brings updated values, **Then** the group is refreshed to the new Apple Health values.
3. **Given** a value shown in the editor, **When** the user views it, **Then** its source (Apple Health vs entered by the user) is indicated.
4. **Given** a hand-entered value, **When** the user clears it to empty and saves, **Then** that signal group becomes eligible to be filled from Apple Health on the next import.

---

### Edge Cases

- **Apple Health unavailable or denied**: indistinguishable from "no data" by design; both resolve to empty, manually fillable fields — never an error or a blocked screen.
- **Day boundaries / timezone**: a signal must be attributed to the correct local calendar day; instants near midnight and timezone changes must not create duplicate or misattributed days.
- **Duplicate day**: only one record may exist per calendar day; repeated imports or edits for the same day update that single record.
- **Partial data**: a day may have some signal groups present and others absent (e.g. activity but no sleep); absent groups stay empty and fillable.
- **Re-sync**: re-importing a day that was previously Apple-Health-filled refreshes it; re-importing a day with hand-entered groups leaves those groups untouched.
- **Sleep quality not derivable**: when Apple Health data is insufficient to rate sleep quality, sleep imports without a quality rating rather than guessing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST let the user view and edit four health signal groups — sleep, activity, heart, and menstrual cycle — for any chosen calendar day.
- **FR-002**: The system MUST persist each day's signals locally and present them when the user returns to that day, across app launches.
- **FR-003**: The system MUST store at most one record per local calendar day, with each day independent of every other.
- **FR-004**: The system MUST allow manual entry and editing of every signal group regardless of whether Apple Health is connected, available, or has data.
- **FR-005**: The system MUST request read-only access to the four signals from Apple Health, preceded by a plain-language explanation of what is read and that data stays on the device.
- **FR-006**: The system MUST populate days' signals from Apple Health when access is granted and data exists, on app open and on manual refresh.
- **FR-007**: On first grant of access, the system MUST backfill the most recent 30 days of available signals.
- **FR-008**: The system MUST track the provenance of each signal group as one of: not set, sourced from Apple Health, or entered by the user.
- **FR-009**: The system MUST NOT overwrite a signal group the user entered by hand during any subsequent import (user edits are sticky).
- **FR-010**: The system MUST refresh signal groups previously sourced from Apple Health when a later import provides new values for them.
- **FR-011**: The system MUST fill only "not set" or "Apple Health"-sourced groups during import; it MUST mark groups it fills as sourced from Apple Health.
- **FR-012**: When the user clears a hand-entered group to empty, the system MUST reset that group to "not set," making it eligible for Apple Health to fill on the next import.
- **FR-013**: The system MUST indicate, per value in the editor, whether it came from Apple Health or was entered by the user.
- **FR-014**: The system MUST treat denied permission, unavailable Apple Health, and absent data identically — showing empty, editable fields with no error and never blocking core app flows.
- **FR-015**: The system MUST attribute each imported or entered signal to the correct local calendar day across timezone differences.
- **FR-016**: The system MUST keep all health data on the device; it MUST NOT transmit health data off the device. *(Constitution VI — On-Device Privacy, non-negotiable.)*
- **FR-017**: The system MUST NOT write any value back to Apple Health (read + local manual entry only) in this version.

### Key Entities *(include if feature involves data)*

- **Daily Signals**: one record per local calendar day; the source of truth for that day's four signal groups. Holds, per group, the recorded values plus that group's provenance and a last-updated timestamp.
- **Signal group — Sleep**: hours slept and a 5-step sleep-quality rating (restless / light / okay / good / deep), rendered through the app's existing 5-step bead grammar (A6).
- **Signal group — Activity**: steps, active energy, exercise minutes.
- **Signal group — Heart**: resting heart rate, heart-rate variability.
- **Signal group — Menstrual cycle**: flow level (none / light / medium / heavy / spotting) and a small set of symptom tags.
- **Signal source (provenance)**: per group — not set, Apple Health, or user-entered — the value that drives the "manual-wins" rule.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user with no Apple Health connection can record all four signal groups for a day and see them persist across an app restart — 100% of entered values retained.
- **SC-002**: A user who grants access sees recent days populated from Apple Health on app open with zero manual entry for any day Apple Health has data.
- **SC-003**: After granting access for the first time, the user sees up to 30 prior days of available signals without any manual action.
- **SC-004**: In 100% of cases, a value a user entered by hand is still present and shown as user-entered after a subsequent import that had different data for that day.
- **SC-005**: With Apple Health denied or unavailable, the user reaches a fully usable manual editor with no error state — measured as zero error or empty-blocking screens across all four groups.
- **SC-006**: Every value displayed in the editor shows a source indication (Apple Health vs user-entered), verifiable for all four groups.
- **SC-007**: No health data leaves the device — verifiable by the absence of any outbound transmission of health values.

## Assumptions

These were decided in the design phase. The three scope-significant items were confirmed in the 2026-06-20 clarification session above; the rest are reasonable defaults that can still be vetoed before `/speckit-plan`.

- **Dependency / scope**: HealthKit is now in active scope — `docs/SPECKIT.md` was updated 2026-06-20 to move HealthKit from "Out of scope" to "In scope (active)" referencing this spec. *(Resolved.)*
- **A1**: Provenance is tracked per signal *group* (four sources: sleep, activity, heart, cycle), not per individual scalar field. Easy to split later if a field needs independent provenance.
- **A2**: ~~Optional check-in→sleep bridge~~ — **excluded from this feature** *(clarified 2026-06-20)*. A check-in note's sleep does not seed Daily Signals here; deferred to a later spec. Today's manual sleep entry instead moves into the new signals editor (FR-004).
- **A3**: Sleep quality is derived from a heuristic over Apple Health sleep data; when it cannot be computed, sleep imports without a quality rating rather than guessing.
- **A4**: First-grant backfill window is the most recent 30 days.
- **A5**: Clearing a user-entered field to empty resets that group to "not set," re-enabling Apple Health fill on the next import.
- **A6**: Only sleep renders through the app's existing 5-step signal visual grammar; activity, heart, and cycle render as plain values/labels. *(Confirmed 2026-06-20.)*
- **A7**: No write-back to Apple Health in this version (read + local manual entry only).
- **A8**: All four signal groups (sleep, activity, heart, menstrual cycle) are built end-to-end (import + manual + minimal display) in this version, rather than shipping a subset first. *(Confirmed 2026-06-20.)*
- Import is read-on-open + manual refresh only; background/automatic delivery is explicitly out of scope (named follow-up).
- The check-in→sleep bridge (former A2) is out of scope here; deferred to a later spec.
- No new trend/correlation analytics ship here; wiring signals into Insights is a separate, later feature.
