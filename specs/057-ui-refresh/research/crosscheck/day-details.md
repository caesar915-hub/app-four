<!-- Created: 2026-09-27 22:27 WEST · Updated: 2026-09-27 22:27 WEST -->
# Cross-check — pen "iPhone 17 - 1" (Day Mode Details) vs the shipping SwiftUI

Inputs: `out/screens/day-details.md` (read fully), the PNG render, `out/design-system.md`, the three codebase maps, `out/constraints.md`, and the Swift files named below (opened and read; every line number is from the worktree at `feat/057-ui-refresh`, HEAD `08ba8cba`). Planning only — no Swift touched, no build run. Paths are repo-relative.

---

## 1. Mapping — what implements this surface today

| Pen | Code | Notes |
|---|---|---|
| The screen | **`app-four/Views/RecordingDetailView.swift`** (322 lines) | A plain `ScrollView` (not `ScreenContainer`), `NewLook.screen` background (:37), `.medicationBarOverlay()` (:40), inline system nav bar (:43-44). |
| View model | `app-four/ViewModels/RecordingDetailViewModel.swift` | Holds one `Recording` (:7). Only `delete()` (:34) and `retryTranscription()` (:81) are reachable from the view; `toggleFavorite` (:30), `startRegenerate` (:54), `updateTitle/Date/Mood` (:59-75) have no UI. |
| Signal card | `signalHeroStrip` / `heroColumn` / `levelBar` — `RecordingDetailView.swift:127-181` | Order **Mood → Energy → Focus** (:129-139). |
| Emotions · Medications · Sleep · Side effects | `app-four/Views/Components/ADHDSummarySection.swift` (:8-11 order: meds, sleep, emotions, side effects) + `TagFlowView.swift:6-27` | Four separate `.newLookCard()`s. |
| AI summary | `summaryCard` — `RecordingDetailView.swift:203-221` | Bullets in `Typography.body`, caption `"Written by on-device AI from your voice — tap Edit to correct"` with `sparkles` **below** the text (:215). |
| Audio player | `audioCard` (:291-298) → `app-four/Views/Components/AudioPlayerView.swift` + `PlaybackWaveformBars.swift` + `app-four/ViewModels/AudioPlaybackViewModel.swift` | Separate last card; 44 pt purple play button (`Palette.medication`, `AudioPlayerView.swift:52`). |
| Push site | `app-four/Views/Library/CalendarLibraryView.swift:47-54` (`navigationDestination(for: UUID.self)`) ← `TimelineRow` tap `path.append($0)` (:137) | Also registered from `InsightsView.swift:34` but nothing there pushes. |
| Models | `app-four/Models/Recording.swift`, `MedicationEvent.swift`; `Packages/SquirlSignals/…/Levels.swift` | — |

**Scope fact the pen leaves open (Q1):** the code surface is **one `Recording` = one check-in**, never a day. `DayTimelineBuilder` puts several check-ins on one day and each `TimelineRow` pushes its own detail. The pen's copy ("Today's Mood", "How Does It Feels Today?", "Daily Check-In") reads as a day view. If the owner wants a day aggregate, this is a different view model (average logic already exists in `DayCardSummary.swift` for the calendar card), not a restyle.

---

## 2. Delta table — section by section (pen order)

Legend: KEEP = already matches · CHANGE = exists, restyle/rearrange · NEW = must be built · REMOVE = exists today, absent in the pen.

### 2.1 Chrome and page

