# Screen-Recording Feedback → Change Plan (2026-06-15)

**Status:** Planning only — no code changed.
**Source:** Four iOS screen recordings with voice commentary in `docs/superpowers/`.
**Author of commentary:** product owner (walkthrough of a live build, mock-data mode partly on).

## How the commentary was captured

The four `.MP4` files are iOS ReplayKit captures (HEVC video + AAC audio). Claude
cannot ingest audio directly, so the commentary was transcribed with `whisper.cpp`
(`small.en` model) off ffmpeg-extracted 16 kHz mono WAVs, then hand-corrected against
keyframes pulled at the moments each remark was made. The speaker is a non-native
English speaker; ASR slips (e.g. "crawling" → *scrolling*, "mount" → *month*,
"pretty fault" → *pre-defaulted*) were corrected from screen context and are marked
`[ASR]` where the reading is inferred rather than certain.

| # | File | Duration | Screen(s) | Theme |
|---|------|----------|-----------|-------|
| 1 | `RPReplay_Final1781545214.MP4` | 2:26 | Calendar + Insights | Mock-data crash, bar disappears, scroll/fade/spacing, day-selection scroll |
| 2 | `RPReplay_Final1781545309.MP4` | 0:56 | Med bar (on Settings/Calendar) | Tap target must cover the whole bar |
| 3 | `RPReplay_Final1781545396.MP4` | 0:58 | Log Dose sheet | Replace free-text name with a medication picker from the DB |
| 4 | `RPReplay_Final1781545559.MP4` | 1:05 | Recording detail | Transcribe placeholder, slow/failed transcription, remove back button, bar consistency |

---

## Recording 1 — Calendar & Insights scroll behaviour (2:26)

> **Cleaned transcript.** "So it seems we have a crash here when we use the synthetic
> data. Here we have a medication logged at 16:47 but the bar seems to have
> disappeared — I hope this is only for the mock data. So here we have the medication
> [bar] on top in all the views; this scrolling is good, the principle seems to work.
> But when I scroll down I see this on the bottom part of the next card and it's not
> adjusted. Now scroll is fine, here is fine, but here the connection disappears with
> the month selection. When I go up it's fine, but sometimes it doesn't get the proper
> place. Here we have the medication bar and here we have the bar — these can't be
> aligned, as mentioned. So here I have months; these should not move down — it should
> filter the daily card to the top so I don't have to scroll back to the previous
> position. Here we're on 15; when we move to 14 we go down — it should filter to the
> top. And 'today' [button] can also be removed, you need to be there. Always align —
> something like this space — between the daily card and the medication bar. Also the
> scrolling here is not fading: I still see 'June' on top of the medication bar, and if
> I keep moving I see the card. It should fade like it fades below. Here the month and
> the daily-card selector fade, but afterwards it does not fade the daily card."

