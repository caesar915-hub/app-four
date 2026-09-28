<!-- Created: 2026-09-27 22:40 WEST · Updated: 2026-09-27 22:40 WEST -->
# Cross-check — pen "iPhone 17 - 1" (Day Mode Details) vs the shipping SwiftUI — VERIFIED

Inputs: `out/screens/day-details.md` (read fully), the PNG render, `out/design-system.md`, the three codebase maps, `out/constraints.md`, and the Swift files named below (opened and read; every line number is from the worktree at `feat/057-ui-refresh`, HEAD `08ba8cba`). Planning only — no Swift touched, no build run. Paths are repo-relative.

**Verification pass (2026-09-27 22:40 WEST):** an independent verifier re-opened every file cited below and re-computed every contrast ratio. Corrections are applied in place and marked **[verified: corrected]**; additions the original missed are marked **[verified: added]**. The full list is in §8 "Verifier notes".

---

## 1. Mapping — what implements this surface today

| Pen | Code | Notes |
|---|---|---|
| The screen | **`app-four/Views/RecordingDetailView.swift`** (322 lines) | A plain `ScrollView` (not `ScreenContainer`), `NewLook.screen` background (:37), `.medicationBarOverlay()` (:40), inline system nav bar (:43-44). Content gutter is `Spacing.l` = **16 pt** (:35, `Spacing.swift:13`). |
| View model | `app-four/ViewModels/RecordingDetailViewModel.swift` (164 lines) | Holds one `Recording` (:7). Only `delete()` (:34), `retryTranscription()` (:81) and the `showModelMissing` flag (:17) are reachable from the view; `toggleFavorite` (:30), `generateSummary` (:38), `regenerateSummary` (:46), `startRegenerate` (:54), `updateTitle/Date/Mood` (:59-75) have no UI. **[verified: added]** `startRegenerate` is covered by `app-fourTests/ViewModels/RecordingDetailViewModelTests.swift:36` — deleting it deletes a test. |
| Signal card | `signalHeroStrip` / `heroColumn` / `levelBar` — `RecordingDetailView.swift:127-181` | Order **Mood → Energy → Focus** (:129-139). |
| Emotions · Medications · Sleep · Side effects | `app-four/Views/Components/ADHDSummarySection.swift` (:8-11 order: meds, sleep, emotions, side effects) + `TagFlowView.swift:6-27` | Four separate `.newLookCard()`s. |
| AI summary | `summaryCard` — `RecordingDetailView.swift:203-221` | Bullets in `Typography.body`, caption `"Written by on-device AI from your voice — tap Edit to correct"` with `sparkles` **below** the text (:215). |
| Audio player | `audioCard` (:291-298) → `app-four/Views/Components/AudioPlayerView.swift` + `PlaybackWaveformBars.swift` + `app-four/ViewModels/AudioPlaybackViewModel.swift` | Separate last card; 44 pt purple play button (`Palette.medication` `#7E5CA8`, `AudioPlayerView.swift:52`, `Palette.swift:12`). |
| Push site | `app-four/Views/Library/CalendarLibraryView.swift:47-54` (`navigationDestination(for: UUID.self)`) ← `DayCard.onTapRecording` `path.append($0)` (:137) ← `TimelineRow.swift:21` `Button { onTapRecording(recording.id) }` | Also registered from `InsightsView.swift:32-34` but nothing there pushes (no `path.append`, no `NavigationLink` under `Views/Insights`). |
| Models | `app-four/Models/Recording.swift`, `MedicationEvent.swift`; `Packages/SquirlSignals/…/Levels.swift` | — |

**Scope fact the pen leaves open (Q1):** the code surface is **one `Recording` = one check-in**, never a day. `DayTimelineBuilder` (`app-four/ViewModels/DayTimeline.swift:37-44`) puts several check-ins on one day and each `TimelineRow` pushes its own detail. The pen's copy ("Today's Mood", "How Does It Feels Today?", "Daily Check-In") reads as a day view. If the owner wants a day aggregate, this is a different view model (average logic already exists in `DayCardSummary.swift:12-24` for the calendar card), not a restyle.

---

## 2. Delta table — section by section (pen order)

Legend: KEEP = already matches · CHANGE = exists, restyle/rearrange · NEW = must be built · REMOVE = exists today, absent in the pen.

### 2.1 Chrome and page

| Element | Verdict | Today | Pen | What changes / what is lost |
|---|---|---|---|---|
| Screen ground | CHANGE (global) | `NewLook.screen` `#EFF2EB` / dark `#12140F` (`NewLook.swift:13`) | `#fbfffc`, light only | Token swap; dark pair must be derived (§5). |
| Card grammar | CHANGE (global) | `.newLookCard()` r 20 (`Radius.swift:14`), borderless, shadow `black@0.05 r8 y2` + `black@0.03 r2 y1` (`NewLook.swift:52-66`) | style A r 12 / style B r 24, stroke 0.5 `#000000@0.10`, shadow `0 3|4 8 #183c28@0.08` | Two radii on one screen (C-15); a bordered card contradicts the current "never a card border" rule (`NewLook.swift:26`, `:50`). Shared-component work, assumed done. |
| Gutters **[verified: added]** | CHANGE | 16 pt (`Spacing.l`, :35) | header 31 / content 28 (right 30) / tab bar 28 (C-14) | The pen itself has three gutters; §7 assumes 28. Pick one before the HTML mockup. |
| Nav bar | CHANGE | System inline bar; principal = date `"EEE · d MMMM"` uppercase `Typography.label` `inkSecondary` (:46-52, :109-112); trailing = 44 pt `pencil` circle → Edit sheet (:53-68); back = system back control | Left: 42.6 circle back pill (`#ffffff`, stroke 1.065 `#e4ece4`, `arrow-left` 20 `#1e6725`) + title "Today's Mood" 18/600 `#17501d` + date "Monday, Jun 29" 12/500 `#6f7f75`; right: 42.6 `•••` pill | NEW **Circle Icon Button** (not in Frame 3) + NEW header layout; the pencil-as-edit affordance moves into a `•••` **Menu** (undesigned). **[verified: corrected]** DESIGN.md's 2026-06-15 decision ("Detail: no back button (swipe-left); pencil → 'Edit check-in' button", Decisions Log) was **already reversed in code** by spec 023: the shipping view has a system back control and a trailing pencil (`RecordingDetailView.swift:41-42` comment, `:61`). The pen therefore continues the current code direction (back + trailing control), not a reversal of it; what the pen changes is the *form* (custom pill + `•••` instead of system back + pencil). The Decisions Log entry to write is "back pill + `•••` menu supersede system back + pencil (spec 023)", not a reversal of 06-15. |
| Title block | REMOVE | `displayTitle` ("Mood · Energy · Focus" joined at `Recording.swift:221`, or "Transcribing…"/"Ready shortly…", `Recording.swift:44-50`) in `Typography.title` + meta `"<time> · <m:ss>"` `mono12` (:96-117) | absent | Loses **check-in time** (the only per-check-in disambiguator when a day has 3 check-ins) and the **status placeholder** for a recording still transcribing / pending. Both need a new home (see Transcript row). |
| Medication bar overlay | REMOVE? | `.medicationBarOverlay()` (:40) = `safeAreaInset(edge: .top)` of `MedicationBarView` (`DesignSystem/MedicationBarOverlay.swift:16-24`), governed by `@AppStorage("medicationBarVisible")` (`MedicationBarView.swift:8`) | not drawn on this screen (the pen Calendar draws a medication bar in-content instead) | Decision, not a defect — the bar is applied per screen via the modifier, but every screen applies it. |
| Tab bar visible while pushed | KEEP (behaviour) / CHANGE (visual) | `TabView` + per-tab `NavigationStack` (`RootTabView.swift:19-36`, `ScreenContainer.swift:49-60`) → the native tab bar stays visible on pushed screens | Floating pill bar + FAB stay visible | Behaviour already matches; the pill bar/FAB are global NEW components (§4). |
| Bottom "Delete check-in" | REMOVE (relocate) | Destructive plain button, `Theme.danger` (:302-310) → `confirmationDialog` (:79-86) → deferred delete in `onDisappear` (:74-78) | absent; implied inside `•••` | Function must survive. Keep the deferred-delete pattern (it exists because deleting a live `@Model` under a mounted sheet traps SwiftData). |
| "Insights Model Not Downloaded" alert | KEEP | (:87-91) | invisible chrome | — |

