# Calendar Day-Selection & Navigation — Design

**Date:** 2026-06-13
**Status:** 📐 Design — decisions locked; hardened against the codebase (multi-agent review, 2026-06-13)
**Mockups:** [day-selection variants](../plans/2026-06-13-calendar-day-selection-mockup.html) · [navigator & list granularity](../plans/2026-06-13-calendar-granularity-mockup.html)
**Replaces in:** [CalendarLibraryView.swift](../../../app-four/Views/Library/CalendarLibraryView.swift) — the `MonthSelectorScrollView` header
**Reference:** Todoist "Upcoming" screen recording (`html-mockups/ScreenRecording_06-13-2026 17-21-12_1.MP4`)

---

## Problem

The Calendar tab today has a **month-only** header (`MonthSelectorScrollView` → "MAY · JUN 2026"). You can switch *months*, but you cannot:
- jump to a **specific day**,
- see **which days have check-ins** (or what the mood was) without scrolling the whole list,
- get a **calendar-grid overview** of a month.

The Todoist recording demonstrates a navigation pattern that solves exactly this: a **collapsible calendar** (week strip ↔ month grid) whose **selected day is two-way bound to the scroll position** of the list below.

## Goal

Port that navigation chrome onto our **mood/medication timeline**, reframed for a journal (we browse the **past**, not future tasks). The timeline node visuals (mood-fill beads, med rings, banners, chips) are unchanged — this design replaces the **header/navigation**, adds **day markers**, **two-way scroll-sync**, and an **empty-day state** in the list.

---

## Decisions (all locked)

