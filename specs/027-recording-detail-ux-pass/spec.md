# Feature Specification: Recording Detail UX Pass — 4 Info Cards, Glyph Tuning, Visible Edit/Delete, Log Dose Design System

**Feature Branch**: `feat/027-recording-detail-ux-pass`

**Created**: 2026-06-27

**Status**: Draft

**Source**: On-device QA screenshots (IMG_5121–5126), design iteration in session 2026-06-27.
Approved mockup: [`html-mockups/checkin-detail-and-log-dose.html`](../../html-mockups/checkin-detail-and-log-dose.html).
Four source files touched; no schema changes; pure presentation refactor.

---

## Constitution Check

| Principle | Status |
|---|---|
| I. SwiftUI-First | ✅ All changes use modern SwiftUI APIs (iOS 26+). HTML mockup approved before implementation. No UIKit. |
| II. Test-Build-Ship | ✅ Build + full test suite green on branch before PR. Device QA by owner. |
| III. Correctness Over Speed | ✅ All four changes correct verified bugs or information-architecture deficiencies. No shortcuts. |
| IV. Minimal Surface | ✅ No new protocol, service, abstraction, or model. `onRegenerate` parameter removed (no longer needed); no dead parameter kept. |
| V. Solo Git Discipline | ✅ `feat/027-recording-detail-ux-pass` off `main`. PR + `/code-review` before merge. |
| VI. On-Device Privacy | N/A — no data-flow change; presentation only. |
| VII. Deterministic Extraction | N/A — extraction pipeline untouched. |
| VIII. Service-Oriented Architecture | N/A — no new capability or service. |
| IX. Pre-Release Data Posture | N/A — no schema change. |
| X. Test-First Development | ✅ All four changes are SwiftUI view rewrites or 1-line layout fixes — no new model logic. Exempt from test-first per Principle X; verified by build + on-device run. |

---

## User Scenarios & Testing

### User Story 1 — Day-card header title centres when the card is expanded (Priority: P2)

When I expand a day card in the calendar, the day title ("Flat · Today, 27 Jun") centres
vertically against the mood glyph — the way the code's own spec comment says it should.
Today it sticks to the top edge, leaving a visual gap below the title.

**Why this priority**: The spec comment in `FoldedDayCardHeader.swift:6` already documents
the correct behaviour ("The glyph and text are centre-aligned"). This is a silent code
drift from the spec, not a disputed design decision. It is P2 only because it is cosmetic.

**Root cause**: `FoldedDayCardHeader.swift:18` uses `HStack(alignment: .top, …)`. When
expanded the summary line disappears, leaving a single text line that sits at the top of
the 40pt glyph instead of at its vertical centre.

**Independent Test**: Expand any day card in the calendar. The mood word + date line
must be vertically centred against the mood glyph (±2pt tolerance at default text size).

**Acceptance Scenarios**:

1. **Given** a day card is collapsed, **When** I expand it, **Then** the title line
   ("Mood · Date") is vertically centred against the inline mood glyph.
2. **Given** a day card is collapsed (two lines: title + summary), **When** rendered,
   **Then** visual layout is not degraded by the alignment change.
3. **Given** Dynamic Type is at maximum size, **When** the expanded header wraps,
   **Then** the glyph aligns to the vertical centre of the text block.