### 2.2 Section 1 — "How Does It Feels Today?" signal card

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Section title | NEW | none | "How Does It Feels Today?" 20/600 `#212529`, 12 gap to card | Copy defect C-01; the only 20 pt heading on the screen. |
| Column order | CHANGE | Mood · Energy · Focus (:129-139) | Mood · **Focus** · Energy | Pen differs from every other pen screen too (C-10). Pick one app-wide. |
| Column anatomy | CHANGE | glyph 30 · **word** `headline` · **label** uppercase `label` tracking 0.6 · 4 pt bar (:145-157) | glyph 28/27/33 · **label** 14/500 `#1e2225` · **value** 12/600 signal colour · 86×4 bar | Label and value swap places; word shrinks from 16 → 12 pt. |
| Value colours | CHANGE | mood `level.deepFill` (= `MoodLevel.color`, `MoodLevel+Palette.swift:42`), energy `Palette.energyRamp[l-1]` (yellow ramp `#7C6E2E…#FCEE64`), focus `Palette.focusRamp[l-1]` (blue `#44546E…#79C4FF`) (:174-181, `Palette+Signals.swift:10-33`) | `#0e7718` / `#447097` / `#e38400` — all off-palette; Charged `#e38400` on white is 2.78:1 | New tokens; energy leaves the yellow ramp for amber. **[verified: corrected]** Only the **mood** hexes are pinned by tests (`RecordingMoodDisplayTests.swift:28-33` pins `#9FCB79` / `#DA7A2A` / `#2E8B57`; `DayCardPaletteTests.swift:51` pins `#2E8B57`). The energy/focus ramps are **not** pinned anywhere in `app-fourTests` (no test references `energyRamp`, `focusRamp` or their hexes), and `SignalGlyphTests` pins only names and clamping. So changing energy/focus value colours cascades into no test; changing mood colours cascades into two. **[verified: added]** `MoodLevel.wordColor` (`MoodLevel+Palette.swift:55-63`; great = `#1E5C38` light, 7.95:1 on white) is the existing AA-guarded mood-word token — the natural replacement for the pen's `#0e7718` (5.72:1) rather than a new token. |
| Bars | CHANGE | fill = `level/5` on a `hairline` groove (:163-172) | 78/86 · 48/86 · 21/86 = 91 % / 56 % / 24 % on `#e9e9ea` | No continuous score exists (§3). Recommend keep `level/5`. Energy 24 % vs "Charged" is a pen error. **[verified: added]** The pen's mood bar fill `#2e8b57` **is exactly** `MoodLevel.great.color` `#2E8B57` (`MoodLevel+Palette.swift:22`) — the one pen colour on this screen that already matches a shipped token. |
| Glyphs | CHANGE (assets NEW in DS package) | `SignalGlyph` → `SproutGlyph` / `BoltGlyph` / `ApertureGlyph` Canvas drawings tinted by ramp (`SignalGlyph.swift:45-62`, `Glyphs/`) | filled multi-colour illustrations (`#4caf50/#388e3c` sprout, `#4278a8/#447097/#eda94a` target, `#eda94a` bolt) at three different box sizes | Screen glyphs ≠ Frame 12 glyphs (Q7); a common 32 pt box is needed or the baselines misalign as in the PNG. |
| Diagonal separators | NEW | none | two `/` hairlines `#000000@0.10`, 81 pt rotated | Decorative; needs a small `Shape`. Q8 asks whether to keep them. |
| Empty signal | REMOVE (behaviour) | a column is omitted when its signal is `nil`; whole strip hidden when all nil (:121-125) | no empty state drawn | Keep today's omission rule unless the pen adds a "not logged" state. |

### 2.3 Section 2 — "Today's Emotional Condition"

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Container | CHANGE | `.newLookCard()` with header "Emotions" (`ADHDSummarySection.swift:87-99`) | section title 16/600 outside, **no card** | Title copy C-04 ("Emotions" elsewhere). |
| Chip | CHANGE → shared **Bill-shape** component | `TagFlowView` chip: `heart.fill` + `.caption/.medium` in `Theme.accent` (bronze `#B8842A`, `Theme.swift:8`) on `accent@0.13` capsule (`TagFlowView.swift:9-24`, colour at `ADHDSummarySection.swift:89`) | `BG=solid`: fill+stroke `#2a9134`, r 15, text 14/500 `#ffffff`, padding 6/16, shadow `0 7 6 #183c28@0.06`, 29 tall (DS master is 12/500, 27 tall — C-16) | Drops the heart icon. White on green-500 is 4.04:1 (fails AA at 14 pt). **[verified: added]** Q5 from the screen spec is unaddressed: every chip is solid green regardless of valence — do "Unpleasant" emotions (`Lexicon.swift:274-278`: angry, anxious, sad, …) render in the same green solid? Today all emotions share one bronze tint, so the code has no valence colour either. |
| Wrap | KEEP | `FlowLayout` wraps (`TagFlowView.swift:32-77`) | 2 chips, no clipping | Pen's edit screen clips rows; here wrap is right. |
| Empty | KEEP | card omitted when `decodedEmotions` empty (:91) | not drawn | — |

