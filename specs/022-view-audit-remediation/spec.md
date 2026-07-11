# Feature Specification: View-Layer Audit Remediation

**Feature Branch**: `022-view-audit-remediation`

**Created**: 2026-06-25

**Status**: Draft

**Input**: Remediate ALL confirmed findings from the 2026-06-25 view-layer audit ([docs/audits/2026-06-25-views-audit.md](../../docs/audits/2026-06-25-views-audit.md), static architecture + code quality, 55 verified findings) and the iOS design review ([docs/audits/2026-06-25-ios-design-review.md](../../docs/audits/2026-06-25-ios-design-review.md), visual). This is remediation/hardening — no new product features.

> **Scope reference.** The two audit reports above are the authoritative, verification-passed inventory of in-scope findings. This spec frames them as user-and-maintainer outcomes; the file-/symbol-level checklist belongs in `/speckit-plan` and `/speckit-tasks`. Severity tiers in the reports map to the priorities below: 🔴 → P1, 🔴/🟡 dead-code & debug → P2, 🟡 → P3, 🟢 → P3.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Delete & identify a check-in from every entry point (Priority: P1)

A person opens a saved check-in's detail screen from the **Calendar** tab. They see the check-in's date in the title bar and a Delete control — exactly as they do when they open the same check-in from **Insights**. Today, opening from Calendar silently drops the date title and the Delete control, so the check-in cannot be deleted from that path.

**Why this priority**: Correctness and data-control bug. A user literally cannot delete a check-in opened from Calendar — a broken core action affecting sensitive health/mood data.

**Independent Test**: Open a saved check-in from the Calendar tab; confirm the date title and a working Delete appear and match the Insights entry point.

**Acceptance Scenarios**:

1. **Given** a saved check-in, **When** the user opens its detail from the Calendar tab, **Then** the navigation bar shows the check-in's date and a Delete control.
2. **Given** the detail is open from the Calendar tab, **When** the user taps Delete and confirms, **Then** the check-in is removed and the user returns to the calendar.
3. **Given** the same check-in, **When** opened from Insights versus Calendar, **Then** both present identical toolbar affordances.

---

### User Story 2 - Readable check-in chips at the largest accessibility text sizes (Priority: P1)

A low-vision person uses the largest accessibility text size. On their day timeline, the mood, sleep, and medication chip labels (for example "Taken Concerta 36mg") grow with their text-size setting and stay legible. Today those labels are frozen small and do not scale at all.

**Why this priority**: Accessibility correctness for an app that surfaces medication and health data; frozen medication labels are unreadable for low-vision users at large text sizes.

**Independent Test**: Set Dynamic Type to the maximum accessibility size, view a day with chips; confirm chip labels scale and remain legible without clipping.

**Acceptance Scenarios**:

1. **Given** Dynamic Type at the maximum accessibility size, **When** the user views a day timeline with chips, **Then** chip labels render at the scaled size and remain readable.
2. **Given** the maximum accessibility size, **When** a chip label is long (e.g. "Taken Concerta 36mg"), **Then** the text is not clipped and the layout adapts.
3. **Given** the default text size, **When** the user views chips, **Then** their appearance is unchanged from today.

---

### User Story 3 - No internal debug surfaces in released builds (Priority: P2)

A shipped (Release / TestFlight) build contains no internal test or diagnostic screens, and no user ever reaches a control that does nothing.

**Why this priority**: Release hygiene and safety. Internal scaffolding must not ship; a visible no-op "Done" button is a defect a tester can hit.

**Independent Test**: Build for Release; confirm internal test/diagnostic screens are absent and unreachable, and no non-functional control is present.

**Acceptance Scenarios**:

1. **Given** a Release build, **When** the user explores Settings, **Then** no internal test or diagnostic screen is reachable or present.
2. **Given** a build configuration where a diagnostic screen IS available, **When** the user taps its Done control, **Then** the screen dismisses.
3. **Given** a Debug build, **When** developers use diagnostics, **Then** they still function as before.

---

### User Story 4 - A view layer free of dead and unreachable code (Priority: P2)

