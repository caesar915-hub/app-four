# Quickstart — Daily Card (014): Simulator Validation Guide

**Feature**: `feat/daycard-update` · **Spec**: [`spec.md`](./spec.md) · **Plan**: [`plan.md`](./plan.md)

This is a **manual validation / run guide**, not implementation code. It lists the runnable simulator scenarios that prove spec 014 is correct. Each scenario maps to its `FR-###` and `SC-###`. Entity shapes (`Day`, `Check-in`/`Recording`, `Signal level`, `Medication`, `Selected date`) and component/state contracts are defined in [`data-model.md`](./data-model.md) and [`contracts/`](./contracts/) — this guide references them rather than restating them.

---

## Prerequisites

- **Build/run harness**: drive the build, install, launch, and UI inspection through the **`ios-debugger-agent`** skill (XcodeBuildMCP). Do not hand-run `xcodebuild`; use the agent so simulator state, logs, and screenshots are captured.
- **Branch**: `feat/daycard-update`, building clean (`Test-Build-Ship`, Constitution II). Run the unit suites for this feature first (`MoodLibraryViewModelTests`, `FoldedDayCardHeaderTests`, `DayCardExpandStateTests` per [`data-model.md`](./data-model.md) / [`contracts/`](./contracts/)) and confirm GREEN before any simulator run.
- **Simulator**: an iOS 26 iPhone simulator, booted once and reused across scenarios.
- **Appearance**: run **every** visual scenario in **both Light and Dark** (Settings ▸ Developer ▸ Dark Appearance, or the Xcode environment override). Paper & Pollen tokens (FR-018) must hold in both.
- **Seed data**: load a fixture month containing, at minimum — (a) a day with mood + energy + focus + a medication, (b) a mood-only day, (c) a multi-medication day, (d) a check-in with no medication logged, (e) a partial check-in (some signals missing), (f) a zero-check-in (empty) day, (g) the oldest available day, and (h) today. These back the scenarios below; see `Day` / `Check-in` in [`data-model.md`](./data-model.md).
- **Accessibility toggles** (Settings ▸ Accessibility): Color Filters → Grayscale, Display & Text Size → Larger Text (largest standard size), Motion → Reduce Motion, VoiceOver. Toggle per the scenario that needs it; reset afterward.

---

## Scenario 1 — Read a whole day at a glance (folded summary)

**Maps to**: US1 · FR-001, FR-002, FR-003, FR-018 · SC-001

**Steps**
1. Launch to the calendar; do **not** tap anything.
2. Inspect the folded card for the **mood+energy+focus+medication** day (fixture a).
3. Inspect the **mood-only** day (fixture b).
4. Inspect the **multi-medication** day (fixture c).

**Expected**
- Each folded card shows: a **mood-glyph circle on the left**, the **weekday above**, and **one summary line** beneath reading `mood · energy · focus · medication-name` (FR-001).
- Medication appears **by name only** — no dose, no time (FR-003).
- The mood-only day's line shows **only the mood**; energy, focus, and medication are **omitted entirely** — no zeros, blanks, or `–` placeholders (FR-002).
- The multi-medication day's line shows exactly **one medication name — the most-recent check-in's** (FR-003; lists are newest-first).
- Card wash, type, spacing, and corner radius come from shared tokens (no ad-hoc values) in both Light and Dark (FR-018).
- **SC-001 pass**: you can state mood, energy, focus, and medication from the folded card alone, without opening it or scrolling inside it.

---

## Scenario 2 — Open a day, then shrink it back

**Maps to**: US2 · FR-005, FR-006, FR-007, FR-008, FR-020 · SC-002, SC-007

**Steps**
1. Tap the **header** of a folded card that has check-ins.
2. Observe the expansion.
3. Inspect an expanded check-in row, including one for the **no-medication** check-in (fixture d) and the **partial** check-in (fixture e).
4. Tap the header again.