### 2.4 Section 3 — "Your Medications"

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Container | CHANGE | one `.newLookCard()` headed "Medications" (`ADHDSummarySection.swift:32`) with a single joined line `"Name dose ×½ (missed) · …"` (:30-57) | section title "Your Medications" 16/600 + **one style-A row card per medication** (342×50, padding 11) | Per-row layout replaces the joined string. **[verified: added]** C-05: "Your Medications" (pen) vs "Medications" (code today) vs "Medication" (pen Edit) — pick one. |
| Badge + glyph | CHANGE | `SignalGlyph(.medication, size: 18, decorative: true)` = two-tone **horizontal filled** capsule (`Glyphs/CapsuleGlyph.swift`) in `Palette.medication` | 28 ⌀ circle `#f4f0fb` stroke 0.45 `#000000@0.10` + 15 pt **outline diagonal** capsule `#4d3974` | New glyph drawing or asset; medication purple token moves `#7E5CA8` → violet-800/50. |
| Text | CHANGE | `"\(name) \(dose)"` (:47), `Typography.body` | `"Concerta · 36 mg"` 14/500 `#17501d` (green-800, not violet) | Needs a formatter (middle dot; SI spacing — dose strings from transcripts are free text, e.g. "36mg"). |
| Which events | DECISION | `.transcript` only, sorted by `takenAt` (:15-19) — manual doses logged inside a text check-in are hidden (known seam) | undefined | Say whether the row lists all `recording.medicationEvents`. |
| Quantity / missed / time / status | REMOVE (info) | `×½`, `×2`, `(missed)` (:48-54); no time, no status | none of them | Losing `(missed)` hides a `taken == false` event as if taken — flag. Time (`takenAt`) and status words exist (§3) but the pen omits them here (Q17). |
| Row tap **[verified: added]** | UNDEFINED | the joined line is static text | card row with no chevron | The screen spec (§7) asks whether the row opens a medication detail / log sheet; the cross-check did not decide. Today nothing on this screen logs a dose except the medication bar overlay. |

### 2.5 Removed sections between Emotions and the AI card

| Element | Verdict | Today | Lost function |
|---|---|---|---|
| Sleep card | REMOVE | `ADHDSummarySection.swift:61-83`: "Deep" (`decodedSleepLevel.rawValue.capitalized`) or "7h sleep" chip in `Palette.sleepIndigo` (`#5566A6`, `Palette.swift:24`) with the bed glyph | The only place the detail shows sleep. Data still captured by the LLM and editable in the Edit sheet — silently dropped from the read view (Q2). |
| Side effects card | REMOVE | `:103-115`: `decodedSideEffects` chips, `bandage.fill`, `Palette.warning` (`#C2772E`) | The pen transcript itself mentions "dry mouth" and "jitters"; the chips vanish (Q4). |

### 2.6 Section 4 — "Daily Check-In" AI card with player

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Section title | CHANGE | card header "Summary" (:205) | "Daily Check-In" 16/600 outside the card | Copy C-08 (a day can hold 3 check-ins). |
| Card | CHANGE | three cards: Summary (:203-221), Transcript (:226-262), Audio (:291-298) | **one** style-B card r 24, padding 11, gap 11 | Merge summary + player; transcript is gone (next table). |
| AI caption | CHANGE | `Label("Written by on-device AI from your voice — tap Edit to correct", systemImage: "sparkles")` `caption` `inkSecondary`, **below** the text (:215-217) | sparkle vector 13.6×16.4 `#7f5fc0` + "Written by on-device AI from your Voice, tap to Correct" 12/400 `#8a8a8e`, **above** the text, 2 lines, then a 1 pt divider | Custom sparkle asset (not SF `sparkles`) or keep SF. Copy C-07. `#8a8a8e` is the AA-failing `inkSecondary` value the owner accepted 2026-07-12 (3.44:1 on white, 3.04:1 on `screen`; `NewLook.swift:21-25`). |
| Body | CHANGE | `summaryBullets` each as a `Typography.body` (16 pt) paragraph (:207-213) | one paragraph 12/400 `#1e2225`, ≈15 pt line height | `summaryBullets` is a **single narrative string** on the live path (`ExtractionValidator.swift:855-861`: `bullets = [summary]`, else `[rawTranscript]`), so the pen's paragraph maps 1:1. 16 → 12 pt is a readability regression for the ADHD audience — flag. |
| Fallback guard | KEEP (must carry over) | card hidden when `bullets == [fullTranscriptText]` (:193-199) — the raw transcript echoed back must not be labelled "written by AI" | no state drawn | Without this guard, text check-ins and LLM-failed notes show the user's own words under an AI byline. |
| "tap to Correct" | NEW | nothing edits the summary: `ExtractionReviewView` has no summary field (no `summary`/`bullet`/`TextEditor` in the file); `ExtractionReviewViewModel` only re-seeds `bullets` (`:87`, `:237`) | tap → correct | Needs an editor (inline `TextEditor` or sheet), a VM write path (`summaryBulletsJSON` + `summary`), and a provenance flag so the caption can change — none exists (§3). |
| Divider under body | NEW | — | 1 pt `#000000@0.10` | trivial |
| Player position | CHANGE | own "Audio" card, last | inside the AI card, after the second divider | Move `AudioPlayerView` into the composite. |
| Play button | CHANGE | 44 pt circle (label fills a `minWidth/minHeight: Metrics.minTapTarget` = 44 frame, :15-16, :51-52), `Palette.medication` fill, `play.fill/pause.fill/ellipsis` (`AudioPlayerView.swift:37-64`) | 27.75 ⌀ `#8c68d3`, stroke 0.75 `#000000@0.10`, `tabler:player-play-filled` 17.25 | Keep the 44 pt hit frame around the 27.75 visual. Pause/finished/loading states exist in code; the pen draws only "play". |
| Waveform | CHANGE (+ possible NEW data) | `PlaybackWaveformBars`: **32 bars** (`:6`), spacing 3 (`:11`), heights 4–24 from a hash of `recording.id` + index (`:42-49`), played `Theme.accent@0.6` / unplayed `tintNeutral` (`:18`), drag-end seek (`:24-30`), height 28 (`:32`) | **55 bars** 2.5 wide, pitch 4.6, heights quantised to 5 values (0.23/0.40/0.53/0.74/1.0 × 24.75), played `#8c68d3` / unplayed `#eaf4eb` (1.13:1 on white) | Bar count must derive from width, not 55. If the pen intends **real amplitudes**, no such data exists (§3). |
| Time label | CHANGE | **elapsed** `currentTime` as `"%02d:%02d"` in `Typography.duration` (SF Mono 12, `Typography.swift:51`) `inkSecondary`, minWidth 42 (`:26-30`, `:74-79`) | "03:24" 9/600 `#4d5154` — reads as **total** | Q11: total vs elapsed. 9 pt is below iOS's 11 pt floor. **[verified: corrected]** The leading-zero format is *not* purely a pen choice: the player already renders `"%02d:%02d"` (`AudioPlayerView.swift:78`, e.g. "03:24"), while the title meta line uses `Recording.formattedDuration` `"%d:%02d"` ("3:24", `Recording.swift:125`). Two formats coexist in code today; C-09 is a code cleanup as much as a pen fix. |
| Text check-ins | RISK | player renders for `audioFileName "text-…"` recordings (`RecordingStore.swift:143`) and errors "Audio file not found" on tap (`AudioPlaybackViewModel.swift:30-35`); `duration == 0` | no "no recording" state | Must hide the player row (and the second divider) when `storageService.getAudioURL(for:)` is nil (`AudioFileStorageServiceImpl.swift:60-63`). |

### 2.7 Transcript — the biggest functional removal

