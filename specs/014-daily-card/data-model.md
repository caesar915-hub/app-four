# Data Model: Daily Card — Folded Summary, Opens to the Day

**Feature**: `specs/014-daily-card/spec.md` · **Branch**: `feat/daycard-update` · **Date**: 2026-06-23

## Scope & posture

This is a **behavioral/UI redesign**, not a data redesign. The day-card reads existing
data in a new structure (folded summary + expand-on-tap) and adds one new interaction
(select-a-date → filter-above + jump-to-top + auto-expand).

**SwiftData `@Model` changes required: NONE.** The one new preference
(`autoExpandOnSelection`, default ON, FR-019) is a view-level **`@AppStorage`** flag — not a
`@Model` attribute — matching the codebase's `MedicationBar*` toggles (see §4). The
pre-release schema is therefore untouched, which satisfies **Constitution Principle IX**
trivially (no new attribute, no `@Attribute(.unique)`, no migration). **`Recording` and
`AppSettings` are unchanged — verified below.**

The other state the feature needs is **ephemeral UI state** (selected date, per-card
open set), which lives in the View, not in any `@Model` and not in the ViewModel
(Constitution Principle VIII: ViewModels hold no view-ephemeral selection state).

---

## 1. `Recording` — existing `@Model`, NO schema change (VERIFIED)