| Element | Verdict | Today | Pen | What changes / what is lost |
|---|---|---|---|---|
| Screen ground | CHANGE (global) | `NewLook.screen` `#EFF2EB` / dark `#12140F` (`NewLook.swift:13`) | `#fbfffc`, light only | Token swap; dark pair must be derived (§5). |
| Card grammar | CHANGE (global) | `.newLookCard()` r 20, borderless, shadow `black@0.05 r8 y2` + `black@0.03 r2 y1` (`NewLook.swift:52-66`) | style A r 12 / style B r 24, stroke 0.5 `#000000@0.10`, shadow `0 3|4 8 #183c28@0.08` | Two radii on one screen (C-15); a bordered card contradicts the current "never a card border" rule. Shared-component work, assumed done. |
| Nav bar | CHANGE | System inline bar; principal = date `"EEE · d MMMM"` uppercase `Typography.label` `inkSecondary` (:46-52, :109-112); trailing = 44 pt `pencil` circle → Edit sheet (:53-68); back = system back control | Left: 42.6 circle back pill (`#ffffff`, stroke 1.065 `#e4ece4`, `arrow-left` 20 `#1e6725`) + title "Today's Mood" 18/600 `#17501d` + date "Monday, Jun 29" 12/500 `#6f7f75`; right: 42.6 `•••` pill | NEW **Circle Icon Button** (not in Frame 3) + NEW header layout; the pencil-as-edit affordance moves into a `•••` **Menu** (undesigned). Note: this reverses the 2026-06-15 decision "no back button (swipe-left); pencil → Edit" — log it. |
| Title block | REMOVE | `displayTitle` ("Mood · Energy · Focus" or "Transcribing…"/"Ready shortly…", `Recording.swift:44-50`) in `Typography.title` + meta `"<time> · <m:ss>"` `mono12` (:96-117) | absent | Loses **check-in time** (the only per-check-in disambiguator when a day has 3 check-ins) and the **status placeholder** for a recording still transcribing. Both need a new home (see Transcript row). |
| Medication bar overlay | REMOVE? | `.medicationBarOverlay()` rides on top of this screen (:40), governed by `@AppStorage("medicationBarVisible")` | not drawn on this screen (the pen Calendar draws a medication bar in-content instead) | Decision, not a defect — the bar is app-level chrome today. |
| Tab bar visible while pushed | KEEP (behaviour) / CHANGE (visual) | `TabView` + per-tab `NavigationStack` (`RootTabView.swift:19-36`, `ScreenContainer.swift:49-60`) → the native tab bar stays visible on pushed screens | Floating pill bar + FAB stay visible | Behaviour already matches; the pill bar/FAB are global NEW components (§4). |
| Bottom "Delete check-in" | REMOVE (relocate) | Destructive plain button, `Theme.danger` (:302-310) → `confirmationDialog` (:79-86) → deferred delete in `onDisappear` (:74-78) | absent; implied inside `•••` | Function must survive. Keep the deferred-delete pattern (it exists because deleting a live `@Model` under a mounted sheet traps SwiftData). |
| "Insights Model Not Downloaded" alert | KEEP | (:87-91) | invisible chrome | — |

### 2.2 Section 1 — "How Does It Feels Today?" signal card

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Section title | NEW | none | "How Does It Feels Today?" 20/600 `#212529`, 12 gap to card | Copy defect C-01; the only 20 pt heading on the screen. |
| Column order | CHANGE | Mood · Energy · Focus (:129-139) | Mood · **Focus** · Energy | Pen differs from every other pen screen too (C-10). Pick one app-wide. |
| Column anatomy | CHANGE | glyph 30 · **word** `headline` · **label** uppercase `label` tracking 0.6 · 4 pt bar (:145-157) | glyph 28/27/33 · **label** 14/500 `#1e2225` · **value** 12/600 signal colour · 86×4 bar | Label and value swap places; word shrinks from 16 → 12 pt. |
| Value colours | CHANGE | mood `level.deepFill`, energy `Palette.energyRamp[l-1]` (yellow ramp `#7C6E2E…#FCEE64`), focus `Palette.focusRamp[l-1]` (blue `#44546E…#79C4FF`) (:174-181, `Palette+Signals.swift:10-33`) | `#0e7718` / `#447097` / `#e38400` — all off-palette; Charged `#e38400` on white is 2.78:1 | New tokens; energy leaves the yellow ramp for amber. Hex pins in `RecordingMoodDisplayTests` / `DayCardPaletteTests` cascade. |
| Bars | CHANGE | fill = `level/5` on a `hairline` groove (:163-172) | 78/86 · 48/86 · 21/86 = 91 % / 56 % / 24 % on `#e9e9ea` | No continuous score exists (§3). Recommend keep `level/5`. Energy 24 % vs "Charged" is a pen error. |
| Glyphs | CHANGE (assets NEW in DS package) | `SignalGlyph` → `SproutGlyph` / `BoltGlyph` / `ApertureGlyph` Canvas drawings tinted by ramp (`GlyphSignal.swift`, `SignalGlyph.swift`) | filled multi-colour illustrations (`#4caf50/#388e3c` sprout, `#4278a8/#447097/#eda94a` target, `#eda94a` bolt) at three different box sizes | Screen glyphs ≠ Frame 12 glyphs (Q7); a common 32 pt box is needed or the baselines misalign as in the PNG. |
| Diagonal separators | NEW | none | two `/` hairlines `#000000@0.10`, 81 pt rotated | Decorative; needs a small `Shape`. Q8 asks whether to keep them. |
| Empty signal | REMOVE (behaviour) | a column is omitted when its signal is `nil`; whole strip hidden when all nil (:121-125) | no empty state drawn | Keep today's omission rule unless the pen adds a "not logged" state. |