| Element | Verdict | Today | Lost function |
|---|---|---|---|
| Transcript card | REMOVE | `transcriptSection` (:226-262): header + status pill (`Recorded` amber · `Transcribing` · `Completed` · `Failed`, :265-278; `.placeholder` / `.pendingTranscription` draw **no pill**, :275-276); `.failed` → **"Retry transcription"** button (:234-239, the only caller of `RecordingDetailViewModel.retryTranscription` — confirmed by grep); `.transcribing` → spinner + "Transcribing…" (:241-248); empty → "No transcript available yet." (:249-252); else the full text (:253-258) | 1) The user's verbatim words — the "auditable" half of PRODUCT.md principle 4 (`PRODUCT.md:48`: "every inferred signal is shown plainly, attributed, and one tap from correction"). 2) **The recovery path**: `RecordingStore.swift:34-45` (orphan recovery, copy at :40) and `CheckInViewModel.swift:349, :357` write transcript text *"…Tap to retry in the recording detail view."* — that instruction points at a button the pen deletes. 3) Any visible state for a recording that is still transcribing, pending, or failed (the title placeholder is removed too, §2.1). **[verified: added]** A fourth state exists: `.pendingTranscription` ("Ready shortly…" title, `Recording.swift:47`; no pill; "No transcript available yet.") — the pen designs none of the four. |

Recommendation: keep the transcript reachable (a "Transcript" disclosure under the summary, or `•••` → "Show transcript") and design the transcribing/pending/failed states for the AI card. This is a spec item, not a restyle.

### 2.8 Removed / dead code that this screen's rewrite should settle

- `RecordingDetailViewModel.toggleFavorite`, `updateTitle`, `updateDate`, `updateMood`, `startRegenerate` (+ `generateSummary`, `regenerateSummary`) (`:30`, `:38-75`) — no UI today, none in the pen. Constitution III says delete unless the `•••` menu adopts "Regenerate summary". **[verified: added]** `startRegenerate` has a unit test (`RecordingDetailViewModelTests.swift:36-47`) that goes with it; `RecordingStore.toggleFavorite` (`RecordingStore.swift:87`) and `RecordingStore.updateTitle` (`:93`) are the store-side halves of the same dead pair.
- `Recording.isFavorite` (`Recording.swift:15`) — never rendered (no reference in `Views/` or `ViewModels/` besides the VM method); not in the pen.
- `NewLook.selection` as the `rampColor` default (`RecordingDetailView.swift:179`) — unreachable branch (`default:` for mood, which never calls `rampColor`; mood passes `level.deepFill` directly at :130).
- **[verified: added]** `app-four/Views/Components/Chip.swift` (`Chip.topic` / `Chip.filter`) has **zero call sites** in `app-four/` — already dead. Relevant to Risk 7 below.

---

## 3. Data availability — every field/label the pen shows

| Pen field | Exists? | Source | Gap / note |
|---|---|---|---|
| Title "Today's Mood" | **NO as drawn** (hard-coded copy) | Relative day label exists in `MoodLibraryViewModel.dayLabel(for:)` (`:157-165`: "Today, d MMM" / "Yesterday, d MMM" / "EEEE, d MMM"; formatters at `:25-33`) but on the calendar VM, not the detail | Recommend a relative title from `recording.createdAt`; needs a small formatter on the detail VM. |
| Date "Monday, Jun 29" | yes | `Recording.createdAt` (`Recording.swift:7`); today formatted `"EEE · d MMMM"` (`RecordingDetailView.swift:109-112`) | Change format to `EEEE, MMM d`. |
| "Mood" / "Focus" / "Energy" labels | yes | `GlyphSignal.title` (`GlyphSignal.swift:13-21`) | — |
| "Great" | yes | `MoodLevel(name: recording.mood)?.displayLabel` (`MoodLevel+Palette.swift:65-73`); today uses `mood.capitalized` (:130) | — |
| "Sharp" / "Locked In" | yes | `FocusLevel(rawValue:)?.displayLabel` (`Levels.swift:113-121`) | Stored raw is `"lockedIn"`; always go through the enum. |
| "Charged" | yes | `EnergyLevel.displayLabel` = `rawValue.capitalized` (`SignalLevel.swift:57`) | — |
| Bar fractions 91 % / 56 % / 24 % | **NO** | Only 1–5 enums (`numericValue`, `Levels.swift:20, :65, :110`); bar today = `level/5` (:163-172) | A continuous score would need a new LLM output, validator rule (Principle VII clamps to enum rawValues) and a schema column. Not worth it — use `level/5`. |
| Value colours `#0e7718` `#447097` `#e38400` | NO tokens | Today `MoodLevel.deepFill`, `Palette.energyRamp`, `Palette.focusRamp` | New tokens + dark pairs; energy amber fails AA as text (2.78:1). Mood already has an AA word token (`wordColor`, §2.2). |
| Chips "Proud", "Excited" | yes | `Recording.decodedEmotions` (`Recording.swift:169-174`), values are lowercase members of `Lexicon.defaultEmotions` (`Lexicon.swift:271-278`; "proud", "excited" included) → `.capitalized` | — |
| "Concerta · 36 mg" | yes (format varies) | `MedicationEvent.name` / `dose` (`MedicationEvent.swift:12-13`); catalog doses are `"36 mg"` (`MedicationCatalog.swift:23`), transcript doses are free text | Needs one formatter (C-06). |
| Medication status "Kicking In" / "Active" (Calendar; not on this screen) | yes, private | `stateWord(for:)` in `MedicationBarView.swift:79-86` (fill-fraction thresholds 0.2/0.8, words "kicking in / active / wearing off / worn off") over `MedicationEvent.effectProgress(at:)` (`:68-72`) | Private to the bar; hoist to a shared helper if the detail ever shows it. Catalog `onsetMinutes` (`MedicationCatalog.swift:10, :24`) exists but the bar ignores it (only `MedicationLogSheet.swift:105` reads it, as info text). |
| Medication time "09:54" (not on this screen) | yes | `MedicationEvent.takenAt` (`:15`) | **[verified: added]** Two time formats already coexist in code: the detail meta line uses locale `time: .shortened` (`RecordingDetailView.swift:115`), the medication bar a fixed `"HH:mm"` (`MedicationBarView.swift:90-94`). The screen spec's 12 h / 24 h inconsistency is a code fact too. |
| Taken / missed | yes | `MedicationEvent.taken` (`:16`), `quantity` (`:17`) | Pen hides them. |
| "8h Sleep" (Calendar; absent here) | yes | `Recording.sleepLabel` (`Recording+MoodDisplay.swift:94-103`), `sleepHours` (`Recording.swift:30`), `decodedSleepLevel` (`:165-167`) | — |
| Side effects (absent here) | yes | `Recording.decodedSideEffects` (`:158-163`) | — |
| Summary paragraph | yes | `Recording.summaryBullets` (`:145-150`) — one string from pass 1 (`MLXJournalService.swift:52-62`; `ExtractionValidator.swift:855-861`); `summary` column duplicates it as "- …" lines (`:280`) | Fallback `[rawTranscript]` (`ExtractionValidator.swift:893-910`) must not be shown under the AI byline. |
| "Written by on-device AI" provenance / "edited by you" | **NO** | `RecordingTag` categories are mood/energy/focus/medication/emotions (`RecordingTag.swift:11-17`); `ExtractionReviewViewModel` tags only those five (`:273-289`). No `summaryEditedAt`, no summary tag category. `summaryStatus` (`Recording.swift:20`; `AppEnums.swift:92-97` notGenerated/generating/completed/failed) covers the *generating* state only | Needs a new column (schema change → constitution IX, empty migration plan in `App/SquirlSchema.swift:25-33`) or a `TagCategory.summary` row. |
| Summary editing target | **NO** | No write path for `summaryBulletsJSON` outside `applySummary` (`Recording.swift:202-284`) | New VM method + tests (Principle X). |
| Duration "03:24" | yes | `Recording.formattedDuration` `"%d:%02d"` (`Recording.swift:122-126`) → "3:24"; player `timeString` `"%02d:%02d"` (`AudioPlayerView.swift:74-79`) → "03:24"; `AudioPlaybackViewModel.duration` after load (`:41`) | **[verified: corrected]** Both formats ship today; C-09 must pick one for the whole screen. |
| Playback position 41.8 % | yes | `currentTime / duration` (`AudioPlayerView.swift:20`) | — |
| Waveform amplitudes (55 × 5 levels) | **NO** | `PlaybackWaveformBars.barHeight` is a hash of the recording id (`:42-49`) — decorative, not audio | Real amplitudes = read the m4a with `AVAudioFile`, downsample off the main actor (Principle VIII: "dispatch CPU/IO-heavy work off the main actor"), cache (a new `waveformJSON` column is another schema change; a file-side cache avoids it). |
| Recording status (transcribing / pending / failed) | yes, unrendered in pen | `Recording.status` (`:12`; `AppEnums.swift:5-13`) | Pen has no state. |
| Check-in time | yes, unrendered in pen | `Recording.createdAt` | Needed to tell three same-day check-ins apart. |
| Month selector · "24 check-ins" · weekday dominant level · connection unlock thresholds · "Installed" · "34MB" | n/a | Not on this screen (Insights / Settings) | Covered by the sibling cross-checks. |

