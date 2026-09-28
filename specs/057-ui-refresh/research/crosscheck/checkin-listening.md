<!-- Created: 2026-09-27 22:24 WEST · Updated: 2026-09-27 22:24 WEST -->
# Cross-check — pen `iPhone 17 - 5` (Check-In Recording · B · listening) vs the SwiftUI on `feat/057-ui-refresh`

**Inputs:** `out/screens/checkin-listening.md` (screen spec, read in full) · `pen/named/iphone17-5-checkin-recording-b.png` · `out/design-system.md` · `out/codebase-designsystem.md` · `out/codebase-views-capture-insights-settings.md` · `out/constraints.md` · the Swift files named below (worktree HEAD `08ba8cba`, read-only).
**Status:** planning only. No Swift changed. Every code claim carries `path:line`. Pen numbers are 1× pt from the Figma JSON as quoted by the screen spec.

Sections: 1 Mapping · 2 Delta table · 3 Data availability · 4 Navigation delta · 5 Accessibility / Dynamic Type / dark · 6 Risks & open questions · 7 Effort

---

## 1. Mapping — what implements this surface today

| Layer | Today | Notes |
|---|---|---|
| Screen | `app-four/Views/CheckIn/CheckInView.swift` — the `.recording` branch of `captureStage` (`:143-193`): `recordingHeader` (`:273-279`) + `recordingCentre` (`:285-332`) over the ring | Idle (A), listening (B), processing and save-failed all share **one** `ZStack` so the ring never moves (`:137-142`). Saved (C) is the separate private `CheckInSavedView` (`:456-507`). The pen also draws A/B/C as three frames sharing one ring group, so the single-view/three-state architecture is compatible with the pen. |
| Ring | `app-four/Views/CheckIn/CrescentRing.swift` (`:7-54`) — a **uniform full-circle stroke**, `Theme.meadowGreen` `#5F8A4C`, `lineWidth` 22, butt caps; spins 360°/7 s while active, breathes at idle | Also used by onboarding `app-four/Views/Onboarding/WelcomeView.swift:52` (`breathing: false`). Any ring rewrite touches both. |
| View model | `app-four/ViewModels/CheckInViewModel.swift` — `state: RecordingState` (`:9`), `elapsedTime` (`:10`), `timeString` (`:96-98`), `nudgePrompts` (`:438-444`), `currentPromptIndex` (`:449-453`), `currentPrompt` (`:455`), `promptProgress` (`:458-460`), `promptInterval` (`:447`, loaded `:164` from `AppSettings.promptPaceSeconds` via `:422-429`), `stopRecording()` (`:227-251`), `cancelRecording()` (`:402-413`), `isApproachingCap` (`:31`), `saveFailed` (`:50`) | `@MainActor @Observable`. 32 tests in `app-fourTests/ViewModels/CheckInViewModelTests.swift`. |
| State enum | `app-four/Models/AppEnums.swift:18-24` `RecordingState { idle, recording, paused, processing, done }` | `.paused` is never assigned by the check-in VM (grep over `app-four/`: only `AudioPlayerView` uses a different `.paused`; `CheckInView.swift:102,150,297,302` merely read it). |
| Timer format | `app-four/Utils/AccessibilityHelpers.swift:10-14` `formatDuration` → `String(format: "%d:%02d", …)` | Produces exactly the pen's `0:07` grammar. |
| Cap | `app-four/Utils/Constants.swift:10` `maxRecordingDuration = 480`; auto-stop at cap `CheckInViewModel.swift:517-523`; approach window 30 s (`:26`) | Pen shows none of it. |
| Chrome | `app-four/DesignSystem/ScreenContainer.swift:49-60` — `NavigationStack`, inline empty title, `NewLook.screen` ground, tab bar painted `NewLook.screen` and forced visible; medication bar `safeAreaInset` at top (`:79`, `:82`; `app-four/DesignSystem/MedicationBarOverlay.swift:18-23`) | `CheckInView.swift:26` passes `showsMedicationBar: true, scrollable: false`. |
| Entry | Tab root: `app-four/Views/RootTabView.swift:24` (`Tab.checkIn`); deep link / App Intent → `selectedTab = .checkIn; shouldAutoStartRecording = true` (`app-four/App/SquirlApp.swift:72-76`) → `consumeAutoStart()` (`CheckInView.swift:98-106`) lands straight on B | |
| Tokens used on B today | `Typography.timer` (SF Mono 22 medium, `Typography.swift:50`), `Typography.text(24,.bold,.title2)`, `Typography.headline/callout/caption/label`, `NewLook.inkPrimary/inkSecondary/card/tintNeutral/onSelection/onInk`, `Theme.meadowGreen`, `Metrics.CheckIn.crescentDiameter 300 / stopGlyph 11 / stopGlyphRadius 3 / promptDot 6 / promptBarHeight 4` (`Metrics.swift:51-67`), `Motion.smooth`, `Opacity.deEmphasis` | Nothing on B uses the shared button styles in `Buttons.swift`; the stop and cancel pills are hand-rolled (`CheckInView.swift:392-415`, `:309-321`). |
| Mockup | none — `html-mockups/` holds only `055-paywall.html` | Constitution I requires an HTML mockup before SwiftUI. |

