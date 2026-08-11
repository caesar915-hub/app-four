# Feature Specification: Nutrition Day Card + Sleep Hours Sync (Demo)

**Feature Branch**: `018-nutrition-day-card`

**Created**: 2026-08-03 22:35 UTC

**Status**: Draft

**Input**: User description: "Create the feature specification from docs/NUTRITION_DAYCARD_IMPLEMENTATION_PLAN.md (primary source) and docs/NUTRITION_DAYCARD_FSD.md (requirements source): Nutrition Day Card + Sleep Hours Sync demo — Apple Health / Health Connect read-only sync of nutrition (kcal, protein, caffeine), exercise, and sleep hours onto the calendar day card (folded tokens + unfolded timeline + totals footer), deterministic 30-day demo seeding via the mock- partition, real-wins-per-day resolution, and a Settings health section (sync switch, delete imported data, last sync time)."

## Clarifications

### Session 2026-08-03

- Q: When should sleep sync trigger, given synced sleep is stored against a check-in — what should a calendar-visit sweep do about sleep when there is no triggering check-in? → A: Sleep syncs only after a completed check-in (attached to that check-in); the once-per-day surface sweep covers nutrition/exercise only.
- Q: Should the calendar show any indication while a health sync runs or when it completes? → A: Fully silent — imported data simply appears on the next visit; the Settings "last sync" time is the only visible record of sync activity.
- Q: What performance acceptance target should apply to the calendar under full demo load? → A: Existing bar only — scrolling and card expand/collapse must stay within the app's current frame-performance budget with 30 seeded days; no new feature-specific target.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spot nutrition on the calendar at a glance (Priority: P1)

The user opens the Calendar tab and, on days that have nutrition data, sees a calorie token and a caffeine token appended to the folded day card's existing signal tokens — without tapping anything. With demo data enabled, this works on any device, so the feature can be experienced end-to-end without real health logs.

**Why this priority**: This is the core value proposition — pattern-spotting ("high-caffeine, unmedicated, low-mood" days) with zero interaction. It is also the demo's storefront: if the folded tokens land, the feature is demonstrable.

**Independent Test**: Enable demo data on a device with no food logs, open the Calendar tab, and confirm that at least 28 of the last 30 day cards show calorie and caffeine tokens with no tap required — a complete, shippable slice on its own.

**Acceptance Scenarios**:

1. **Given** a day with dietary-energy and caffeine data, **When** the user views the folded day card, **Then** a kcal token and a caffeine token appear after the existing energy · focus · medication · sleep tokens.
2. **Given** a day with only caffeine data, **When** the user views the folded card, **Then** only the caffeine token appears (no placeholders for missing metrics).
3. **Given** a day with no nutrition or exercise data, **When** the user views the folded card, **Then** it renders exactly as it does today — no nutrition tokens, no layout change.
4. **Given** demo data enabled and no real food logs, **When** the user opens the calendar, **Then** at least 28 of the last 30 days show nutrition tokens.

---

### User Story 2 - Expand a day to see the food and exercise story (Priority: P2)

The user taps a day card and it unfolds into a timeline where each food event and each exercise event appears as its own read-only entry, interleaved by time with check-in and medication rows — visually distinct lanes (clay for food, teal for exercise) with distinct glyphs. A totals footer closes the card: energy in, protein, caffeine, energy out, with a cue for whether the data came from the OS health platform or from demo seeding.

**Why this priority**: The unfolded detail is what turns a glance into understanding — it proves nutrition/exercise as a first-class timeline lane. It depends on the same data pipeline as Story 1 but ships independently: Story 1 alone is already a viable demo.

**Independent Test**: Expand any seeded day and verify 100% of that day's food/exercise events appear at the correct chronological positions among check-ins, the footer totals reconcile exactly with the visible entries, and tapping an entry does nothing.

**Acceptance Scenarios**:

1. **Given** a day with food, exercise, and check-in entries, **When** the user expands the card, **Then** every food and exercise event appears as its own timeline entry at its recorded time, interleaved with existing rows in the established ordering.
2. **Given** a food entry with only some metrics (e.g., energy but no protein), **When** it renders, **Then** only the present values are shown; an unnamed event displays as "Food" (exercise: "Workout").
3. **Given** any expanded day with nutrition data, **When** the user reads the footer, **Then** it shows energy in (kcal), protein (g), caffeine (mg), and energy out (kcal) — with "—" for absent metrics — and energy out equals the sum of that day's exercise entries' active energy only.
4. **Given** a day with nutrition data but zero check-ins, **When** the user taps the card, **Then** it expands and shows its entries and totals.
5. **Given** any food or exercise entry, **When** the user taps it, **Then** nothing happens and no navigation affordance is shown (read-only).

---

### User Story 3 - See measured sleep on the day card (Priority: P2)

With health access previously granted, the user's measured sleep duration appears on the day card through the existing sleep lane — in hours and minutes — preferred over self-reported sleep values when both exist. Sync happens quietly after a check-in, never interrupting anything.

**Why this priority**: Sleep is the highest-signal health metric for this audience and completes the "body signals" picture alongside nutrition. It is independently valuable and independently testable from the nutrition lanes.

**Independent Test**: With health access granted, complete a morning check-in; that day's card shows the measured sleep duration in the folded tokens and in the expanded row detail. With access absent, the card behaves exactly as before.

**Acceptance Scenarios**:

1. **Given** health access granted and a completed check-in, **When** the day's card renders, **Then** the measured sleep duration (hours and minutes) appears in the sleep lane.
2. **Given** both measured and self-reported sleep exist for an entry, **When** the card renders, **Then** the measured value is displayed.
3. **Given** a failed or unavailable sleep sync, **When** the user completes a check-in, **Then** the check-in completes normally and the card shows whatever data it already had — no error surfaces.
4. **Given** a day with no check-ins, **When** the card renders, **Then** no synced sleep is shown for that day in this iteration.

---

### User Story 4 - Control health syncing from Settings (Priority: P3)

The user opens Settings and finds a health section with a single sync switch (platform-appropriate naming — Apple Health / Health Connect), the last completed sync time, a note that read permission is managed in the OS health app, and a "Delete Imported Health Data" action behind confirmation. Turning the switch off offers "Stop and delete?" (Keep Data / Delete, keep by default).

**Why this priority**: Privacy control is mandatory for trust, but the demo's core loop (Stories 1–3) can be proven with seeded data before real-sync controls are exercised.

**Independent Test**: Toggle the switch and confirm every health read in the app stops; delete imported data and confirm all imported values vanish while manual and demo data remain; re-enable and confirm syncing resumes on the next calendar visit without reinstalling.

**Acceptance Scenarios**:

1. **Given** the switch is on, **When** the user turns it off and chooses "Keep Data", **Then** no health reads occur anywhere until re-enabled, and already-imported data remains visible.
2. **Given** imported health data exists, **When** the user taps "Delete Imported Health Data" and confirms, **Then** all imported copies on device are removed (nutrition/exercise events and synced sleep), while check-ins, self-reported data, and demo data remain, and the OS health store is untouched.
3. **Given** syncing was disabled, **When** the user re-enables the switch and visits the calendar, **Then** the once-per-day sync resumes automatically.
4. **Given** any state of the feature, **When** the user browses the calendar, **Then** no permission dialog ever originates from the calendar — the permission sheet only ever appears from the Settings switch.

---

### Edge Cases

- **Day boundary**: a sample recorded at 23:58 belongs to that local calendar day; day membership follows local midnight rollover.
- **Duplicate logging**: two apps writing the same meal to the health platform — values are shown as recorded; de-duplication beyond the platform's own duplicate removal is out of scope for the demo.
- **Sync disabled mid-sweep**: an in-flight day's update finishes atomically; the switch gates the start of reads, so no partial-day writes are torn.
- **Delete while demo data is on**: seeded demo data survives (it is not "imported"); cards fall back to demo values per the real-wins rule.
- **Re-seed vs re-sync**: demo rows are removed only by the demo seeding/removal path, never by health re-sync; imported rows are never touched by the seeder.
- **Denied or unreadable access**: indistinguishable from "no data" by platform design; the UI never claims denial; demo data still demos.
- **Device locked (mobile OS data protection)**: the sync skips quietly and retries on the next surface visit; no crash, no error UI.
- **Very full day**: 6+ food events plus check-ins — the card grows vertically, values never truncate, list scroll is the overflow mechanism.
- **Large text / dark mode**: the folded summary line wraps without truncation; both new color lanes have dark-mode variants.
- **Clear All Data**: the app's existing "erase everything" action also removes stored nutrition/exercise events.