---

## 4. Navigation delta

| Item | Today | Pen | Delta |
|---|---|---|---|
| Tab bar | Native `TabView` + `.tabItem` (`RootTabView.swift:19-36`; SF symbols `calendar` / `checkmark.circle` / `chart.bar.fill` / `gear`, `Icons.swift:7-10`), tint `Theme.meadowGreen` (:36), painted opaque `NewLook.screen` from each tab root (`ScreenContainer.swift:56-60`); no iOS 18+ `Tab` builder, no `tabBarMinimizeBehavior` | Custom floating pill 274×60 (`#ffffff`, r 75, shadow `0 8 24 #183c28@0.16`), active pill `#2a9134` icon-only 64×44, inactive icons `#999b9d` (2.79:1) | Global NEW component. Two options: (a) hide the system bar (`.toolbar(.hidden, for: .tabBar)`) and overlay a custom bar at the root — loses system behaviours (tab re-tap-to-root, iOS 26 minimize-on-scroll, VoiceOver tab traits unless re-added); (b) restyle the native bar — cannot reach the pen's pill shape. Decide once, app-wide, not on this screen. **[verified: added]** Q16 (icon-only active pill vs the DS `Navigation` variant with a 12/500 label, 122 wide) is also unresolved and changes the bar's width math. |
| Tab bar on pushed screens | Visible (NavigationStack lives inside each tab) | Visible on this screen, hidden on Edit Check-In (`iPhone 17 - 18`) | Matches today for the detail. Edit today is a **sheet** (`.sheet(item:)` `RecordingDetailView.swift:71-73`; `presentationDetents([.large])` is set inside `ExtractionReviewView.swift:53` **[verified: corrected]**), which naturally hides the bar — the pen draws Edit as a pushed page with a back pill (Q-L2). |
| FAB `+` | does not exist | 50 ⌀ `#8c68d3`, `add` icon `#e9e9ea` (3.44:1) | NEW, global. Plumbing exists: `AppIntentRouter.requestCheckIn()` (`Intents/AppIntentRouter.swift:41`) → `SquirlApp.swift:72-76` `selectedTab = .checkIn; shouldAutoStartRecording = true`. Tapping it from a pushed detail also pops the Calendar stack (`CalendarLibraryView.swift:57-62` clears `path` on tab change) — acceptable. Q12: dated today, not the viewed day. |
| Back | System back + interactive pop | 42.6 pt custom pill, chevron only | Either a custom `ToolbarItem(placement: .topBarLeading)` (keeps the pop gesture) or hide the nav bar and draw the header in content (pop gesture can break; must be verified on device). Hit area < 44 pt → pad. |
| `•••` | Trailing pencil → Edit sheet | Menu, undesigned | `Menu` with Edit (exists), Delete (exists; relocate), and — to be decided — Transcript, Share transcript (`exportTranscript` in `Services/Protocols.swift:127`, impl `AudioFileStorageServiceImpl.swift:65-94`, exists and is unused from this screen), Regenerate (`startRegenerate` exists, unused). Export must never be gated (CLAUDE.md). |
| Bottom inset | System safe area; no `edgeFadeMask` (not a `ScreenContainer`; the mask is `EdgeFadeMask.swift:29`) | Floating bar 60 + 34 home indicator + 5 → ≥ 95 pt inset | `safeAreaInset(edge: .bottom)` or `contentMargins`; also `ScrollView` must scroll when content exceeds 874 pt (pen fits by luck at 714.75). |
| Sheets | Edit (`ExtractionReviewView`), delete `confirmationDialog`, model-missing `alert` | none drawn | Keep. |

---

## 5. Accessibility · Dynamic Type · dark mode (this screen)

**Type.** The pen is Inter at fixed 9/12/14/16/18/20 pt; every `Typography` role today scales via `UIFontMetrics` (`Typography.swift:12-18`). Mapping if SF stays (Q13): 20/600 → `Typography.text(20, weight: .semibold, relativeTo: .title3)` (new; signature at `Typography.swift:59`); 18/600 → `text(18, weight: .semibold, relativeTo: .headline)` (new); 16/600 → `headline` (exact, `:34`); 14/500 → `subheadline` (exact, `:36`); 12/600 → `caption` + `.weight(.semibold)`; 12/400 → `caption` (`:44`); 9/600 → **do not ship 9 pt** — `text(11, weight: .semibold, relativeTo: .caption2)`. Body at 12 pt for the narrative is the one size to push back on: today it is 16 pt `body` (`:38`), and this is the paragraph the user reads.

**Dynamic Type layout.** Three 94 pt signal columns with 14 pt labels + 12 pt values break at AX sizes ("Charged"/"Energy" exceed 94 pt). Precedent: `CalendarHeaderView.swift:20` forces week view at `dynamicTypeSize >= .accessibility1`; do the same here (columns stack vertically). Chips wrap already (`FlowLayout`). The medication row must allow the name to wrap under the badge. The player row: hide the waveform below `.accessibility3` and keep play + time.