---

## 2. Delta table (pen → code), top to bottom

Legend: **KEEP** already matches · **CHANGE** exists, restyle/rearrange · **NEW** must be built · **REMOVE** exists today, absent in the pen.

### 2.1 Page frame & column

| Pen | Code today | Verdict |
|---|---|---|
| Ground `#fbfffc`; content column x 30, width 342; nothing scrolls | `NewLook.screen` `#EFF2EB` (`NewLook.swift:13`); `.padding(.horizontal, Spacing.l)` = 16 (`CheckInView.swift:162`); `scrollable: false` (`:26`) | **CHANGE** — ground is a token swap (owned by the tokens slice); gutter 16 → 30 on this screen. Not scrolling: KEEP. |
| Vertical rhythm: status 52 → 25 → back pill 42.6 → 10.4 → card 98.25 → 59 → ring 347 → 65 → hint 17 → 123.75 free | `ZStack`: card pinned top (`:156-159`), ring centred (`:147-153`); gaps are whatever the screen height leaves | **CHANGE** — rebuild as a fixed-gap `VStack` (card · 59 · ring · 65 · hint) or keep the anchored `ZStack` and tune. The pen leaves 124 pt empty at the bottom; on shorter devices the 586 pt stack will not fit unscaled (see §6). |
| Medication bar: **not drawn** | `showsMedicationBar: true` → `MedicationBarView` inset at the top whenever an active dose exists (`ScreenContainer.swift:82`, `MedicationBarView.swift:12`) | **REMOVE (for the flow)** — informational only; tapping it opens "Log new dose" (`MedicationBarView.swift:20-39`), which is odd mid-recording. Losing it during B costs nothing functional. Owner call on A (also not drawn in the pen). |

### 2.2 Nav row — back pill

| Pen | Code today | Verdict |
|---|---|---|
| Back pill 42.6 ⌀, `#ffffff`, stroke 1.065 `#e4ece4` inside, chevron `vuesax/outline/arrow-left` 20 box / path 7.16 × 14.45 `#1e6725`; empty title slot | No back affordance on the check-in tab (it is a tab root; `ScreenContainer.swift:49-52` inline empty title). Nearest existing pattern: `ExtractionReviewView` cancel pill (44 ⌀ circle, `chevron.backward` in `checkInGreen`; see `codebase-views-journal.md` §Edit) and `NewLookNavBar` (`NewLook.swift:116-148`) | **NEW** — a shared nav pill component (used by pen screens 1/4/5/6/18/19) in `Packages/SquirlDesignSystem`; SF `chevron.left`, 44 pt hit target (`Metrics.minTapTarget`, `Metrics.swift`). Its **action on B is undefined** in the pen: today's only exits are `cancelRecording()` (`CheckInViewModel.swift:402-413`, discards audio, `.idle`) and `stopRecording()`. See Q3. |

### 2.3 Prompt card ("How's Your Mode?")