`app-four/Models/Recording.swift` (`@Model final class Recording`). The spec's "check-in"
is user-facing copy for this model (spec Clarification, 2026-06-23: "`Recording` is the
code source-of-truth; no model rename"). The folded card and expanded check-in rows are
**read-only projections** of fields that already exist:

| Field (existing) | Type | Used by | Notes |
|---|---|---|---|
| `id` | `UUID` (`@Attribute(.unique)`) | row identity | unchanged |
| `createdAt` | `Date` | check-in time; day grouping (`startOfDay`); newest-first sort | drives the time-circle label and day bucketing |
| `mood` | `String?` | folded summary mood; expanded mood word | optional → omit when nil (FR-002, FR-007) |
| `energyLevel` | `String?` | folded summary energy; expanded energy glyph | optional → omit when nil |
| `focusLevel` | `String?` | folded summary focus; expanded focus glyph | optional → omit when nil |
| `feelingsJSON` | `String?` | expanded "feelings" chips | optional → omit when empty |
| `sideEffectsJSON` | `String?` | expanded "side-effects" chips | optional → omit when empty |
| `medicationEvents` | `[MedicationEvent]` (`@Relationship`) | medication name/dose chips; phase ring | unchanged |

**Decision: no fields added to `Recording`.** The folded-summary string and the
most-recent-medication name are **derived at render time** from data already present;
storing them on the model would duplicate state and couple the model to view concerns
(rejected — Principle IV Minimal Surface; matches decision "Most-Recent Medication
Selection"). Signal-level parsing (1→5 + glyph) is reused unchanged from spec 006.

**Invariant**: every `Recording` field consumed here is already optional; absence is
rendered as omission, never as `0`/blank/placeholder (FR-002, FR-007, SC-007).

---

## 2. `MedicationEvent` / `DayTimeline.Ring` — existing, NO schema change

The medication-phase percentage is **already derived and cached** during timeline build
and is **not newly computed** here (spec Assumption "Medication-phase percentage … this
feature does not introduce new pharmacokinetic calculation").

`DayTimeline.Ring` (`app-four/ViewModels/DayTimeline.swift`) — value type, unchanged:

| Field | Type | Role for this feature |
|---|---|---|
| `doseID` | `UUID` | ring identity |
| `progress` | `Double` (0…1) | the medication-phase fraction; rendered as arc length **and** as the "% beneath" redundant readout (FR-020) |
| `name` | `String` | medication name → folded line (name only, FR-003) and expanded chip |
| `dose` | `String?` | expanded chip ("name + dose"); never in the folded line (FR-003) |

`progress` is computed once via `MedicationEvent.effectProgress(at:)` inside
`DayTimelineBuilder.activeRings(at:doses:)` and cached on the `Ring`. The new
medication-phase ring view **reads** `ring.progress`; it MUST NOT recompute (Principle IV;
avoids drift from the medication bar).

**Invariant**: a check-in with no dose in-window has no `Ring`; the time-circle still
renders and the ring/percentage is omitted, never shown as `0%` (spec Edge Cases;
FR-006/FR-020 apply only when a ring exists).

---

## 3. `MoodLibraryViewModel.TimelineDay` — existing value type, derived fields added (NO `@Model`)

`MoodLibraryViewModel.TimelineDay` (`app-four/ViewModels/MoodLibraryViewModel.swift:9-14`)
is a plain `Identifiable` struct (not persisted, not a `@Model`). Current shape:

```
struct TimelineDay: Identifiable {
    let date: Date            // start-of-day; stable id for scroll-sync
    let label: String
    let nodes: [DayTimeline.Node]   // newest-first (DayTimelineBuilder sorts time desc)
    var id: Date { date }
}
```

`id == date` (start-of-day) is the stable identity used for scroll-sync and for the
per-card open `Set<Date>` (§5). `nodes` is already newest-first.

### 3a. Derived presentation values (computed, NOT stored on the struct)

These are pure functions of `nodes`, computed in the view layer (`DayCard` /
`FoldedDayCardHeader`). They are listed as part of the data model because they define the
folded card's payload; the **decision is to keep them as render-time derivations**, not
new stored fields, to avoid duplicating state (matches decisions "Folded Summary Line
Component", "Most-Recent Medication Selection", "Folded summary line structure").

| Derived value | Type | Derivation rule | FR / invariant |
|---|---|---|---|
| `isEmpty` | `Bool` | `nodes.isEmpty` | drives empty-state copy (FR-004) |
| folded mood | `String?` | mood of the day used to wash the card / lead the summary line | omit if no mood logged (FR-002) |
| folded energy | `String?` | energy signal for the summary line | omit if unlogged (FR-002) |
| folded focus | `String?` | focus signal for the summary line | omit if unlogged (FR-002) |
| `mostRecentMedication` | `String?` | `nodes.first { !$0.intakeDoses.isEmpty }?.intakeDoses.first?.name` (nodes are newest-first) — equivalently the newest ring's `name`. **Name only.** | FR-003: one name only, no dose/time; omit if no dose logged that day |
| summary line | ordered, gap-free list | concatenation of the logged values above, separated by `·`, **omitting absent signals entirely** | FR-001, FR-002; never zeros/blanks/placeholders |
| empty copy | constant | `"No check-ins this day. That's alright."` | FR-004 verbatim; replaces current terse `"No check-ins"` |

**Invariants**
- The **header never resizes** between folded and open states; only the body
  (summary line ↔ check-in rows) changes (US2; mockup "the top never resizes").
- A **medication-only day** (dose, no `Recording`) still yields a `TimelineDay` with
  nodes (already covered by `manualDoseWithoutRecordingStillProducesADay` in
  `MoodLibraryViewModelTests`); its folded line shows only the medication name; the mood
  circle is neutral.
- Component/row order is **stable** and never reshuffles (FR-016, SC-008).

### 3b. Filter-above (derived collection on the ViewModel)

Add a **pure method** to `MoodLibraryViewModel` (not a stored/observable property):

```
func timelineDaysFiltered(to selectedDate: Date) -> [TimelineDay]
```

Rule: take the existing `timelineDays` (already month-scoped + newest-first) and drop any
day with `date > startOfDay(selectedDate)`; keep `date <= selectedDate`, still newest-first
(so the selected day is first/top). Days older than the selection remain, scrollable
(FR-010). The list simply stops at the oldest day — no end-of-history marker (spec Edge
Cases).

- **selectedDate is a parameter, never stored on the ViewModel.** Persisting it on the VM
  would inject view-ephemeral selection state into the model layer (rejected — Principle
  VIII). The View owns `selectedDate` and passes it in.
- Calendar-row de-emphasis (greying more-recent days) is a **view concern** in
  `CalendarDayCell`, not a data field: opacity `0.34` **plus** a second non-color cue
  (lighter weight / dropped marker dot) for greyscale survival (FR-011, FR-014).

---

## 4. Auto-expand setting — `@AppStorage` (no schema change)

Persisted user preference (FR-019, default ON). Stored as **`@AppStorage("autoExpandOnSelection")`**, the pattern the codebase already uses for view-consumed behavior toggles — the `MedicationBar*` visibility flags ([MedicationBarSettingsSection.swift](app-four/Views/Settings/MedicationBarSettingsSection.swift) writes, [MedicationBarView.swift](app-four/Views/Components/MedicationBarView.swift) reads, sharing `"medicationBarVisible"`).

| Field | Type | Default | Persistence | FR |
|---|---|---|---|---|
| `autoExpandOnSelection` | `Bool` | `true` | `@AppStorage("autoExpandOnSelection")` (UserDefaults) | FR-019 |

```swift
// CalendarLibraryView (read) and DayCardSettingsSection (toggle) share the key:
@AppStorage("autoExpandOnSelection") private var autoExpandOnSelection = true
```

**Why `@AppStorage`, not `AppSettings`/`SettingsViewModel`**: a `@Model` attribute would force plumbing the setting into `CalendarLibraryView` (which holds only `AppServices` in its environment) and would depend on `SettingsViewModelTests`, currently **disabled** pending a mock `AppServices`. `@AppStorage` is read directly anywhere, needs no plumbing, and is test-exempt (view state) — matching the `MedicationBar*` precedent. **No `@Model` attribute, no schema change** → Principle IX is satisfied trivially and Principle IV surface is lower.

**Invariant**: when `false`, selecting a date scrolls/jumps the day to top **without**
opening it; the day can still be opened by a header tap.

**Invariant**: when `false`, selecting a date scrolls/jumps the day to top **without**
opening it; the day can still be opened by a header tap.

---

## 5. Ephemeral UI state — lives in the View, NOT persisted, NOT a `@Model`

These exist only for the session and never touch SwiftData (Constitution Principle IX:
"selectedDate in CalendarLibraryView is @State (ephemeral), not persisted").

In `CalendarLibraryView`:

| State | Type | Default | Role | FR |
|---|---|---|---|---|
| `selectedDay` | `@State Date` | `startOfDay(Date())` (already exists, `CalendarLibraryView.swift:8`) | the focused date; feeds `timelineDaysFiltered(to:)` and calendar highlight | FR-009/010 |
| `expandedCardDates` | `@State Set<Date>` | `[]` | which day-cards are open; keyed by `TimelineDay.id` (start-of-day) | FR-005 |

**Why `Set<Date>`**: `O(1)` membership for the per-card open check, and it directly
supports the multi-open requirement (FR-005: "multiple cards MAY be open at once via
header taps"). A single `Date?` would violate multi-open; a `Dictionary<Date,Bool>` carries
an unused value (rejected). Keyed by `startOfDay` so it aligns with `TimelineDay.id`.

**State-transition rules (invariants):**

| Trigger | Effect on `expandedCardDates` | FR |
|---|---|---|
| Header tap on day *d* | toggle `d` (`contains` → remove, else insert); other cards untouched | FR-005, FR-008 |
| Select date *d* (auto-expand **on**) | `removeAll()` then `insert(startOfDay(d))` — collapse all, open only *d* | FR-009 |
| Select date *d* (auto-expand **off**) | `removeAll()` (jump-to-top only, no open) | FR-019 |
| Re-select the already-selected date | **idempotent** — no collapse, no re-animate; day stays top-and-open | FR-009, Edge Cases |
| Rapid re-selection to *d2* | behaves as a fresh select of *d2* (collapse all, open *d2*); never a mixed state | Edge Cases |

The header toggle and the select-driven collapse are wrapped in
`withAnimation(reduceMotion ? nil : Motion.smooth)` (Reduce-Motion honored per the
2026-06-23 Clarifications; mirrors existing `CalendarLibraryView` scroll-to-top at line ~143).

**No selection accent state**: the selected day carries no border/outline; top-position +
expanded state are the only cues (FR-012). No today-ring state in `CalendarDayCell`; the
"Today" pill is the sole today affordance (FR-013).

---

## Summary of schema impact

| Entity | Kind | Change |
|---|---|---|
| `Recording` | `@Model` | **none** (verified — all consumed fields already exist & are optional) |
| `MedicationEvent` / `DayTimeline.Ring` | `@Model` / value | **none** (phase % already cached, reused) |
| `MoodLibraryViewModel.TimelineDay` | value struct | **none stored**; adds render-time derivations + one pure filter method `timelineDaysFiltered(to:)` |
| `AppSettings` | `@Model` | **none** — auto-expand is `@AppStorage`, not a model attribute (no schema change) |
| auto-expand preference | `@AppStorage` | `autoExpandOnSelection` (default `true`); view-level, matches `MedicationBar*` toggles; not in the SwiftData schema |
| selected date / open-cards | View `@State` | new ephemeral UI state (`selectedDay` exists; add `expandedCards: ExpandedDayCards` over `Set<Date>`); not persisted |

**CloudKit posture (Principle IX): satisfied.** The only `@Model` change is a defaulted
`Bool` — no unique constraints, no required-without-default attributes, no relationship
changes; lightweight, additive, non-destructive migration.