**Expected**
- On expand: the **one-line summary collapses**, but the **mood circle + weekday stay in place**; check-ins are revealed **newest-to-oldest** within the day (FR-005, FR-006).
- Each check-in shows the **time inside a medication-phase ring**, with the **dose-phase percentage beneath** the ring (FR-006, FR-020), then the **mood word**, **energy + focus** level-encoding glyphs, and **chips** for medication / feelings / side-effects (FR-006).
- The **no-medication** check-in still renders its **time-circle**, but the **ring/percentage is omitted** — not shown as 0% (FR-007, edge case).
- The **partial** check-in shows **only logged signals/chips** — no empty or placeholder slots (FR-007; **SC-007**).
- Tapping the header again **collapses** the card back to the folded summary (FR-008).
- **SC-002 pass**: open in one tap, collapse in one tap.

> Independence note (FR-005): expand a **second** card via its header while the first stays open — multiple cards MAY be open at once. (This is distinct from selection behavior in Scenario 3.)

---

## Scenario 3 — Filter-above + jump-to-top + auto-expand on selection

**Maps to**: US3 · FR-009, FR-010, FR-011, FR-012, FR-016, FR-019 · SC-003, SC-008

**Precondition**: auto-expand-on-selection is **ON** (default per FR-019). Open one or two cards first so the "collapse all, then open only selected" behavior is observable.

**Steps**
1. Scroll the list to an arbitrary position.
2. Tap a **mid-month date** in the calendar week-row.
3. Inspect the list and the calendar row.

**Expected**
- The selected day **moves to the top** of the list and **auto-expands**; any previously-open cards are **collapsed first**, so only the selected day is open (FR-009).
- Days **more recent than** the selected date are **absent from the list**; older days remain **below, scrollable** (FR-010).
- In the **calendar week-row**, more-recent days are **de-emphasised (greyed)** — **not removed** (FR-011). (Greyscale survivability is verified in Scenario 5.)
- The selected day carries **no accent border/outline** — its **top position + expanded state** are the only selection cues (FR-012).
- The **medication bar → calendar row → day list** vertical order is unchanged through the interaction (FR-016; **SC-008**).
- **SC-003 pass**: one action brings the day to top + expanded with more-recent days removed.

**Auto-expand OFF variant** (FR-019)
1. Turn the auto-expand setting **OFF**.
2. Repeat the selection.
3. Expected: the selected day still **jumps to top** and more-recent days still drop out, but the card **does not open** — it can still be opened by a header tap (FR-019).

---

## Scenario 4 — Same-date re-select is idempotent

**Maps to**: US3 (edge case) · FR-009 · SC-003

**Steps**
1. Select a date (it goes top + expanded per Scenario 3).
2. Tap the **same** date in the calendar row again.
3. Then test **rapid re-selection**: select a different date while a day is expanded.

**Expected**
- Re-selecting the same date is **idempotent**: the day **stays at top and open** — it does **not** collapse or re-animate (folding is done only via the card-header tap) (FR-009, edge case).
- Rapid selection of a **new** date predictably re-focuses to the new day (top + expanded), with no mixed/half-collapsed list state (edge case).

---

## Scenario 5 — Greyscale (desaturated) signal legibility

**Maps to**: US4 · FR-011, FR-014, FR-020 · SC-004

**Setup**: Accessibility ▸ Color Filters ▸ **Grayscale ON**.

**Steps**
1. View a day with all three signals logged, expanded.
2. View the **calendar week-row** after selecting a mid-month date (so more-recent days are de-emphasised).
3. View a medication-phase ring.

**Expected**
- Every signal **level is distinguishable by shape + fill**, not hue alone (FR-014; **SC-004**).
- De-emphasised (more-recent) calendar days remain distinguishable via the **second, non-color cue** (lighter weight / dropped marker dot), not opacity alone (FR-011).
- The medication-phase ring reads via **arc length + the % text beneath** — no patterned fill needed, value survives greyscale (FR-020).
- Reset Color Filters afterward.

---

## Scenario 6 — Largest Dynamic Type

**Maps to**: US4 · FR-015 · SC-005

**Setup**: Accessibility ▸ Larger Text → **largest standard size** (not the AX/extra-large accessibility sizes unless verifying beyond spec).