The view layer contains no orphaned files or unreachable members. The shipping codebase reflects what actually runs, so future changes are safe, fast, and unambiguous.

**Why this priority**: Maintainability and constitution Principle III ("Dead code … MUST NOT be merged"). Removes confusion and risk, shrinks the binary; behavior is unchanged for users.

**Independent Test**: After removals, search the repository for the removed file/symbol names and confirm zero production references; build the app and run the full test suite; confirm user-visible behavior is unchanged.

**Acceptance Scenarios**:

1. **Given** the removals, **When** the project is searched for the removed file/symbol names, **Then** zero production references remain.
2. **Given** the removals, **When** the app is built and the test suite runs, **Then** build and tests pass.
3. **Given** the removals, **When** a user exercises existing flows, **Then** all behavior is unchanged.
4. **Given** the summary-state cleanup, **When** the dependent orphan is removed before the type it references, **Then** the build never breaks mid-change.

---

### User Story 5 - Insights stays responsive and the app uses current platform idioms (Priority: P3)

Insights stays smooth as a month accumulates many check-ins, and the tab bar and visuals use current iOS conventions.

**Why this priority**: Performance-at-scale and modern-API alignment (constitution Principle I). No current user-blocking issue, but it prevents future jank and deprecation.

**Independent Test**: With a month of many recordings, page through Insights and confirm smoothness; switch tabs and confirm correct behavior under the modern tab API.

**Acceptance Scenarios**:

1. **Given** a month with many check-ins, **When** the user pages through Insights sections, **Then** scrolling and paging stay smooth with no recompute stutter.
2. **Given** the app launches, **When** the user switches tabs, **Then** tab selection works correctly with no regression.

---

### User Story 6 - Visual polish, consistency, and preview/contrast coverage (Priority: P3)

Small inconsistencies are cleaned up, every primary screen has a working preview, and dark-mode secondary text meets contrast guidelines.

**Why this priority**: Long-term quality and reviewability. No user-blocking issue; raises the floor.

**Independent Test**: Review confirms consistent inputs/sheets, working previews for all primary screens (populated where relevant), and AA-compliant dark-mode secondary text.

**Acceptance Scenarios**:

1. **Given** dark mode, **When** the user reads secondary text, **Then** its contrast meets WCAG AA.
2. **Given** the dense editor screen and the day card, **When** a developer opens their previews, **Then** they render (populated where relevant).
3. **Given** an empty multi-line text input (feedback, text check-in), **When** the user views it, **Then** it shows guiding placeholder text.

---

### Edge Cases

- A recording is deleted out from under an open day-detail sheet — the existing deletion guard (defer delete until the view disappears) MUST continue to hold after the detail screen is wrapped in its own navigation container.
- At the maximum accessibility text size, long medication strings MUST wrap or otherwise adapt — never clip or overflow horizontally.
- Release versus Debug divergence — debug-only surfaces MUST compile cleanly in BOTH build configurations.
- After the duplicate summary-state machine is removed, the summary/processing UI (driven by the persisted recording status) MUST still correctly reflect generating, ready, and failed states.
- Removing the unused title-editing machinery MUST NOT affect any saved check-in titles or provenance.

## Requirements *(mandatory)*

### Functional Requirements

**Correctness & accessibility (P1)**

- **FR-001**: Opening a check-in's detail MUST present the same navigation toolbar (date title and Delete control) regardless of entry point (Calendar or Insights).
- **FR-002**: Deleting a check-in from its detail MUST work from every entry point and return the user to the prior screen.
- **FR-003**: Check-in chip labels (mood, sleep, medication) MUST scale with the user's Dynamic Type setting up to the maximum accessibility size and remain legible without clipping.
- **FR-004**: At the default text size, chip appearance MUST be unchanged from current behavior.

**Release hygiene (P2)**

- **FR-005**: Released (non-debug) builds MUST NOT compile or expose internal test or diagnostic screens.
- **FR-006**: Any diagnostic screen that can be presented MUST have a functioning dismiss control.

**Dead code & single source of truth (P2)**

