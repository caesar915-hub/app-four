<!-- Created: 2026-07-03 14:21 (WEST) · Updated: 2026-07-03 17:03 (WEST) -->
# Feature Specification: Calendar Day Context — "The Day, Remembered" (Phase 1)

**Feature Branch**: `029-calendar-day-context`

**Created**: 2026-07-03

**Status**: Draft

**Input**: User description: "Calendar integration Phase 1 — EventKit foundation + day context (memory prosthesis). Approved design: docs/superpowers/specs/2026-07-03-calendar-integration-design.md. Fully on-device; degrade silently if permission denied; snapshots ride the encrypted export; Insights correlations, med-coverage overlay, and check-in markers are later phases. Post-v1.0 (v1.1+)."

> **Design authority**: [2026-07-03-calendar-integration-design.md](../../docs/superpowers/specs/2026-07-03-calendar-integration-design.md) holds the owner-approved decisions (direction, write scope, context-first arc, snapshot-vs-live-query). Decisions added during specification (2026-07-03): **historical backfill on grant**, **title-capture choice presented before grant**, **purge + explicit re-capture actions**, **latest-capture-wins re-capture rule**.

## Clarifications

### Session 2026-07-03

- Q: Context-line composition — plain titles + overflow, or classified summary? (wireframe: [mockups/context-line-variants.html](mockups/context-line-variants.html)) → A: **B — classified summary.** Events with invited attendees fold into "N meetings"; other events keep their title ("3 meetings · Dentist · Mum's birthday"). Classification is deterministic from facts on the local event (attendee count, busy/free availability) — never inferred from titles, never using attendee identities. Capture therefore also records attendee count + availability per event. Per-event include/exclude is out of scope for Phase 1; relevance is controlled per calendar (FR-008).
- Q: Where does the full event list render (expanded day card · interleaved timeline · sheet)? → A: **Deferred — no full-list UI in Phase 1.** The owner has not chosen a surface; capture stores the complete event set so any future detail surface can render without re-capture, but the only Phase-1 UI is the day-card context line. The surface choice returns as its own mockup-first decision later.
- Q: Do days with only a logged med dose (no check-in) get day context? → A: **No — check-in days only.** A standalone dose log does not trigger capture; med-context pairing belongs to Phase 3 of the design arc.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Remember what a day held (Priority: P1)

Months after the fact, an ADHD user reviewing a past check-in cannot reconstruct what that day actually contained — episodic memory is exactly what ADHD makes unreliable. With calendar access granted, every day card in the journal quietly carries the day's outer shape: a one-line classified summary of what was on the calendar ("3 meetings · Dentist · Mum's birthday"). New check-ins capture their day's events at save time; on grant, the journal's existing check-in days are backfilled, so the whole history lights up immediately. The full event set is captured and retained (ready for a future detail surface), but Phase 1 renders only the summary line.

**Why this priority**: This is the feature's core value — the memory prosthesis. Everything else (permission flow, settings) exists to serve this. It is also the foundation the later phases (correlations, med overlay) build on.

**Independent Test**: Grant calendar access on a device with calendar events and an existing journal; verify past check-in days show their day context; make a new check-in and verify today's context appears; remove a calendar account and verify previously captured context is still shown.

**Acceptance Scenarios**:

1. **Given** calendar access is granted and today has 3 events on included calendars, **When** the user saves a check-in, **Then** the full calendar day's events (title, start/end time, all-day flag, attendee count, busy/free availability) are captured for that day and the day card shows the context line.
2. **Given** access was just granted and the journal has prior check-in days, **When** the backfill completes, **Then** each past check-in day shows the day context recorded in the device calendar for that date.
3. **Given** a captured day holding 3 events with invitees and 2 without, **When** the day card renders, **Then** the line reads "3 meetings" followed by the two events' titles; the complete event set (times, all-day flags, classification facts) remains in the captured context even though only the summary renders.
4. **Given** a day's final capture has occurred, **When** the user later edits or deletes those calendar events, or removes the calendar account entirely, **Then** the journal still shows the context as it was captured — the day as lived.
5. **Given** a day whose calendar had no events, **When** the user views that day card, **Then** no context line is shown (no "no events" placeholder, no visual noise).
6. **Given** a day with an existing captured context, **When** another check-in is saved on that day, **Then** the day is re-captured under the settings in force at that moment and the latest capture replaces the previous one — the day still presents exactly one context.
7. **Given** the user saves a check-in dated to a past day, **When** the save completes, **Then** context is captured for that past day (the check-in's assigned journal day), not for the day the save happened.

---

### User Story 2 - Grant or decline access on my own terms (Priority: P2)

The feature offers itself in exactly two places: a permanent Calendar row in Settings, and a single dismissible invitation shown once on the Calendar tab after the feature becomes available. Choosing either leads to a short explainer that states what Squirl reads, that nothing leaves the device, what the user gets — and lets the user decide, before anything is captured, whether event titles are included or only the shape of the day. Only after the user proceeds does the system permission prompt appear. Declining at any step is a first-class outcome: the app behaves exactly as before, with no nagging and no repeated prompts.

**Why this priority**: Without a trustworthy grant flow there is no feature — and for this audience and this app's privacy posture, a clumsy permission ask damages more than this one feature.

**Independent Test**: On a fresh install, verify the one-time Calendar-tab invitation and the Settings row both lead to the explainer and that the explainer precedes the system prompt; dismiss the invitation and verify it never reappears; decline and verify zero behavioral change and zero re-prompts; grant later from Settings and verify the feature activates (including backfill honoring the title choice made in the explainer).

**Acceptance Scenarios**:

1. **Given** the user has never engaged with the feature, **When** they visit the Calendar tab after the feature becomes available, **Then** a single dismissible invitation is shown once; dismissing it removes it permanently, and the Settings Calendar row remains the way in.
2. **Given** the user opens the explainer (from the invitation or Settings), **Then** it describes what is read, the on-device promise, and the benefit, and offers the title-capture choice (titles included by default) — all before any system permission prompt.
3. **Given** the explainer is shown, **When** the user chooses not to proceed, **Then** no system prompt appears and the app does not raise the topic again unprompted; the Settings row still allows starting over later.
4. **Given** the user denied the system prompt, **When** they use the app afterwards, **Then** no calendar affordances appear outside Settings, no errors are shown, and no re-prompt occurs; the Settings Calendar section shows the state and points to system settings as the way to change it.
5. **Given** access was revoked in system settings after a period of use, **When** the user views past days, **Then** previously captured context is still shown; check-ins made while revoked capture nothing at save time.
6. **Given** access is re-granted after a revoked period, **When** the app next runs capture, **Then** check-in days that lack context (including those from the revoked gap) are backfilled.

---

### User Story 3 - Control what Squirl sees (Priority: P3)

In Settings, a Calendar section shows the current access state and lets the user choose which calendars feed day context — system-designated birthday and holiday calendars are excluded by default, and events the user declined never count. The title-capture toggle (first offered in the explainer) can be changed at any time. Because history may have been captured under earlier settings, the user holds two explicit levers: re-capture history under the current settings, and remove all captured calendar context outright.

**Why this priority**: Control is what makes the capture acceptable — but it only matters once capture (US1) and grant (US2) exist.

**Independent Test**: With access granted, exclude a calendar in Settings and verify its events stop appearing in newly captured context; turn title capture off and verify new context records counts/times only; run "re-capture history" and verify old context now honors both changes; run "remove captured calendar context" and verify all context disappears.

**Acceptance Scenarios**:

1. **Given** access is granted, **When** the user opens the Settings Calendar section, **Then** they see the access state, a per-calendar include/exclude list, the title-capture toggle, and the re-capture and remove actions.
2. **Given** a calendar is excluded, **When** context is next captured (at save or backfill), **Then** that calendar's events are absent from the captured context.
3. **Given** title capture is off, **When** context is captured, **Then** no event titles are stored; day cards show a classified count-only line (e.g. "3 meetings · 2 events").
4. **Given** events the user declined exist on an included calendar, **When** context is captured, **Then** declined events are not included.
5. **Given** the user changes included calendars or the title toggle, **When** they view previously captured days, **Then** previously captured context is unchanged — settings apply to future captures, unless the user explicitly runs re-capture.
6. **Given** captured context exists, **When** the user runs "re-capture history with current settings", **Then** all check-in days are re-captured under the settings now in force.
7. **Given** captured context exists, **When** the user runs "remove captured calendar context", **Then** all captured day context is deleted from the journal (and from future exports).

---

### Edge Cases

- **All-day events and long events**: all-day events and timed events lasting 24 hours or more appear in the context of each day they cover; timed events shorter than 24 hours are attributed solely to the day they start.
- **Day attribution and time zones**: an event's day is determined using the device's current time zone at the moment of capture; captured context is not recomputed when the device's time zone later changes.
- **Crowded days** (10+ events): the day-card line truncates gracefully (meeting count + first named events + overflow); the complete set stays captured (no detail surface in Phase 1).
- **Med-only days**: a day with a logged dose but no check-in is not a capture target — no context is captured or shown for it (Clarifications, Q3).
- **Backfill scale and resilience**: a journal with hundreds of check-in days must backfill without blocking the UI or degrading capture. Capture is idempotent coverage: whenever access allows, any check-in day lacking context is captured — so interrupted backfills, failed save-time captures, and revoke→re-grant gaps all self-heal without user action.
- **Deleting check-ins**: deleting a day's last check-in deletes that day's captured context with it; days with remaining check-ins keep their context.
- **Permission "limited"/partial access states**: treated the same as granted for whatever the system exposes; never prompts the user to upgrade access; the Settings section shows the actual state.
- **No calendars on device / all calendars excluded**: capture yields nothing; no error, no empty-state noise.
- **Bounded calendar history**: some account types sync only a limited window of past events to the device; backfill can only capture what the device store holds — older days simply show nothing (indistinguishable from empty days, by design).
- **Mock data mode**: mock recordings carry fixed fixture day context so the feature is visible and testable in mock mode; the user's real calendar is never read while in mock mode.
- **Encrypted export**: captured day context (including titles, when enabled) is part of the journal and rides the export; the privacy/export copy must disclose this.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The feature MUST be reachable from exactly two surfaces: a permanent Settings Calendar section, and a one-time dismissible invitation on the Calendar tab (dismissal is permanent). Both lead to a plain-language explainer (what is read, on-device promise, user benefit) that includes the title-capture choice (default: titles included) and MUST precede any system calendar permission prompt. The app MUST NOT request calendar access at launch.
- **FR-002**: With access granted, saving a check-in MUST capture the events of the check-in's assigned journal day — the full calendar day, using the device's current time zone — recording per event: title (subject to FR-007), start/end, all-day flag, attendee count, and busy/free availability, from included calendars only. Attendee identities (names, emails), locations, notes, and every other event field MUST NOT be captured. Backdated check-ins capture their assigned past day.
- **FR-003**: Capture MUST be idempotent coverage: whenever access is available, any check-in day lacking captured context MUST be captured without blocking interactive use — this single rule provides the initial backfill on grant, repair after failed captures, and fill-in after access is re-granted.
- **FR-004**: A day's captured context MUST be durable from its latest capture onward: unaffected by later calendar edits, event deletions, calendar-account removal, or permission revocation.
- **FR-005**: Day cards MUST show a one-line context summary for days that have captured events; days with no captured events show nothing extra. The summary is a classified line: events with invited attendees group as "N meetings"; remaining events are named by title ("3 meetings · Dentist · Mum's birthday"). Classification is deterministic (attendee presence), never inferred from titles. The context line is the ONLY Phase-1 display surface — no full-list UI ships in this phase, but captured context MUST retain the complete event set so a future detail surface can render it without re-capture.
- **FR-006**: A day MUST present exactly one coherent context. Each check-in save on a day re-captures the whole day under the settings in force at that moment; the latest capture replaces prior ones.
- **FR-007**: A title-capture setting (offered first in the explainer, changeable in Settings) MUST allow the user to exclude event titles from capture; when off, captured context holds counts, times, all-day flags, and classification facts (attendee count, availability) only — day cards then show classified counts without names (e.g. "3 meetings · 2 events").
- **FR-008**: The Settings Calendar section MUST show the current access state and provide a per-calendar include/exclude list. Calendars the operating system designates as birthday or holiday calendars MUST default to excluded; all other calendars default to included. Events the user has declined MUST never be captured.
- **FR-009**: Settings changes (calendar inclusion, title toggle) MUST apply to future captures only; previously captured context changes only through the day's own re-capture on a new check-in save (FR-006) or the user's explicit re-capture action (FR-013).
- **FR-010**: If access is denied, revoked, or the user declined the explainer, the app MUST degrade silently: no calendar affordances outside Settings, no errors, no re-prompting; the Settings Calendar section MUST reflect the state and direct the user to system settings where applicable. Previously captured context remains visible per FR-004.
- **FR-011**: Calendar data MUST never leave the device except inside the user's own encrypted journal export; the export/privacy copy MUST disclose that captured day context is included.
- **FR-012**: Capture MUST NOT add perceptible delay to the check-in save flow or alter the capture experience.
- **FR-013**: The Settings Calendar section MUST provide two explicit data actions: **re-capture history with current settings** (re-captures all check-in days) and **remove captured calendar context** (deletes all captured day context).
- **FR-014**: Deleting a day's last check-in MUST delete that day's captured context.

### Key Entities

- **Day Context**: the durable record of one day's calendar events as captured for the journal — a set of items each holding a title (optional per FR-007), start/end, all-day flag, attendee count, and busy/free availability (never attendee identities); keyed to a journal day; exactly one per day, replaced whole on re-capture (FR-006).
- **Calendar Inclusion Preference**: the user's per-calendar include/exclude choices plus the title-capture toggle; defaults exclude system-designated birthday/holiday calendars.
- **Calendar Access State**: not requested · invitation dismissed / explainer declined (system never asked) · granted · denied/revoked (plus any partial state the system exposes) — drives which UI surfaces appear and whether capture runs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For any past check-in day whose events are present in the device calendar store at capture time, the user can see what their calendar held that day without leaving the journal — the summary visible on the day card with zero extra taps.
- **SC-002**: Check-in capture feel is unchanged: saving a check-in with context capture active introduces no new UI state and no added visible wait in the save flow (verified by device QA).
- **SC-003**: Zero calendar data leaves the device: no network transmission of calendar-derived data in any code path (verifiable by audit).
- **SC-004**: Declining costs nothing: a user who dismisses the invitation, declines the explainer, or denies the system prompt retains 100% of existing functionality and receives zero unprompted re-asks thereafter.
- **SC-005**: Context durability is total: after removing a calendar account or revoking access, 100% of previously captured day context remains visible.
- **SC-006**: Control is reachable: excluding a calendar, toggling title capture, re-capturing history, or removing all captured context each takes ≤ 3 interactions from opening Settings.
- **SC-007**: Backfill delivers promptly: for a journal on the order of 300 check-in days, backfill completes within 5 minutes of grant without the user doing anything further.

## Assumptions

- **Roadmap**: post-v1.0 work (v1.1+), not tied to a dated milestone; branch/PR per the repo's normal flow when implementation starts.
- **Scope boundary**: the sole display surface is the day-card context line; the full-event-list UI is deferred (surface undecided — see Clarifications) though its data is captured. Insights correlations, the med-coverage-vs-today overlay, and writing check-in markers to the calendar are later phases of the approved design and explicitly out of scope here.
- **Snapshot storage shape** (per-check-in vs day-keyed record) is an implementation decision for the plan; the spec constrains behavior only (FR-004, FR-006).
- **No paywall interaction**: monetization is not implemented in the app; no premium gating is specified for this feature. Revisit if/when a paywall spec exists.
- **Context-line format** (truncation rules, ordering of named events after the "N meetings" group) and the exact invitation/explainer copy will be settled in the HTML mockup (per Constitution Principle I) before implementation; the classified composition itself is decided (Clarifications, FR-005) — see [mockups/context-line-variants.html](mockups/context-line-variants.html), variant B.
- **Per-event relevance**: there is no per-event include/exclude in Phase 1 — relevance is controlled per calendar (FR-008). Per-event curation would need exclusions that survive re-capture (FR-006) and is deferred until proven needed.
- **Language**: event titles render as-is from the user's calendar; surrounding copy is English, consistent with the app.
- **Backfill window**: capture covers existing check-in days (the journal's own span), not arbitrary calendar history.
- **Day attribution** follows the app's existing convention: journal days are derived from the device's current calendar/time zone.