1. **Direction: past, newest-first.** Opens anchored on **Today** at the top; scrolling **down** reveals **older** days. Future days are disabled/dimmed in the calendar. (Inversion from Todoist, which points forward.)
2. **Navigation model: month-paged.** The calendar grid and the list are both scoped to one **`currentMonth`** — reusing the existing `currentMonth` + `availableMonths` + `timelineDays` model (lowest-risk). Tapping a day scrolls **within** the visible month; earlier months are reached by paging the header (chevron/swipe), bounded by `availableMonths` (earliest `Recording.createdAt`'s month → today). *Deliberate divergence from the video's continuous mid-scroll month flip — not worth a `timelineDays` rebuild for v1.*
3. **Empty days: show all days of the visible month.** Every day of `currentMonth` (1…last, or 1…today for the current month) renders a `DayCard`, with a **"No check-ins"** state for empty days. Bounded (~28–31 rows), so tap-a-day → scroll is **exact** (no nearest-day snapping). Requires `timelineDays` to emit the full month and `DayCard` to gain an empty state.
4. **Expand interaction: tap chevron.** Tap the month label/chevron to flip week↔month. (Dropped the Todoist drag handle for v1 — most gesture code for marginal feel gain.)
5. **Navigator: N1 · day → month grid.** Collapsed = a 7-cell week strip (the week containing the selected day); expanded = the `currentMonth` grid. (N2 heatmap / N3 week-rows remain on record in the granularity mockup if the month grid later proves a weak trend view.)
6. **Day marker: mood-colour dot.** A dot below each day number, tinted by that day's dominant mood (turns the calendar into a mood-over-time heat-strip). See *Visual tokens* for exactly which palette end.
7. **List grouping unchanged.** Keeps per-day `DayCard` grouping, reverse-chronological. No week separators, no weekly digest.

---

## Design guidelines

### Layout (top → bottom)
1. **Title bar** — screen title, unchanged.
2. **Month header row** — `Month YYYY` + a chevron (`›` collapsed / `⌄` expanded). A **"jump to today"** control appears at the right when `currentMonth`/selection ≠ today; tapping it returns to the current month, selects Today, and scrolls the list to top.
3. **Calendar** — collapsed = a **7-cell week strip** (M T W T F S S weekday caps + the selected day's week). Expanded = the **`currentMonth` grid** (5–6 rows). Thin separator beneath.
4. **Timeline list** — `currentMonth`'s days, reverse-chronological, **all days including empty ones** (header + "No check-ins").
5. **Tab bar** — the app's existing system tab bar (Calendar selected), unchanged.

### Day-cell anatomy
- **Number** centered; weekday caps (M…S) in the grid's header row only.
- **Marker** — a mood dot ~5–6 pt directly **below** the number, tinted by the **deep `MoodLevel.color`** of the day's rounded-average mood (legible at small size — see *Visual tokens*). No dot on empty days.
- **Selected day:** a filled **ink/charcoal** circle behind the number (white number). Selection is **neutral chrome** so it never competes with the mood-coloured marker dots.
- **Today (when not selected):** number in ink with a hollow ring — always locatable. When today *is* selected, the filled ink circle wins (selection trait still announced).
- **Future days:** dimmed (`Theme` tertiary), non-interactive.
- **Out-of-month days** (grid only): faint; tapping one **sets `currentMonth` to that month, selects the day, and scrolls the list to it** — a single gesture (don't leave a selected day hidden behind the wrong month).

### Scroll-sync (two-way, within `currentMonth`)
- **List → calendar:** the **top-most visible `DayCard`** (each tagged `.id(dayDate)`) drives the selected day. Debounce to a day boundary — only fire when the topmost day actually changes, not every scroll tick.
- **Calendar → list:** tapping a day scrolls the list with `scrollTo(id: dayDate, anchor: .top)`. Exact, because every day of the month is an anchor (decision #3).
- **Feedback-loop guard:** a `@State private var isProgrammaticScroll` in the view, set `true` when a day is tapped (around the animated `scrollTo`) and cleared after the scroll settles (a `Task` sleeping ~the animation duration). The list→calendar observer is a no-op while it's `true`.
- No cross-month sync needed (month-paged) — changing month re-renders the grid and the list together.

### Motion
- **Week↔month height:** animate the container height with **`Motion.smooth`** (`.smooth(0.4)` — the existing token; `Motion` has no bespoke spring, don't invent one). Collapsed height = one week row; expanded = the month grid.
- **Selection from a tap:** the ink circle animates in; the list scroll runs inside `withAnimation(Motion.smooth) { … scrollTo … }`.
- **Reduce Motion:** the app guards explicitly (see `InsightsView`/`CheckInView`): `@Environment(\.accessibilityReduceMotion)` → `withAnimation(reduceMotion ? nil : Motion.smooth)`. Apply to **both** the height change and the scroll (instant, no cross-fade).

### Accessibility
- Each day cell `accessibilityLabel` = full date + state, e.g. *"Tuesday 10 June, 3 check-ins, mostly good"*; empty days announce *"…, no check-ins."* Selected/today via `.accessibilityAddTraits`.
- Expand control labelled "Expand to month" / "Collapse to week."
- Marker dots are **never colour-only** — the a11y label always carries the mood word.
- **Dynamic Type:** there is no `@ScaledMetric` precedent in the app (day headers are deliberately fixed-size). Cap day-number scaling with `@ScaledMetric(relativeTo: .body)` clamped to a max, and **force week-only (disable month expansion) at `dynamicTypeSize >= .accessibility1`** via `@Environment(\.dynamicTypeSize)` — month-grid cells are unreadable beyond that. (Concrete threshold, not "consider.")

### Edge cases
- **First-ever launch / empty store:** `availableMonths` returns `[currentMonth]`; the grid shows the current week with no markers; the list shows today's "No check-ins" plus the existing `ContentUnavailableView` empty state in `CalendarLibraryView`.
- **History bound:** month paging is already bounded by `availableMonths` (earliest recording's month → current); the chevron/swipe must stop at both ends. No "empty infinity" — empties are bounded within each month (decision #3).
- **Month label:** equals `currentMonth` (no mid-scroll flip in the month-paged model). Updating `currentMonth` updates the label, grid, and list together.
- **DST / timezone:** bucket days with `Calendar.current.startOfDay(for:)`, identical to `timelineDays` ([MoodLibraryViewModel.swift:66-71](../../../app-four/ViewModels/MoodLibraryViewModel.swift#L66-L71)), so the grid and list always agree.
- **Tab switches:** `CalendarLibraryView.onChange(of: selectedTab)` already clears the nav path and bumps `scrollResetToken` (scroll-to-top). Extend it: on return to Calendar, reset selection to Today, collapse to week, and (existing) scroll to top — no stale selection.

---

## Mapping to the codebase

| New / changed piece | Role | Builds on |
|---|---|---|
| `CalendarHeaderView` *(new)* | Collapsible week/month calendar + month label + jump-to-today | replaces `MonthSelectorScrollView` in `CalendarLibraryView` |
| `CalendarMonthModel` *(new, in VM)* | weeks/days for `currentMonth`, today, selection, per-day `DayMarker` — kept **separate** from `DayTimeline` (timeline-render layer) | `MoodLibraryViewModel` (`currentMonth`, `timelineDays`), `MoodLevel` |
| `DayMarker` *(new)* | `enum DayMarker { none, mood(Color), neutral }` — `.mood` = deep `MoodLevel.color` of the day's rounded-average mood; `.neutral` = has entries but no mood; `.none` = no entries | `MoodLevel.average` + `.color`; bucketed via `Calendar.current.startOfDay` (match `timelineDays`) |
| `timelineDays` *(change)* | Emit a `TimelineDay` for **every** day of `currentMonth` (not just the union of recordings/doses), empty ones with `nodes: []` | [MoodLibraryViewModel.swift:59-84](../../../app-four/ViewModels/MoodLibraryViewModel.swift#L59-L84). Also give `TimelineDay` a stable `Date` id (today it's the label string) for `.id`-based scroll-sync |
| `DayCard` empty state *(change)* | Render header + "No check-ins" when `day.nodes.isEmpty` | [DayCard.swift:24-30](../../../app-four/Views/Components/DayCard.swift#L24-L30) |
| Scroll-sync *(new)* | id-based `.scrollPosition(id:)` (iOS 17+) with each `DayCard` tagged `.id(dayDate)`; topmost-visible read → selection | **`ScreenContainer` only exposes edge-scroll** (`ScrollPosition(edge:.top)` + scroll-to-top token, [ScreenContainer.swift:37,64-69](../../../app-four/DesignSystem/ScreenContainer.swift#L37)). Either extend it to accept an id-based binding, or have this view manage its own `ScrollView` (`scrollable: false`) |

**Visual tokens to reuse** (verified against `MoodLevel+Palette.swift`, `DayCard.swift`, `Palette.swift`):
- The mood palette has **two ends per `MoodLevel`**:
  - **deep — `color` / `deepFill`:** `low #C2503F · flat #DE8050 · okay #E5C46A · good #94C56F · great #4CAF6E` (legend dots, header text, accents)
  - **light — `fill` / `gradientPartner`:** `low #D4705F · flat #EA9D72 · okay #EFD68C · good #AED68C · great #6BC68A` (bead/banner surfaces, the day-card wash)
- **Day-marker dot → the deep `MoodLevel.color`** (legend-dot semantics; legible at small size) of `MoodLevel.average(of:)`. *Not* the light fill — that's the large day-card wash, which would wash out a tiny dot.
- **Day-card mood tint** = `MoodLevel.averageFill` (light) at **`.opacity(0.16)`** (16%) over `Theme.cardBackground` — unchanged ([DayCard.swift:37-38](../../../app-four/Views/Components/DayCard.swift#L37-L38)).
- **Medication** = `Palette.medication` = `Color(.systemPurple)` (system-dynamic, adapts to appearance) — **not** a fixed hex. Unchanged.
- SF Pro; the system tab bar is unchanged (not restyled here).

---

## Implementation notes (for the plan)
- **Reuse, don't rebuild:** `currentMonth`, `availableMonths`, `prevMonth()/nextMonth()`, and `monthLabel` already exist and cover month paging + bounds. The work is the header view, the per-day `DayMarker` computation, the `timelineDays` full-month emission, the `DayCard` empty state, and id-based scroll-sync.
- **`CalendarMonthModel`** computes, for `currentMonth`: leading blanks (Mon-start), each day's `DayMarker`, and `isToday`/`isFuture`/`isSelected`/`isOutOfMonth` flags. Pure/testable — feed it the month's `timelineDays` (or the raw recordings) and `Calendar.current`.
- **`DayMarker` rules:** day has ≥1 mood → `.mood(MoodLevel.average(of: moods).color)`; has entries but no mood (e.g. med-only) → `.neutral`; no entries → `.none`.
- **Min OS:** `.scrollPosition(id:)` needs iOS 17+ — confirm the deployment target before relying on it; else fall back to `ScrollViewReader` + a `GeometryReader`/`PreferenceKey` top-anchor.
- **Tests:** `CalendarMonthModel` (grid shape, markers, today/future/selection flags, DST month boundaries); `timelineDays` now emits full-month incl. empties (count + ordering); existing `DayTimelineBuilder`/VM tests stay green.

## Out of scope
- The Todoist "Display" sheet (Agenda vs Board, sort, filters).
- Editing/creating entries from the calendar.
- Timeline node visuals (beads, rings, banners, chips) — unchanged.
- Continuous cross-month scrolling (decision #2 chose month-paged).