| Element | Pen | Code today | Verdict |
|---|---|---|---|
| Card | 342 × 98.25, r **18**, `#ffffff`, stroke 0.5 `#000000@10%` inside, shadow (0, 4) blur 8 `#183c28@8%`, padding 15, inner gap 11 | `.newLookCard()` (`NewLook.swift:52-66`): padding 16, r **20**, no border, shadows `black@0.05 r8 y2` + `black@0.03 r2 y1`; `VStack(spacing: 12)` (`CheckInView.swift:274`) | **CHANGE** — radius, border, shadow tint, paddings. Card M in `design-system.md` §4.6; if the card slice ships a `Card M` modifier this is a one-line swap. |
| Progress bar | **absent** | `promptProgressBar` 4 pt capsule, `tintNeutral` track, `meadowGreen` fill, `.linear(0.1)`, re-id'd per prompt (`:334-350`, `Metrics.CheckIn.promptBarHeight`) | **REMOVE** — but it **loses a function**: the bar tells a time-blind user when the prompt will advance (spec 036 a05). The dots only encode *which* prompt. Recommend keeping it as a hairline under the dots unless the owner drops it (Q4). If removed, `promptProgress` (`CheckInViewModel.swift:458-460`) and the test `promptProgressIsNormalized` (`CheckInViewModelTests.swift:56`) become dead and must go too (Principle III). |
| Title | "How’s Your Mode?" Inter **24 / 500** `#17501d`, single line | `viewModel.currentPrompt.question` = "How's your mood?" in `Typography.text(24, .bold, .title2)` `inkPrimary` `#1C1B1F`, centred, slides in from trailing (`:354-362`) | **CHANGE** — weight 700 → 500, ink → green-800; copy: pen "Mode" is a typo for "Mood" (pen hint lists mood adjectives; code and `nudgePrompts[0]` say mood), Title Case vs sentence case, typographic apostrophe U+2019 vs straight `'`. The **question copy is pinned by `nudgePromptContents`** (`CheckInViewModelTests.swift:34-40`) — any casing change is a test change. Slide transition: pen is static; KEEP the transition unless told otherwise (Reduce-Motion guarded at `:374`). |
| Subtitle | "Heavy, Light, Flat, Bright- Whatever Fits" Inter **12 / 500** `#6a6d70`, gap 6 under the title | `currentPrompt.hint` = "Heavy, light, flat, bright — whatever fits." in `Typography.callout` (15 regular) `inkSecondary` `#8A8A8E` (`:364-369`) | **CHANGE** — size 15 → 12 (see §5: 12 pt is under the 13 pt floor the screen spec flags in Q12; recommend 13–14), colour `#8A8A8E` (AA fail) → `#6a6d70` (5.21:1). Copy: keep the code's spaced em dash and full stop. |
| Page dots | 5 × **7.25** ⌀, gap **4**, active `#2a9134` (green-500), inactive `#bdddc0` (green-100), gap 11 under the text block | 5 × `Metrics.CheckIn.promptDot` **6** ⌀, spacing 6, active `Theme.meadowGreen`, inactive `inkSecondary.opacity(0.3)`, `.padding(.top, Spacing.xs)` (`:379-390`), count from `nudgePrompts.count` (`:381`) | **CHANGE** — size/gap/colours. Count and driving index: KEEP. |
| Card a11y | — | `.accessibilityElement(children: .ignore)` + combined "question hint" label (`:375-376`); dots hidden (`:389`) | **KEEP** |

### 2.4 Recording ring

| Element | Pen | Code today | Verdict |
|---|---|---|---|
| Size | **347 ⌀** (overhangs the 342 column by 2.5 each side); shadow (0, 2) blur 18 `#000000@8%` | **300 ⌀** (`Metrics.CheckIn.crescentDiameter`, `CheckInView.swift:148-149,195`); no shadow | **CHANGE** |
| Disc | fill `#ebf8ee` (off-palette; green-50 is `#eaf4eb`) | none — the ring is a stroke only, the screen ground shows through (`CrescentRing.swift:30-35`) | **NEW** |
| Track | stroke **21.33** `#bdddc0` inside | `lineWidth` 22 `Theme.meadowGreen`, uniform, inset by half the stroke (`CrescentRing.swift:9,30-35`) | **CHANGE** — width ≈ same; colour becomes the *track* (green-100), the coloured part becomes the arc below. |
| Progress arc | annulus 20.82 wide, vertical linear gradient `#26842f` 0 % → `#3fbb4b` 50 % → `#25832e` 100 %, from 3 o'clock **clockwise to 237.6° = 66 %**, **butt** caps; 33 % on A, 100 % on C | none — no arc, no progress (`CrescentRing.swift` is a full circle; doc comment `:3-5` says the spin "reads as a hold") | **NEW** — `CheckInRing(progress:)` component: disc + track + gradient-arc `trim`, `.butt` caps, shadow, `accessibilityHidden` (as today `CheckInView.swift:151`). Replaces `CrescentRing` at both call sites (`CheckInView.swift:148`, `WelcomeView.swift:52` — Welcome needs an idle look, presumably 33 % or 0 %). The **progress value has no source today** (§3, Q1). |
| Motion | unspecified (static frame) | active: 360° rotation `.linear(7)` repeatForever (`CrescentRing.swift:37-42`); idle: breathe scale 1.035 / opacity 0.94 over 5 s (`:43-49`); Reduce Motion → static | **REMOVE the rotation** — with a real 66 % arc, a spinning ring would read as a loader; **breathing is an owner call** (Q1). Reduce-Motion guards: KEEP. |
| Ring a11y | — | `.accessibilityHidden(true)` (`CheckInView.swift:151`, `CrescentRing.swift:15`) | **KEEP**, unless the arc is exposed as "Step 2 of 3" (Q1). |