**Steps**
1. Render the folded list.
2. Expand a card.

**Expected**
- **Weekday, summary line, mood words, times, and percentages all scale** with Dynamic Type (FR-015) — confirming the fixed-font gap noted in the spec is resolved.
- No text is **clipped to illegibility**; lines may wrap but stay readable (**SC-005**).
- Verify in both Light and Dark; reset text size afterward.

---

## Scenario 7 — Reduce Motion

**Maps to**: Clarifications (Reduce Motion) · FR-005/FR-009 interactions

**Setup**: Accessibility ▸ Motion ▸ **Reduce Motion ON**.

**Steps**
1. Tap a folded card header (fold/unfold).
2. Select a date (jump-to-top + auto-expand).

**Expected**
- **Fold/unfold and scroll-to-top are instant** — no expand/collapse or scroll animation when Reduce Motion is enabled, mirroring the existing calendar interaction (Clarifications, 2026-06-23).
- Reset Reduce Motion afterward.

---

## Scenario 8 — VoiceOver: folded card as a single element

**Maps to**: US4 · FR-017 · SC-001 (non-visual)

**Setup**: Accessibility ▸ **VoiceOver ON**.

**Steps**
1. Swipe to focus a **folded** card.
2. Activate it to expand, then swipe through the revealed check-ins.

**Expected**
- A **folded card is announced as a single element** summarising the day and its logged signals (FR-017) — not a pile of separate, unlabelled glyphs.
- **Expanding exposes the individual check-ins** as their own elements, each announcing time, mood, energy, focus, and medication.
- Reset VoiceOver afterward.

---

## Scenario 9 — Empty / quiet day copy

**Maps to**: US1 · FR-004 · SC-006

**Steps**
1. Inspect the **zero-check-in** day (fixture f), folded.
2. Tap its header.

**Expected**
- The empty-state card reads exactly **"No check-ins this day. That's alright."** (FR-004) — never red, never "missed"/"overdue", no streak or score (**SC-006**).
- Expanding an empty day reveals **no rows** (there are none); the chevron affordance is visual only.
- Distinguish from a day that **has** at least one check-in but few signals: that day still shows its **time-circle(s)**, not the empty-state copy (edge case).

---

## Scenario 10 — Today affordance + edge selections

**Maps to**: US3 · FR-012, FR-013 · edge cases (today, oldest day)

**Steps**
1. In the calendar row, locate **today**.
2. Select **today**.
3. Select the **oldest available day** (fixture g).

**Expected**
- Today is marked **only by the "Today" pill** — there is **no ring** around today's number (FR-013).
- Selecting **today**: it jumps to top + expands; **no days are filtered out** (nothing is more recent); only the "Today" pill marks it (edge case).
- Selecting the **oldest** day: it moves to top + expands, and the list below is **empty without error or glitch** — the list simply **stops**, with **no end-of-history marker or copy** (edge case).
- No selected day shows an accent border/outline at any point (FR-012).

---

## Sign-off checklist

| FR / SC | Scenario | Pass |
|---|---|---|
| FR-001, FR-002, FR-003 / SC-001 | 1 | ☐ |
| FR-005–FR-008, FR-020 / SC-002, SC-007 | 2 | ☐ |
| FR-009, FR-010, FR-011, FR-012, FR-016, FR-019 / SC-003, SC-008 | 3 | ☐ |
| FR-009 (idempotent) | 4 | ☐ |
| FR-011, FR-014, FR-020 / SC-004 | 5 | ☐ |
| FR-015 / SC-005 | 6 | ☐ |
| Reduce Motion clarification | 7 | ☐ |
| FR-017 | 8 | ☐ |
| FR-004 / SC-006 | 9 | ☐ |
| FR-012, FR-013 (+ today/oldest edges) | 10 | ☐ |
| FR-018 (tokens, Light + Dark) | all visual | ☐ |

All scenarios must pass in **both Light and Dark** before opening the PR. Run [`/code-review`](../../CLAUDE.md) on the diff and tag any FR/SC that could not be demonstrated.