### 2.3 Section 2 — "Today's Emotional Condition"

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Container | CHANGE | `.newLookCard()` with header "Emotions" (`ADHDSummarySection.swift:87-99`) | section title 16/600 outside, **no card** | Title copy C-04 ("Emotions" elsewhere). |
| Chip | CHANGE → shared **Bill-shape** component | `TagFlowView` chip: `heart.fill` + `.caption/.medium` in `Theme.accent` (bronze) on `accent@0.13` capsule (`TagFlowView.swift:9-24`, colour at `ADHDSummarySection.swift:89`) | `BG=solid`: fill+stroke `#2a9134`, r 15, text 14/500 `#ffffff`, padding 6/16, shadow `0 7 6 #183c28@0.06`, 29 tall (DS master is 12/500, 27 tall — C-16) | Drops the heart icon. White on green-500 is 4.04:1 (fails AA at 14 pt). |
| Wrap | KEEP | `FlowLayout` wraps (`TagFlowView.swift:32-77`) | 2 chips, no clipping | Pen's edit screen clips rows; here wrap is right. |
| Empty | KEEP | card omitted when `decodedEmotions` empty (:91) | not drawn | — |

### 2.4 Section 3 — "Your Medications"

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Container | CHANGE | one `.newLookCard()` "Medications" with a single joined line `"Name dose ×½ (missed) · …"` (`ADHDSummarySection.swift:30-57`) | section title 16/600 + **one style-A row card per medication** (342×50, padding 11) | Per-row layout replaces the joined string. |
| Badge + glyph | CHANGE | `SignalGlyph(.medication, 18)` = two-tone **horizontal filled** capsule (`Glyphs/CapsuleGlyph.swift`) in `Palette.medication` | 28 ⌀ circle `#f4f0fb` stroke 0.45 `#000000@0.10` + 15 pt **outline diagonal** capsule `#4d3974` | New glyph drawing or asset; medication purple token moves `#7E5CA8` → violet-800/50. |
| Text | CHANGE | `"\(name) \(dose)"` (:47), `Typography.body` | `"Concerta · 36 mg"` 14/500 `#17501d` (green-800, not violet) | Needs a formatter (middle dot; SI spacing — dose strings from transcripts are free text, e.g. "36mg"). |
| Which events | DECISION | `.transcript` only, sorted by `takenAt` (:15-19) — manual doses logged inside a text check-in are hidden (known seam) | undefined | Say whether the row lists all `recording.medicationEvents`. |
| Quantity / missed / time / status | REMOVE (info) | `×½`, `×2`, `(missed)` (:48-54); no time, no status | none of them | Losing `(missed)` hides a `taken == false` event as if taken — flag. Time (`takenAt`) and status words exist (§3) but the pen omits them here (Q17). |

### 2.5 Removed sections between Emotions and the AI card

| Element | Verdict | Today | Lost function |
|---|---|---|---|
| Sleep card | REMOVE | `ADHDSummarySection.swift:61-83`: "Deep" (`decodedSleepLevel.rawValue.capitalized`) or "7h sleep" chip in `Palette.sleepIndigo` with the bed glyph | The only place the detail shows sleep. Data still captured by the LLM and editable in the Edit sheet — silently dropped from the read view (Q2). |
| Side effects card | REMOVE | `:103-115`: `decodedSideEffects` chips, `bandage.fill`, `Palette.warning` | The pen transcript itself mentions "dry mouth" and "jitters"; the chips vanish (Q4). |

### 2.6 Section 4 — "Daily Check-In" AI card with player