**Contrast (re-computed by the verifier; all light mode, WCAG relative luminance).** Fails: Charged `#e38400` on white **2.78**, caption `#8a8a8e` on white **3.44**, date `#6f7f75` on `#fbfffc` **4.19** (12 pt), chip white on `#2a9134` **4.04** (14/500; green-600 `#26842f` gives 4.75), inactive tabs `#999b9d` **2.79** (non-text 3:1), energy bar on track **2.29** (Mood 3.50, Focus 4.32), unplayed waveform `#eaf4eb` **1.13**. Passes: "Great" `#0e7718` 5.72, "Sharp" `#447097` 5.24, FAB plus `#e9e9ea` on `#8c68d3` 3.44 (icon), header title `#17501d` on `#fbfffc` 9.45, "03:24" `#4d5154` 8.01. `DayCardPaletteTests.swift:35-46` already asserts ≥ 4.5:1 for `MoodLevel.wordColor` on the block tint in both modes — extend the same helper to the three signal value colours and the chip label so the rule is enforced, not remembered.

**Hit targets.** Back/`•••` 42.6, play 27.75, chips 29 tall — all < 44. `AudioPlayerView.swift:15-16` already wraps the button in `Metrics.minTapTarget` (44, `Metrics.swift:10`) + `.contentShape(.rect)`; reuse. Chips are display-only here → not buttons, no target rule, but group them.

**VoiceOver.** Keep `heroColumn`'s `accessibilityElement(children: .ignore)` + `"Mood: Great"` (`:159-160`). Diagonal separators `accessibilityHidden`. Emotions: one element "Emotions: Proud, Excited". Medication row: "Concerta, 36 milligrams" (spell the unit). AI card: if tappable, a button with label "Summary, written by on-device AI" and hint "Double tap to correct" — do not read the caption's imperative copy as content. Waveform today exposes only a percent label (`PlaybackWaveformBars.swift:34`) and seeks on drag-end; add `.accessibilityAdjustableAction` for scrubbing. Timer label reads "3 minutes 24 seconds", not "03:24".

**Colour is never the only cue.** Signal values carry word + glyph + colour — fine. Played/unplayed waveform is colour-only at 1.13:1 — needs a luminance step (violet-100 `#dbd0f1` gives 1.47, still weak) or a position marker.

**Dark mode.** Nothing in the pen. Every new colour must go through `Color(lightHex:darkHex:)` (`Color+Hex.swift:7`) like the existing tokens; derived dark values are the spec-033 precedent (2026-07-16 ruling, DESIGN.md Decisions Log). Specific traps: `#ffffff` cards on a dark ground need the existing `#1C1E19`-style card (`NewLook.swift:15`); the 0.5 pt `#000000@0.10` card stroke is invisible on dark (needs a light hairline); the `#183c28` shadow disappears on dark (drop or lighten); violet-50 badge `#f4f0fb` needs a dark tint; `#e9e9ea` bar tracks and `#eaf4eb` unplayed bars need dark pairs; the sparkle `#7f5fc0` and play `#8c68d3` are fine on dark.

**Reduce Motion.** No motion on this screen beyond playback; nothing to gate.

---

## 6. Risks and open questions

### Risks

1. **Transcript + retry removal deletes the only failure-recovery UI.** `retryTranscription()` is reachable solely from `RecordingDetailView.swift:234-239`; recovery copy elsewhere (`RecordingStore.swift:40`, `CheckInViewModel.swift:349, :357`) literally sends users here. Shipping the pen as drawn strands failed recordings.
2. **False AI attribution.** With the transcript gone and the body under an AI byline, the `hasSummary` guard (`:193-199`) is the only thing stopping a typed note or a fallback transcript from being labelled "written by on-device AI". The pen draws no state for it.
3. **Summary correction needs persistence the model lacks** — a provenance flag means a schema change; under constitution 3.0.0 (on `feat/055-revenuecat`, "Version change: 2.2.0 → 3.0.0") the store may not be wiped in release, and `SquirlSchemaV1` has an empty migration plan (`SquirlSchema.swift:31-33`). Plan the migration or use a `RecordingTag` row (no schema change, but `TagCategory` gains a case).
4. **Custom nav bar vs interactive pop.** Hiding the system bar to draw the pill header can disable swipe-back; verify on device before committing to the header approach.
5. **Glyph asset ambiguity blocks the signal card.** Screen glyphs ≠ Frame 12 glyphs; energy/sleep masks export as black blocks; three box sizes. Cutting assets before Q6/Q7 are answered means cutting twice.
6. **Token cascade into tests — mood only. [verified: corrected]** Mood hexes are pinned by `RecordingMoodDisplayTests.swift:28-33` and `DayCardPaletteTests.swift:51`; the energy/focus ramps in `Palette+Signals.swift` are pinned by **no** test, and `SignalGlyphTests` pins level names/clamping only. Changing mood colours here means re-pinning two tests; changing energy/focus colours breaks nothing — which is itself a gap (no guard on those ramps).
7. **Sixth-plus chip grammar. [verified: corrected]** Chip implementations that coexist: `.newLookChip` (`NewLook.swift:94-107`; used by `ExtractionReviewView`, `MonthSelectorScrollView`), `TagFlowView`, `RecordingRow.swift:89`, `MedicationLogSheet.swift:177-179`, `SettingsChip` (`Settings/MyMedicationSection.swift:106, :129`), and a private `Chip` in `FoldedDayCardHeader.swift:112-118`. `Components/Chip.swift` is a seventh definition with **zero call sites** (dead). Adding Bill-shape without deleting the others fails constitution IV/III; deleting `Chip.swift` is free.
8. **Real waveform cost.** Decoding up to 8 min of AAC on open is IO/CPU work; it must be off-main and cached, or the screen stutters on push. Seeded bars are cheaper and already exist — but they are fiction.
9. **12 pt body for the one paragraph the user reads**, in an app whose audience rule is low cognitive load. Product regression, not a style choice.
10. **Medication `.transcript` filter** already hides manual doses inside text check-ins; the pen doesn't decide, so the seam ships unless the spec says.
11. **FAB on a pushed detail** contradicts PRODUCT.md "one primary action per screen" (`PRODUCT.md:45`) and coexists with back + `•••`.
12. **Timeline.** Nothing here can reach a Shipaton build; the screen ships post-055 merge, after the `feat/057` re-cut (constraints §5.2, items 1 and 4).

### Open questions for the owner (only the ones the code cannot answer)

