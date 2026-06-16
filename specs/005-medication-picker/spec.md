# Feature Specification: Medication Picker for Dose Logging

**Feature Branch**: `005-medication-picker`

**Created**: 2026-06-15

**Status**: Draft

**Input**: User description: "Replace the free-text Log Dose sheet with a medication picker sourced from a curated catalog plus the user's own history; selecting a med fills dose options, shows onset (info), prefills an editable duration, defaults taken time to now, and still allows typing a brand-new medication."

**Source feedback**: Screen recording 3 (`RPReplay_Final1781545396.MP4`) — see `docs/superpowers/2026-06-15-screen-recording-feedback-plan.md` §3.1. The curated catalog originates from the owner's research chat (distilled EU ADHD-stimulant table: medication · dose options · onset · duration).

## Clarifications

### Session 2026-06-15

- Q: For a user-added medication with no catalog metadata, what onset/duration applies? → A: Omit onset (no source data) and prefill the effect duration with a standard fallback value that the user can override.
- Q: How are history-derived medication names de-duplicated for display? → A: Normalize case-insensitively on the base medication name (ignoring trailing dose text); a history medication matching a catalog medication folds into the catalog entry rather than appearing twice.
- Q: Are taken-times in the future allowed? → A: No. The taken-time selector is capped at the current time; earlier times are allowed.

### Session 2026-06-16

- Q: How many catalog medications for the beta? → A: Three — **Concerta, Ritalin, Elvanse** (the meds the first testers take). The catalog type is structured so the fuller EU list can be added later without redesign. The full feature behaviour (history, dedup, onset, editable duration, add-new) is unchanged — only the catalog size is scoped.
- Q: Relationship to the medication chips already shipped in the Edit sheet (`ExtractionReviewView`, via `fix/med-crash-mvp` on `main`)? → A: That shipped picker is the *Edit-check-in* medications section (3 chips, name + free dose, no onset/duration). THIS feature targets the *Log-Dose sheet* (the medication bar's "Log new dose"). It MUST stay consistent with the shipped chip pattern (FR-012) and SHOULD share a control where practical, but adds dose-options, read-only onset, and an editable duration the Edit-sheet chips don't yet have.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log a known medication without typing (Priority: P1)

A person logging a dose opens the dose-logging sheet and sees the medications they can pick from — both a built-in list of common ADHD stimulants and any medication they have logged before. They tap their medication, pick a dose from the options shown for it, and save. The taken time is already set to now. No keyboard is required for the common case.

**Why this priority**: This is the core of the complaint — today the user must type the medication name every time. Selection-first logging is the minimum that makes the feature worth shipping; everything else refines it.

**Independent Test**: With at least one medication available, open the sheet, select a medication, select a dose, and save. A dose is recorded with that name, dose, and the current time. Fully delivers "log a dose without typing."

**Acceptance Scenarios**:

1. **Given** the dose-logging sheet is open and the catalog is available, **When** the user selects a medication, **Then** that medication's dose options are presented for selection.
2. **Given** a medication and a dose are selected, **When** the user saves, **Then** a dose is recorded with that name, that dose, and the current time, and it appears in the medication bar and the day's timeline.
3. **Given** no medication has been selected or typed, **When** the user looks at the save control, **Then** saving is unavailable until a medication is identified.

---

### User Story 2 - See onset and effect duration, and adjust duration (Priority: P2)

When the user selects a medication, the sheet shows that medication's onset time as information, and prefills the expected effect duration. The user can accept the prefilled duration or override it with a custom value, so the dose's tracked effect window reflects reality for them.

**Why this priority**: The medication bar's "ends" time and the timeline effect window are only meaningful if duration is per-medication rather than a fixed default. Onset is informational context the owner explicitly asked to surface. Valuable, but the feature is still usable without it (US1).

**Independent Test**: Select a catalog medication; confirm onset is displayed read-only and a duration is prefilled; change the duration; save; confirm the recorded dose's effect window uses the chosen duration (the medication bar's end time matches).

**Acceptance Scenarios**:

1. **Given** a catalog medication is selected, **When** the selection completes, **Then** its onset time is shown as read-only information and its effect duration is prefilled into an editable field.
2. **Given** a prefilled duration, **When** the user overrides it with a custom duration and saves, **Then** the recorded dose uses the custom duration for its effect window.
3. **Given** a medication is selected with its prefilled duration unchanged, **When** the user saves, **Then** the recorded dose uses the catalog duration (not a generic fixed default).

---

### User Story 3 - Add a medication that isn't listed (Priority: P3)

If the medication the user takes isn't in the list, they can type a new name (and optionally a dose) and log it. That medication then becomes selectable the next time they log a dose, so they only type it once.

**Why this priority**: Preserves the only capability the old free-text sheet had, and makes the picker complete. Lower priority because the curated catalog already covers the common cases.

**Independent Test**: Type a medication name not present in the list, save, reopen the sheet, and confirm the typed medication is now selectable.

**Acceptance Scenarios**:

1. **Given** the desired medication is not in the list, **When** the user types a new name and saves, **Then** a dose is recorded under that name.
2. **Given** a medication was logged by typing a new name, **When** the user next opens the dose-logging sheet, **Then** that medication appears among the selectable options.

---

### Edge Cases