| Element | Verdict | Today | Pen | Change |
|---|---|---|---|---|
| Section title | CHANGE | card header "Summary" (:205) | "Daily Check-In" 16/600 outside the card | Copy C-08 (a day can hold 3 check-ins). |
| Card | CHANGE | three cards: Summary (:203-221), Transcript (:226-262), Audio (:291-298) | **one** style-B card r 24, padding 11, gap 11 | Merge summary + player; transcript is gone (next table). |
| AI caption | CHANGE | `Label("Written by on-device AI from your voice — tap Edit to correct", systemImage: "sparkles")` `caption` `inkSecondary`, **below** the text (:215-217) | sparkle vector 13.6×16.4 `#7f5fc0` + "Written by on-device AI from your Voice, tap to Correct" 12/400 `#8a8a8e`, **above** the text, 2 lines, then a 1 pt divider | Custom sparkle asset (not SF `sparkles`) or keep SF. Copy C-07. `#8a8a8e` is the AA-failing `inkSecondary` value the owner accepted 2026-07-12 (3.44:1). |
| Body | CHANGE | `summaryBullets` each as a `Typography.body` (16 pt) paragraph (:207-213) | one paragraph 12/400 `#1e2225`, ≈15 pt line height | `summaryBullets` is a **single narrative string** on the live path (`ExtractionValidator.swift:855-861`: `bullets = [summary]`, else `[rawTranscript]`), so the pen's paragraph maps 1:1. 16 → 12 pt is a readability regression for the ADHD audience — flag. |
| Fallback guard | KEEP (must carry over) | card hidden when `bullets == [fullTranscriptText]` (:193-199) — the raw transcript echoed back must not be labelled "written by AI" | no state drawn | Without this guard, text check-ins and LLM-failed notes show the user's own words under an AI byline. |
| "tap to Correct" | NEW | nothing edits the summary: `ExtractionReviewView` has no summary field; `ExtractionReviewViewModel` only re-seeds `bullets` (`:87`, `:237`) | tap → correct | Needs an editor (inline `TextEditor` or sheet), a VM write path (`summaryBulletsJSON` + `summary`), and a provenance flag so the caption can change — none exists (§3). |
| Divider under body | NEW | — | 1 pt `#000000@0.10` | trivial |
| Player position | CHANGE | own "Audio" card, last | inside the AI card, after the second divider | Move `AudioPlayerView` into the composite. |
| Play button | CHANGE | 44 pt circle, `Palette.medication` fill, `play.fill/pause.fill/ellipsis` (`AudioPlayerView.swift:37-64`), `minTapTarget` frame (:15-16) | 27.75 ⌀ `#8c68d3`, stroke 0.75 `#000000@0.10`, `tabler:player-play-filled` 17.25 | Keep the 44 pt hit frame around the 27.75 visual. Pause/finished/loading states exist in code; the pen draws only "play". |
| Waveform | CHANGE (+ possible NEW data) | `PlaybackWaveformBars`: **32 bars**, spacing 3, heights 4–24 from a hash of `recording.id` + index (`:42-49`), played `Theme.accent@0.6` / unplayed `tintNeutral` (`:18`), drag-end seek (`:24-30`), height 28 (`:32`) | **55 bars** 2.5 wide, pitch 4.6, heights quantised to 5 values (0.23/0.40/0.53/0.74/1.0 × 24.75), played `#8c68d3` / unplayed `#eaf4eb` (1.13:1 on white) | Bar count must derive from width, not 55. If the pen intends **real amplitudes**, no such data exists (§3). |
| Time label | CHANGE | **elapsed** `currentTime` as `"%02d:%02d"` in `Typography.duration` (SF Mono 12) `inkSecondary`, minWidth 42 (`:26-30`, `:74-79`) | "03:24" 9/600 `#4d5154` — reads as **total** | Q11: total vs elapsed. 9 pt is below iOS's 11 pt floor. |
| Text check-ins | RISK | player renders for `audioFileName "text-…"` recordings (`RecordingStore.swift:143`) and errors "Audio file not found" on tap (`AudioPlaybackViewModel.swift:30-35`); `duration == 0` | no "no recording" state | Must hide the player row (and the second divider) when `storageService.getAudioURL(for:)` is nil (`AudioFileStorageServiceImpl.swift:60-63`). |

### 2.7 Transcript — the biggest functional removal

| Element | Verdict | Today | Lost function |
|---|---|---|---|
| Transcript card | REMOVE | `transcriptSection` (:226-262): header + status pill (`Recorded` amber · `Transcribing` · `Completed` · `Failed`, :265-278); `.failed` → **"Retry transcription"** button (:234-239, the only caller of `RecordingDetailViewModel.retryTranscription`); `.transcribing` → spinner + "Transcribing…" (:241-248); empty → "No transcript available yet." (:249-252); else the full text (:253-258) | 1) The user's verbatim words — the "auditable" half of PRODUCT.md principle 4 ("every inferred signal is shown plainly, attributed, and one tap from correction"). 2) **The recovery path**: `RecordingStore.swift:34-45` (orphan recovery) and `CheckInViewModel` write transcript text *"…Tap to retry in the recording detail view."* — that instruction points at a button the pen deletes. 3) Any visible state for a recording that is still transcribing or failed (the title placeholder is removed too, §2.1). |

Recommendation: keep the transcript reachable (a "Transcript" disclosure under the summary, or `•••` → "Show transcript") and design the transcribing/failed states for the AI card. This is a spec item, not a restyle.

### 2.8 Removed / dead code that this screen's rewrite should settle

- `RecordingDetailViewModel.toggleFavorite`, `updateTitle`, `updateDate`, `updateMood`, `startRegenerate` (`:30`, `:54-75`) — no UI today, none in the pen. Constitution III says delete unless the `•••` menu adopts "Regenerate summary".
- `Recording.isFavorite` (`Recording.swift:15`) — never rendered; not in the pen.
- `NewLook.selection` as the `rampColor` default (`RecordingDetailView.swift:179`) — unreachable branch (`default:` for mood, which never calls `rampColor`).

---

## 3. Data availability — every field/label the pen shows

