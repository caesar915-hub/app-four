# Feature Specification: QA fixes — med-bar scroll fade, calendar dot, Log-Dose colour

**Feature Branch**: `018-qa-review-fixes`

**Created**: 2026-06-24

**Input**: Owner screen-recording walkthrough on 2026-06-24, transcribed and matched to keyframes ([docs/qa-review-2026-06-24.md](../../docs/qa-review-2026-06-24.md)). Three correctness/fidelity gaps the owner flagged as "rules" to enforce — A2 the top scroll-fade behind the medication bar, A1 greyed calendar days losing their registered-state cue, A3 a missing/mismatched colour in the Log-Dose flow. Direction for A1 and A2 was decided with the owner before this spec; A4 (expanded day-card redesign drift) is explicitly deferred to its own spec.

---

## Overview

The 2026-06-24 walkthrough confirmed most of the calendar/day-card work is right, but surfaced three small, independently-shippable defects where the app contradicts the design system or hides real data. None changes data, schema, or behaviour beyond presentation:

1. **Restore the top scroll-fade behind the medication bar (A2).** The shared `EdgeFadeMask` dissolves scroll content at the bottom edge (into the tab bar) but the **top** fade is hardcoded to `0` on the two screens that pin the floating medication bar over their own scroll — Insights ([app-four/Views/InsightsView.swift#L113](../../app-four/Views/InsightsView.swift#L113)) and Settings (a `List` with no mask at all, [app-four/Views/SettingsView.swift#L43-L45](../../app-four/Views/SettingsView.swift#L43)). Content scrolls up *sharp* into and around the floating capsule instead of dissolving, which the owner called out directly ("the fade behind the medication bar is not working… the bottom fades, the top doesn't"). A stale rationale in `ScreenContainer` ("the bar is now translucent glass; content should frost under it, not fade to clear", [app-four/DesignSystem/ScreenContainer.swift#L43-L44](../../app-four/DesignSystem/ScreenContainer.swift#L43)) no longer holds: the bar is a **floating capsule with horizontal margins and a top gap** ([app-four/DesignSystem/MedicationBarOverlay.swift#L18-L24](../../app-four/DesignSystem/MedicationBarOverlay.swift#L18)), so it only frosts the area directly behind the pill — content in the side margins and above it has nothing occluding it.
2. **Keep registered days visibly registered when greyed (A1).** When a past day is selected, the calendar "filter-above" de-emphasis greys every more-recent day **and drops its mood marker dot** ([app-four/Views/Components/CalendarDayCell.swift#L52-L62](../../app-four/Views/Components/CalendarDayCell.swift#L52)), so a day that already has check-ins reads as empty/unregistered. The owner's rule: a greyed day with data must still show it has data. Decided direction: **keep the filled marker dot and let the existing parent opacity dim it** (the whole cell already carries `Opacity.deEmphasis`, [app-four/Views/Components/CalendarDayCell.swift#L36](../../app-four/Views/Components/CalendarDayCell.swift#L36)) rather than removing the dot entirely. This amends spec 014's FR-011/FR-014, which deliberately dropped the dot as a greyscale-safe second cue.
3. **Bring the Log-Dose sheet into the design language (A3).** Logging a dose (Check-in → Log meds) shows a colour the owner found "missing / not matching." The Log-Dose sheet ([app-four/Views/Components/MedicationLogSheet.swift](../../app-four/Views/Components/MedicationLogSheet.swift)) is a bare SwiftUI `Form` using default system chrome and ad-hoc `Color.secondary.opacity(...)` for chips, with no Paper & Pollen (`Theme`/`Palette`) tokens — unlike every other surface in the app. The exact mismatched element needs on-device reproduction to pinpoint; the fix is to audit the sheet against the design system and tokenise it so it matches.

**Out of scope (deferred to their own specs):**
- **A4 — expanded day-card redesign drift.** The in-app expanded `DayCard` interior lags the latest mockup (`mockups/summary/`, revised 2026-06-24, *after* the 014 build). This is a behavioural 014-daily-card redesign follow-up and gets its own spec after a mockup-vs-code diff. Not included here.
- **The Calendar screen's own top fade.** Calendar uses a separate header-opacity fade (the header scrolls into content and fades, spec 001 / commit `8cfe289c`); the owner scoped A2 to Insights + Settings. Whether Calendar's top edge also needs work is a verification item (see Edge Cases), not a change in this spec.
- Any redesign of the medication bar's shape, the tab bar, or the native Settings `List` chrome (the grouped-`List` typography exemption stands per 017).

**Coordination with feature 014 (daily card):** A1 reverses a deliberate decision in 014 (FR-011/FR-014 dropped the marker dot on above-selection days as a non-colour, greyscale-safe de-emphasis cue). This spec amends that: the dot stays, dimmed by opacity. The greyscale/Reduce-Transparency tradeoff (opacity-only de-emphasis is a weaker cue than a dropped dot for users who can't perceive the colour) is accepted by the owner and MUST be recorded in 014's spec so code and spec agree (FR-009 below). No 014 code other than `CalendarDayCell` is touched.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Content dissolves behind the medication bar (A2) (Priority: P1)

A user scrolls the Insights screen (and the Settings list) while the medication bar floats pinned at the top. Today the bubbles and rows scroll up and collide with sharp edges in the gaps beside and above the floating capsule — text stays crisp right up to the bar instead of dissolving, while the bottom of the list fades cleanly into the tab bar. The asymmetry looks broken. After this change, content fades to transparent as it approaches the top, mirroring the bottom dissolve, so the floating bar reads as sitting above a soft edge on both screens.

**Why this priority**: **P1** — the most visible of the three, on primary screens, and the one the owner emphasised (his only English sentence in the walkthrough). It is isolated, the direction is decided, and the bottom fade already proves the mechanism works.

**Independent Test**: On the Insights and Settings screens, scroll content toward the top and confirm it dissolves to transparent as it passes behind/around the floating medication bar, symmetric with the existing bottom fade; confirm the fade height tracks the bar's actual height as Dynamic Type grows.

**Acceptance Scenarios**:

1. **Given** the Insights screen with the medication bar shown, **When** the user scrolls content upward, **Then** content fades to transparent as it reaches the medication bar (no sharp text behind or beside the floating capsule), matching the bottom-edge dissolve.
2. **Given** the Settings screen with the medication bar shown, **When** the user scrolls the list upward, **Then** list content fades behind the medication bar at the top rather than scrolling sharply under it.
3. **Given** either screen at a large Dynamic Type size (which makes the bar taller), **When** the user scrolls, **Then** the top fade region still aligns with the bottom of the bar (the fade is not clipped short or overshooting because of a hardcoded height).
4. **Given** the medication bar is hidden in Settings (Show Medication Bar OFF), **When** the user scrolls Insights/Settings, **Then** no spurious top fade is applied where there is no bar (the top fade is tied to the bar's presence/height).
5. **Given** the Settings `List`, **When** the top fade is applied, **Then** scrolling, row selection, and the tab-reselect scroll-to-top still work (the mask does not break list interaction).

---

### User Story 2 - Greyed calendar days still show they're registered (A1) (Priority: P2)

A user taps a past day to focus it. Every more-recent day greys out (the filter-above de-emphasis) — but a more-recent day that already has check-ins loses its mood dot entirely and looks like a day with no data. The user can no longer tell, at a glance, which of the greyed days are actually registered. After this change, a greyed day that has check-ins keeps its mood-coloured dot (dimmed along with the rest of the cell), so "registered" survives the de-emphasis.

**Why this priority**: **P2** — a real data-visibility error (the owner: "it can't stay greyed, it has to show it's already registered"), but he framed it as a small thing and it affects only the transient filter-above state. Small, decided, low-risk.

**Independent Test**: Select a past day that has at least one more-recent day with check-ins; confirm the more-recent registered day greys/dims but still shows its mood-coloured marker dot; confirm a more-recent day with no check-ins shows no dot (unchanged); confirm the selected and older days are unaffected.

**Acceptance Scenarios**:

1. **Given** a selected past day and a more-recent day that has check-ins, **When** the calendar greys the more-recent day, **Then** that day still shows its mood-coloured marker dot (dimmed, not removed).
2. **Given** a more-recent (greyed) day that has *no* check-ins, **When** it is greyed, **Then** it shows no marker dot (behaviour unchanged — there was never data to show).
3. **Given** the greyed day with a dot, **When** compared to a non-greyed day with the same mood, **Then** the greyed day's whole cell (number + dot) reads as de-emphasised via reduced opacity, not as a different state.
4. **Given** VoiceOver is on, **When** the user focuses a greyed registered day, **Then** its accessibility label still conveys it has check-ins (the data-presence cue is not greyscale/opacity-only for assistive tech).

---

### User Story 3 - The Log-Dose sheet matches the app's design language (A3) (Priority: P3)

A user logs a medication dose from the check-in flow. The Log-Dose sheet looks off — a colour is missing or doesn't match the rest of the app, because the sheet uses default system form chrome and ad-hoc greys instead of the Paper & Pollen palette every other surface uses. After this change, the sheet's colours (background, chips, accents) match the design system, so logging a dose feels like part of the same app.

**Why this priority**: **P3** — real but the smallest and least certain: the exact mismatched element wasn't captured on a clean frame, so it needs on-device reproduction before the precise fix is known. Logging still works today; this is fidelity, not function.

**Independent Test**: Reproduce Check-in → Log meds on the simulator, capture the sheet, identify the off colour; then confirm the sheet's background, medication chips, and any accent colours use `Theme`/`Palette` tokens and match the design system in both light and dark mode.

**Acceptance Scenarios**:

1. **Given** the Log-Dose sheet is open, **When** the user views it, **Then** its surface and control colours use the app's design-system tokens (no default-system grey or ad-hoc opacity that reads as foreign to Paper & Pollen).
2. **Given** the medication chips, **When** one is selected vs unselected, **Then** the selected/unselected colours use the medication/design tokens consistently with the rest of the app (e.g. the medication accent, not an arbitrary grey).
3. **Given** dark mode, **When** the sheet is shown, **Then** all colours remain correct and legible (no token resolves to an unintended value).
4. **Given** the specific element the owner flagged (confirmed on-device), **When** re-checked after the fix, **Then** the previously missing/mismatched colour renders correctly.

---

### Edge Cases

- **Medication bar hidden** — with Show Medication Bar OFF, the top fade must not appear (or must collapse to zero) on Insights and Settings; the fade is tied to the bar's presence (US1 #4).
- **Dynamic Type / accessibility text sizes** — the bar grows taller with text size; the top fade height must be measured, not a constant, so it neither clips content early nor leaves a sharp band below the bar (US1 #3).
- **Settings is a native `List`, not a `ScrollView`** — applying an edge-fade mask to a `List` must not break scroll indicators, row separators, selection, or the tab-reselect scroll-to-top animation (US1 #5).
- **Greyed day with a *neutral* entry (entries but no mood)** — A1 should keep the neutral marker dot too, dimmed, since it still indicates the day is registered.
- **Calendar's own top region** — verify on-device whether the Calendar screen's header fade already covers the top adequately or also reads as sharp under the bar; if it regresses, raise separately (out of scope here unless it's the same root cause).
- **Reduce Transparency / greyscale users (A1 tradeoff)** — with the dot dimmed by opacity rather than dropped, de-emphasis is conveyed by opacity alone visually; the VoiceOver label must still distinguish "has check-ins" (US2 #4) so the data-presence cue is not purely visual.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Medication-bar scroll fade (US1 / A2)

- **FR-001**: On the Insights screen, scroll content MUST fade to transparent at the top edge as it passes behind the floating medication bar, symmetric with the existing bottom fade (replacing the current hardcoded `top: 0`).
- **FR-002**: On the Settings screen, list content MUST fade to transparent at the top edge behind the floating medication bar (Settings currently applies no edge-fade mask at all).
- **FR-003**: The top-fade region MUST be sized to the medication bar's actual rendered height (including its top gap), so the fade tracks the bar across Dynamic Type sizes rather than using a fixed constant.
- **FR-004**: When the medication bar is hidden, the top fade MUST be absent or zero on these screens (no fade where there is no bar).
- **FR-005**: Applying the top fade MUST NOT break existing scroll behaviour — Insights section paging/snapping, Settings list scrolling/selection/separators, and the tab-reselect scroll-to-top — on either screen.
- **FR-006**: The stale "frost under translucent glass / no top fade" rationale in `ScreenContainer` and `InsightsView` MUST be corrected so the code comments match the restored fade behaviour.

#### Calendar registered-day cue (US2 / A1)

- **FR-007**: A greyed (above-selection) calendar day that has check-ins MUST display its mood-coloured marker dot; the dot MUST NOT be removed solely because the day is greyed.
- **FR-008**: The greyed day's marker dot MUST be de-emphasised by the same cell-level opacity as the rest of the cell (number + dot dim together), not shown at full strength and not dropped.
- **FR-009**: Spec 014's FR-011/FR-014 MUST be amended to reflect the dot being dimmed rather than dropped, recording the accepted greyscale/Reduce-Transparency tradeoff so spec and code agree.
- **FR-010**: A greyed day with *no* entries MUST continue to show no marker dot (no behaviour change for empty days).
- **FR-011**: The accessibility label for a greyed registered day MUST still convey that it has check-ins/entries (the registered-state cue MUST NOT become opacity-only for assistive technology).

#### Log-Dose colour fidelity (US3 / A3)

- **FR-012**: The Log-Dose sheet's surface and control colours MUST use the app's design-system tokens (`Theme`/`Palette`) consistent with other surfaces, rather than default system chrome or ad-hoc greys.
- **FR-013**: The medication chips' selected and unselected states MUST use design-system colours (the medication accent and a tokenised unselected fill), not arbitrary opacity-on-`Color.secondary`.
- **FR-014**: The specific missing/mismatched colour the owner flagged MUST be identified by on-device reproduction and corrected; the fix MUST be verified in both light and dark mode.

### Non-Functional / Cross-Cutting

- **FR-015**: All three fixes are presentation-only — they MUST NOT change any persisted data, SwiftData schema, or the medication-logging/check-in/data behaviour; only visual rendering changes.
- **FR-016**: Each fix MUST be independently shippable and independently revertable (separate, focused changes), so any one can land or roll back without the others.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On Insights and Settings, scroll content visibly dissolves behind the medication bar at the top, symmetric with the bottom fade — verified on-device in light and dark mode, at default and an accessibility Dynamic Type size.
- **SC-002**: The top fade aligns with the bar at every tested text size (no sharp band, no premature clipping) and disappears when the bar is hidden.
- **SC-003**: Selecting a past day leaves every more-recent day that has check-ins still showing a (dimmed) mood dot; zero registered days read as empty in the filter-above state.
- **SC-004**: A source/behaviour check confirms empty greyed days still show no dot, and VoiceOver still announces "has check-ins" for greyed registered days.
- **SC-005**: Spec 014 records the amended dot-dimming decision and its tradeoff (no silent divergence between 014's text and the shipped `CalendarDayCell`).
- **SC-006**: The Log-Dose sheet matches the design system (tokenised colours, correct in light and dark), and the originally-flagged colour renders correctly when re-checked on-device.
- **SC-007**: The full test suite remains green and the app builds and runs after all three fixes; no data/behaviour regression is observed in the check-in, calendar, or medication-logging flows.

## Assumptions

- **A1 direction is settled and overrides 014.** The owner chose "keep the filled dot, just dim it" over the alternatives (hollow/outline dot; or leaving the dot dropped and updating only the spec). The greyscale/Reduce-Transparency weakening is accepted and will be documented in 014, not litigated again.
- **A2 is scoped to Insights + Settings.** The owner named these two screens. Calendar keeps its separate header-opacity fade; other screens using the scrollable `ScreenContainer` path are not in scope unless found to share the exact defect (verification item, not a committed change).
- **The fade is a top-edge mask sized to the bar.** The intended mechanism is the existing `EdgeFadeMask` (or equivalent) with a measured top height, not a redesign of the bar or a translucent-material approach; the bar stays a floating capsule.
- **A3's precise element is unknown until reproduced.** The walkthrough didn't capture a clean frame of the mismatch. The fix is framed as "tokenise the Log-Dose sheet to the design system," with the specific element confirmed on-device; if reproduction reveals the issue is *not* a missing token but something else (e.g. a wrong `Palette` value), the FR-012/013 audit still covers correcting it.
- **No data-model work.** None of the three fixes adds, removes, or migrates persisted state or schema; they are view/styling changes, so the test burden is build-and-run verification plus any existing view-logic tests, consistent with the SwiftUI-view exemption in Principle X.
- **A4 is deferred, not dropped.** The expanded day-card redesign drift is tracked for its own spec after a mockup-vs-code diff; excluding it here keeps this feature a tight, low-risk QA pass.