### 2.5 Timer "0:07"

| Pen | Code today | Verdict |
|---|---|---|
| Inter **72 / 500** `#17501d`, 154 × 87, vertically centred in the disc, 9.2 above the button stack; format `m:ss` (no leading zero on minutes, seconds zero-padded) | `Text(viewModel.timeString)` in `Typography.timer` = **SF Mono 22 medium** relative to `.title2` (`Typography.swift:50`), `inkPrimary`; format `"%d:%02d"` (`AccessibilityHelpers.swift:10-14`) → "0:07" (`CheckInView.swift:293-300`) | **CHANGE** — new type role (e.g. `Typography.timerHero` 72 / medium) on a proportional face with `.monospacedDigit()` so "0:07 → 0:08" does not jitter (SF Mono handles that today); `#17501d` ink; cap Dynamic-Type growth (§5). Format and one-second throttling: **KEEP**. `Typography.timer` then has 0 users → delete (Principle III). |
| Live region "Recording, 0:07 elapsed", `.updatesFrequently` | `CheckInView.swift:296-300` | **KEEP** |

### 2.6 Stop & Save (primary)

| Pen | Code today | Verdict |
|---|---|---|
| `Button / Filled · Medium · With Icon · Default`: 152 × **44**, fill `#2a9134`, r 999, padding 10 / 18, gap 8, label "Stop & Save" 16 / 500 / lh 24 `#ffffff`; icon slot 16 × 16 at (18, 14) rendering as a **solid white rounded square r 4** (layer named `vuesax/outline/stop`) | Hand-rolled capsule (`CheckInView.swift:392-415`): `Theme.meadowGreen` `#5F8A4C` fill, `onSelection` label `Typography.headline` (16 **semibold**), stop glyph `RoundedRectangle(r 3)` **11 × 11** (`Metrics.CheckIn.stopGlyph/stopGlyphRadius`), `HStack(spacing: 8)`, padding v 12 / h 24, minHeight 44; copy "Stop & save"; a11y "Finish check-in" | **CHANGE** — adopt the shared Filled Medium style (assumed to exist from Frame 3), glyph 11 r 3 → 16 r 4 (`stop.fill` or the shape), weight 600 → 500, copy casing. Pen has **no processing state**: today the label becomes a `ProgressView` and the button is `.disabled` while `.processing` (`:397-398`, `:413`) and VoiceOver hears "Saving…" (`:186-189`). **Do not remove** — it is the only visible "your check-in is being saved" feedback and the DS has only Default/Hovered/Focused/Disabled (Q5). |
| Contrast | white on `#2a9134` = **4.04:1** (fails AA normal text at 16 / 500) | white on `#5F8A4C` ≈ **4.0:1** (computed) — the same class of failure | **DS-level decision** (Q7): green-600 `#26842f` fill gives 4.75:1. Not a screen decision. |

### 2.7 Cancel (secondary)

| Pen | Code today | Verdict |
|---|---|---|
| `Button / Outlined · Medium · Without Icon · Default`: 91 × 46 (44 + 1 pt outside stroke), fill `#ffffff`, stroke 1 `#cbd5e1`, r 999, padding 10 / 18, label "Cancel" 16 / 500 `#26842f`; 8 pt below Stop & Save | Text button (`CheckInView.swift:309-321`): `Typography.callout` (15 regular) `inkSecondary` `#8A8A8E`, `NewLook.card` capsule, padding h 16, minWidth 44 / minHeight **38**, `.newLookCardShadow()`; a11y "Cancel recording"; `VStack(spacing: 12)` with the stop button (`:289`) | **CHANGE** — adopt the shared Outlined Medium style (44 tall, stroke drawn inside), label green-600 16 / 500, drop the shadow, gap 12 → 8. Action `cancelRecording()` (immediate discard, no confirm) is what the pen implies too: **KEEP** unless Q3 adds a confirm. |

### 2.8 Hint "Take Your Time, Speak Freely."

