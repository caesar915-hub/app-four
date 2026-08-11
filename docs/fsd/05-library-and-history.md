<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# 05 — Library & History

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4`. All `path:line` citations are against `main`.

## Purpose

Describe how the user browses and inspects past check-ins: the Calendar library tab (month grid, week↔month collapse, day selection, day-grouped timeline), folding day cards, the recording detail screen (signal hero, transcript, audio playback, deletion), and tag display.

## Scope

- In scope: `CalendarLibraryView`, `CalendarHeaderView`/`CalendarMonthModel`/`CalendarDayCell`, `CalendarStripFade`, `MoodLibraryViewModel`, `DayTimeline`/`DayTimelineBuilder`, `DayCard`/`ExpandedDayCards`/`DayCardSummary`/`FoldedDayCardHeader`/`TimelineRow`, `RecordingDetailView`/`RecordingDetailViewModel`, `AudioPlaybackViewModel`/`AudioPlayerView`/`PlaybackWaveformBars`, `ADHDSummarySection`, `Recording+MoodDisplay`, `EdgeFadeMask`, `GlyphRampPicker`, `RecordingRow` (shared row, unused by the calendar timeline on main).
- Out of scope: extraction itself ([Processing & Extraction](04-processing-and-extraction.md)), aggregated charts ([Insights](06-insights.md)), the floating medication bar's behavior ([Medications](07-medications.md)) — noted here only where it overlays these screens.

## Actors & triggers

- **User** — switches to the Calendar tab; taps/swipes the month header to expand; swipes horizontally to page months; taps a day cell; taps a day card header to fold/unfold; taps a timeline row to open recording detail; expands the transcript; plays/seeks audio; taps "Retry transcription"; confirms "Delete"; opens the Edit sheet.
- **System triggers** — entering the Calendar tab runs `jumpToToday()`; leaving it pops the whole navigation path; `.medicationEventsDidChange` re-fetches timeline doses; launch-time orphan recovery rewrites stuck `.transcribing` recordings to `.failed`.

## Functional requirements

### Calendar library screen

- **FR-LIB-01 — Tab placement & hosting.** The Calendar tab is the first of four root tabs (`calendar, checkIn, insights, settings`), labeled "Calendar". `CalendarLibraryView` is hosted in `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false, path:)`; the floating medication bar rides above content as a shared overlay, with calendar content laid out below the bar's safe-area inset (`RootTabView.swift:5-22`; `CalendarLibraryView.swift:29-34`).
- **FR-LIB-02 — Monday-first month grid.** The grid is built Monday-first (`leading = (weekdayOfFirst + 5) % 7`), rows = `ceil((leading + daysInMonth)/7)`, including out-of-month padding days from adjacent months. The weekday header row is hardcoded single letters `["M", "T", "W", "T", "F", "S", "S"]` (`CalendarMonthModel.swift:30-66`; `CalendarHeaderView.swift:18`).
- **FR-LIB-03 — Marker dots.** Each in-month cell carries a `DayMarker`: `.mood(Color)` when ≥1 mood exists (dot in the **rounded-average deep mood colour** — mean of numeric values, `rounded()`, back to level, deepFill); `.neutral` when entries exist but no mood (e.g. medication-only day); `.none` when empty. Out-of-month cells always get `.none`. The dot is 6×6 pt; `.neutral` renders `NewLook.inkSecondary` (`CalendarMonthModel.swift:5-9, 61-62, 70-74`; `MoodLevel+Palette.swift:97-105`; `CalendarDayCell.swift:31, 50-56`).
- **FR-LIB-04 — Future days disabled.** `isFuture = cellDate > startOfToday` (strictly after today); future cells are `.disabled` and tinted `Color(.tertiaryLabel)`. Out-of-month cells stay tappable and trigger month paging (`CalendarMonthModel.swift:61`; `CalendarDayCell.swift:37, 43-48`; `CalendarLibraryView.swift:161-168`).
- **FR-LIB-05 — Week↔month collapse.** The strip starts collapsed to the week containing the selected day (`isCalendarExpanded = false`); tapping the month label toggles expansion with `Motion.smooth` (skipped under Reduce Motion), rotating a decorative `chevron.right` 90°. AX hint "Collapse to week" / "Expand to month"; min tap target ≥ 44 pt. At `dynamicTypeSize >= .accessibility1` the grid is force-collapsed to one week and the expand button is replaced by plain text (`CalendarLibraryView.swift:10`; `CalendarHeaderView.swift:20-21, 49-85`).
- **FR-LIB-06 — Bounded month paging.** Horizontal `DragGesture(minimumDistance: 24)` acts only when `abs(width) > abs(height)`; swipe right → older month, left → newer. Backward paging is bounded by the earliest month with data; forward paging by the current month (`!isCurrentMonth`). After paging, the selection jumps to the newest in-range day of the now-current month (`CalendarHeaderView.swift:116-122`; `CalendarLibraryView.swift:190-206`).
- **FR-LIB-07 — Scroll-driven strip fade (exact constants).** Scrolling the timeline collapses the strip via `CalendarStripFade`: `deadZone = 24` pt absorbed before fading starts; `minFadeDistance = 44` pt floor guards the pre-measurement frame; `band = max(stripHeight - 24, 44)`; `raw = (offset - 24) / band`, clamped [0,1] and **floor-quantized to 1/100** (never reports full collapse early). `stripOpacity = 1 - min(1, progress / 0.8)` — fully transparent at progress 0.8, ahead of the geometric exit. The offset contract: 0 at rest, negative on rubber-band pull-down, positive scrolling up (`CalendarStripFade.swift:11-38`; `CalendarLibraryView.swift:147-154`).
- **FR-LIB-08 — Compact title band.** When `progress >= 0.8` (`titleReveal = 0.8`), a solid in-content band appears directly below the medication band showing `dayLabel(for: selectedDay)` plus a hairline divider, cross-fading with `Motion.snappy` (skipped under Reduce Motion); it is never a nav-bar item (`CalendarLibraryView.swift:73-96`; `CalendarStripFade.swift:17, 40`).
- **FR-LIB-09 — Tab-switch behavior.** Leaving the Calendar tab pops the entire navigation path; entering it calls `jumpToToday()`: sets `currentMonth = Date()`, collapses to the week strip, and scrolls to today (`CalendarLibraryView.swift:57-62, 183-188`).
- **FR-LIB-10 — Selection & list cap.** Day selection is **tap/jump-only** — scrolling never re-filters the list, so browsing older days can't ratchet newer days out. `scrollList(to:)` sets the selected day, scrolls to top with `Motion.smooth` (skipped under Reduce Motion), and resets expansion (collapse all, open the selected day only when auto-expand is on). The visible list is `timelineDaysFilteredToSelectedDate`: every day strictly more recent than the selected date is removed (`$0.date <= cap`) — the selected day becomes the top entry when it has data (`CalendarLibraryView.swift:161-181`; `MoodLibraryViewModel.swift:102-110`).
- **FR-LIB-11 — Timeline construction.** The timeline shows days of the displayed month that have at least one recording (`createdAt` in month) or taken dose (`takenAt` in month); iteration **breaks at the first future day** and skips empty days; sorted newest-first. `availableMonths` spans the earliest recording's month through the current month (recording dates only); falls back to `[currentMonth]` with no recordings (`MoodLibraryViewModel.swift:56-100`).
- **FR-LIB-12 — Stale-push guard.** If the recording for a pushed UUID no longer exists (deleted out from under an open push), the destination renders `Color.clear` and pops itself back (`CalendarLibraryView.swift:50-53`).
- **FR-LIB-13 — Empty state.** When there are no recordings and no taken medication events at all, the screen shows the pinned, fully opaque calendar strip (no scroll → nothing to collapse) plus `ContentUnavailableView("No entries yet", systemImage: "calendar.badge.exclamationmark", description: Text("Record a voice note to see it here."))` (`CalendarLibraryView.swift:36-45, 208-214`).
- **FR-LIB-14 — No search / filter.** There is **no search field and no filter UI** anywhere in the calendar library, day cards, or recording detail on `main`. The only "filter" is the implicit date-cap of FR-LIB-10. `Chip.Style.filter` exists as a component but is unused in this area (previews only) (notes §2.9, §10.5; `CalendarLibraryView.swift`).

### Day cards

- **FR-LIB-15 — Folding day cards.** Each timeline day renders a `DayCard` whose whole header is a button toggling expansion; multiple cards may be open at once. Expanded and non-empty → one `TimelineRow` per node. Selection carries no border — top position + expansion convey it (`DayCard.swift:3-37`; `ExpandedDayCards.swift:22-27`).
- **FR-LIB-16 — Expansion settings (`@AppStorage`).** Two settings under Settings → "Calendar": **"Always expand cards"** (`alwaysExpandCards`, default `false`, icon `rectangle.stack`; hint "When on, every day's check-ins stay open in the calendar.") — `shouldExpand` returns true for every card; and **"Auto-expand selected day"** (`autoExpandOnSelection`, default `true`, icon `rectangle.expand.vertical`; hint "When on, tapping a date opens that day's check-ins automatically.") — on selection, all cards collapse then only the selected day opens; when off, all cards close (`DayCardSettingsSection.swift:12-20`; `ExpandedDayCards.swift:31-40`; `CalendarLibraryView.swift:15-16`).
- **FR-LIB-17 — Merged timeline nodes.** `DayTimelineBuilder` produces one node per distinct instant (union of recording `createdAt` and dose `takenAt`), sorted newest-first; each node carries the recording (if any), the doses taken at that instant, and `rings`: every dose still inside its effect window at that time, oldest→newest, **max 3**, with `progress = effectProgress(at:)`. **Implemented, dormant in 1.0:** the current `TimelineRow` redesign does **not** render these medication-phase rings — the ring data feeds nothing in the row UI (`DayTimeline.swift:9-91`; `TimelineRow.swift:3-8`).
- **FR-LIB-18 — Folded card header.** Shows an optional mood sprout glyph, a one-`Text` title `"<Mood word> · <WEEKDAY>"` (mood word 24 pt bold in `wordColor`; weekday = `"EEE"` uppercased, 13 pt semibold caps, 1.3 tracking; no mood → weekday only), a `FlowLayout` summary line of chips in order energy, focus, medication (name only), sleep, separated by "·", and a trailing `chevron.down`. Background is the mood `blockTint`. When expanded and non-empty, the header switches to a slim uppercase band `"<MOOD> · <WEEKDAY>"` with the chevron rotated 180°. Empty day (presentation paths outside the filtered list): literal copy **"No check-ins this day. That's alright."** in secondary ink, max 2 lines, no glyph, no tint — calm by design, never red, never "missed"/"overdue" (`FoldedDayCardHeader.swift:28-163`; `DayCardSummary.swift:36-39`).
- **FR-LIB-19 — Timeline rows.** Rows with a recording are tappable anywhere (pushing the recording UUID; AX hint "Opens recording detail"); **dose-only nodes render without the ⋯ affordance and are not tappable**. Layout: 43 pt mood disc (`badgeTint`) with mood sprout glyph; headline = mood word (24 pt bold) + time (13 pt, `HH:mm` 24-hour, two-digit) as one `Text`; when no mood was extracted, the recording's `displayTitle` takes the headline slot (17 pt semibold) so the row reads a status, never a bare timestamp; dose-only node → time alone (`TimelineRow.swift:13-95`).
- **FR-LIB-20 — Chip line with 4-item cap.** Below the headline, a `FlowLayout` chip line with "·" separators in fixed order: energy (glyph), focus (glyph), distinct medication names (name only — no dose, no "Taken"), sleep label (**no glyph**, indigo), feelings (`"♥ " + joined`), side effects. Feelings and side effects are capped at **4 items + "+N" overflow** (`"a, b, c, d +2"`, cap constant `max = 4`) (`TimelineRow.swift:97-168`; `Recording+MoodDisplay.swift:106-113`).

### Recording detail

- **FR-LIB-21 — Structure.** Pushed via `navigationDestination(for: UUID.self)`. Content order: title block (`displayTitle`, wraps, never truncates; meta `"<shortened time> · <durationString>"`, e.g. "8:05 AM · 4:32") → signal hero strip (only when any of mood/energy/focus present) → `ADHDSummarySection` → transcript card → audio card → delete button. Nav bar principal shows `"<WEEKDAY-ABBR> · <d Month>"` uppercased (e.g. "TUE · 10 JUNE"); trailing pencil button (44×44, AX label "Edit check-in") opens the Edit sheet (see [Processing & Extraction](04-processing-and-extraction.md)). The floating medication bar overlays the screen (`.medicationBarOverlay()`) (`RecordingDetailView.swift:26-111`).
- **FR-LIB-22 — Signal hero strip.** Shown when any of mood/energy/focus is non-nil. One column per present signal: 30 pt `SignalGlyph`, level word (mood → `mood.capitalized`; energy/focus → enum `displayLabel`), uppercase micro-label ("MOOD"/"ENERGY"/"FOCUS"), and a 4 pt capsule level bar filled to `level/5` tinted from the signal's ramp (`deepFill` for mood; out-of-range → `NewLook.inkSecondary`). AX per column: `"<Kind>: <Word>"` (`RecordingDetailView.swift:113-175`).
- **FR-LIB-23 — Transcript card & status pills.** Header is a toggle button ("Transcript" + status pill + rotating chevron, 0.2 s easeInOut, skipped under Reduce Motion); default collapsed. Status pill (capsule at 0.15 opacity): `.recorded` → "Recorded"; `.transcribing` → "Transcribing"; `.completed` → "Completed"; `.failed` → "Failed"; `.pendingTranscription`/`.placeholder` → **no pill**. Expanded body: `.transcribing` → spinner + "Transcribing…"; empty text (not transcribing) → **"No transcript available yet."**; otherwise the full transcript (lineSpacing 4) (`RecordingDetailView.swift:185-265`).
- **FR-LIB-24 — 90-second retry transcription.** Whenever `status == .failed`, a **"Retry transcription"** button appears below the header. Retry: sets `.transcribing`, clears text, streams from `transcribe(audioURL:)` with a **90-second timeout** (racing task group; `RecordingError.timeout`); each segment overwrites `fullTranscriptText`; `isError` segments throw. Success → `.completed` + summary regeneration. Failures (all → `.failed`, message stored into `fullTranscriptText` so it displays as the transcript text): cancellation → **"Transcription cancelled. Tap Retry to try again."**; timeout → **"Transcription timed out. Tap Retry to try again."**; other → `"Transcription failed: \(error.localizedDescription)"`. Launch-time orphan recovery stores **"Transcription was interrupted. Tap to retry in the recording detail view."** (`RecordingDetailViewModel.swift:73-130`; `RecordingStore.swift:25-36`).
- **FR-LIB-25 — Summary regeneration.** `generateSummary()` no-ops on empty transcript; `regenerateSummary()` clears summary/topics and regenerates through the same `applySummary` path; `startRegenerate()` cancels any in-flight task. Also implemented but **not wired to any button** on main: `startRegenerate()`, `toggleFavorite()`, `updateTitle`, `updateDate`, `updateMood` (`RecordingDetailViewModel.swift:26-71, 132-150`).
- **FR-LIB-26 — Deferred deletion.** A visible destructive **"Delete check-in"** button presents a confirmation dialog titled **"Delete this check-in?"** with a single destructive "Delete" button (system-provided cancel). Confirming sets `pendingDelete = true` and dismisses; the actual delete runs in `.onDisappear` — deleting a `@Model` while the view is mounted would invalidate views still reading it ("BackingData detached without resolving faults"). Deletion cascades to `segments`, `correctionTags`, `medicationEvents`; the audio file is removed by the storage service; the calendar's stale-push guard pops any open push (`RecordingDetailView.swift:75-85, 278-288`; `RecordingStore.swift:58-63`; `Recording.swift:52-59`).

### Audio playback

- **FR-LIB-27 — Playback states.** `PlaybackState`: `idle`, `loading`, `playing(currentTime:)`, `paused(currentTime:)`, `finished`, `error(String)`. `play()` lazily creates the `AVAudioPlayer` from the stored file; missing file → `.error("Audio file not found")`; init failure → `.error(localizedDescription)`. Playing from `.finished` rewinds to 0. `pause()` snapshots the time. There is no error UI — an `.error` state renders the play button again and the error string is not displayed (`AudioPlaybackViewModel.swift:7-56`; `AudioPlayerView.swift`).
- **FR-LIB-28 — 250 ms polling & clamped seeking.** While playing, a task loop copies `player.currentTime` into state every **250 ms**. `seek(to:)` clamps to `[0, duration]`; playing stays playing at the new time; every other state (including `.finished`, `.idle`, `.error`) becomes `.paused(clamped)`. Finish → `.finished`, `currentTime = duration` (fires regardless of the `successfully` flag). The player is torn down on disappear (`AudioPlaybackViewModel.swift:58-105`; `AudioPlayerView.swift:32-34`).
- **FR-LIB-29 — 32-bar pseudo-waveform.** The waveform is **32 bars**, 3 pt gaps, container height 28 pt, bar heights 4–24 pt from a deterministic `Hasher` over the recording's `id.uuidString` + index — **not** derived from actual audio levels. Played bars (`index < barCount * clamp(progress)`) fill `Theme.accent.opacity(0.6)`; unplayed `NewLook.tintNeutral`. Scrubbing is a `DragGesture(minimumDistance: 0)`; seek commits only on gesture end, `onSeek(clamp(location.x / width))`. The elapsed label is `"MM:SS"` monospaced. AX: `"Playback progress, <N> percent"` (`PlaybackWaveformBars.swift:6-49`; `AudioPlayerView.swift:13-79`).

### Tag display

- **FR-LIB-30 — `displayTags` order.** Chips assemble in fixed order: topic categories (icon + displayName + category color), energy (`"<level> energy"`, `bolt.fill`, energy glyph badge), focus (raw label, `target` icon), sleep (`"<N>h sleep"` / `"<quality> sleep"` / "sleep", `bed.double.fill`, indigo), side effects (capitalized, `bandage.fill`, warning), emotions (capitalized, `heart.fill`, pink), medications (distinct by name; `name` + " ½" when quantity 0.5 + " ↑" started / " ↓" stopped; `pills.fill`, medication color). `chipTags` = `displayTags` minus energy/focus/medication (`Recording+MoodDisplay.swift:26-89`).
- **FR-LIB-31 — Summary section.** `ADHDSummarySection` renders up to four cards, each omitted entirely when its data is absent: **Medications** (transcript-sourced events only, sorted `takenAt` ascending, joined " · " as `"<name> <dose?>"` with `×½` / `×<n>` quantity suffixes and `" (missed)"` when not taken — e.g. "Concerta 36mg ×½ · Ritalin 10mg (missed)"); **Sleep**; **Emotions**; **Side effects** (`ADHDSummarySection.swift:6-157`).
- **FR-LIB-32 — Provenance tags not rendered.** `RecordingTag` provenance rows (`nlp`/`user`/`userCorrected`; categories mood/energy/focus/medication/emotions) are written by the Edit sheet and cascade-deleted with the recording, but are **not rendered as chips anywhere** in this area (`RecordingTag.swift:4-43`; `Recording.swift:55-56`).

## User flows

### Happy path — browse to a past check-in

1. User opens the Calendar tab → `jumpToToday()`: current month, week strip, list scrolled to today, today's card auto-expanded (default settings).
2. User taps the month label to expand the month grid (or swipes to page months, bounded by data and the current month).
3. User taps a day cell → the list re-caps to that day, scrolls to top, and the selected card expands.
4. User taps a timeline row → recording detail pushes in: hero strip, summary cards, transcript (expandable), audio playback, delete.

### Alternate flows

- **First launch / no entries:** pinned strip + "No entries yet" empty state (FR-LIB-13).
- **Scrolling a long list:** the strip fades out per FR-LIB-07; the compact title band appears at progress ≥ 0.8 with the selected-day label.
- **Transcription failed:** transcript card shows "Failed" pill + "Retry transcription"; the stored error message displays as transcript text; retry runs the 90 s flow (FR-LIB-24).
- **Delete from detail:** confirm → sheet dismisses → deletion in `.onDisappear` → back at the library, the day card/timeline recomputed.
- **Recording deleted elsewhere while its detail is pushed:** destination renders `Color.clear` and pops itself.

## UI states

- **Empty (library):** "No entries yet" + "Record a voice note to see it here." (no recordings and no taken doses).
- **Empty (day):** folded card copy "No check-ins this day. That's alright." (presentation paths outside the filtered list; the timeline itself skips empty days).
- **Loading:** the calendar has none (in-memory store data); detail "loading" exists only as the transcript card's `.transcribing` spinner and the player button's `.loading` icon (the VM never sets `.loading` in current code).
- **Error:** no error surfaces exist in this area beyond the transcript card's "Failed" pill + retry copy; audio-file-missing surfaces only as the internal `.error("Audio file not found")` state with no visible UI.
- **Status pill absence:** `.pendingTranscription` ("Ready shortly…" display title) and `.placeholder` render no pill — calm by design, never error wording.

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| Weekday header | Monday-first, `["M","T","W","T","F","S","S"]` | `CalendarHeaderView.swift:18` |
| Strip fade | deadZone 24 pt; minFadeDistance 44 pt; floor-quantized 1/100; opacity 0 at progress 0.8; title reveal ≥ 0.8 | `CalendarStripFade.swift:11-40` |
| Month swipe | `DragGesture(minimumDistance: 24)`, horizontal-dominant only | `CalendarHeaderView.swift:116-122` |
| Paging bounds | earliest month with data … current month | `CalendarLibraryView.swift:190-206` |
| Day cell | number in 30 pt circle (cap 40 pt), marker dot 6×6 pt, tap target ≥ 44 pt, `minimumScaleFactor(0.6)` | `CalendarDayCell.swift:13-37` |
| Future days | `cellDate > startOfToday` → disabled | `CalendarMonthModel.swift:61`; `CalendarDayCell.swift:37` |
| Settings defaults | `alwaysExpandCards` false; `autoExpandOnSelection` true | `DayCardSettingsSection.swift:12-20` |
| Timeline rings | max 3, oldest-first (computed, not rendered) | `DayTimeline.swift:71-84` |
| Chip cap | feelings/side effects: max 4 + "+N" overflow | `Recording+MoodDisplay.swift:106-113` |
| Transcript retry timeout | 90 s | `RecordingDetailViewModel.swift:87` |
| Playback polling | 250 ms | `AudioPlaybackViewModel.swift:82-95` |
| Waveform | 32 bars, heights 4–24 pt, container 28 pt, 3 pt gaps | `PlaybackWaveformBars.swift:6-49` |
| Day/month labels | `"MMMM yyyy"`; today "Today, d MMM"; yesterday "Yesterday, d MMM"; else "EEEE, d MMM" | `MoodLibraryViewModel.swift:35-41, 157-165` |
| Time formats | timeline rows `HH:mm` 24-hour; detail meta/RecordingRow locale-shortened 12-hour | `TimelineRow.swift`; `RecordingRow.swift:55-69` |

## Edge cases

- **Mock-data partitioning:** recordings and medication events are fetched with `isMockData == UserDefaults.standard.bool(forKey: "debugMockMode")` — mock and real data are mutually exclusive in the timeline.
- **Orphan recovery:** recordings stuck in `.transcribing` at launch become `.failed` with "Transcription was interrupted. Tap to retry in the recording detail view."; `.pendingTranscription` is explicitly not swept.
- **Reduce Motion:** every animation in this area (expand/collapse, title-band fade, list scroll, transcript toggle, chevrons) is skipped when enabled.
- **Dynamic Type:** the grid force-collapses to a week at `.accessibility1`+; day numbers shrink instead of truncating; headlines use concatenated `Text` + `fixedSize` to wrap.
- **Dose-only timeline nodes** are not tappable and render without the ⋯ affordance.
- **Short filtered lists** can't flicker-fade (`.scrollBounceBehavior(.basedOnSize)`).
- **`RecordingRow`** (the carded shared row with status badges) exists for the Notes library; the calendar timeline renders `TimelineRow`, not `RecordingRow`, on main.

## Acceptance criteria

1. With no data, the library shows the pinned strip and the exact "No entries yet" empty state; with data, days without entries never get cards and future days never appear in the list.
2. Tapping an out-of-month cell pages the grid to that month (respecting bounds) and selects the day; future cells are not tappable.
3. Scrolling the timeline fades the strip to fully transparent exactly at progress 0.8 and reveals the compact title band at ≥ 0.8; with Reduce Motion, all animations are skipped.
4. With "Always expand cards" off and "Auto-expand selected day" on (defaults), selecting a day collapses all other cards and opens only that day; multiple cards can be opened manually.
5. A failed recording shows the "Failed" pill and "Retry transcription"; retry succeeds within the 90 s timeout and regenerates the summary, or stores the exact retry copy on failure.
6. Deleting from detail shows "Delete this check-in?", performs deletion only after the view disappears, and leaves no stale push.
7. The waveform renders 32 deterministic bars; scrubbing seeks clamped to [0, duration] on gesture end; progress polls every 250 ms while playing.

## Source references

- `app-four/Views/Library/CalendarLibraryView.swift:7-214` · `CalendarStripFade.swift:6-40` · `ExpandedDayCards.swift:7-40`
- `app-four/Views/Components/CalendarHeaderView.swift:8-122` · `CalendarDayCell.swift:13-67` · `DayCard.swift:3-37` · `FoldedDayCardHeader.swift:28-163` · `TimelineRow.swift:3-187` · `RecordingRow.swift:19-127` · `AudioPlayerView.swift:13-79` · `PlaybackWaveformBars.swift:6-49` · `ADHDSummarySection.swift:6-157` · `TagFlowView.swift:3-78` · `Chip.swift:8-69` · `EdgeFadeMask.swift:8-32` · `GlyphRampPicker.swift:9-30`
- `app-four/ViewModels/CalendarMonthModel.swift:5-74` · `MoodLibraryViewModel.swift:9-165` · `DayTimeline.swift:9-91` · `RecordingDetailViewModel.swift:22-150` · `AudioPlaybackViewModel.swift:7-105`
- `app-four/Views/RecordingDetailView.swift:26-288` · `app-four/Views/Settings/DayCardSettingsSection.swift:12-20` · `app-four/Views/RootTabView.swift:5-22`
- `app-four/Models/Recording.swift:40-193` · `Recording+MoodDisplay.swift:9-123` · `RecordingTag.swift:4-43` · `MedicationEvent.swift:68-77` · `app-four/Store/RecordingStore.swift:14-63`
- `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/MoodLevel+Palette.swift:16-105` · `GlyphSignal.swift:7-83` · `SignalLevel.swift:12-64` · `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift:8-99`
- Sibling FSD: [Processing & Extraction](04-processing-and-extraction.md) · [Insights](06-insights.md) · [Medications](07-medications.md)