| Pen field | Exists? | Source | Gap / note |
|---|---|---|---|
| Title "Today's Mood" | **NO as drawn** (hard-coded copy) | Relative day label exists in `MoodLibraryViewModel.dayLabel(for:)` (`:157-165`: "Today, d MMM" / "Yesterday, d MMM" / "EEEE, d MMM") but on the calendar VM, not the detail | Recommend a relative title from `recording.createdAt`; needs a small formatter on the detail VM. |
| Date "Monday, Jun 29" | yes | `Recording.createdAt` (`Recording.swift:7`); today formatted `"EEE · d MMMM"` (`RecordingDetailView.swift:109-112`) | Change format to `EEEE, MMM d`. |
| "Mood" / "Focus" / "Energy" labels | yes | `GlyphSignal.title` (`GlyphSignal.swift:13-19`) | — |
| "Great" | yes | `MoodLevel(name: recording.mood)?.displayLabel` (`MoodLevel+Palette.swift:65-73`); today uses `mood.capitalized` (:130) | — |
| "Sharp" / "Locked In" | yes | `FocusLevel(rawValue:)?.displayLabel` (`Levels.swift:113-121`) | Stored raw is `"lockedIn"`; always go through the enum. |
| "Charged" | yes | `EnergyLevel.displayLabel` = `rawValue.capitalized` (`SignalLevel.swift:57`) | — |
| Bar fractions 91 % / 56 % / 24 % | **NO** | Only 1–5 enums (`numericValue`); bar today = `level/5` (:163-172) | A continuous score would need a new LLM output, validator rule (Principle VII clamps to enum rawValues) and a schema column. Not worth it — use `level/5`. |
| Value colours `#0e7718` `#447097` `#e38400` | NO tokens | Today `MoodLevel.deepFill`, `Palette.energyRamp`, `Palette.focusRamp` | New tokens + dark pairs; energy amber fails AA as text (2.78:1). |
| Chips "Proud", "Excited" | yes | `Recording.decodedEmotions` (`Recording.swift:169-174`), values are lowercase members of `Lexicon.defaultEmotions` (`Lexicon.swift:271-278`; "proud", "excited" included) → `.capitalized` | — |
| "Concerta · 36 mg" | yes (format varies) | `MedicationEvent.name` / `dose` (`MedicationEvent.swift:12-13`); catalog doses are `"36 mg"` (`MedicationCatalog.swift:23`), transcript doses are free text | Needs one formatter (C-06). |
| Medication status "Kicking In" / "Active" (Calendar; not on this screen) | yes, private | `stateWord(for:)` in `MedicationBarView.swift:79-86` (fill-fraction thresholds 0.2/0.8, words "kicking in / active / wearing off / worn off") over `MedicationEvent.effectProgress(at:)` (`:68-72`) | Private to the bar; hoist to a shared helper if the detail ever shows it. Catalog `onsetMinutes` (`MedicationCatalog.swift:10, :24`) exists but the bar ignores it. |
| Medication time "09:54" (not on this screen) | yes | `MedicationEvent.takenAt` (`:15`) | — |
| Taken / missed | yes | `MedicationEvent.taken` (`:16`), `quantity` (`:17`) | Pen hides them. |
| "8h Sleep" (Calendar; absent here) | yes | `Recording.sleepLabel` (`Recording+MoodDisplay.swift:94-103`), `sleepHours` (`Recording.swift:30`), `decodedSleepLevel` (`:165-167`) | — |
| Side effects (absent here) | yes | `Recording.decodedSideEffects` (`:158-163`) | — |
| Summary paragraph | yes | `Recording.summaryBullets` (`:145-150`) — one string from pass 1 (`MLXJournalService.swift:52-62`; `ExtractionValidator.swift:855-861`); `summary` column duplicates it as "- …" lines (`:280`) | Fallback `[rawTranscript]` (`ExtractionValidator.swift:893-910`) must not be shown under the AI byline. |
| "Written by on-device AI" provenance / "edited by you" | **NO** | `RecordingTag` categories are mood/energy/focus/medication/emotions (`RecordingTag.swift:11-17`); `ExtractionReviewViewModel` tags only those five (`:274-290`). No `summaryEditedAt`, no summary tag category. `summaryStatus` (`Recording.swift:20`; notGenerated/generating/completed/failed) covers the *generating* state only | Needs a new column (schema change → constitution IX, empty migration plan in `App/SquirlSchema.swift`) or a `TagCategory.summary` row. |
| Summary editing target | **NO** | No write path for `summaryBulletsJSON` outside `applySummary` (`Recording.swift:202-284`) | New VM method + tests (Principle X). |
| Duration "03:24" | yes | `Recording.formattedDuration` `"m:ss"` (`Recording.swift:122-126`) → "3:24"; `AudioPlaybackViewModel.duration` after load (`:41`) | Leading zero (C-09) is a pen choice; code gives "3:24". |
| Playback position 41.8 % | yes | `currentTime / duration` (`AudioPlayerView.swift:20`) | — |
| Waveform amplitudes (55 × 5 levels) | **NO** | `PlaybackWaveformBars.barHeight` is a hash of the recording id (`:42-49`) — decorative, not audio | Real amplitudes = read the m4a with `AVAudioFile`, downsample off the main actor (Principle VIII), cache (a new `waveformJSON` column is another schema change; a file-side cache avoids it). |
| Recording status (transcribing / failed) | yes, unrendered in pen | `Recording.status` (`:12`) | Pen has no state. |
| Check-in time | yes, unrendered in pen | `Recording.createdAt` | Needed to tell three same-day check-ins apart. |
| Month selector · "24 check-ins" · weekday dominant level · connection unlock thresholds · "Installed" · "34MB" | n/a | Not on this screen (Insights / Settings) | Covered by the sibling cross-checks. |