| Pen | Code today | Verdict |
|---|---|---|
| 14 / 500 `#6f7f75` (off-palette), centred, 65 below the ring, full width | Nothing while recording. The idle-only, one-time whisper "Say whatever's on your mind — a few words is plenty." (`CheckInView.swift:212-217`, gated by `@AppStorage("checkInHintSeen")` `:16`) is not this | **NEW** — static string; 14 / 500; colour must move to `#6a6d70` (grey-300, 5.21:1) or `#4d5154`, since `#6f7f75` on `#fbfffc` is **4.19:1** (AA fail). Sentence case per app convention (Q6). |

### 2.9 States the code has that the pen does not draw

| State | Code | Verdict |
|---|---|---|
| Paused | ring dimmed to `Opacity.deEmphasis` (`CheckInView.swift:150`), "PAUSED" label (`:302-307`), a11y "Paused, … elapsed" (`:297-299`) | **REMOVE the UI** — it is unreachable today (`.paused` is never set by `CheckInViewModel`), so nothing is lost. Keep the enum case only if another owner (audio interruption handling) is planned; otherwise it is dead code under Principle III. |
| Cap approach ("Wrapping up soon") | `:325-329`, `.task(id: isApproachingCap)` `:169-175`; VM `:26-42`; tests `isApproachingCapTrueOnlyInFinalWindow`, `capApproachCueIsOneShot` (`CheckInViewModelTests.swift:421,438`) | **KEEP (restyle)** — the pen shows 0:07, not 7:30; removing it would drop FR-014's soft landing for an 8-minute cap that still auto-stops (`CheckInViewModel.swift:520-523`). Render as the hint line's text swap ("Wrapping up soon" replaces "Take your time…" for 4 s) so no new element is needed (Q9). |
| Save failed | `failureRecovery` (`:419-449`): "Couldn't save that one." / "Your check-in is safe — tap to try again." / **Try again** (ink capsule) / **Discard**; error haptic `:164-166` | **KEEP (restyle)** — US2 never-lose-a-capture; the audio is buffered (`CheckInViewModel.swift:44-49`). Map Try again → Filled Medium, Discard → Underline (text) button from Frame 3. |
| Model-download / permission / storage / memory alerts | `CheckInView.swift:46-88` (7 alerts) | **KEEP** — system alerts, out of the pen's scope. Note the "approx. 40MB" copy bug (`:67`) vs "~150 MB" elsewhere. |
| Prompt announcement gate (`isSpeaking`, threshold 0.1) | `CheckInViewModel.swift:56-72`, `:464-478`; view `:176-184` | **KEEP** |
| Idle-only chrome (date line `:201-204`, hub pills `:223-268`) | in the same `captureStage` | Not B's concern; covered by the A cross-check. |

---

## 3. Data availability — every field/label the pen shows

| Pen field | Exists? | Source / what is needed |
|---|---|---|
| `0:07` elapsed | **Yes** | `CheckInViewModel.elapsedTime` (`:10`, ticks 0.1 s at `:510-513`), `timeString` (`:96-98`) → `AccessibilityHelpers.formatDuration` `"%d:%02d"` (`Utils/AccessibilityHelpers.swift:10-14`). Max 8:00 (`Constants.swift:10`) so hours never occur. |
| Prompt title "How's Your Mode?" | **Yes (copy differs)** | `currentPrompt.question` = "How's your mood?" (`CheckInViewModel.swift:439`). Pen string is a typo + Title Case. |
| Prompt subtitle | **Yes (copy differs)** | `currentPrompt.hint` = "Heavy, light, flat, bright — whatever fits." (`:439`). |
| Dot count 5 / active index | **Yes** | `nudgePrompts.count` = 5 (`:438-444`; test `:30-32`), `currentPromptIndex` (`:449-453`) — advances every `promptInterval` s (10 relaxed / 6 brisk, `Models/PromptPace.swift:3-15`). |
| Ring fill 66 % (flow step 2 of 3) | **NO** | No `flowStep`/progress property. Derivable from `state` (`AppEnums.swift:18-24`): `.idle` → 1/3, `.recording/.paused/.processing` → 2/3, `.done` → 3/3. Needs one computed value (e.g. `CheckInViewModel.flowProgress: Double`) written test-first (Principle X). If instead the ring is elapsed-based, `elapsedTime / maxDuration` exists (`:10-11`) but 66 % at 0:07 contradicts the pen. |
| Recording is live (mic open) | **Yes** | `state == .recording` (`:161`); `isIdleTimerDisabled` set (`:162`). |
| Stop & Save enabled / busy | **Yes** | `state == .processing` → disabled (`CheckInView.swift:413`); `saveFailed` (`CheckInViewModel.swift:50`). |
| Cancel | **Yes** | `cancelRecording()` (`:402-413`). |
| Back pill target | **NO action defined** | Nothing to bind: either `cancelRecording()` or a confirm → owner (Q3). |
| Hint "Take Your Time, Speak Freely." | **NO** | New static string; nothing equivalent while recording. |
| Audio level (if any live-mic feedback is wanted, Q8) | **Yes, unused visually** | `audioService.audioLevelStream` consumed at `:528-533` for `isSpeaking` only (deliberately not a glow, comment `:56-59`). |
| Cap approach (not in pen) | Yes | `isApproachingCap` (`:31`), `hasShownCapApproach` (`:36`). |
| Date (on A only) | Yes | `todayDate` (`CheckInView.swift:115-117`) — not shown on B. |
| Prompt pace | Yes | `AppSettings.promptPaceSeconds` → `promptInterval` (`:164`, `:422-429`). Pen B has no pace affordance; whether the Settings pen keeps "Prompt Pace" is the Settings cross-check's question. |