**Fix**: [`FoldedDayCardHeader.swift:18`](../../app-four/Views/Components/FoldedDayCardHeader.swift#L18)
`HStack(alignment: .top, spacing: Spacing.m)` → `HStack(alignment: .center, spacing: Spacing.m)`

---

### User Story 2 — Check-in detail replaces opaque Summary with 4 scannable cards (Priority: P1)

When I open a check-in, I want to see structured cards for Medications, Sleep, Emotions,
and Side Effects — not a paragraph summary I have to read to find what I care about.
Today the detail shows an AI-generated bullet summary that requires reading and a "regenerate"
button that creates complexity. The structured data (medication events, sleep hours, emotions,
side effects) already exists on the `Recording` model; the summary is a lossy aggregation of it.

**Why this priority**: The summary card obscures actionable structured data behind prose. A
user checking "did I take my meds today" has to read three bullets. The 4-card layout puts
each category in a named, skimmable row — one glance per category.

**Independent Test**: Open any check-in that has at least one medication event, sleep data,
emotions, and side effects. Confirm four individually-titled cards appear in the correct order.
Open a check-in with no sleep data — confirm the Sleep card is absent. Open a check-in with
no medication events — confirm the Medications card is absent.

**Acceptance Scenarios**:

1. **Given** a check-in with transcript-sourced medication events, **When** the detail
   opens, **Then** a "Medications" card appears first, listing events in chronological
   order using the existing `medsLine` format.
2. **Given** a check-in with sleep data (`decodedSleepLevel` or `sleepHours`), **When**
   the detail opens, **Then** a "Sleep" card appears second with a sleep tag (indigo, sleep
   glyph / moon icon, same tag style as the old tag flow).
3. **Given** a check-in with emotions (`decodedEmotions`), **When** the detail opens,
   **Then** an "Emotions" card appears third with a tag per emotion (amber `heart.fill` tags).
4. **Given** a check-in with side effects (`decodedSideEffects`), **When** the detail
   opens, **Then** a "Side Effects" card appears fourth with a tag per effect (warning-amber
   `bandage.fill` tags).
5. **Given** a check-in where any category is empty, **When** the detail opens, **Then**
   that category's card is absent (not shown as empty).
6. **Given** the summary section was previously visible, **When** the new layout renders,
   **Then** no "Summary" eyebrow, no regenerate button (↻), and no AI-generated bullet
   points appear anywhere in the detail.

**Files changed**:
- [`app-four/Views/Components/ADHDSummarySection.swift`](../../app-four/Views/Components/ADHDSummarySection.swift) — replace `summaryCard` with 4 individual cards; remove `onRegenerate` parameter.

---

### User Story 3 — Edit and Delete are directly accessible, not buried in a menu (Priority: P2)

Today "Edit check-in" is a bottom pill and "Delete check-in" is hidden inside a `···` menu.
A user who wants to delete must know to tap `···`, which is not discoverable. The new layout
puts edit as a top-right icon (direct access, no menu) and delete as a visible destructive
text button below the audio card.

**Why this priority**: Discoverability. The "Delete" action is invisible. The "Edit" action
duplicates the bottom pill unnecessarily via the menu. Moving them removes the menu entirely
and surfaces both affordances at their logical positions.

**Independent Test**: Open any check-in. A pencil icon must be visible top-right in the
nav bar. Scrolling to the bottom must reveal a "Delete check-in" text button in destructive
red below the audio card. Tapping the pencil must open the edit sheet. Tapping delete must
show a confirmation dialog before deleting.

**Acceptance Scenarios**:

1. **Given** the detail is open, **When** the nav bar renders, **Then** a pencil edit icon
   appears top-right (circle background, `pencil` SF Symbol) with no `···` menu alongside it.
2. **Given** a user taps the pencil icon, **Then** `ExtractionReviewView` opens as a sheet
   (identical to the current "Edit check-in" button behaviour).
3. **Given** the detail is open and the user scrolls to the bottom, **Then** a full-width
   "Delete check-in" button in destructive red appears below the audio card.
4. **Given** a user taps "Delete check-in", **Then** a `.confirmationDialog` appears asking
   for confirmation before any deletion is committed.
5. **Given** the user cancels the confirmation, **Then** no deletion occurs and the detail
   remains open.
6. **Given** the user confirms deletion, **Then** the view dismisses and the recording is
   deleted via `pendingDelete` + `.onDisappear` (preserving the existing SwiftData
   safe-delete pattern).
7. **Given** the bottom of the detail is visible, **Then** the old gradient "Edit check-in"
   primary pill is absent.

**Glyph size change** (bundled with this story as a single-file change):
The signal glyph row (mood/energy/focus) increases from 26pt to 30pt — between the 26pt
"before" and 36pt "after" explored in the mockup, landing at a size that gives the glyphs
weight without dominating the card.

**Files changed**:
- [`app-four/Views/RecordingDetailView.swift`](../../app-four/Views/RecordingDetailView.swift) — pencil toolbar item, delete button, glyph size 26→30, remove `onRegenerate:` argument.

---

### User Story 4 — Log Dose sheet matches the app's design system (Priority: P2)

When I log a dose via the medication bar, the sheet looks like a generic Apple Form — grey
section headers, light grey cells, a green "Cancel" nav title, a system DatePicker. It
clashes with every other screen in the app, which uses the dark card pattern established
by `TextCheckInComposer`.

**Why this priority**: Visual inconsistency breaks the "Paper & Pollen" feel the rest of
the app has. This is the same design-system gap that motivated spec 024's check-in fixes.

**Independent Test**: Log a dose from the medication bar. The sheet must use `Theme.background`
as its background, have a custom navbar matching `TextCheckInComposer`, and render all
input sections as `Theme.cardBackground` cards with separator borders — no `Form`, no grey
section headers.

**Acceptance Scenarios**:

1. **Given** the Log Dose sheet opens, **When** it renders, **Then** the background is
   `Theme.background` (dark loam), not the system grouped background.
2. **Given** the sheet renders, **Then** the navbar shows: `×` circle dismiss button
   (left), "Log Dose" title (centre), "Save" text button (right, disabled when name is empty).
   There is no `NavigationStack` title bar with system-styled Cancel/Save buttons.
3. **Given** a medication name is selected, **Then** the chip row highlights the selected
   chip using `Palette.medication.opacity(0.25)` background with a `Palette.medication`-tinted
   border and `Palette.medication` foreground text.
4. **Given** the dose section renders, **Then** it appears as a `Theme.cardBackground`
   rounded card with `Theme.separator` border — not a `Form` section.
5. **Given** the catalog entry has an onset value, **Then** an "Onset" row appears inside
   the dose card showing "≈ N min" in `Theme.textSecondary`.
6. **Given** the effect duration section renders, **Then** it is a card with an inline
   `Hours` label and numeric value — not a `Form` section.
7. **Given** the taken-at section renders, **Then** the `DatePicker` is wrapped in a
   card row with a "Time" label on the left.
8. **Given** the sheet is presented, **Then** a drag indicator (`presentationDragIndicator(.visible)`)
   is visible at the top.
9. **Given** the user taps Save with a valid name, **Then** `onLog` is called with the
   same arguments as before (name, dose?, takenAt, durationHours) — no behaviour change,
   only presentation.

**Files changed**:
- [`app-four/Views/Components/MedicationLogSheet.swift`](../../app-four/Views/Components/MedicationLogSheet.swift) — replace `NavigationStack { Form { … } }` with custom dark-card sheet.

---

## Out of Scope

- Restyle of `ExtractionReviewView` (the edit sheet opened by the pencil icon) — separate spec.
- Any change to what data is stored or how it is extracted.
- The AI summary feature as a whole — it is removed from the UI, not from the model or viewModel. `regenerateSummary()` on `RecordingDetailViewModel` is retained; the call site in the view is removed.
- Showing manual (non-transcript) medication events in the Medications card — the card continues to show only transcript-sourced events to scope the card to "what this recording is about".
- Confirmation dialog for delete — **note**: spec-026 User Story 3 also adds a confirmation dialog for the same delete action. If spec-026 lands first, this spec inherits the dialog; if this spec lands first, the dialog implementation here must match spec-026's approach (`.confirmationDialog` on a `@State` Bool trigger). Either way only one implementation should exist.

## Related

- `spec-024` — calendar/check-in/settings QA (same branch currently active)
- `spec-026` — critical UI audit fixes (also adds delete confirmation)
- `html-mockups/checkin-detail-and-log-dose.html` — approved before/after mockup