---

## 4. Navigation delta

| Item | Today | Pen | Delta |
|---|---|---|---|
| Tab bar | Native `TabView` + `.tabItem` (`RootTabView.swift:19-36`), tint `Theme.meadowGreen` (:36), painted opaque `NewLook.screen` from each tab root (`ScreenContainer.swift:56-60`); no iOS 18+ `Tab` builder, no `tabBarMinimizeBehavior` | Custom floating pill 274×60 (`#ffffff`, r 75, shadow `0 8 24 #183c28@0.16`), active pill `#2a9134` icon-only 64×44, inactive icons `#999b9d` (2.79:1) | Global NEW component. Two options: (a) hide the system bar (`.toolbar(.hidden, for: .tabBar)`) and overlay a custom bar at the root — loses system behaviours (tab re-tap-to-root, iOS 26 minimize-on-scroll, VoiceOver tab traits unless re-added); (b) restyle the native bar — cannot reach the pen's pill shape. Decide once, app-wide, not on this screen. |
| Tab bar on pushed screens | Visible (NavigationStack lives inside each tab) | Visible on this screen, hidden on Edit Check-In (`iPhone 17 - 18`) | Matches today for the detail. Edit today is a **sheet** (`.sheet(item:)` `:71-73`, `presentationDetents([.large])`), which naturally hides the bar — the pen draws Edit as a pushed page with a back pill (Q-L2). |
| FAB `+` | does not exist | 50 ⌀ `#8c68d3`, `add` icon `#e9e9ea` (3.44:1) | NEW, global. Plumbing exists: `AppIntentRouter.requestCheckIn()` → `selectedTab = .checkIn; shouldAutoStartRecording = true` (`SquirlApp.swift:72-76`). Tapping it from a pushed detail also pops the Calendar stack (`CalendarLibraryView.swift:57-62` clears `path` on tab change) — acceptable. Q12: dated today, not the viewed day. |
| Back | System back + interactive pop | 42.6 pt custom pill, chevron only | Either a custom `ToolbarItem(placement: .topBarLeading)` (keeps the pop gesture) or hide the nav bar and draw the header in content (pop gesture can break; must be verified on device). Hit area < 44 pt → pad. |
| `•••` | Trailing pencil → Edit sheet | Menu, undesigned | `Menu` with Edit (exists), Delete (exists; relocate), and — to be decided — Transcript, Share transcript (`exportTranscript` in `Protocols.swift:127` exists, unused), Regenerate (`startRegenerate` exists, unused). Export must never be gated (CLAUDE.md). |
| Bottom inset | System safe area; no `edgeFadeMask` (not a `ScreenContainer`) | Floating bar 60 + 34 home indicator + 5 → ≥ 95 pt inset | `safeAreaInset(edge: .bottom)` or `contentMargins`; also `ScrollView` must scroll when content exceeds 874 pt (pen fits by luck at 714.75). |
| Sheets | Edit (`ExtractionReviewView`), delete `confirmationDialog`, model-missing `alert` | none drawn | Keep. |

---

## 5. Accessibility · Dynamic Type · dark mode (this screen)

**Type.** The pen is Inter at fixed 9/12/14/16/18/20 pt; every `Typography` role today scales via `UIFontMetrics` (`Typography.swift`). Mapping if SF stays (Q13): 20/600 → `Typography.text(20, .semibold, relativeTo: .title3)` (new); 18/600 → `text(18, .semibold, .headline)` (new); 16/600 → `headline` (exact); 14/500 → `subheadline` (exact); 12/600 → `caption` + `.weight(.semibold)`; 12/400 → `caption`; 9/600 → **do not ship 9 pt** — `text(11, .semibold, .caption2)`. Body at 12 pt for the narrative is the one size to push back on: today it is 16 pt `body`, and this is the paragraph the user reads.

**Dynamic Type layout.** Three 94 pt signal columns with 14 pt labels + 12 pt values break at AX sizes ("Charged"/"Energy" exceed 94 pt). Precedent: `CalendarHeaderView.swift:20` forces week view at `dynamicTypeSize >= .accessibility1`; do the same here (columns stack vertically). Chips wrap already (`FlowLayout`). The medication row must allow the name to wrap under the badge. The player row: hide the waveform below `.accessibility3` and keep play + time.