Nothing on this screen needs medication status, sleep hours, month selection, counts or thresholds.

---

## 4. Navigation delta

| Aspect | Pen | Code today | Delta |
|---|---|---|---|
| Container | Full-screen, **no tab bar**, **no FAB**, back pill top-left, empty title slot (same on A and C) | Check-in is a **tab root** in a native `TabView` (`RootTabView.swift:19-35`, `.tint(Theme.meadowGreen)` `:36`), wrapped by `ScreenContainer` → `NavigationStack` + inline empty title; tab bar background `NewLook.screen`, forced `.visible` (`ScreenContainer.swift:56-60`). **Nothing hides the tab bar during recording** (grep: the only `.tabBar` references are those two lines). | Two viable shapes, owner picks (Q2): **(a)** Check In stays a tab (Frame 4 has a `Status=Check In` variant), the tab bar and medication bar hide only while `state != .idle` (`.toolbar(.hidden, for: .tabBar)` driven by state; `showsMedicationBar` false); the pen's A-without-tab-bar is treated as an artboard omission. **(b)** The whole A→B→C flow becomes a `fullScreenCover` launched from the FAB and/or the tab, with the back pill as its dismiss. (b) matches the pen literally but contradicts Frame 4 and changes the deep-link path (`SquirlApp.swift:72-76` selects the tab and auto-starts; it would have to present the cover instead). |
| Back pill | 42.6 ⌀, action unspecified | none on this screen; the app's precedent for a custom back is `ExtractionReviewView`'s 44 ⌀ cancel pill; onboarding hides the system back while downloading (`LLMDownloadView.swift:24`, `DownloadPermissionView.swift:26`) | NEW shared component; must be ≥ 44 pt; decide back = cancel (immediate) vs confirm; if the flow is pushed, the interactive edge-swipe pop must be blocked while recording or it silently discards audio (Q3). |
| Tab switching mid-recording | impossible (no bar) | possible today; whether audio keeps recording on another tab is **not verified here** — device QA item | Hiding the bar removes the ambiguity. |
| Sheets | none on B | `MedicationLogSheet` and `TextCheckInComposer` are attached to `CheckInView` (`:34-45`) but only reachable from idle pills | KEEP the attachments; nothing new. |
| Alerts | none drawn | 7 `.alert`s (`:46-88`) | KEEP. |
| Saved → "Go Back Home" (C) | pops to a tab root the pen does not name | `CheckInSavedView` "Done" → `viewModel.reset()` → idle (`:123-125`, `:489-495`) | C's cross-check; B's Stop & Save keeps pushing into `.processing` → `.done` (`CheckInViewModel.swift:231`, `:267`). |

---

## 5. Accessibility, Dynamic Type, dark mode — specific to B

**The pen is light-only, Inter, fixed sizes.** The code is SF, fully Dynamic-Type scaled (every `Typography` role is `UIFontMetrics`-scaled, `Typography.swift`), adaptive colours via `Color(lightHex:darkHex:)`.