1. **One check-in or the whole day?** The view is a `Recording`; days hold several. If day: aggregate how, and where do the other check-ins go? If check-in: the title must carry the time.
2. **Where does the transcript live** (disclosure under the summary, `•••` → Transcript, or gone), and what do the *transcribing* / *pending* / *failed* / *retry* states look like?
3. **Sleep and side effects:** dropped from the read view on purpose, or add two chip sections (data and edit UI already exist)?
4. **Bars:** `level/5` (what exists) or a continuous score (new LLM output + schema)?
5. **"tap to Correct":** inline editor or sheet; does the caption become "Edited by you"; is the edited text persisted as the summary (schema) or as a tag?
6. **Waveform:** real amplitudes (new service + cache) or the existing seeded bars restyled?
7. **Text check-ins:** what does the card show with no audio and a typed note (hide the player row; drop the AI byline)?
8. **`•••` menu contents:** Edit + Delete only, or also Share/Export transcript and Regenerate summary (both have backend, no UI)?
9. **Medication row:** transcript-only events (today) or all; show `(missed)`, time and status, or name · dose only? Is the row tappable, and to what?
10. **Medication bar overlay on this screen:** keep (today) or drop (pen)?
11. **FAB on a detail page:** keep (creates a check-in for *today*, pops the stack) or hide on pushed screens?
12. **Dark mode in scope for the refresh?** Decides whether every token above ships with a pair.
13. **Inter or SF?** Global, but it fixes every size on this screen and whether 9/12 pt survive.
14. **Body at 12 pt** — accept the pen or hold the current 16 pt body for the narrative?
15. **[verified: added] Emotion chip valence:** do unpleasant emotions render in the same solid green-500 chip (Q5 in the screen spec)?
16. **[verified: added] Gutter:** 28 (tab bar), 31 (header) or 30 (content right) — the pen has three; today is 16.

---

## 7. Rough effort — senior SwiftUI engineer, tokens + shared components assumed done

Shared work **not** counted here: palette tokens + dark pairs, Bill-shape chip, card modifiers (style A/B), Circle Icon Button, floating tab bar + FAB, Frame-12 glyph assets, Inter/SF decision.

| Bucket | Item | Hours |
|---|---|---|
| NEW | Custom header: back pill + title/date + `•••` `Menu` (Edit / Delete / Transcript), hide or replace the system bar, keep the pop gesture, 44 pt hit areas | 3 |
| NEW | Signal card: 3 columns, diagonal separators, value colours, `level/5` bars, AX-size vertical fallback | 4 |
| NEW | Composite AI card: caption row (sparkle asset), dividers, body, inline player; states: generating, fallback-transcript, no-audio, transcribing/pending/failed (whatever Q2 decides) | 4 |
| NEW | Summary correction: editor + `RecordingDetailViewModel` write path + provenance flag + persistence/migration + tests | 6 |
| NEW | Waveform: width-derived bar count, 5-level quantisation, played/unplayed tokens, adjustable AX action — seeded bars | 2 |
| NEW | HTML mockup before SwiftUI (constitution I, `constitution.md:29`) incl. AX5 and dark toggles | 3 |
| **NEW subtotal** | | **22** (+6 if real amplitudes: `AVAudioFile` reader off-main, cache, tests) |
| CHANGE | Emotions: section title, Bill-shape chips, drop card + heart | 1 |
| CHANGE | Medication rows: per-event card, badge + outline capsule glyph, `name · dose` formatter (catalog vs free-text doses) | 2 |
| CHANGE | Player restyle: 27.75 visual in 44 hit frame, colours, one duration format (C-09, both exist today), pause/finished icons | 2 |
| CHANGE | Page rhythm: gutter per Q16 (pen 28/31/30, today 16), 24/12/8 gaps, `#fbfffc` ground, bottom inset for the floating bar, scrolling | 2 |
| CHANGE | Dark pairs + AA test extension for this screen's colours (extend `DayCardPaletteTests` helper) | 2 |
| CHANGE | VoiceOver pass (grouping, labels, hint on the AI card) + AX-size QA | 2 |
| **CHANGE subtotal** | | **11** |
| REMOVE | Title block, sleep card, side-effects card, transcript card, audio card, bottom delete; relocate delete + retry; fix recovery copy in `RecordingStore` / `CheckInViewModel` if the transcript moves | 3 |
| REMOVE | Dead VM methods (`toggleFavorite`, `updateTitle/Date/Mood`, `startRegenerate` + its test if not adopted), store-side `toggleFavorite`/`updateTitle`, `isFavorite` UI remnants, `Components/Chip.swift`, stale comments (`:38-42`) | 1 |
| **REMOVE subtotal** | | **4** |
| Verify | Build + full test run (serial), simulator run, PR + `/code-review` findings, owner device-QA support | 4 |
| **Total** | | **≈ 41 h** (≈ 47 h with real waveform amplitudes) |

Assumes the owner answers Q1–Q9 before `/speckit-specify`; each unanswered one adds a rework loop of roughly 2–4 h. The verifier found no evidence to move the totals; the corrections above shift work between rows (e.g. fewer test re-pins for energy/focus, one extra dead file to delete), not the sum.

---

## 8. Verifier notes

Method: every file path and line range in the original was opened in the worktree at `08ba8cba`; every contrast figure was recomputed from the hex values (WCAG 2.x relative luminance); the screen spec and the PNG were re-read for sections, states, copy and clipping the cross-check did not mention. Claims that held are left as written. Nothing below is speculative; each row names the evidence.

### Corrections (claim → correction → evidence)

| # | Original claim | Correction | Evidence |
|---|---|---|---|
| 1 | §2.1 Nav bar: the pen "reverses the 2026-06-15 decision 'no back button (swipe-left); pencil → Edit' — log it." | The shipping code already reversed that decision under spec 023: it has a **system back control** and a **trailing pencil**. The pen keeps back + trailing control and changes only their form (pill + `•••`). The log entry should record "back pill + `•••` supersede system back + pencil (spec 023)", not a reversal of 06-15. | `RecordingDetailView.swift:41-42` (comment: "Pushed from the calendar / insights (spec 023): a standard back control returns to the day"), `:61` (`Image(systemName: "pencil")`); `git show HEAD:DESIGN.md` Decisions Log row "2026-06-15 · Detail: no back button (swipe-left); pencil → 'Edit check-in' button". |
| 2 | §2.2 / Risk 6: "Energy/focus ramps (`Palette+Signals.swift`) and mood hexes are pinned by `RecordingMoodDisplayTests`, `DayCardPaletteTests`, `SignalGlyphTests`; changing value colours here means … re-pinning." | Only **mood** hexes are pinned. No test in `app-fourTests/` references `energyRamp`, `focusRamp` or any of `#7C6E2E / #FCEE64 / #44546E / #79C4FF / #63A4E0`. `SignalGlyphTests` pins level names and clamping, no colours. | `app-fourTests/Models/RecordingMoodDisplayTests.swift:28-33` (`#9FCB79`, `#DA7A2A`, `#2E8B57`); `app-fourTests/Models/DayCardPaletteTests.swift:51` (`#2E8B57`); `app-fourTests/SignalGlyphTests.swift:10-39` (no `Color`/hex/ramp); grep of `app-fourTests` for the ramp identifiers and hexes returns nothing; `Packages/SquirlDesignSystem/Tests` does not exist. |
| 3 | §3 Duration: "Leading zero (C-09) is a pen choice; code gives '3:24'." | Code gives **both**: `Recording.formattedDuration` is `"%d:%02d"` ("3:24") but the player's `timeString` is `"%02d:%02d"` ("03:24"). C-09 is also a code inconsistency. | `Recording.swift:125`; `AudioPlayerView.swift:78`. |
| 4 | §4 Tab bar on pushed screens: "Edit today is a sheet (`.sheet(item:)` `:71-73`, `presentationDetents([.large])`)." | The detents modifier is not in `RecordingDetailView`; it is set inside the presented view. | `RecordingDetailView.swift:71-73` (sheet only); `ExtractionReviewView.swift:53` (`.presentationDetents([.large])`). |
| 5 | Risk 7: "Five chip implementations already coexist (`.newLookChip`, `Chip.swift`, `TagFlowView`, `RecordingRow`, `MedicationLogSheet`)." | Count and membership are wrong: `Components/Chip.swift` (`Chip.topic`/`Chip.filter`) has **zero call sites** (dead code), while two implementations were missed — `SettingsChip` and a private `Chip` in `FoldedDayCardHeader`. Live count is six; `Chip.swift` is a free deletion. | grep `Chip.topic\|Chip.filter\|Chip(style` in `app-four/` → none outside `Components/Chip.swift`; `Views/Settings/MyMedicationSection.swift:106, :129` (`SettingsChip(`); `Views/Components/FoldedDayCardHeader.swift:112-118` (`Chip(kind:…)`); `NewLook.swift:94-107`; `RecordingRow.swift:89`; `MedicationLogSheet.swift:177-179`. |
| 6 | §2.8: `startRegenerate` "no UI today … Constitution III says delete." | Deleting it also deletes a passing unit test, and `generateSummary` / `regenerateSummary` (`:38`, `:46`) plus the store's `toggleFavorite` / `updateTitle` are part of the same unreachable set the original did not list. | `app-fourTests/ViewModels/RecordingDetailViewModelTests.swift:36-47` (`startRegenerateOnSecondCallCancelsPreviousTask`); `RecordingDetailViewModel.swift:38-57`; `RecordingStore.swift:87-95`. |