## Requirements *(mandatory)*

### Functional Requirements

**Folded card summary**

- **FR-001**: The folded day card MUST show a dietary-energy token (kcal) and a caffeine token (mg) appended after the existing signal tokens whenever the day has that data; days without nutrition data show no nutrition tokens.
- **FR-002**: Only tokens with data MUST appear; missing metrics are absent, never placeholder rows.
- **FR-003**: Days without any nutrition/exercise data MUST render identically to the current release (byte-identical folded presentation).
- **FR-004**: The folded card's accessible description MUST include the day's calorie and caffeine summary, and the sleep duration when present.

**Unfolded card timeline**

- **FR-005**: The expanded card MUST render each food event and each exercise event as its own timeline entry, interleaved with existing entries by time using the established ordering convention.
- **FR-006**: A food entry MUST display its name and any of: energy (kcal), protein (g), caffeine (mg); an exercise entry MUST display its name and any of: duration (min), active energy (kcal); absent values are omitted; unnamed events display as "Food" / "Workout".
- **FR-007**: The expanded card MUST end with a per-day totals footer — energy in (kcal), protein (g), caffeine (mg), energy out (kcal) — rendering "—" for metrics with no data, plus a provenance cue distinguishing imported from demo data; energy out MUST be the sum of that day's exercise entries' active energy only.
- **FR-008**: A day with nutrition or exercise data but zero check-ins MUST be expandable, showing its entries and totals.
- **FR-009**: Food and exercise entries MUST be read-only: tapping does nothing and no navigation affordance is shown.
- **FR-010**: Food entries MUST use the clay lane (`#B5674A` light / `#CB8266` dark) and exercise entries the teal lane (`#3E8E86` light / `#5FAEA5` dark); color MUST never be the only cue — distinct glyphs (fork = food, flame = exercise, cup = caffeine) and smaller hollow markers distinguish these rows from check-in rows.

**Data, sync & seeding**

- **FR-011**: Nutrition and exercise values MUST be persisted on-device as timestamped events; the card MUST render from the stored data, never from live health-platform queries; re-syncing a day MUST replace that day's imported rows atomically rather than duplicate them.
- **FR-012**: Demo mode MUST seed 30 days of deterministic nutrition and exercise data (identical across re-seeds): meals at realistic hours, caffeine inversely correlated with medication days, roughly 2 of 30 days skipped entirely; seeded data MUST be clearly partitioned, independently removable, and never written to the OS health store.
- **FR-013**: When a day has both demo and real data, the real data MUST win for that day — all-or-nothing per day, never mixed within a day.
- **FR-014**: The calendar MUST never trigger a health-permission prompt; reads occur only when syncing is enabled and access was previously granted. Sync activity MUST surface no indicator, toast, or notification on the calendar — imported data simply appears on the next visit, and the Settings last-sync time (FR-023) is the only visible record of sync activity.
- **FR-015**: All nutrition, exercise, and sleep data MUST remain 100% on-device — no server, no analytics payloads, no telemetry — and MUST be excluded from OS-level backups, consistent with the app's zero-cloud privacy posture.
- **FR-016**: Day membership MUST follow the local calendar day (local-midnight rollover); a sample at 23:58 belongs to that day.

**Sleep hours sync**

- **FR-017**: With syncing enabled, the app MUST read the previous night's total asleep duration after each completed check-in — and only then; calendar/insights visits do not trigger sleep reads.
- **FR-018**: Synced sleep MUST be stored on-device against the check-in that triggered the sync; the card MUST render from stored data, never live queries; days without check-ins carry no synced sleep in this iteration.
- **FR-019**: The day card MUST display measured sleep duration (hours and minutes) through the existing sleep lane, preferred over self-reported sleep when both exist.
- **FR-020**: Sleep sync MUST be failure-isolated: it runs after the check-in is saved, never blocks or fails a check-in, and surfaces no error UI; locked-device or denied states are silently skipped and retried.