1. **72 pt timer inside a fixed 347 pt disc.** Today the 22 pt mono timer + two pills already live inside a fixed 300 pt ring with no `dynamicTypeSize` handling anywhere in `CheckInView.swift` (grep: none). At 72 pt base, a role relative to `.largeTitle` would exceed the disc by AX2. Spec must pick one: cap the timer role (e.g. scale with `.title1` and clamp via `@ScaledMetric` max), or size the disc from its content (`GeometryReader` min(width, content height)), or move Stop & Save / Cancel **below** the ring from `.accessibility1` upward (the layout fallback the old DESIGN.md demanded for AX1–AX5). Buttons must never shrink below 44 pt.
2. **Contrast (measured, not the DS chart):** Stop & Save label 4.04:1 (fail, normal text) — today's `#5F8A4C` is ≈4.0:1 too, so B neither improves nor regresses; hint `#6f7f75` on `#fbfffc` 4.19:1 (fail) → use grey-300 `#6a6d70` (5.21:1); subtitle `#6a6d70` at 12 pt passes 5.21:1 but 12 pt is under the 13 pt floor flagged in the screen spec Q12; active dot vs inactive 2.74:1 (< 3:1 UI) — encode the active dot by size/shape as well as colour ("colour is never the only cue", PRODUCT.md principle 5); arc mid `#3fbb4b` vs track 1.69:1 — the step indicator is weakest at its brightest point; acceptable only if the ring is decorative (`accessibilityHidden`, as today).
3. **Touch targets:** back pill 42.6 → 44 (`Metrics.minTapTarget`); Cancel 46/44 fine; Stop & Save 44 fine (today minHeight 44 `:409`). Cancel today is minHeight **38** (`:316`) — the pen fixes that.
4. **VoiceOver:** keep the timer live region (`:296-300`, whole-second throttling `:290-292`), the combined prompt label (`:375-376`), prompt announcements gated on quiet (`:176-184`), "Saving…"/"Captured." announcements (`:186-192`), a11y labels "Finish check-in" (`:414`) and "Cancel recording" (`:321`). New: back pill label; decide whether the arc is decorative (hidden) or announced as "Step 2 of 3".
5. **Reduce Motion:** today guards the state animation (`:29`), the prompt slide (`:374`), the ring spin/breathe (`CrescentRing.swift:40,47`), the cap cue (`:172-174`). The new arc growth 33 % → 66 % on state change and any breathing must be guarded the same way; the pen specifies no motion at all.
6. **Monospaced digits:** SF Mono today keeps "0:07"→"0:08" stable; a proportional 72 pt face needs `.monospacedDigit()` or the timer will shimmer every second.
7. **Dark mode:** the pen has no dark values (`design-system.md` §1.6: only `#1C1E19` exists). Every B colour needs a derived partner in the same commit, per the spec-033 precedent ("Figma specs light only; dark is derived"): `#fbfffc` ground, `#ffffff` card, `#ebf8ee` disc, `#bdddc0` track, `#17501d` title/timer (invisible on a dark ground — needs a green-100/200 ink), `#6a6d70` subtitle, `#26842f` Cancel label, `#cbd5e1` outline stroke, `#e4ece4` pill stroke, `#183c28@8%` shadow (shadows on dark grounds usually drop to ~0). The gradient arc can stay.
8. **Idle-timer:** recording disables the idle timer (`CheckInViewModel.swift:162`) — unchanged.

---

## 6. Risks, and open questions for the owner

### Risks
1. **Wrong container is the costliest reversal.** Pen chrome (no tab bar on A/B/C) contradicts Frame 4's `Status=Check In` tab. Tab-with-hidden-bar vs full-screen cover changes the deep-link path (`SquirlApp.swift:72-76`), auto-start (`CheckInView.swift:98-106`), and where the back pill goes. Decide before `/speckit-plan`.
2. **Ring rewrite is shared with onboarding.** `WelcomeView.swift:52` renders `CrescentRing(breathing: false)`; a `CheckInRing(progress:)` replacement must define Welcome's look or onboarding regresses. `Metrics.CheckIn.crescentDiameter` (300) is also read there.
3. **Copy is test-pinned.** `nudgePromptContents` (`CheckInViewModelTests.swift:34-40`) pins the five questions; "How's Your Mode?" must not ship; a casing policy change is a test change.
4. **Silent feature loss.** Dropping the prompt progress bar, the cap cue, the processing spinner or the save-failed recovery because "the pen doesn't show them" would violate spec 036 FR-014/US2 and Principle III's "surface the tradeoff". They are listed above as KEEP/decision items, not removals.
5. **Fixed pen geometry vs device range.** 347 pt ring + 65/59 gaps + 98 card = 586 pt from y 130 assumes a 402 × 874 canvas. Narrower (393/390) and shorter devices need a scaling rule; the pen gives none, and Dynamic Type makes it worse (§5.1).
6. **AA failure is design-system-wide.** White on green-500 fails on every Filled button in the file, not just here; fixing it on B alone would fork the button style.
7. **Sequencing.** `feat/057-ui-refresh` is identical to `main`; `feat/055` (Swift skills, constitution 3.0.0) and audit PR #45 (touches `CheckInViewModel`) are unmerged (`constraints.md` §5). Implementing B before they land invites the exact "stacked branches" conflict Principle V forbids.
8. **No HTML mockup exists for B** (`html-mockups/` has only the paywall); Constitution I blocks SwiftUI until one does.