### Omissions added

| # | Added | Where | Evidence |
|---|---|---|---|
| A | The pen's mood bar fill `#2e8b57` is exactly the shipped `MoodLevel.great.color` — the only pen colour on this screen that already is a token. | §2.2 Bars | `MoodLevel+Palette.swift:22`; screen spec §2.3 bar fill `#2e8b57`. |
| B | `MoodLevel.wordColor` (`#1E5C38` light, 7.95:1 on white) is the existing AA-guarded mood-word token and the natural home for the pen's `#0e7718` (5.72:1). | §2.2 Value colours, §3 | `MoodLevel+Palette.swift:55-63`; `DayCardPaletteTests.swift:35-46`. |
| C | Two time formats already coexist in code (locale `.shortened` vs fixed `"HH:mm"`), mirroring the screen spec's 12 h/24 h inconsistency. | §3 Medication time | `RecordingDetailView.swift:115`; `MedicationBarView.swift:90-94`. |
| D | Q5 (chip colour for unpleasant emotions) was never carried into the cross-check; today all emotions share one bronze tint, so the code has no valence colour either. | §2.3, Open question 15 | screen spec Q5; `ADHDSummarySection.swift:89` (`Theme.accent` for every emotion); `Lexicon.swift:271-278`. |
| E | C-05 naming: pen "Your Medications" vs code "Medications" vs pen Edit "Medication". | §2.4 Container | `ADHDSummarySection.swift:32`; screen spec C-05. |
| F | Medication row tap target is undefined (screen spec §7 asks; the cross-check did not). | §2.4 Row tap, Open question 9 | screen spec §7 row "Medication row". |
| G | A fourth recording state, `.pendingTranscription` ("Ready shortly…", no status pill, "No transcript available yet."), which the pen also does not design. | §2.7, Open question 2 | `Recording.swift:47`; `RecordingDetailView.swift:275-276` (`default: EmptyView()`), `:249-252`; `AppEnums.swift:8-11`. |
| H | C-14 gutters: the pen has 31/28/30/28 and today is 16 pt; §7 silently assumed 28. | §2.1 Gutters, Open question 16, §7 | `RecordingDetailView.swift:35` + `Spacing.swift:13`; screen spec §2.0 / C-14. |
| I | Q16 (icon-only vs labelled active tab pill) affects the global bar's width math. | §4 Tab bar | screen spec Q16. |
| J | `Components/Chip.swift` is dead code today. | §2.8, Risk 7, §7 REMOVE | grep evidence in correction 5. |
| K | Exact SF symbols of today's tab items, for the icon-mapping table the DESIGN.md rewrite will need. | §4 Tab bar | `Icons.swift:7-10` (`calendar`, `checkmark.circle`, `chart.bar.fill`, `gear`). |

### Confirmed without change (summary)

All other file/line citations in §1–§7 were opened and hold at `08ba8cba`, including: `RecordingDetailView.swift` (:24-44, :46-68, :71-91, :96-117, :121-181, :193-221, :226-262, :265-278, :291-310), `RecordingDetailViewModel.swift` (:7, :30, :34, :54, :59-75, :81), `ADHDSummarySection.swift` (:8-11, :15-19, :30-57, :61-83, :87-99, :103-115), `TagFlowView.swift` (:9-24, :32-77), `AudioPlayerView.swift` (:15-16, :20, :26-30, :37-64, :74-79), `PlaybackWaveformBars.swift` (:6, :11, :18, :24-30, :32, :34, :42-49), `AudioPlaybackViewModel.swift` (:30-35, :41), `Recording.swift` (:7, :12, :15, :20, :30, :44-50, :122-126, :145-150, :158-174, :202-284), `MedicationEvent.swift` (:12-17, :68-72), `NewLook.swift` (:13, :25, :26, :52-66), `Palette+Signals.swift` (:10-33), `Palette.swift:12` (`#7E5CA8`), `MoodLevel+Palette.swift` (:65-73), `Levels.swift` (:113-121), `SignalLevel.swift:57`, `GlyphSignal.swift` (:13-21), `RecordingTag.swift` (:11-17), `ExtractionReviewViewModel.swift` (:87, :237, :273-289), `ExtractionValidator.swift` (:855-861, :893-910), `MLXJournalService.swift` (:52-62), `RecordingStore.swift` (:34-45, :143), `CheckInViewModel.swift` (:349, :357), `MedicationBarView.swift` (:79-86, :8), `MedicationCatalog.swift` (:10, :23, :24), `Lexicon.swift` (:271-278), `MoodLibraryViewModel.swift` (:157-165), `CalendarHeaderView.swift:20`, `CalendarLibraryView.swift` (:47-54, :57-62, :137), `InsightsView.swift` (:32-34, no push), `RootTabView.swift` (:19-36), `ScreenContainer.swift` (:49-60), `SquirlApp.swift` (:72-76), `Services/Protocols.swift:127`, `AudioFileStorageServiceImpl.swift` (:60-63), `SquirlSchema.swift` (empty `stages`), `Typography.swift` (UIFontMetrics scaling, roles), `Metrics.swift:10`, `Radius.swift:14`, `Color+Hex.swift:7`, constitution principles I/III/IV/VII/VIII/IX/X wording, constitution 3.0.0 on `feat/055-revenuecat`, constraints §5.2, and all eleven contrast ratios (2.78, 3.44, 4.19, 4.04, 2.79, 3.44, 2.29, 3.50, 4.32, 1.13, ≈1.5→1.47).