- **FR-007**: The view layer MUST contain no orphaned files or unreachable members per the audit inventory; every removal MUST be reference-verified (no production references remain).
- **FR-008**: Removals MUST preserve all existing user-visible behavior; the build and the full test suite MUST pass afterward.
- **FR-009**: Summary/processing state shown to the user MUST derive from a single source of truth (the persisted recording), with no duplicate, unobserved state machine.
- **FR-010**: Removal order MUST avoid transient build breakage — a dependent orphan MUST be removed before the type it references.

**Performance & idiom (P3)**

- **FR-011**: Insights analytics MUST NOT recompute the month's derived data on every render or paging interaction, and MUST stay responsive as the recording count grows.
- **FR-012**: The app MUST use current platform APIs for the tab bar and text styling, with no deprecated forms (constitution Principle I).

**Polish & coverage (P3)**

- **FR-013**: Multi-line text inputs MUST present guiding placeholder text when empty.
- **FR-014**: Mutually-exclusive modal presentations MUST be driven by a single selection value rather than parallel boolean flags.
- **FR-015**: Dark-mode secondary text MUST meet WCAG AA contrast.
- **FR-016**: Each primary screen — including the extraction-review editor and the day card — MUST have a working preview, populated with representative data where relevant.
- **FR-017**: Shared utilities and types MUST follow the project's one-type-per-file and shared-utility-placement conventions.
- **FR-018**: Time-based delays and date formatting MUST use current, non-wasteful APIs (no per-render formatter allocation; no manual nanosecond delay literals).

### Key Entities *(include if feature involves data)*

- **Recording (existing persisted model)**: its persisted summary status becomes the single source of truth for the summary/processing state shown in the UI, replacing the duplicate unobserved view-model state machine. No schema change; no new attributes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can delete a check-in opened from the Calendar tab 100% of the time, with the date title visible — at full parity with the Insights entry point.
- **SC-002**: At the maximum accessibility text size, 100% of check-in chip labels are legible and unclipped.
- **SC-003**: A Release build contains zero reachable internal test/diagnostic screens and zero non-functional controls.
- **SC-004**: Zero orphaned files or unreachable members remain in the view layer (search-verified); the build and the full test suite pass.
- **SC-005**: Insights paging stays smooth with at least a full month of dense check-ins (e.g., 100+) — no perceptible recompute stutter.
- **SC-006**: All audited primary screens render correctly in light and dark mode; dark-mode secondary text meets WCAG AA; every primary screen has a working preview.
- **SC-007**: No user-visible behavior regressions across the app — existing flows are unchanged except the explicit bug, accessibility, and debug fixes.

## Assumptions

- The two audit reports ([views-audit](../../docs/audits/2026-06-25-views-audit.md), [ios-design-review](../../docs/audits/2026-06-25-ios-design-review.md)) are the authoritative, verification-passed inventory of in-scope findings.
- Platform/stack: iOS 26.5, Swift 5 language mode, SwiftUI with the Observation macro and SwiftData (per constitution and the project's current configuration).
- The design system (DESIGN.md) tokens, glyphs, and fixed decorative sizes are intentional and remain unchanged; the only token change is swapping the chip's frozen font for the scaling typography token (an accessibility fix, not a visual redesign).
- **Remediation, not new features.** The unused title-editing machinery and the unobserved duplicate processing-state machine are REMOVED, not converted into new UI. If a user-facing processing indicator or a title-edit feature is later wanted, each is a separate spec.
- The existing summary-state test coverage is retargeted to assert on the persisted recording status after the duplicate state machine is removed.
- Dead-code deletions are reference-verified (zero production references) before removal, and the dependent-orphan-before-referenced-type ordering constraint is honored.
- Per constitution Principle X, testable-logic changes (view-models, services) are built test-first (RED→GREEN); SwiftUI view changes are verified by build + on-simulator run (Principle II).

### Dependencies

- Requires the existing build pipeline and test suite (Xcode / XcodeBuildMCP) to verify green per constitution Principle II.
- The visual follow-ups (dark-mode contrast, populated previews) depend on the design review report for the specific screens.
