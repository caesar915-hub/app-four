# Feature Specification: Nutrition & Exercise Signals on the Day Card (Demo)

**Feature Branch**: `feat/nutrition-signals-demo`

**Created**: 2026-07-05

**Status**: Draft

**Input**: User description: "Nutrition and exercise signals on the calendar Day card (demo-only). Display four health signals from Apple Health — Dietary energy (kcal), Protein (g), Caffeine (mg), Active energy (kcal) — on the calendar Day card in both folded and unfolded states. Folded: two summary tokens (dietary kcal + caffeine mg). Unfolded: food and exercise events as first-class timeline check-in entries interleaved by time with mood check-ins, plus a per-day totals footer. New clay color lane for food, teal for exercise. Real Apple Health reads of timestamped samples plus deterministic mock seeding so the demo works on any device; real data wins per-day. Manual editor deferred. Demo-only: stacked on the unmerged 009-healthkit-signals work, no merge to main planned."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nutrition at a glance on the folded card (Priority: P1)

As a person tracking my ADHD medication and mood, when I scan my calendar I want each day's folded card to show how much I ate (kcal) and how much caffeine I had, next to the energy/focus/medication summary I already get — so I can spot "high-caffeine, unmedicated, low-mood" days without opening anything.

**Why this priority**: The folded card is the surface every calendar visit touches; caffeine-next-to-medication is the core demo story (stimulant interaction). If only this ships, the demo already lands its point.

**Independent Test**: With demo data enabled on a device that has no food logs, scroll the calendar: folded cards show a kcal token and a caffeine token for seeded days and nothing extra for days without data.

**Acceptance Scenarios**:

1. **Given** a day with nutrition data, **When** its card is folded, **Then** the summary line shows a dietary-kcal token and a caffeine token after the existing energy · focus · medication tokens (approved mockup V3).
2. **Given** a day with no nutrition data, **When** its card is folded, **Then** no nutrition tokens appear and the card is byte-identical to today's behavior.
3. **Given** a day where only caffeine was logged, **When** its card is folded, **Then** only the caffeine token appears.
4. **Given** VoiceOver is on, **When** the folded card is focused, **Then** the spoken label includes the day's calories and caffeine.

---

### User Story 2 - Meals and workouts as timeline entries on the unfolded card (Priority: P2)

When I expand a day, I want each meal (name, kcal, protein, caffeine) and each workout (name, minutes, active kcal) to appear as its own entry in the day's timeline, in time order among my mood check-ins, with a day-totals line at the bottom — so I can see *when* I ate or exercised relative to how I felt.

**Why this priority**: This is the "re-imagined" unfolded card (approved mockup variant A) and the visual heart of the demo, but it needs US1's data plumbing and is only reachable after expanding.

**Independent Test**: Expand a seeded day: food/exercise entries appear at their times interleaved with check-in rows, visually distinct (smaller hollow markers, clay for food, teal for exercise), read-only, with a totals footer (kcal in · protein · caffeine · kcal out) and a data-source indicator.

**Acceptance Scenarios**:

1. **Given** a day with 3 check-ins, 4 food events, and 1 workout, **When** the card is expanded, **Then** all 8 entries appear in one timeline ordered by time using the same ordering convention as existing check-in rows.
2. **Given** a food entry with kcal, protein, and caffeine, **When** displayed, **Then** all three values appear with units; absent values are simply not shown.
3. **Given** an expanded day with any nutrition or exercise data, **When** the timeline renders, **Then** a totals footer shows kcal in, protein, caffeine, and kcal out, with "—" for any metric that has no data, plus a provenance glyph (Apple Health vs manual).
4. **Given** a day with nutrition data but zero check-ins, **When** the user taps the card, **Then** it expands and shows the food/exercise entries and totals (today an empty day cannot expand).
5. **Given** a food or exercise entry, **When** the user taps it, **Then** nothing happens (read-only in the demo; no navigation chevron is shown).

---

### User Story 3 - Real Apple Health data wins over demo data (Priority: P3)

As the owner demoing on my own phone, when I have real food, caffeine, or workout entries in Apple Health, I want the card to show those real values for that day instead of demo values — without any prompt appearing on the calendar tab.

**Why this priority**: Real-data credibility matters for the demo's finale, but the demo functions end-to-end on seeded data alone.

**Independent Test**: Log a meal and caffeine in Apple Health (with health access already granted via the existing Insights flow), open the calendar: that day shows the real values; other days still show seeded values; no permission sheet ever appears from the calendar tab.

**Acceptance Scenarios**:

1. **Given** health access was previously granted and a real food entry exists for today, **When** the calendar loads, **Then** today's tokens, timeline entries, and totals reflect the real Apple Health values.
2. **Given** health access has never been offered, **When** the user browses the calendar, **Then** no permission prompt appears there (the existing health-access flow elsewhere in the app remains the only entry point).
3. **Given** demo data is disabled and no real data exists, **When** the calendar renders, **Then** no nutrition tokens, entries, or totals appear anywhere.
4. **Given** a day has both seeded demo data and real Apple Health nutrition data, **When** that day renders, **Then** the real data is shown for that day.

---

### Edge Cases