### Open questions (only the ones that block the code plan)
1. **Ring meaning + motion.** Confirm it is a 3-step flow indicator (33/66/100 %), not elapsed time; say whether it animates 33 → 66 on tap and whether it breathes while listening (today's spin goes; Reduce Motion fallback either way).
2. **Container.** Keep Check In as a tab and hide the tab bar + medication bar while `state != .idle`, or make A→B→C a full-screen cover launched from the FAB/tab? (Affects deep links and the back pill.)
3. **Back pill and Cancel.** Same action (immediate discard, as `cancelRecording()` does today) or a confirm dialog? Block the edge-swipe pop while recording?
4. **Prompt progress bar.** Keep the timed 4 pt bar (not in the pen) as a hairline under the dots, or drop it and accept that the user cannot see when the prompt will advance?
5. **Processing look.** Between Stop & Save and C: DS Disabled Filled (`#e5e7eb` / `#9ca3af`), today's inline spinner, or an immediate C with a "Saving…" state?
6. **Copy policy.** Confirm "Mood", sentence case, spaced em dash and full stop (code copy wins over the pen's), and whether "Stop & Save" keeps the ampersand. Applies to A/B/C.
7. **Contrast.** Filled fill green-500 (4.04:1) vs green-600 `#26842f` (4.75:1) for every Filled button; hint colour to grey-300.
8. **Live-mic feedback.** Nothing shows audio is being captured beyond the timer; intentional? (`audioLevelStream` is available if not.)
9. **Cap-approach and save-failed states.** Keep today's behaviour restyled in the pen language (proposal: hint-line text swap for "Wrapping up soon"; Filled + Underline buttons for recovery)?

---

## 7. Effort — senior SwiftUI engineer, assuming tokens + shared components (Filled/Outlined Medium button styles, nav pill, Card M, page ground) already exist

| Bucket | Item | Hours |
|---|---|---|
| **NEW** | `CheckInRing(progress:)` — disc, 21.33 track, gradient arc with butt caps, shadow, Reduce-Motion, dark partners; replace both call sites incl. Welcome idle look | 5.0 |
| NEW | `flowProgress` computed on the VM, test-first (idle/recording/processing/done) | 1.0 |
| NEW | Back pill wiring on B: action, optional confirm, edge-swipe block, a11y label | 1.5 |
| NEW | Hint line + "Wrapping up soon" text-swap | 0.5 |
| NEW | Hide tab bar + medication bar for the flow (state-driven), verify deep-link/auto-start still lands on B | 2.0 |
| NEW | 72 pt timer role with `.monospacedDigit()` and a Dynamic-Type cap | 1.0 |
| | *NEW subtotal* | **11.0** |
| **CHANGE** | Prompt card restyle (r 18, hairline, tinted shadow, 24/500 + 12–13/500, dots 7.25 / gap 4 / green-100) + copy/test update | 1.5 |
| CHANGE | Stop & Save → Filled Medium, 16 pt stop glyph, processing mapping | 1.0 |
| CHANGE | Cancel → Outlined Medium (44 pt, no shadow, gap 8) | 0.5 |
| CHANGE | Layout rebuild: 30 pt gutters, card · 59 · ring 347 · 65 · hint; anchored-ring behaviour preserved across A/B/C; device-size scaling rule | 2.0 |
| CHANGE | Dynamic Type / AX fallback (buttons drop below the ring from AX1; nothing under 44 pt) | 2.0 |
| CHANGE | Dark-mode derivation for B's tokens + simulator check both schemes | 1.0 |
| CHANGE | HTML mockup for B (Constitution I) | 2.0 |
| CHANGE | Build + tests + simulator run, fixes | 1.5 |
| | *CHANGE subtotal* | **11.5** |
| **REMOVE** | `promptProgressBar` + `Metrics.CheckIn.promptBarHeight` (+ `promptProgress` and its test if the bar goes), paused UI, ring rotation, `Typography.timer`, obsolete `Metrics.CheckIn` values | 1.5 |
| | *REMOVE subtotal* | **1.5** |
| | **Total** | **≈ 24 h** |

Excluded (other slices): the shared button styles, nav pill and card modifiers themselves; the ground/token swap; A and C screens; the Settings "Prompt Pace" question.