**Settings — health section**

- **FR-021**: Settings MUST offer a single sync switch (platform-appropriate naming) that gates every health read in the app through one shared control; the default is off until access is granted through the switch; turning it off MUST NOT delete data by itself.
- **FR-022**: Settings MUST offer "Delete Imported Health Data" behind explicit confirmation, removing all imported copies on device (nutrition/exercise events and synced sleep) while leaving check-ins, self-reported data, demo data, and the OS health store untouched; the same choice MUST be offered inline when the switch is turned off ("Stop and delete?" — Keep Data / Delete), defaulting to keeping; re-enabling the switch resumes syncing on the next surface visit.
- **FR-023**: The section MUST show the last completed sync time and state that read permission is managed in the OS health app (the app cannot revoke it programmatically).

### Key Entities *(include if feature involves data)*

- **Food Event**: one logged meal or food item — optional name, timestamp, and any of energy (kcal), protein (g), caffeine (mg); provenance (imported from the health platform vs. demo seed).
- **Exercise Event**: one logged workout — optional name, start time, and any of duration (min), active energy (kcal); provenance as above.
- **Day Totals**: derived per-day sums (energy in, protein, caffeine, energy out) computed from that day's visible events, so the footer always reconciles with the timeline.
- **Sleep Record**: measured nightly asleep duration (minutes precision), attached to the check-in that triggered its sync; provenance is always "imported".
- **Sync Settings**: the user's sync-enabled preference and the last completed sync time.
- **Demo Data**: the seeded 30-day nutrition/exercise dataset — deterministic, clearly partitioned from imported data, independently removable.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With demo data enabled on a device with no food logs, at least 28 of the last 30 day cards show calorie and caffeine tokens with no tap required.
- **SC-002**: For every seeded or real day, 100% of that day's food/exercise events appear at the correct chronological position among check-in rows when the card is expanded.
- **SC-003**: For any day with real health-platform data, 100% of displayed values match the OS health app for that day.
- **SC-004**: Days without nutrition data render pixel-identically to the current release in side-by-side comparison.
- **SC-005**: A screen-reader user hears the day's calories, caffeine, and sleep duration from the folded card and every entry's values and units from the expanded card.
- **SC-006**: Zero permission dialogs originate from the calendar across a full demo run.
- **SC-007**: After disabling sync and deleting imported data, zero imported values remain visible anywhere in the app and zero health reads occur on subsequent visits; re-enabling restores sync on the next visit without reinstalling.
- **SC-008**: After a check-in with health access granted, the measured sleep duration appears on that day's card; a failed sync leaves 100% of check-ins completing normally with previously available data shown.
- **SC-009**: With 30 days of demo data seeded (including worst-case days of 6+ food events plus check-ins), calendar scrolling and day-card expand/collapse remain within the app's established frame-performance budget — no fluidity regression versus the current release.

## Assumptions

- Kilocalories are displayed regardless of locale (kJ localization is deferred).
- Nutrition and exercise entries are read-only in this iteration; manual entry/editing is deferred.
- Demo data is controlled through the app's existing debug/demo controls and is sequestered from imported data by construction.
- Health access is granted (or denied) only through the Settings sync switch; denial is indistinguishable from "no data" and is treated as such.
- The OS health platform's own duplicate removal is the only de-duplication applied in this iteration.
- Synced sleep attaches to a check-in; a day with no check-ins shows no synced sleep (accepted limitation of this iteration).
- Sync cadence: nutrition/exercise sync once per day per surface visit; sleep syncs only after each completed check-in; no background syncing.
- Energy-out totals count workout active energy only; non-workout movement is excluded.
- Non-functional constants (30-day seed window, color lanes, glyph set, per-clock-hour grouping of loose food samples) follow the decisions recorded in `docs/NUTRITION_DAYCARD_FSD.md`.