- **Partial day data**: only some metrics exist (e.g. caffeine only) → folded shows only existing tokens; totals show "—" for missing metrics; missing entries are absent, not placeholder rows.
- **Day boundary**: a sample timestamped 23:58 belongs to that local calendar day; the day rolls over at local midnight (existing day-key convention).
- **Very full day**: 6+ food events plus check-ins → the card grows vertically; entries never truncate values; scrolling the calendar list is the overflow mechanism.
- **Large Dynamic Type**: the folded summary line wraps to additional lines without truncation (existing behavior of that line).
- **Denied or unreadable health access**: indistinguishable from "no data" (platform behavior); the card simply shows nothing real — seeded data still demos.
- **Multiple sources double-logging** (e.g. two apps writing the same meal): values are shown as recorded; de-duplication is out of scope for the demo.
- **Dark mode**: both new color lanes have dark variants (approved mockups show both).
- **Demo data toggled off mid-session**: nutrition disappears from cards on next calendar refresh.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The folded day card MUST show a dietary-energy token (kcal) and a caffeine token (mg) appended after the existing energy, focus, and medication tokens whenever the day has that data, and MUST show no nutrition tokens otherwise (approved mockup V3).
- **FR-002**: The expanded day card MUST render each food event and each exercise event as its own read-only timeline entry, interleaved with check-in entries using the same time-ordering convention as existing rows (approved mockup variant A).
- **FR-003**: A food entry MUST display its name and any of: energy (kcal), protein (g), caffeine (mg). An exercise entry MUST display its name and any of: duration (min), active energy (kcal). Absent values are omitted.
- **FR-004**: The expanded card MUST end with a per-day totals footer — energy in (kcal), protein (g), caffeine (mg), energy out (kcal) — rendering "—" for metrics with no data, plus a provenance glyph distinguishing Apple Health from manually entered data.
- **FR-005**: A day with nutrition or exercise data but no check-ins MUST be expandable, showing its entries and totals.
- **FR-006**: Food entries MUST use the new clay color lane (#B5674A light / #CB8266 dark) and exercise entries the new teal lane (#3E8E86 light / #5FAEA5 dark), per the approved Pair 2 mockup; color MUST never be the only cue (distinct glyphs: fork for food, flame for exercise, cup for caffeine). The two new lanes MUST be recorded in the design system's Decisions Log.
- **FR-007**: Values MUST come from timestamped Apple Health samples (per-event), read on-device; per-day totals are derived from the same data.
- **FR-008**: When demo data is enabled, the system MUST seed 30 days of deterministic nutrition and exercise data (identical across re-seeds): meals at realistic hours, caffeine inversely correlated with medication days, roughly 2 of 30 days skipped entirely. Seeded data MUST be partitioned from real data using the existing mock-data mechanism and MUST never be written to Apple Health.
- **FR-009**: When a day has both demo and real nutrition data, the real data MUST be shown for that day.
- **FR-010**: The calendar MUST NOT trigger any health-permission prompt; it refreshes health data only if access was already offered through the existing flow elsewhere in the app.
- **FR-011**: The folded card's accessibility label MUST include the day's calorie and caffeine summary; timeline entries and the totals footer MUST be readable by VoiceOver with values and units.
- **FR-012**: All nutrition and exercise data MUST remain on-device (no server, no analytics payloads), consistent with the app's privacy posture.
- **FR-013**: Manual entry/editing of nutrition and exercise is OUT of scope; entries and totals are read-only in this feature.
- **FR-014**: Days without any nutrition/exercise data MUST render exactly as they do today (zero regression to the existing card).

### Key Entities

- **Food event**: one eating occasion at a point in time — name/label, energy (kcal), protein (g), caffeine (mg); source (Apple Health / demo).
- **Exercise event**: one workout at a point in time — name/label, duration (min), active energy (kcal); source.
- **Day nutrition totals**: per-local-day sums of energy in, protein, caffeine, energy out; derived, with a single provenance for display.
- **Existing check-in entry**: unchanged; food/exercise events interleave with it visually but do not alter it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a device with no food logs, enabling demo data populates nutrition on at least 28 of the last 30 day cards, and the folded kcal + caffeine values are visible without any tap.
- **SC-002**: For every seeded or real day, expanding the card shows 100% of that day's food/exercise events at the correct chronological position among check-ins.
- **SC-003**: For a day with real Apple Health data, every displayed value matches the value shown in the Apple Health app for that day.
- **SC-004**: Days without nutrition data render identically to the current release (side-by-side comparison shows no visual or behavioral difference).
- **SC-005**: A VoiceOver user can hear the day's calories and caffeine from the folded card and every entry's values from the expanded card.
- **SC-006**: No permission dialog ever originates from the calendar tab across a full demo run.

## Assumptions

- Demo-only scope: this ships on `feat/nutrition-signals-demo` (stacked on the unmerged 009-healthkit-signals branch, PR #8) and is not planned for `main`; the known merge collision with spec 029 on the folded-card summary is accepted.
- The three approved HTML mockups are the binding visual contract: `docs/superpowers/plans/2026-07-05-nutrition-signals-daycard.html` (folded V3), `2026-07-05-nutrition-checkins-unfolded.html` (variant A), `2026-07-05-nutrition-exercise-hues.html` (Pair 2 hues). This satisfies the mockup-before-UI gate (Constitution I).
- The existing 009 health stack (day-keyed signals storage, health service seam, sync coordination, provenance model) is reused and extended; per-event display additionally requires timestamped samples, which is new relative to 009's per-day aggregates.
- "Meal" naming from Apple Health data may be generic (e.g. "Food") when the source app provides no label; seeded demo data uses realistic names (Breakfast, Lunch, Coffee, Run…).
- Exercise duration comes from workout entries; a day's "energy out" total uses active energy.
- Local calendar day boundaries follow the app's existing day-key convention.
- The manual signals editor from 009 is not extended to nutrition in this feature (deferred).