**Contrast (from the screen spec's measurements; all light mode).** Fails: Charged `#e38400` 2.78, caption `#8a8a8e` 3.44, date `#6f7f75` 4.19 (12 pt), chip white on `#2a9134` 4.04 (14/500), inactive tabs `#999b9d` 2.79 (non-text 3:1), energy bar on track 2.29, unplayed waveform `#eaf4eb` 1.13. `DayCardPaletteTests` already asserts ≥ 4.5:1 for mood word colours on the card surface — extend the same test to the three signal value colours and the chip label so the rule is enforced, not remembered.

**Hit targets.** Back/`•••` 42.6, play 27.75, chips 29 tall — all < 44. `AudioPlayerView.swift:15-16` already wraps the button in `Metrics.minTapTarget` + `.contentShape(.rect)`; reuse. Chips are display-only here → not buttons, no target rule, but group them.

**VoiceOver.** Keep `heroColumn`'s `accessibilityElement(children: .ignore)` + `"Mood: Great"` (`:159-160`). Diagonal separators `accessibilityHidden`. Emotions: one element "Emotions: Proud, Excited". Medication row: "Concerta, 36 milligrams" (spell the unit). AI card: if tappable, a button with label "Summary, written by on-device AI" and hint "Double tap to correct" — do not read the caption's imperative copy as content. Waveform today exposes only a percent label (`PlaybackWaveformBars.swift:34`) and seeks on drag-end; add `.accessibilityAdjustableAction` for scrubbing. Timer label reads "3 minutes 24 seconds", not "03:24".

**Colour is never the only cue.** Signal values carry word + glyph + colour — fine. Played/unplayed waveform is colour-only at 1.13:1 — needs a luminance step (violet-100 `#dbd0f1` at minimum) or a position marker.

**Dark mode.** Nothing in the pen. Every new colour must go through `Color(lightHex:darkHex:)` (`Color+Hex.swift`) like the existing tokens; derived dark values are the spec-033 precedent (2026-07-16 ruling). Specific traps: `#ffffff` cards on a dark ground need the existing `#1C1E19`-style card; the 0.5 pt `#000000@0.10` card stroke is invisible on dark (needs a light hairline); the `#183c28` shadow disappears on dark (drop or lighten); violet-50 badge `#f4f0fb` needs a dark tint; `#e9e9ea` bar tracks and `#eaf4eb` unplayed bars need dark pairs; the sparkle `#7f5fc0` and play `#8c68d3` are fine on dark.

**Reduce Motion.** No motion on this screen beyond playback; nothing to gate.

---

## 6. Risks and open questions

### Risks

1. **Transcript + retry removal deletes the only failure-recovery UI.** `retryTranscription()` is reachable solely from `RecordingDetailView.swift:234-239`; recovery copy elsewhere (`RecordingStore.swift:34-45`) literally sends users here. Shipping the pen as drawn strands failed recordings.
2. **False AI attribution.** With the transcript gone and the body under an AI byline, the `hasSummary` guard (`:193-199`) is the only thing stopping a typed note or a fallback transcript from being labelled "written by on-device AI". The pen draws no state for it.
3. **Summary correction needs persistence the model lacks** — a provenance flag means a schema change; under constitution 3.0.0 (on `feat/055`) the store may not be wiped in release, and `SquirlSchemaV1` has an empty migration plan. Plan the migration or use a `RecordingTag` row (no schema change, but `TagCategory` gains a case).
4. **Custom nav bar vs interactive pop.** Hiding the system bar to draw the pill header can disable swipe-back; verify on device before committing to the header approach.
5. **Glyph asset ambiguity blocks the signal card.** Screen glyphs ≠ Frame 12 glyphs; energy/sleep masks export as black blocks; three box sizes. Cutting assets before Q6/Q7 are answered means cutting twice.
6. **Token cascade into tests.** Energy/focus ramps (`Palette+Signals.swift`) and mood hexes are pinned by `RecordingMoodDisplayTests`, `DayCardPaletteTests`, `SignalGlyphTests`; changing value colours here means changing them app-wide and re-pinning.
7. **Sixth chip grammar.** Five chip implementations already coexist (`.newLookChip`, `Chip.swift`, `TagFlowView`, `RecordingRow`, `MedicationLogSheet`). Adding Bill-shape without deleting the others fails constitution IV/III.
8. **Real waveform cost.** Decoding up to 8 min of AAC on open is IO/CPU work; it must be off-main and cached, or the screen stutters on push. Seeded bars are cheaper and already exist — but they are fiction.
9. **12 pt body for the one paragraph the user reads**, in an app whose audience rule is low cognitive load. Product regression, not a style choice.
10. **Medication `.transcript` filter** already hides manual doses inside text check-ins; the pen doesn't decide, so the seam ships unless the spec says.
11. **FAB on a pushed detail** contradicts PRODUCT.md "one primary action per screen" and coexists with back + `•••`.
12. **Timeline.** Nothing here can reach a Shipaton build; the screen ships post-055 merge, after the `feat/057` re-cut (constraints §5.2).

### Open questions for the owner (only the ones the code cannot answer)

1. **One check-in or the whole day?** The view is a `Recording`; days hold several. If day: aggregate how, and where do the other check-ins go? If check-in: the title must carry the time.
2. **Where does the transcript live** (disclosure under the summary, `•••` → Transcript, or gone), and what do the *transcribing* / *failed* / *retry* states look like?
3. **Sleep and side effects:** dropped from the read view on purpose, or add two chip sections (data and edit UI already exist)?
4. **Bars:** `level/5` (what exists) or a continuous score (new LLM output + schema)?
5. **"tap to Correct":** inline editor or sheet; does the caption become "Edited by you"; is the edited text persisted as the summary (schema) or as a tag?
6. **Waveform:** real amplitudes (new service + cache) or the existing seeded bars restyled?
7. **Text check-ins:** what does the card show with no audio and a typed note (hide the player row; drop the AI byline)?
8. **`•••` menu contents:** Edit + Delete only, or also Share/Export transcript and Regenerate summary (both have backend, no UI)?
9. **Medication row:** transcript-only events (today) or all; show `(missed)`, time and status, or name · dose only?
10. **Medication bar overlay on this screen:** keep (today) or drop (pen)?
11. **FAB on a detail page:** keep (creates a check-in for *today*, pops the stack) or hide on pushed screens?
12. **Dark mode in scope for the refresh?** Decides whether every token above ships with a pair.
13. **Inter or SF?** Global, but it fixes every size on this screen and whether 9/12 pt survive.
14. **Body at 12 pt** — accept the pen or hold the current 16 pt body for the narrative?

---

## 7. Rough effort — senior SwiftUI engineer, tokens + shared components assumed done

Shared work **not** counted here: palette tokens + dark pairs, Bill-shape chip, card modifiers (style A/B), Circle Icon Button, floating tab bar + FAB, Frame-12 glyph assets, Inter/SF decision.

| Bucket | Item | Hours |
|---|---|---|
| NEW | Custom header: back pill + title/date + `•••` `Menu` (Edit / Delete / Transcript), hide or replace the system bar, keep the pop gesture, 44 pt hit areas | 3 |
| NEW | Signal card: 3 columns, diagonal separators, value colours, `level/5` bars, AX-size vertical fallback | 4 |
| NEW | Composite AI card: caption row (sparkle asset), dividers, body, inline player; states: generating, fallback-transcript, no-audio, transcribing/failed (whatever Q2 decides) | 4 |
| NEW | Summary correction: editor + `RecordingDetailViewModel` write path + provenance flag + persistence/migration + tests | 6 |
| NEW | Waveform: width-derived bar count, 5-level quantisation, played/unplayed tokens, adjustable AX action — seeded bars | 2 |
| NEW | HTML mockup before SwiftUI (constitution I) incl. AX5 and dark toggles | 3 |
| **NEW subtotal** | | **22** (+6 if real amplitudes: `AVAudioFile` reader off-main, cache, tests) |
| CHANGE | Emotions: section title, Bill-shape chips, drop card + heart | 1 |
| CHANGE | Medication rows: per-event card, badge + outline capsule glyph, `name · dose` formatter (catalog vs free-text doses) | 2 |
| CHANGE | Player restyle: 27.75 visual in 44 hit frame, colours, total-duration label, pause/finished icons | 2 |
| CHANGE | Page rhythm: 28 pt gutters, 24/12/8 gaps, `#fbfffc` ground, bottom inset for the floating bar, scrolling | 2 |
| CHANGE | Dark pairs + AA test extension for this screen's colours | 2 |
| CHANGE | VoiceOver pass (grouping, labels, hint on the AI card) + AX-size QA | 2 |
| **CHANGE subtotal** | | **11** |
| REMOVE | Title block, sleep card, side-effects card, transcript card, audio card, bottom delete; relocate delete + retry; fix recovery copy in `RecordingStore` / `CheckInViewModel` if the transcript moves | 3 |
| REMOVE | Dead VM methods (`toggleFavorite`, `updateTitle/Date/Mood`, `startRegenerate` if not adopted), `isFavorite` UI remnants, stale comments (`:38-42`) | 1 |
| **REMOVE subtotal** | | **4** |
| Verify | Build + full test run (serial), simulator run, PR + `/code-review` findings, owner device-QA support | 4 |
| **Total** | | **≈ 41 h** (≈ 47 h with real waveform amplitudes) |

Assumes the owner answers Q1–Q9 before `/speckit-specify`; each unanswered one adds a rework loop of roughly 2–4 h.