- **No history yet**: With no previously logged medications, only the built-in catalog is shown; the sheet is still usable.
- **Custom dose**: The user needs a dose amount not among a medication's listed options — they MUST be able to enter a custom dose.
- **User-added medication has no catalog metadata**: A typed-in medication has no onset and no catalog duration. Resolved (FR-013): onset is omitted and a standard fallback duration is prefilled and editable.
- **Name normalization**: "Concerta", "Concerta XL", and "concerta 36mg" should not appear as separate pickable entries from history. Resolved (FR-014): de-duplicated case-insensitively on the base name, ignoring trailing dose text.
- **Switching selection**: The user selects one medication, then another — dose and duration MUST reset to the newly selected medication's values rather than retaining the previous one's.
- **Taken time**: Defaults to now; the user may set it earlier (e.g., logging a dose taken hours ago). Resolved (FR-006): future taken times are not allowed — the selector is capped at now.
- **Accessibility text sizes**: Long medication names and the dose options must remain legible and selectable at large Dynamic Type sizes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dose-logging experience MUST present selectable medications drawn from (a) a built-in curated catalog and (b) medications the user has previously logged.
- **FR-002**: The built-in catalog MUST include these medications with their dose options, onset, and effect duration (beta subset — see Clarifications 2026-06-16; the catalog type is structured to extend to the fuller EU list later):
  - **Concerta** (Concerta XL) — doses 18/27/36/54 mg — onset 60 min — duration 12 h
  - **Ritalin** (methylphenidate IR) — doses 5/10/20 mg — onset 20 min — duration 3 h
  - **Elvanse** (lisdexamfetamine) — doses 20/30/40/50/60/70 mg — onset 90 min — duration 10 h
- **FR-003**: Selecting a medication MUST present that medication's dose options for quick selection, while still allowing a custom dose to be entered.
- **FR-004**: Selecting a catalog medication MUST display its onset time as read-only information.
- **FR-005**: Selecting a catalog medication MUST prefill its effect duration, and the user MUST be able to override that duration with a custom value before saving.
- **FR-006**: The taken time MUST default to the current time and remain user-editable, but MUST NOT be settable to a time in the future (the selector is capped at now; earlier times are allowed).
- **FR-007**: Users MUST be able to enter a medication name not present in the list (with an optional dose) and log it.
- **FR-008**: A medication first entered as free text MUST become selectable for subsequent dose logging.
- **FR-009**: Saving a dose MUST record at minimum the medication name, dose, taken time, and effect duration.
- **FR-010**: A saved dose's effect window MUST be derived from the chosen/overridden duration, not a fixed global default.
- **FR-011**: Saving MUST be unavailable until a medication is identified (selected from the list or typed).
- **FR-012**: The dose-logging experience MUST be consistent wherever a dose is logged (from the medication bar and from a check-in), presenting the same selection, dose, onset, duration, and taken-time behavior.
- **FR-013**: When a medication is entered as free text (absent from the catalog), the experience MUST omit onset (no source data) and prefill the effect duration with a standard fallback value the user can override.
- **FR-014**: Medications drawn from history MUST be de-duplicated for display by normalized base name (case-insensitive, ignoring trailing dose text); a history medication matching a catalog medication MUST fold into the catalog entry rather than appear twice.

### Key Entities *(include if feature involves data)*

- **Medication (catalog entry)**: a known medication the user can pick. Attributes: display name, set of dose options, onset time, default effect duration. Read-only reference data in v1.
- **Logged dose**: a record that a dose was taken. Attributes: medication name, dose amount, taken time, effect duration (for the active-effect window), origin (manually logged). Relates to the medication it was logged for and, when logged inside a check-in, to that check-in entry.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can log a medication that exists in the catalog or their history using selection only (no keyboard) in 3 interactions or fewer after opening the sheet (select medication → select dose → save).
- **SC-002**: For every logged dose, the effect-window end time reflects the medication's chosen duration; the previously observed fixed-duration mismatch occurs in 0% of logged doses.
- **SC-003**: Onset and effect duration are visible before saving for 100% of catalog medications.
- **SC-004**: A medication added via free text is selectable on the next dose-logging without restarting the app.
- **SC-005**: Typing is required only when adding a medication absent from both the catalog and the user's history.

## Assumptions

- The curated catalog (the **three** EU stimulants above — Concerta/Ritalin/Elvanse, the beta-tester subset) is acceptable seed reference data and is not user-editable beyond adding new medications via free text (which persist through logging history). The catalog type is extensible to the fuller EU list without a redesign.
- **"Interval" (dosing frequency) is out of scope for v1.** It appeared in earlier research but the owner dropped it from the final distilled list; it can be reinstated via a later spec.
- Catalog values are taken from the owner's curated table recorded in `docs/superpowers/2026-06-15-screen-recording-feedback-plan.md` §3.1.
- Reference data being static (not a persisted, migratable store) keeps the change within the project's pre-release data posture (Constitution IX: CloudKit-compatible schema, no new required/unique attributes). If a persisted catalog is later required, it must be justified in the plan's Complexity Tracking.
- Per Constitution I, an HTML mockup of the revised dose-logging sheet precedes implementation; that mockup is design-phase work (superpowers), not part of this spec.
- This spec defines what & why only. Component/view/data-model choices are deferred to `/speckit-plan`, which runs the Constitution **I–X** gate (v1.2.0; Principle X = test-first for the catalog/logic; the SwiftUI sheet is view-layer, verified by build + simulator run).