### 1.1 — Crash when using synthetic / mock data
- **Requested:** App must not crash when synthetic data is enabled.
- **Where:** [MockDataGenerator.swift](app-four/Utils/MockDataGenerator.swift) (generation) and the refresh it triggers in [MedicationBarViewModel.refresh()](app-four/ViewModels/MedicationBarViewModel.swift#L80).
- **Notes:** No deterministic crash is visible by inspection — the force-unwraps (`randomElement()!` on non-empty enums, lines 27‑33) are safe and the hour math stays in range. Likely a SwiftData relationship/threading issue (`event.recording = recording` set after insert, line 106) or a downstream consumer of the mock rows.
- **Action:** Reproduce with the mock toggle, capture the crash log/stack, then fix at the real site. **Do not guess-patch.** Treat as a bug, not a tweak.

### 1.2 — Medication bar disappears in mock mode despite an active dose
- **Observed:** A mock dose logged at 16:47 (87% elapsed in the timeline) shows no bar at the top; the bar is present on non-mock data.
- **Where:** [MedicationBarViewModel.refresh()](app-four/ViewModels/MedicationBarViewModel.swift#L80-L97) — predicate filters `isMockData == mockMode` (line 84), then `.filter { takenAt + durationHours·3600 > now }` and `.prefix(3)` (lines 95‑97).
- **Hypothesis:** In mock mode the fetch is scoped to mock rows, but the active-window filter + `prefix(3)` may exclude the 16:47 dose, or `debugMockMode` is out of sync with what the timeline renders. The owner themselves flagged it as "I hope this is only mock data."
- **Action:** Confirm whether this is mock-only (acceptable) or a real-data regression (must fix). Add a unit case to [MedicationBarViewModelTests.swift](app-fourTests/ViewModels/MedicationBarViewModelTests.swift) covering an active mock dose.

### 1.3 — Top fade not working: content shows *through* the medication bar
- **Requested:** Scroll content must fade to transparent *under* the medication bar the same way it fades into the tab bar at the bottom. Currently "June" (month label) and card content remain visible on/through the bar.
- **Root cause:** Top fade is hard-disabled. [ScreenContainer](app-four/DesignSystem/ScreenContainer.swift#L43-L44) sets `barFadeHeight = 0` and applies `edgeFadeMask(top: 0, …)` (line 70); [CalendarLibraryView.timelineList](app-four/Views/Library/CalendarLibraryView.swift#L78) likewise passes `top: 0`. The code comment claims the bar is "translucent `.bar` material … content should frost under it" — but the bar is actually **Liquid Glass** (`.glassEffect(.regular)`, [MedicationBarView.swift:24](app-four/Views/Components/MedicationBarView.swift#L24)), which is *see-through*, so content bleeds through instead of dissolving. The mask + the bar material are fighting each other.
- **Secondary cause (Calendar only):** The month header + weekday/day selector live **outside** the scroll view (fixed `CalendarHeaderView` in the [VStack](app-four/Views/Library/CalendarLibraryView.swift#L27-L41), above `timelineList`). A fade applied to the scroll view can never fade that fixed header — which is exactly the "I still see June on the bar" symptom.
- **Decision (confirmed 2026-06-15): Real top fade, keep the glass.** Restore a non-zero `topFade` in [EdgeFadeMask](app-four/Views/Components/EdgeFadeMask.swift) sized to the **measured** bar height (Dynamic Type-safe), feed it to the `top:` argument in [ScreenContainer](app-four/DesignSystem/ScreenContainer.swift#L44) and [CalendarLibraryView.timelineList](app-four/Views/Library/CalendarLibraryView.swift#L78), and route the Calendar's fixed header into the faded region (or fade it separately) so "June" dissolves too. The `.glassEffect` bar stays — content fades to clear before it reaches the bar, the same treatment the owner likes at the bottom edge. Update the stale "no top fade" comments at [ScreenContainer.swift:43](app-four/DesignSystem/ScreenContainer.swift#L43) and [EdgeFadeMask.swift:7](app-four/Views/Components/EdgeFadeMask.swift#L7).

### 1.4 — Selecting a day should pin that day's card to the top, not scroll away
- **Requested:** Tapping a day (e.g. 15 → 14) should bring that day's card to the top of the timeline so the user never scrolls back. Today the list "goes down" / "sometimes doesn't get the proper place."
- **Where:** The intent is already implemented — [CalendarLibraryView.scrollList(to:)](app-four/Views/Library/CalendarLibraryView.swift#L96-L106) animates `topDayID` and the list uses `.scrollPosition(id:anchor:.top)` ([line 77](app-four/Views/Library/CalendarLibraryView.swift#L77)). So this is a **reliability bug**, not a missing feature.
- **Likely issues:** (a) `.top` anchor scrolls the card under the fixed header + bar (no inset accounting for header height); (b) the 0.45s `isProgrammaticScroll` guard ([line 103](app-four/Views/Library/CalendarLibraryView.swift#L103)) races with the user's own scrolling, occasionally resetting `selectedDay`.
- **Action:** Account for the header/bar height when anchoring to `.top` (content inset or a scroll anchor below the header), and verify the guard timing against the animation. Existing coverage: [CalendarMonthModelTests](app-fourTests/ViewModels/CalendarMonthModelTests.swift).

### 1.5 — Consistent spacing between the daily card and the medication bar
- **Requested:** A fixed, consistent gap between the medication bar and the first daily card across screens.
- **Where:** Top padding of the timeline ([CalendarLibraryView.swift:74](app-four/Views/Library/CalendarLibraryView.swift#L74) `.padding(.top, Spacing.m)`) vs. the bar's own insets in [MedicationBarOverlay](app-four/DesignSystem/MedicationBarOverlay.swift#L21-L22). These are set independently per screen.
- **Action:** Define one spacing token for "below the medication bar" and apply it wherever the bar sits above scroll content (Calendar, Insights, Recording detail). Cross-reference §4.4 (bar consistency).

### 1.6 — Timeline connector line disappears near the month selector
- **Requested:** The vertical connector between timeline beads should not vanish when scrolled near the month/selector region.
- **Where:** [TimelineBead.swift](app-four/Views/Components/TimelineBead.swift) / [TimelineRow.swift](app-four/Views/Components/TimelineRow.swift) / [DayCard.swift](app-four/Views/Components/DayCard.swift) — the connector is likely being clipped by the same edge mask discussed in §1.3, or by a card clip bound.
- **Action:** Confirm whether the fade mask (§1.3) is clipping it; fix alongside the fade rework.

### 1.7 — "Today" button — keep it
- **Decision (confirmed 2026-06-15): Keep the Today button.** The owner's intent was "today's row must always remain reachable," not "remove the control."
- **Where:** [CalendarHeaderView](app-four/Views/Components/CalendarHeaderView.swift#L73-L83), gated by `canJumpToToday`.
- **Action:** No change to the button. Just ensure the jump-to-today path lands the card correctly under the fixed header (ties to §1.4).

---

## Recording 2 — Medication bar tap target (0:56)

> **Cleaned transcript.** "Regarding the medication bar on top: if I click in the
> middle, that's what happens [nothing]. But if I click on the end, it logs / shows
> [the menu]. I need it to appear from any place when I click anywhere on the
> medication bar. Here we have check-ins, and since medication was logged it seems
> fine. Let me type to check… okay, we have a new medication, here it's fine, it works.
> So what we have here is this scrolling [ASR]; when I press I can delete — so it's
> taking [removing] this medication."

### 2.1 — Whole bar row must be tappable
- **Requested:** Tapping **anywhere** on a medication-bar row must open the "Log new dose / Delete this dose" dialog. Currently only the ends/filled areas respond; the empty middle does nothing.
- **Root cause:** [MedicationBarView.doseRow](app-four/Views/Components/MedicationBarView.swift#L56-L92) is a `.plain` `Button` whose label is a `ZStack` containing a **partial-width** progress `Rectangle` (`scaleEffect(x: progress…)`, [lines 61‑64](app-four/Views/Components/MedicationBarView.swift#L61)) and an `HStack` of two `Text`s pinned left/right. With no `.contentShape`, SwiftUI hit-tests only the opaque sub-views — so the transparent gap between the labels (and beyond the progress fill) isn't tappable.
- **Fix:** Add `.contentShape(Rectangle())` (or `barShape`) to the row label so the full `maxWidth: .infinity × height` frame is hit-testable. One-line, low-risk.
- **Verify:** The confirmation dialog ([lines 25‑44](app-four/Views/Components/MedicationBarView.swift#L25)) already provides Log/Delete — only the hit area is wrong.

---

## Recording 3 — "Log Dose" sheet: medication picker from the database (0:58)

> **Cleaned transcript.** "Regarding the medication check-in: when I press 'Log med' I
> get this card again. Here I don't want to *type* the medication name — I need a
> pre-selected medication, as developed in the previous mockups. Those should come from
> the database, so I select among the ones shown. After I select the medication it
> shows the dose, then the onset time just for information; the taken time is
> pre-defaulted to the current time, and the duration also appears. As in the previous
> design we must be able to input a custom duration. We display the interval — the
> interval is available in the database — but the text field must still be available to
> write a *new* medication."

### 3.1 — Replace free-text name with a medication selector (existing meds + add-new)
- **Requested behaviour:**
  1. Show medications already in the database as selectable options (don't force typing).
  2. Selecting one auto-fills its **dose**.
  3. Show **onset time** (informational only).
  4. **Taken time** defaults to now (✅ already does).
  5. Show **duration**, and allow a **custom duration**.
  6. Show **interval** (from the DB).
  7. Keep a text field to add a brand-new medication.
- **Where it's wrong today:** [MedicationLogSheet](app-four/Views/Components/MedicationLogSheet.swift#L14-L23) is two raw `TextField`s (`Name`, `Dose`) + a time `DatePicker`. No picker, no onset/duration/interval.
- **The pattern already exists:** The check-in composer was specced with "meds chips (recent names + '+ add' via MedicationLogSheet)" — see [check-in implementation doc, line 919](docs/superpowers/plans/2026-06-12-checkin-view-implementation.md) and [TextCheckInComposer.swift](app-four/Views/CheckIn/TextCheckInComposer.swift). The standalone sheet (opened from the bar's "Log new dose", [MedicationBarView.swift:45‑49](app-four/Views/Components/MedicationBarView.swift#L45)) never adopted it.
- **"The database" is a curated catalog the owner already produced.** It lives in the Claude Code chat from 2026-06-15 15:18 (`~/.claude/projects/-Users-caesargrey-Projects-app-four/7bd9817a-34bb-487a-b283-f0c6f1d2ee7b.jsonl`, prompt: *"pull from the web ADHD medications available in Europe stimulant class and dosages… onset time, duration time… organized in table"*). The distilled final table is the seed data for the picker:

  | Medication | Dosage options (mg) | Onset (min) | Duration (h) |
  |---|---|---|---|
  | Methylphenidate IR (Ritalin, Medikinet) | 5, 10, 20 | 20 | 3 |
  | Medikinet retard | 5, 10, 20, 30, 40, 60 | 30 | 6 |
  | Equasym XL | 10, 20, 30 | 30 | 8 |
  | Ritalin LA | 10, 20, 30, 40 | 30 | 8 |
  | Concerta XL | 18, 27, 36, 54 | 60 | 12 |
  | Dexamfetamine (Attentin, Amfexa) | 5, 10, 20 | 20 | 4 |
  | Lisdexamfetamine (Elvanse) | 20, 30, 40, 50, 60, 70 | 90 | 10 |

- **Model gap:** [MedicationEvent](app-four/Models/MedicationEvent.swift#L10-L29) stores only `durationHours` (no onset, no catalog). The catalog above maps cleanly onto a lightweight static seed — these meds are a fixed clinical set the user *picks* from, not user-authored, so a SwiftData catalog model + migration is overkill.
- **Decision (confirmed 2026-06-15): seed a static medication catalog from the table above.** Approach:
  - Add a `MedicationCatalog` value type / resource: `name`, `doseOptions: [String]`, `onsetMinutes: Int`, `durationHours: Double` — hardcoded from the 7 rows (no migration, no management UI).
  - Picker lists the catalog names **plus** any distinct names from past `MedicationEvent`s (so the user's own additions resurface).
  - Selecting a med → dose becomes a sub-picker of that med's `doseOptions`; **onset** shows as read-only info; **duration** prefills `durationHours` (replacing the hardcoded `10.0` at [MedicationBarViewModel.logManualDose](app-four/ViewModels/MedicationBarViewModel.swift#L138)) and stays **editable** (custom duration, per the ask).
  - Keep the free-text field to add a brand-new medication (then it persists into history for next time).
- **"Interval" is not in the final list** — the owner dropped it when stripping the table (it was "dosed 2–3×/day" in the fuller version). Treat interval as **out of scope** for v1 unless the owner reinstates it; flag in the spec.
- **Reuse the existing chip pattern:** the check-in composer already does "recent names + add" ([impl doc line 919](docs/superpowers/plans/2026-06-12-checkin-view-implementation.md), [TextCheckInComposer.swift](app-four/Views/CheckIn/TextCheckInComposer.swift)); bring the same control into [MedicationLogSheet](app-four/Views/Components/MedicationLogSheet.swift) so the bar's "Log new dose" and the check-in share one picker.
- **Still write a Spec Kit spec** (`docs/SPECKIT.md`) since it touches the data layer — but the catalog/onset/duration questions are now answered.
- **Cross-check** the original intent in the check-in mockups: [2026-06-12-checkin-view-mockup-v3.html](docs/superpowers/plans/2026-06-12-checkin-view-mockup-v3.html), […-FINAL.html](docs/superpowers/plans/2026-06-12-checkin-FINAL.html).

---

## Recording 4 — Recording detail: transcription state, slowness, back button, bar consistency (1:05)

> **Cleaned transcript.** "When I record and wait for the transcription, it appears at
> the top as '18:45 Recording at …' — it should display 'Transcribing with Whisper'.
> The idea is a temporary name showing 'transcribing', and when it's ready we see the
> check-in like the ones below. It seems it's not transcribing right now — a very big
> delay. Also the 'coming back' option needs to be investigated. At the top we always
> have a medication bar; you can't interfere with it. This return button should be
> removed — propose another option. The medication bar must be consistent across all
> screens; we can't have it moving when this screen appears. Transcribing is taking too
> long — we need to consider that it failed at this point."

### 4.1 — Show a temporary "Transcribing…" name while a recording processes
- **Requested:** A recording that is still transcribing should appear with a temporary name like "Transcribing…" (rather than "Recording 15 Jun 2026 at 18:44"), and resolve into a normal check-in card once done.
- **Where:**
  - Detail header title: [RecordingDetailView.swift:54](app-four/Views/RecordingDetailView.swift#L54) (`viewModel.recording.title`).
  - Status already exists: `RecordingStatus.transcribing` / `.placeholder` ([AppEnums.swift:7,10](app-four/Models/AppEnums.swift#L7)). The detail view *does* show "Transcribing with Whisper…" inside the transcript section ([lines 110‑117](app-four/Views/RecordingDetailView.swift#L110)) — but the **title/name** and the **timeline card** don't reflect it.
  - Timeline rendering: [DayTimeline.swift](app-four/ViewModels/DayTimeline.swift) / [DayCard.swift](app-four/Views/Components/DayCard.swift) — needs a transcribing/placeholder presentation so an in-flight recording shows "Transcribing…" at the top of the day, then becomes a full check-in.
- **Action:** When `status == .transcribing` (or `.placeholder`), render the name as "Transcribing…" in both the timeline card and the detail header; swap to the real title when `.completed`.

### 4.2 — Transcription is too slow; treat a long wait as failure
- **Observed:** Long hang; owner wants it to "consider it failed."
- **Where:** A timeout already exists — [CheckInViewModel.consumeStreamWithTimeout(…, timeoutSeconds: 300)](app-four/ViewModels/CheckInViewModel.swift#L119) marks the recording `.failed` after **300 s (5 min)**, far longer than a user will wait. The Whisper service itself ([WhisperKitTranscriptionService.transcribe](app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L83)) has **no internal deadline**; first run also downloads a ~150 MB model ([line 105](app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L105)).
- **Action:**
  - Lower the timeout to a human scale (e.g. 60–90 s for transcription proper), and/or make it proportional to audio length.
  - Distinguish *model-download* from *transcription* so the long first-run download shows its own progress and isn't counted as a hang.
  - On timeout, set `.failed` and surface a **Retry** affordance in the timeline card and [RecordingDetailView](app-four/Views/RecordingDetailView.swift) (status pill already supports `.failed`, [lines 147‑148](app-four/Views/RecordingDetailView.swift#L147)).

### 4.3 — Remove the back/return button on the recording detail; propose another way back
- **Requested:** The top-left back chevron conflicts with the always-on medication bar; remove it and offer a different navigation.
- **Where:** [RecordingDetailView](app-four/Views/RecordingDetailView.swift#L36-L37) is pushed onto the Calendar `NavigationStack` ([CalendarLibraryView.swift:50‑53](app-four/Views/Library/CalendarLibraryView.swift#L50)), so the **system** back button renders in the nav bar *above* the `.medicationBarOverlay()`. That's the chevron seen sitting on top of the bar.
- **Options:**
  1. Present the detail as a **sheet** (swipe-down to dismiss) instead of a nav push — removes the chevron entirely, keeps the bar fixed.
  2. Keep the push but hide the system back button (`.toolbar(.hidden)` / `.navigationBarBackButtonHidden`) and dismiss via swipe + an explicit control placed *below* the bar.
- **Decision (confirmed 2026-06-15): present the detail as a sheet.** Swipe-down dismiss, no back chevron, the medication bar stays fixed at the very top. Replace the `navigationDestination(for: UUID.self)` push in [CalendarLibraryView.swift:50‑53](app-four/Views/Library/CalendarLibraryView.swift#L50) with a `.sheet(item:)` (or `.fullScreenCover` if the bar must remain visible inside the detail). Verify the deep-link/selection path still resolves the recording, and that the bar is rendered consistently inside the sheet (ties to §4.4).

### 4.4 — Medication bar must be identical/fixed across every screen
- **Requested:** The bar must not move or change position when navigating into the detail screen; one consistent placement everywhere.
- **Root cause:** The bar uses `safeAreaInset(edge: .top)` ([MedicationBarOverlay.swift:18](app-four/DesignSystem/MedicationBarOverlay.swift#L18)). On tab roots there's no nav bar, so it sits at the very top; on the **pushed** detail view the nav bar (and its back button) push it down — hence "it moves." Fixing §4.3 (sheet, or hidden nav bar) largely resolves this.
- **Action:** Standardise: ensure every surface that shows the bar has the same top chrome (no nav bar, or a consistent one), and one shared spacing token (ties to §1.5). Audit the three current call sites: [CalendarLibraryView](app-four/Views/Library/CalendarLibraryView.swift#L26), [InsightsView](app-four/Views/InsightsView.swift), [RecordingDetailView](app-four/Views/RecordingDetailView.swift#L36).

---

## Cross-cutting themes

- **Medication bar is the spine of the UI.** Items 1.3, 1.5, 2.1, 4.3, 4.4 all orbit one requirement: the bar is a single, fixed, always-tappable element that content fades *under* — never overlaps, never moves, never half-responds. Worth one consolidated "Medication Bar consistency" spec rather than five isolated fixes.
- **Mock data is a sharp edge.** 1.1 (crash) and 1.2 (bar missing) are both mock-mode artifacts; fix together and add the reseed/debug coverage referenced in [2026-06-12-debug-mock-data-reseed-design.md](docs/superpowers/specs/2026-06-12-debug-mock-data-reseed-design.md).
- **Transcription UX is a state-machine gap.** 4.1 (placeholder name) and 4.2 (timeout/failure) are the visible/invisible halves of the same lifecycle: in-progress → done | failed, surfaced consistently in timeline + detail.

## Priority & effort

| Item | Change | Effort | Priority |
|------|--------|--------|----------|
| 2.1 | `.contentShape` on bar row → full-width tap | XS | **High** (one-liner, clear win) |
| 4.2 | Lower transcription timeout + Retry on failure | S | **High** |
| 1.1 | Reproduce + fix mock-data crash | S–M | **High** (stability) |
| 1.4 | Reliable day-select → scroll-to-top (header inset) | S–M | High |
| 1.3 | Top-fade rework — real fade, keep glass, incl. fixed header (decided) | M | High |
| 4.1 | "Transcribing…" temporary name in timeline + header | S–M | Medium |
| 4.3 / 4.4 | Detail as sheet; remove back button; fix bar consistency | M | Medium |
| 1.2 | Confirm/fix bar-missing in mock mode | S | Medium |
| 1.5 | Single spacing token below the bar | XS | Medium |
| 1.6 | Timeline connector clipping near selector | S | Low |
| 3.1 | Medication picker — static catalog seed (decided) + spec | M | Medium (spec first) |
| 1.7 | "Today" button — keep (no change) | — | Resolved |

## Decisions — resolved 2026-06-15

1. **Medication picker (§3.1):** ✅ Seed a **static catalog** from the owner's curated EU-stimulant table (found in chat `7bd9817a`). Picker = catalog names + past-used names; select → dose sub-picker, read-only onset, editable duration prefill. "Interval" out of scope for v1. Still spec it (touches data layer).
2. **Top fade (§1.3):** ✅ **Real top fade, keep the glass.** Measured bar-height `topFade`; fade the Calendar's fixed header too.
3. **Recording detail navigation (§4.3):** ✅ **Present as a sheet** (swipe-down dismiss, no back chevron, bar stays fixed).
4. **"Today" button (§1.7):** ✅ **Keep it.**

## Still needs investigation (not decisions — bugs to reproduce)

- **§1.1 mock-data crash** — needs a repro + crash log before a fix.
- **§1.2 bar-missing in mock mode** — confirm mock-only vs. real-data regression.

## Suggested next step

These are distinct enough to track as backlog items and, for 3.1 specifically, to run through Spec Kit (`docs/SPECKIT.md`) since it touches the data model. Nothing here has been added to [docs/BACKLOG.md](docs/BACKLOG.md) yet — say the word and I'll register them by stage.
