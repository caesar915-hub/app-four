<!-- Created: 2026-09-27 22:35 WEST · Updated: 2026-09-27 22:35 WEST -->
# Cross-check — Check-In Saved (`iPhone 17 - 6`) vs current SwiftUI — VERIFIED

> Independent verification of `crosscheck/checkin-saved.md` against the worktree at HEAD `08ba8cba`. Corrections are applied in place and listed in **§8 Verifier notes**.

| | |
|---|---|
| Pen frame | `iPhone 17 - 6` — "Check-In Recording — C · saved (Check-In Saved, ring with check, Go Back Home)" |
| Inputs | `out/screens/checkin-saved.md` (full read) · PNG `pen/named/iphone17-6-checkin-recording-c.png` · HTML-lite `pen/html-lite/iPhone-17-6.html` (re-tallied: `#fbfffc` ×2, `#2a9134` ×2, `#ffffff` ×3 — back-pill fill, check glyph, button label — `#212529` ×15 chrome; 34/600, 14/500, 16/500 lh 24; `padding: 10px 18px`; `border-radius: 999px`; 211 ring; 96.946 tile; check 49.716 × 37.287) · `out/design-system.md` · the three codebase maps · `out/constraints.md` |
| Code read | `app-four/Views/CheckIn/CheckInView.swift` (full) · `app-four/ViewModels/CheckInViewModel.swift` (full) · `app-four/Views/CheckIn/CrescentRing.swift` · `app-four/Views/RootTabView.swift` · `app-four/DesignSystem/ScreenContainer.swift` · `app-four/DesignSystem/MedicationBarOverlay.swift` · `app-four/Models/AppEnums.swift:18-24` · `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/{Metrics,Buttons,NewLook,Typography,Theme,Radius,Motion,Haptics}.swift` · `app-four/App/SquirlApp.swift:64-90` · `app-fourTests/ViewModels/CheckInViewModelTests.swift` (grep) |
| Rules | Planning only — no Swift touched. Pen values are quoted verbatim; where the pen is silent it is called out, not guessed. Paths are repo-relative to the `feat/057-ui-refresh` worktree, HEAD `08ba8cba`. |

---

## 1. Mapping — what implements this surface today

**The surface exists.** It is the `.done` branch of the Check-in tab, not a separate screen.

| Layer | Today | Evidence |
|---|---|---|
| View | `private struct CheckInSavedView` inside `CheckInView.swift` — disc + "Captured." + subtitle + full-width "Done" pill | `app-four/Views/CheckIn/CheckInView.swift:456-507` |
| Mounted from | `content` switch: `case .done: CheckInSavedView(recording: viewModel.lastSavedRecording) { viewModel.reset() }`; every other state renders `captureStage` | `CheckInView.swift:119-133` |
| Container / chrome | `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` → system inline nav bar with an empty title, `NewLook.screen` background on screen + nav bar + tab bar, the **medication bar as a top `safeAreaInset`**, and the native **tab bar visible** | `CheckInView.swift:26` · `app-four/DesignSystem/ScreenContainer.swift:49-60, 80-83` · `app-four/DesignSystem/MedicationBarOverlay.swift:16-25` |
| Tab shell | Native `TabView` — tab `.checkIn`, label "Check in", SF `checkmark.circle`, tint `Theme.meadowGreen`; `CheckInView` receives only `shouldAutoStart`, **no `selectedTab` binding** | `app-four/Views/RootTabView.swift:19-36` |
| View model | `CheckInViewModel.state: RecordingState` (`.idle · .recording · .paused · .processing · .done`); `.done` is set by the voice path in `attemptSave` and by the text path in `saveTextCheckIn`; `reset()` returns to `.idle`; `lastSavedRecording` is exposed but the saved view never renders it | `app-four/ViewModels/CheckInViewModel.swift:9, 257-291 (:267), 415-420, 482, 484-508 (:507)` · `app-four/Models/AppEnums.swift:18-24` |
| Side effects at `.done` | VoiceOver announcement `"Captured."`; `Haptics.success()` + spring pop on appear | `CheckInView.swift:186-192 (:189)`, `:501-505` |
| Auto-start from Siri / deep link while on `.done` | `consumeAutoStart()` → `viewModel.reset(); startVoiceCapture()` | `CheckInView.swift:98-106 (:103)` |
| Ring | **Not used on the saved state today.** `CrescentRing` (a full `Theme.meadowGreen` circle stroke, lineWidth 22, 300 pt) is only on `captureStage`; the saved state draws a **78 pt disc** with an SF `checkmark` | `CheckInView.swift:148-149, 465-473` · `app-four/Views/CheckIn/CrescentRing.swift:30-35` · `Metrics.swift:53, 64-66` |
| Tokens consumed | `Theme.meadowGreen` (:467, :494) · `NewLook.onSelection` (:472, :492) · `NewLook.inkPrimary` (:479) · `NewLook.inkSecondary` (:482) · `Metrics.CheckIn.savedDisc` 78 / `savedCheck` 32 (:468, :471) · `Typography.text(24, .bold, .title2)` (:478) · `Typography.callout` (:481) · `Typography.headline` (:491) · `Spacing.l` / `Spacing.hero` (:463, :497, :500) · `.newLookCardShadow()` (:469) · `Haptics.success()` (:502) | `CheckInView.swift` lines as cited |
| Tests | No view test. `CheckInViewModelTests` pins the **VM contract only**: `.done` reached on stop, on retry, on cap, and with Whisper missing; `lastSavedRecording` set/cleared | `app-fourTests/ViewModels/CheckInViewModelTests.swift:70-71, 84, 93, 102-128, 274-291, 512-524` |

Two facts that shape everything below:

1. **The saved state is reached by both capture paths.** Voice (`stopRecording → attemptSave → .done`, `CheckInViewModel.swift:267`) and text (`saveTextCheckIn → .done`, `:507`). The pen draws C only as the terminal of the voice flow A → B → C; it does not say whether "Write Notes" lands here (§6 Q4).
2. **"Saved" is true at `.done`, but the record is still filling in.** `.done` fires the moment the audio file is on disk (`:260-267`); transcription (the `transcriptionTask` at `:278-283` calling `transcribeInBackground`, `:316-366`) and the two-pass extraction (`ProcessingViewModel`) continue afterwards, and with Whisper missing the recording is parked as `.pendingTranscription` and `.done` is still reached (`:272-276`). The pen has no processing state between B and C — this matches today's behaviour (screen spec §8 Q1), and the alerts wired to that background work can surface **over** C (§6 R3).

---

## 2. Delta table

Legend: **KEEP** = already matches the pen · **CHANGE** = exists, restyle/rearrange · **NEW** = must be built · **REMOVE** = exists today, absent in the pen.

### 2.1 Presentation and chrome

| Element | Status | Today (file:line) | Pen | Exactly what changes |
|---|---|---|---|---|
| Screen background | CHANGE | `NewLook.screen` `#EFF2EB` / dark `#12140F` (`ScreenContainer.swift:53`; `NewLook.swift:13`) | `#fbfffc` (off-palette; Figma "Variable collection / BG_Color") | Token-level, shared with every screen: new `surface/screen` = `#fbfffc`; dark value undefined by the pen (§5). |
| System nav bar (inline, empty title) | REMOVE | `ScreenContainer.swift:51-54` | none — no system bar; a bespoke back pill only | Function lost: none (the title is `""`). The flow needs `.toolbar(.hidden, for: .navigationBar)` or a full-screen presentation. |
| Back pill | NEW (shared) | does not exist on a tab root; the only pill-style nav is `NewLookNavBar` on the edit sheet (`NewLook.swift:116-148`) and `ExtractionReviewView` cancel pill | `Background+Border` 42.6 × 42.6, fill `#ffffff`, stroke `#e4ece4` 1.065 inside, r 21.3; icon `vuesax/outline/arrow-left` 20 × 20, glyph 7.16 × 14.45 fill `#1e6725`; at (31, 77) | Build once for A / B / C / Edit (`NavBackPill`). Round to 40 pt drawn / 44 pt hit area (pen 42.6 < 44). **Its action on C is undefined in the pen** (§6 Q3). |
| Empty title slot `Frame 2 › Container` 128 × 22 | KEEP (nothing) | n/a | empty | Renders nothing; no work. |
| Medication bar (top inset) | REMOVE | `ScreenContainer(... showsMedicationBar: true ...)` → `MedicationBarView` padded h 16 / top 8 (`CheckInView.swift:26`; `MedicationBarOverlay.swift:18-23`) | absent on C (and not drawn on A / B either — neither sibling spec lists it) | Function lost: the "kicking in / active" glance for someone who just logged a dose on A. Minor; the bar returns on the tab root. Note `showsMedicationBar` is a per-`ScreenContainer` flag, so hiding it *only* on C means making the flag state-dependent (`viewModel.state == .done`) or presenting the flow outside `ScreenContainer`. |
| Tab bar (native `TabView`, painted `NewLook.screen`) | REMOVE (on this screen) | `RootTabView.swift:19-36`; `ScreenContainer.swift:59-60` | none on C (no `Main_navbar`, no `Add Button`) | See §4. Function lost: tab switching while the saved screen is up (today a user can leave `.done` by tapping Calendar; the saved state then persists on the Check-in tab until "Done"). |
| Status bar / home indicator | KEEP | system | system chrome | Nothing to draw. |

### 2.2 Hero block (`Frame 1707479478`, 342 × 340, vertically centred on the frame)

| Element | Status | Today | Pen | Exactly what changes |
|---|---|---|---|---|
| Completion ring `Group 735` | CHANGE (component) + NEW (state) | Saved state has **no ring** — a `Circle().fill(Theme.meadowGreen)` disc 78 pt with `.newLookCardShadow()` (`CheckInView.swift:466-469`). The capture ring is `CrescentRing`: uniform `Theme.meadowGreen` stroke 22, 300 pt, breathing/rotating (`CrescentRing.swift:30-49`) | 211 × 211 at centre (201, 372.5): disc fill `#ebf8ee`, track stroke `#bdddc0` 12.97 inside (r 105.5); arc `Ellipse 8` full donut 12.66 thick, linear gradient rotated 90° (top → bottom) `#26842f` 0 % → `#3fbb4b` 50 % → `#25832e` 100 %; group shadow `#000000` @ 8 %, offset (0, 1.22), blur 10.95 | Assuming the shared ring (`ProgressRing(progress:size:stroke:)` — A/B at 347 / 21.33, C at 211 / 12.97) exists from the A/B work, C is that component at `progress = 1.0`. NEW here: the **complete** state (no arc caps visible, no gap) and the 0.608× size. Integers: 212 ring / 13 stroke (pen §8 Q6). `CrescentRing` then loses its Check-in consumer; `WelcomeView.swift:52-53` (232 pt, `breathing: false`) is its only other caller — the pen has no Welcome screen, so that consumer must be decided separately. |
| Check tile `Frame 1000002966` + `Vector` | NEW | SF `Image(systemName: "checkmark")` 32 pt bold in `NewLook.onSelection` over the disc (`:470-472`) | **96.95 × 96.95 square, no corner radius**, fill `#2a9134`; white check path 49.72 × 37.29 at rel (23.62, 29.83); `strokeWeight` 1.61 recorded but no stroke paints | Custom shape, C-only. Either a `Path` port of the vector or SF `checkmark` sized to ≈50 × 37 with `.bold` — the pen's check is a filled polygon, thicker than SF bold; confirm (§6 Q5). Must be `accessibilityHidden(true)` — decorative; the title carries meaning. Sharp corners are the only hard rectangle in a pill-and-circle system (§6 Q5). |
| Text stack `Frame 1707479471` | CHANGE | `VStack(spacing: Spacing.l)` = 16 between disc, title, subtitle (`:463`); whole saved view inset **16** each side (`.padding(.horizontal, Spacing.l)`, `:500`) | vertical, **gap 6** between title and subtitle; **48** from ring bottom to title top; width 261 (title-intrinsic), items centred; frame gutters **30** (342 = 402 − 60) | Two gaps (48 / 6) replace one (16). Width must be flexible (`maxWidth: .infinity`, h-padding 30), not 261 fixed (§5). Gutter 16 → 30 is off the `Spacing` grid (`Spacing.swift` has 24 `xxl` and 32 `section`, no 30) — token decision, shared with A / B. |
| Title | CHANGE | `"Captured."` — `Typography.text(24, weight: .bold, relativeTo: .title2)`, `NewLook.inkPrimary` `#1C1B1F` (`:477-479`); no header trait | `"Check-In Saved"` — Inter **34 / Semi Bold (600)**, `#17501d` (green-800), lh auto ≈ 41, centred | Copy, size, weight, colour. No `Typography` role is 34/600 (`largeTitle` is 34 **bold** `.largeTitle`, `display` 28 semibold — `Typography.swift:21-23`); the token pass must add a page-title role (34/600 rel. `.largeTitle`). Add `.accessibilityAddTraits(.isHeader)`. |
| Subtitle | CHANGE | `"That's today's check-in. Talk to you next time."` — `Typography.callout` 15 regular, `NewLook.inkSecondary` `#8A8A8E`, `maxWidth: 240` (`:480-484`) | `"A Moment For Yourself, Captured.⏎See You At Next Check-In"` (⏎ = U+2028) — Inter **14 / Medium (500)**, `#1e2225` (grey-600), centred, two designed lines | Copy, role, colour. `Typography.subheadline` (14 medium rel. `.subheadline`, `Typography.swift:36`) is an exact match. Replace U+2028 with `\n` and let it wrap; drop the 240 cap. Copy issues carried from the screen spec §4: Title Case, missing final period, "At Next" article, "Check-In" vs tab-bar "Check In". Also a Product-Posture question (§6 Q7). |
| Vertical placement of the hero | CHANGE | `Spacer()` above and below (`:464, :486`) → centred in the space *above the button* (button + 40 bottom padding sits in the same VStack) | block y 267 = (874 − 340) / 2 → **centred on the whole frame**, independent of the CTA (constraints `CENTER / CENTER`) | Move the CTA out of the centring VStack (overlay / `safeAreaInset(edge: .bottom)`), so the hero centres on the frame as drawn. |

### 2.3 Primary CTA (`Frame 1707479477`, y 717–761)

| Element | Status | Today | Pen | Exactly what changes |
|---|---|---|---|---|
| Button | CHANGE | `Button("Done")`: `Typography.headline` 16 **semibold**, `NewLook.onSelection`, `frame(maxWidth: .infinity, minHeight: 50)`, `Theme.meadowGreen` `#5F8A4C` capsule, `.buttonStyle(.plain)` (system press-dim only — no designed pressed fill), `.padding(.bottom, Spacing.hero)` = 40 (`:489-497`); width = screen − 32 (`:500`) | `Button / Filled · Medium · Without Icon · Default`: 342 × 44, fill `#2a9134`, r 999, padding **10 v / 18 h**, gap 8; label `"Go Back Home"` Inter **16 / Medium (500)**, lh **24**, `#ffffff`; width 342 (gutters 30) | Copy, fill (`#5F8A4C` → `#2a9134`), height 50 → 44, weight 600 → 500, gutters 16 → 30, add pressed fill (pen "Hovered" `#1e6725` → `configuration.isPressed`), disabled `#e5e7eb` fill / `#9ca3af` label (never disabled here). Use the shared `FilledButtonStyle` assumed from Frame 3, not a local style. Today's button is a one-off (comment at `:487-488`) that bypasses **two** existing package styles: `PrimaryButtonStyle` (`.primary` — `Theme.meadowGradient`, `Radius.button` rect, amber shadow, `Buttons.swift:5-16`) and `CheckInPrimaryButtonStyle` (`.checkInPrimary` — `checkInGreen → checkInGreenSoft` gradient, `Buttons.swift:21-36`), both `Typography.headline` + `opacity(isPressed ? 0.9 : 1)`. The Frame 3 style must **supersede** `CheckInPrimaryButtonStyle` (its only reason to exist was the capture-flow green), not become a third — Constitution III/IV. No `Typography` role is 16/500 (`headline` is semibold, `body` regular — `Typography.swift:34-38`); needs a button-label role. |
| Placement | CHANGE | bottom of the VStack, 40 above the tab-bar safe area | absolute y 717 (constraints `MIN / MIN`): bottom edge 761 = **79 pt above the home-indicator zone (840)**, 113 above the frame edge; 110 below the subtitle | Pin to the bottom safe area (`safeAreaInset(edge: .bottom)`) with a fixed gap; the exact gap is an owner call (pen §8 Q8: SE-class / Pro Max / AX growth). |
| Contrast | CHANGE (decision) | white on `#5F8A4C` = **4.02:1** (`Theme.swift:9`; WCAG relative-luminance calc) — **already fails AA 4.5** for 16 pt semibold; today's Done pill is not a passing baseline | white on `#2a9134` = **4.04:1** (Frame 5's own card) — AA large only; 16/500 is not large | Not a regression — a wash (4.02 → 4.04), but the pen is the moment to fix it. Ship as drawn (fails AA 4.5 for normal text) or fill with green-600 `#26842f` (4.75). Applies to every filled Medium button in the file (§6 Q6). |

### 2.4 Behaviour and motion

| Element | Status | Today | Pen | Exactly what changes |
|---|---|---|---|---|
| Swap on `state == .done` | KEEP | `CheckInView.swift:121-125` | C follows B's "Stop & Save" | No VM change. Keep `.processing` on B's stage (spinner in the stop pill, `:397-398`) and `saveFailed` recovery (`:419-449`) — the pen draws neither; C must not appear before `.done`. |
| One primary action | KEEP | single "Done" (the old DESIGN.md §Screen Specs L111 also asked for a "Check in again" secondary — never shipped; `HEAD:DESIGN.md`) | single "Go Back Home" | Matches PRODUCT.md L45 "one primary action per screen". Nothing to remove. |
| CTA action | CHANGE (semantics) | `onNewCheckIn` → `viewModel.reset()` → `.idle` hub on the **same tab** (`:123-125`, `CheckInViewModel.swift:415-420`) | "Go Back Home" → implies popping the flow to a tab root; "Home" is not a tab (Calendar · Check In · Insights · Settings) | If Home = Check-in idle hub: no change beyond copy. If Home = Calendar (or the launching tab): `CheckInView` needs a `selectedTab: Binding<Tab>` (RootTabView passes none, `RootTabView.swift:24`) **and** the reset, or the whole A→B→C flow becomes a `fullScreenCover` that `dismiss()`es (§4, §6 Q2). |
| Back pill action | NEW (undefined) | no back affordance on a tab root | pill present, target undefined | Options in §6 Q3. |
| Haptic | KEEP | `Haptics.success()` on appear (`:502`) | not specified (no motion/haptic spec in the pen) | Keep; nothing contradicts it. |
| Entrance motion | CHANGE (decision) | Two layers today: (1) the B→C **view swap** itself is animated — `content.animation(reduceMotion ? nil : Motion.smooth, value: viewModel.state)` (`:29`; `Motion.smooth` = `.smooth(duration: 0.4)`, `Motion.swift:10-12`), so `captureStage` crossfades into `CheckInSavedView`; (2) the disc pops scale 0.6 → 1, opacity 0 → 1, `.spring(response: 0.5, dampingFraction: 0.6)`; Reduce Motion → static (`:474-475, :503-504`) | none drawn; B→C transition not designed | Either static (as drawn) or arc 66 % → 100 % + tile settle spring (old DESIGN.md L79 "settles to a check when saved"; L81 no confetti). If the ring is a shared component that persists across A→B→C, the `:29` crossfade should become a matched-geometry / in-place arc animation rather than a fade of the whole stage. Reduce Motion must collapse to static either way (§6 Q8). |
| VoiceOver announcement | CHANGE | `announce("Captured.")` on `.done` (`:189`) | copy is "Check-In Saved" | Announcement text follows the final copy. |
| Auto-start from `.done` | KEEP | `consumeAutoStart` resets then starts (`:103`) | n/a | Unchanged; Siri "check in" while C is up starts a new capture. |
| Alerts attached to the tab (`showMemoryError`, `showModelMissing`, download errors) | KEEP (undesigned) | 7 `.alert`s on `CheckInView` (`:46-88`); two of them fire from background extraction *after* `.done` | not drawn | They can appear over C today and will tomorrow. Not a delta, but an undesigned state (§6 R3). |

### 2.5 REMOVE inventory — and what each removal loses

Only these exist today and are absent in the pen. The task's other examples (audio player, regenerate summary, transcript, medication inline-expand, sleep custom hours, DoseGuard, export, feedback button, stickers/Siri, model download rows) **do not live on this screen** — they belong to Recording detail, Edit sheet, Settings and the composer, and are not touched by the C delta.

| Removed | Where | Function lost? |
|---|---|---|
| 78 pt `Theme.meadowGreen` disc + SF `checkmark` 32 bold + card shadow | `CheckInView.swift:465-473` | None — replaced by ring + tile. |
| `Metrics.CheckIn.savedDisc` (78) / `savedCheck` (32) | `Metrics.swift:63-66` | None; they become dead tokens (Constitution III: delete, don't shim). Replaced by ring 211/13 and tile 97 metrics. |
| `Spacer`-centred single VStack layout | `:463-498` | None. |
| `CheckInSavedView.recording` parameter | `:457` (passed at `:123`, never read) | None — it is dead today; the pen also shows no record data. Drop it (or keep `lastSavedRecording` VM-side only, which tests pin). |
| Spring pop entrance | `:474-475, :503-504` | Decorative only — but see §6 Q8 before deleting; the old DESIGN motion rule wanted a settle. |
| Medication bar inset on the saved screen | `ScreenContainer` flag, `CheckInView.swift:26` | The at-a-glance dose state right after "Log Medications" on A. Minor; bar is visible again on the root. |
| Native tab bar + system nav bar during the flow | `RootTabView.swift`, `ScreenContainer.swift:49-60` | Tab switching mid-flow (today possible; arguably undesirable while recording). Flow-level decision, shared with A/B. |
| "Done" copy, `Theme.meadowGreen` fill, `NewLook.inkPrimary/inkSecondary` inks | `:477-494` | None — token migration. `Theme.meadowGreen` stays load-bearing elsewhere (tint, chip fill; `codebase-designsystem.md` §2) so it is not deleted by this screen. |

---

## 3. Data availability

The pen renders **no record data** on C. Every visible element is static copy or a state-derived visual.

| Pen element | Needs data? | Available today | Path / note |
|---|---|---|---|
| "Check-In Saved" | no (static) | — | Rendered iff `viewModel.state == .done` — `CheckInViewModel.swift:9`; set at `:267` (voice) and `:507` (text). ✅ |
| "A Moment For Yourself, Captured. / See You At Next Check-In" | no (static) | — | ✅ |
| "Go Back Home" | no (static) | — | ✅ Action target: see gap G2. |
| Ring at 100 % | derived, no model | `RecordingState` | If the ring encodes **flow step** (A 33 % → B 66 % → C 100 %, per the B spec §1 "flow-step indicator, not a timer"): `progress = state == .done ? 1 : (state == .idle ? 1/3 : 2/3)` — trivially derivable, no persistence. ✅ If it encoded **processing progress** instead: ❌ **NO** — neither `TranscriptionService` (segment stream, `CheckInViewModel.swift:369-399`) nor `ProcessingViewModel` exposes a fraction. `TranscriptionSegmentDTO` does carry `startTime`/`endTime` (`Protocols.swift:48-55`), but `WhisperKitTranscriptionService` yields only two placeholder segments at `endTime: 0` ("Setting up on-device transcription…", "Transcribing…", `:104-111`, `:121-128`) and then one final segment at full duration (`:163-170`) — so no intermediate fraction exists to read. `ProcessingViewModel` has `showMemoryError` / `showModelMissing` and `activeTask` only (`ProcessingViewModel.swift:16-19`). **Gap G1** — meaning must be fixed (pen §8 Q7). |
| Check tile | derived | `state == .done` | ✅ |
| "9:41", signal, battery, home indicator | system | — | Not drawn by the app. |
| The saved `Recording` (date, duration, transcript, signals, meds) | **not shown in the pen** | `viewModel.lastSavedRecording` (`CheckInViewModel.swift:482`), `Recording.createdAt/duration/…` | Available but intentionally unused — matches the old DESIGN.md §Screen Specs (L111, `HEAD:DESIGN.md`, doc created 2026-06-15): "Saved: … **no transcribing UI, no daily card**". (It is a screen-spec line, not a Decisions Log row.) ✅ (no gap) |
| "Home" destination | navigation, not data | ❌ **NO** — `CheckInView` has no `selectedTab` binding (`RootTabView.swift:24-26`), no `dismiss` context (it is a tab root), no notion of "launching tab" | **Gap G2** — needs either a `Binding<Tab>` into `CheckInView` (+ `reset()`), or a flow container (`fullScreenCover`) that owns dismissal. Decision in §6 Q2. |
| Back-pill target | navigation | ❌ nothing to pop on a tab root | **Gap G3** — same decision as G2 (§6 Q3). |

Labels the task listed as examples — medication status "Kicking In"/"Active", "8h Sleep", "Locked In", month selector, "24 check-ins", weekday dominant level, connection thresholds, "Installed", "34MB" — **none appears on this screen**; they are covered by the Day-details / Insights / Settings cross-checks.

---

## 4. Navigation delta

| Aspect | Today | Pen (C) | Delta |
|---|---|---|---|
| Container | Check-in is a **tab root** inside a native `TabView` (`RootTabView.swift:19-36`); saved state is a state swap inside that root | C is step 3 of a pushed / full-screen flow: no tab bar, no FAB, a back pill top-left, no grabber, status bar drawn (screen spec §1) | Either (a) keep the tab root and hide chrome by state — `.toolbar(.hidden, for: .tabBar)` + `.toolbar(.hidden, for: .navigationBar)` while `state != .idle` (but A also has no tab bar in the pen, so "state" isn't the switch — the whole tab would be barless) — or (b) present A→B→C as a `fullScreenCover` launched from the Check In tab / violet FAB, with the tab root reduced to a launcher. **(b) is the reading the sibling specs converge on**; it is a flow decision, not a C decision. |
| Tab bar style | native, painted `NewLook.screen` from inside each root (`ScreenContainer.swift:59-60`); tint `Theme.meadowGreen` | DS Frame 4 custom pill bar 346 × 60 r 75 — **absent on C** | No custom-tab-bar work is triggered by C; only the *hiding* is. |
| FAB | none | DS Frame 15 violet `Add Button` — **absent on C** | none |
| Back affordance | none (tab root; system back only on pushed detail) | back pill (shared instance with A / B / Edit) | NEW shared component; target on C undefined (§6 Q3). |
| Primary exit | "Done" → `reset()` → idle hub, same tab; tab bar stays | "Go Back Home" → pop to a root | G2 above. If (b): `dismiss()` + `reset()`; if (a) with Home = Calendar: `selectedTab = .calendar` + `reset()`. |
| Sheets | none opened from the saved state; the two `.sheet`s (`MedicationLogSheet`, `TextCheckInComposer`) are attached to `CheckInView` and are only triggered from the idle hub (`CheckInView.swift:34-45, 225-231`) | none | none. |
| Alerts | 7 `.alert`s attached at the view level (`:46-88`); `showMemoryError` / `showModelMissing` are raised by background extraction and can present over C | none drawn | Not a delta; an undesigned overlay (§6 R3). |
| Deep link / Siri | `router.shouldStartCheckIn` → `selectedTab = .checkIn; shouldAutoStartRecording = true` (`SquirlApp.swift:72-76`); on `.done` → `reset(); startVoiceCapture()` (`CheckInView.swift:103`) | n/a | Under (b) the router must present the cover instead of (or as well as) switching the tab — flow-level, flag for the A cross-check. |

---

## 5. Accessibility, Dynamic Type, dark mode (this screen)

**Pen baseline:** light only, Inter, fixed sizes, no state variants, no motion spec, no dark values (design-system.md §1.6, §7 Q13).

- **Typeface.** Inter 34/600 · 14/500 · 16/500 → SF via `Typography` (Q-C1 in constraints §4.4 — decision pending). Mapping if SF: title `text(34, .semibold, relativeTo: .largeTitle)` (new role), subtitle `Typography.subheadline` (exact), button `text(16, .medium, relativeTo: .body)` (new role). All three scale with Dynamic Type through `UIFontMetrics` (`Typography.swift:12-17`).
- **Dynamic Type growth.** Fixed-point imagery: ring 211 and tile 97 (correct — `Metrics` doctrine, `Metrics.swift:47-50`). Text: at AX5 `.largeTitle` scales 34 → ~60 pt, so "Check-In Saved" wraps to two lines (~140 pt) and the 14 pt subtitle to 4–5 lines. Stack: 211 + 48 + 140 + 6 + ~150 + 110 + 44 ≈ 710 pt of content in an 874 frame — fits on iPhone 17, **overflows an SE-class 667 pt height**. Spec must define: (1) the hero block yields (`ScrollView` fallback or `dynamicTypeSize.isAccessibilitySize` → ring 160, gap 24); (2) the CTA stays pinned and never scrolls off; (3) no `minimumScaleFactor` on the title (it is the only heading). Today's `maxWidth: 240` on the subtitle (`:484`) must go — a 261-pt fixed width is a pen artefact.
- **Line separator.** The subtitle's U+2028 hard break must not be reproduced literally; use `\n` (two designed lines at default size) and allow reflow.
- **Contrast** (Frame 5 cards, on white; `#fbfffc` is within 0.1 of white): title `#17501d` 9.54 ✅ AAA · subtitle `#1e2225` 16.02 ✅ · chevron `#1e6725` 6.95 ✅ · **CTA label white on `#2a9134` 4.04 ✗** (AA normal text needs 4.5; passes only at ≥ 18 pt regular / 14 pt bold, i.e. only once Dynamic Type ≥ xxLarge) · check on tile: white on `#2a9134` — non-text, 3:1 UI floor ✅. Fix candidate: green-600 `#26842f` (4.75) for the fill.
- **Touch targets.** CTA 44 ✅. Back pill 42.6 ✗ → draw 40–43, hit 44 (`Metrics.minTapTarget`, `Metrics.swift:10`). Ring/tile are not interactive.
- **VoiceOver.** Order: title (header) → subtitle → "Go Back Home" (button). Ring + tile `accessibilityHidden(true)` (today the SF `checkmark` image at `:470` is *not* hidden and reads as "Checkmark" — fix in the rewrite). Keep the `.done` announcement (`:189`) with the new copy; keep the `Haptics.success()`.
- **Reduce Motion.** Pen: no motion. If a settle/arc-complete entrance is added, gate it on `accessibilityReduceMotion` exactly as `:503-504` does today; static = final state.
- **Dark mode.** Nothing in the pen. Every colour on C needs a derived dark partner or an owner ruling: `#fbfffc` bg, `#ebf8ee` disc, `#bdddc0` track, the three gradient stops, `#2a9134` fills, `#17501d` title (needs a light green in dark — e.g. green-200 `#9dcca2` — or the title stops being green), `#1e2225` subtitle (→ near-white), `#e4ece4` pill stroke. Precedent: spec 033 "light values 1:1, dark derived and logged" (constraints §3.9, 2026-07-16). `NewLook.onSelection` flips to dark ink on light fills in dark mode (`NewLook.swift:32-35`); `#2a9134` is dark enough that white stays — but the derived dark fill, if lifted, may not be.
- **Colour is never the only cue.** Satisfied: the check shape + copy carry "saved"; the ring's 100 % is redundant with both.

---

## 6. Risks and open questions

### Risks

- **R1 — This is a flow decision disguised as a screen.** Chrome (no tab bar, back pill, "Go Back Home") only makes sense if A→B→C is presented as one full-screen flow. Deciding C alone would produce a barless saved state inside a barred tab. Cross-check A/B first; C inherits.
- **R2 — CTA contrast 4.04:1** fails the PRODUCT.md AA floor (L53, ≥ 4.5:1 body) at default size; today's `#5F8A4C` pill already fails at 4.02:1, so this is an inherited defect the refresh can close, not one it introduces. The pen repeats the same fill on every Medium filled button, so the fix is a token decision, not a C tweak.
- **R3 — Undesigned overlays on C.** `showMemoryError` / `showModelMissing` alerts (`CheckInView.swift:79-88`) are raised by extraction that runs *after* `.done` and can appear on top of "Check-In Saved"; a Whisper-missing capture reaches C as `.pendingTranscription`. None of these has a pen design; "Saved" remains truthful, but the spec must say the alerts are acceptable here or move them to the detail view.
- **R4 — Copy vs Product Posture.** "See You At Next Check-In" is a return nudge (constraints Q-P4); Title Case in running copy is not HIG; "Check-In" (C) vs "Check In" (tab bar). Normalise once, file-wide.
- **R5 — Token sprawl.** C alone introduces five off-palette values (`#fbfffc`, `#ebf8ee`, `#e4ece4`, `#3fbb4b`, `#25832e`) next to a palette that already has **four** green tokens in code (`Theme.meadowGreen` `#5F8A4C` `Theme.swift:9`, `NewLook.selection` `#54B492` `:31`, `NewLook.checkInGreen` `#5FB36E` `:41`, `NewLook.checkInGreenSoft` `#96C19F` `:44`) plus the mood-ramp greens in `Palette+Signals.swift` / `MoodLevel+Palette.swift`. Constitution IV requires a Complexity Tracking row; the spec should snap to Frame 5 steps where the eye can't tell (`#ebf8ee` ≈ green-50 `#eaf4eb`).
- **R6 — Dark mode is entirely derived**; the green title `#17501d` has no legible dark counterpart in Frame 5 without choosing one.
- **R7 — Ring semantics.** If the owner reads the ring as processing progress, there is no data source (G1); the safe reading is flow-step, which needs no data.
- **R8 — `CrescentRing` orphaning.** Replacing the ring on Check-in leaves `WelcomeView.swift:52` as the sole consumer of a legacy component; the pen has no Welcome screen. Decide (reskin Welcome with the new ring, or keep `CrescentRing` for it) so no dead component is merged.
- **R9 — HTML-mockup gate.** Constitution I / CLAUDE.md require an HTML mockup before SwiftUI. The pen's HTML-lite export exists (`pen/html-lite/iPhone-17-6.html`) — whether it satisfies the gate, or a Dynamic-Type/dark-toggle mockup is still owed, is a process ruling to make before `/speckit-plan`.
- **R10 — Test surface.** No test pins the saved *view*; `CheckInViewModelTests` pin `.done` / `lastSavedRecording`. Keeping the VM contract untouched keeps all 32 `@Test`s green; adding a `selectedTab` write into the VM would need a new test.
- **R11 — Button-style consolidation.** `CheckInPrimaryButtonStyle` (`Buttons.swift:21-36`) exists solely to carry the capture-flow green; the pen's Frame 3 filled button replaces that role. If the new style is added beside it, three primary styles coexist (`.primary`, `.checkInPrimary`, new) — Constitution IV. Its other consumers (onboarding "Start", text composer per its doc comment) must migrate in the same spec or the token pass, not on C.

### Open questions for the owner (only the ones that block the spec)

1. **Processing gap** — confirm C shows the moment the audio is saved (`.done`, today's behaviour) while transcription/extraction continue in the background, and that `.processing` / `saveFailed` keep B's stage (no pen design for either).
2. **Where is "Home"?** Check-in idle hub (no nav change), Calendar, or the tab the flow was launched from? Decides G2 and whether A→B→C becomes a `fullScreenCover`.
3. **Back pill on C** — hide it, make it equal to "Go Back Home", or a close (×)? Returning to B (a finished recording) is meaningless.
4. **Does "Write Notes" (text composer) also land on C?** Today it does (`saveTextCheckIn → .done`, `CheckInViewModel.swift:507`); the pen shows no composer.
5. **Check tile** — sharp 97 pt square as drawn, or rounded/circular; custom vector check or SF `checkmark`?
6. **CTA fill** — keep `#2a9134` (4.04, fails AA at 16/500) or darken to green-600 `#26842f` (4.75)? File-wide.
7. **Copy** — keep Title Case and "See You At Next Check-In" (return nudge vs Posture), add the final period, and set the VoiceOver announcement to match.
8. **Entrance motion** — static (as drawn) or arc completing + tile settle (Reduce Motion → static)? No confetti either way.
9. **Off-palette colours** — tokenise `#fbfffc` / `#ebf8ee` / `#e4ece4` / gradient stops, or snap to Frame 5 steps? And who supplies dark values (derive-and-log per spec 033 precedent)?
10. **Inter vs SF** — file-wide; decides whether 34/600 · 14/500 · 16/500 map to new `Typography` roles or to bundled fonts.
11. **Medication bar** — hidden for the whole A→B→C flow (pen shows none anywhere in it) or only on C?
12. **Bottom anchoring** — pin the CTA to the bottom safe area (gap ≈ 79 pt as drawn, or a token) with the hero centred in the remaining space, on all device heights?

---

## 7. Effort — senior SwiftUI engineer, tokens + shared components assumed to exist

Assumptions: `surface/screen`, green ramp tokens, `FilledButtonStyle` (Frame 3 Medium), `NavBackPill`, `ProgressRing` (A/B) and the 34/600 + 16/500 `Typography` roles exist from the token/A/B work. HTML mockup per Constitution I counted separately. Excludes the flow-presentation change (cover vs tab), which belongs to the A cross-check.

| Bucket | Work | Hours |
|---|---|---|
| **NEW** | Check tile (97 pt square + check path, decorative, hidden from AX) · ring `progress = 1.0` complete state at 211/13 (no caps, no gap) · back-pill wiring on C once Q3 is answered · optional entrance (arc 66→100 % + settle, Reduce Motion gate) | 1.0 · 0.5 · 0.5 · 1.5 = **3.5** |
| **CHANGE** | Rewrite `CheckInSavedView` layout (hero centred on frame, gaps 48/6, CTA in a bottom safe-area inset) · copy + roles + colours (title/subtitle/CTA) + `isHeader` + announcement text · "Go Back Home" semantics (Q2: `selectedTab` binding through `RootTabView` → `CheckInView`, or `dismiss` in a cover) · Dynamic Type AX1–AX5, dark-mode derived values, VoiceOver order verified on device | 2.0 · 0.5 · 1.0 · 1.5 = **5.0** |
| **REMOVE** | Disc + SF check, `Metrics.CheckIn.savedDisc/savedCheck`, dead `recording` param, spring pop (if Q8 = static) · make `showsMedicationBar` / nav / tab chrome state-dependent on C (if Q11 = C only) · retire `CheckInPrimaryButtonStyle` once its consumers are on the Frame 3 style (counted in the token pass, not here) | 0.25 · 0.5 = **0.75** |
| Process | HTML mockup with Dynamic Type + dark toggles (if R9 rules the pen export insufficient) · no new unit tests unless a VM navigation write is added (+0.5) | **1.0** |
| **Total** | | **≈ 10 h** (range 8–12 depending on Q2/Q8/Q11) |

---

## 8. Verifier notes

Method: every file:line the cross-check cites was opened in the worktree (`feat/057-ui-refresh`, HEAD `08ba8cba`); hex values were re-read from `Theme.swift` / `NewLook.swift`; contrast ratios were recomputed (WCAG 2.x relative luminance) and compared with the Frame 5 cards; the HTML-lite export was re-tallied with `grep`; the PNG was re-read for missed elements. No Swift file was modified. The `.pen` file was not opened.

### 8.1 Corrections (claim → correction → evidence)

| # | Where | Claim as written | Correction | Evidence |
|---|---|---|---|---|
| C1 | §2.3 Contrast, §6 R2 | "white on `#5F8A4C` ≈ 4.6:1 (passes AA)" | **4.02:1 — fails AA 4.5** for the 16 pt semibold label. Today's Done pill is not a passing baseline; pen 4.04 is a wash, not a regression. | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Theme.swift:9` (`#5F8A4C`); luminance calc: L(#5F8A4C)=0.211 → (1.05)/(0.261)=4.02. Frame 5 lists 4.04 for `#2a9134`, 4.75 for `#26842f` (`pen/ds-html-lite/Frame-5.html`) — those two were correct. |
| C2 | Header, Inputs | HTML-lite `#ffffff` ×2 | ×3: back-pill fill, check-glyph `path` fill, button label | `pen/html-lite/iPhone-17-6.html` — `grep -o -i "#ffffff"` → 3 |
| C3 | §2.3 Button | `.buttonStyle(.plain)` "(no pressed feedback)" | `.plain` applies the system press highlight (label dims) on iOS; what is missing is a *designed* pressed fill. | `app-four/Views/CheckIn/CheckInView.swift:496` |
| C4 | §6 R5 | "three greens in code (`meadowGreen`, `selection`, `checkInGreen`)" | Four green colour tokens: add `NewLook.checkInGreenSoft` `#96C19F`; plus the mood-ramp greens. | `NewLook.swift:31, 41, 44`; `Theme.swift:9` |
| C5 | §1 fact 2 | "transcription (`transcribeInBackground`, `:278-283`)" | `:278-283` is the `transcriptionTask` that *calls* it; the function is `:316-366`. | `app-four/ViewModels/CheckInViewModel.swift:278-283, 316-366` |
| C6 | §3 saved-`Recording` row | "matches the 2026-06-15 **decision** 'Check-in saved state shows no transcribing/card'" | It is a §Screen Specs line (L111) in the deleted DESIGN.md, not a Decisions Log row; the quoted wording is "no transcribing UI, no daily card". The same line also asked for a "Check in again" secondary that never shipped. | `git show HEAD:DESIGN.md` L111 (the worktree has `DESIGN.md` deleted, unstaged) |

### 8.2 Omissions added

| # | Where | Added | Evidence |
|---|---|---|---|
| O1 | §2.3 Button, §6 R11, §7 REMOVE | Two package button styles already exist and are bypassed by the saved-view pill: `PrimaryButtonStyle` (`.primary`, meadow gradient, `Radius.button` rect) and `CheckInPrimaryButtonStyle` (`.checkInPrimary`, `checkInGreen → checkInGreenSoft` gradient). The Frame 3 filled style must supersede `CheckInPrimaryButtonStyle`, not sit beside it (Constitution IV, `.specify/memory/constitution.md:46-51`). | `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Buttons.swift:5-16, 21-36, 55-63` |
| O2 | §2.4 Entrance motion | The B→C **view swap** is itself animated today: `content.animation(reduceMotion ? nil : Motion.smooth, value: viewModel.state)` — a 0.4 s crossfade of the whole stage, separate from the disc pop. A persistent shared ring (A→B→C) changes what this animation should be. | `CheckInView.swift:29`; `Motion.swift:10-12` |
| O3 | §2.2 Text stack, §2.3 Button | Horizontal gutters: today 16 (`Spacing.l`, `:500`) vs pen 30; 30 is not on the `Spacing` grid (24 / 32 nearest). | `CheckInView.swift:500`; `Spacing.swift:5-21` |
| O4 | §3 Ring row (G1) | Concrete reason no processing fraction exists: WhisperKit yields two placeholder segments at `endTime: 0` and then one final segment at full duration — no intermediate value; `ProcessingViewModel` holds only two alert flags and `activeTask`. | `app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift:104-111, 121-128, 163-170`; `app-four/Services/Protocols.swift:48-55`; `app-four/ViewModels/ProcessingViewModel.swift:16-19` |
| O5 | §2.4 One primary action | Old DESIGN.md L111 wanted a "Check in again" secondary; code never shipped it, pen has none — no function lost, nothing to remove. | `git show HEAD:DESIGN.md` L111; `CheckInView.swift:489-497` (single button) |

PNG re-read (`pen/named/iphone17-6-checkin-recording-c.png`): status bar, back pill, gradient ring (lighter at the horizontal midline), sharp green square with white check, "Check-In Saved", two-line subtitle, "Go Back Home" pill, home indicator. No element, state, copy string or clipped row is missing from the cross-check or the screen spec.

### 8.3 Confirmed (opened and matched)

1. `CheckInSavedView` is `private struct` at `CheckInView.swift:456-507`; mounted from the `content` switch `:119-133` with `viewModel.reset()` on `.done`.
2. `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` at `:26`; `ScreenContainer.swift:49-60` (`NavigationStack`, inline title, `NewLook.screen` background `:53`, nav-bar `:54` and tab-bar `:59-60` toolbar backgrounds), `:80-83` non-scrollable path.
3. `MedicationBarOverlay.swift:16-25` — top `safeAreaInset`, `Spacing.l` (16) horizontal / `Spacing.s` (8) top.
4. `RootTabView.swift:19-36` — native `TabView`; `CheckInView` receives store/services/`shouldAutoStart` only (`:24`), no `selectedTab`; label "Check in", `Icons.checkIn` = `"checkmark.circle"` (`Icons.swift:8`); `.tint(Theme.meadowGreen)` `:36`.
5. `RecordingState` = idle · recording · paused · processing · done, `AppEnums.swift:18-24`.
6. VM: `state` `:9`; `.done` set at `:267` (voice, inside `attemptSave` `:257-291`) and `:507` (text, `saveTextCheckIn` `:484-508`); `reset()` `:415-420`; `lastSavedRecording` `private(set)` `:482`; `.pendingTranscription` park `:272-276`; save block `:260-267`; `retrySave` keeps `.processing`; `startRecording` guard allows `.done` (`:123`).
7. `announce("Captured.")` at `:189` (`:186-192`); `Haptics.success()` `:502`; spring pop `:503-504`; `scaleEffect`/`opacity` `:474-475`; Reduce Motion guard present.
8. `consumeAutoStart()` `:98-106`; `.done` → `reset(); startVoiceCapture()` `:103`.
9. `CrescentRing` only on `captureStage` (`:148-149`); `CrescentRing.swift:30-35` `Circle().stroke(Theme.meadowGreen, lineWidth: 22)`; breathing / rotation `:37-49`; `Metrics.CheckIn.crescentDiameter` 300 (`Metrics.swift:53`).
10. Saved disc 78 / check 32: `Metrics.swift:63-66`; consumed at `:468`, `:471`.
11. Token line refs all correct: `Theme.meadowGreen` `:467, :494` · `NewLook.onSelection` `:472, :492` · `inkPrimary` `:479` · `inkSecondary` `:482` · `Typography.text(24, .bold, .title2)` `:478` · `callout` `:481` · `headline` `:491` · `Spacing.l` `:463, :500` · `Spacing.hero` `:497` · `.newLookCardShadow()` `:469`.
12. `recording` parameter `:457` is passed at `:123` and never read in the body.
13. Subtitle `maxWidth: 240` at `:484`; no `isHeader` trait on "Captured."; SF `checkmark` image `:470` not `accessibilityHidden`.
14. Local-style comment at `:487-488`; `minHeight: 50` `:493`.
15. 7 `.alert`s at `:46-88`; `showMemoryError` / `showModelMissing` at `:79-88`, forwarded from `ProcessingViewModel` (`CheckInViewModel.swift:82-91`; set at `ProcessingViewModel.swift:78, :84` inside the async `run`, i.e. after `.done`).
16. Two `.sheet`s `:34-45`, triggered only from the idle hub `:225-231`.
17. `.processing` spinner in the stop pill `:397-398`; `failureRecovery` `:419-449`.
18. Tests: no `CheckInSavedView` test; `CheckInViewModelTests` lines `:70-71, :84, :93, :102-128, :274-291, :512-524` assert `.done` / `lastSavedRecording`; 32 `@Test` functions.
19. `NewLook.screen` `#EFF2EB` / `#12140F` (`NewLook.swift:13`); `inkPrimary` `#1C1B1F` (`:17`); `inkSecondary` `#8A8A8E` (`:25`); `onSelection` white / dark-ink flip (`:32-35`); `NewLookNavBar` `:116-148`, consumed by `ExtractionReviewView.swift:34` with `cancelPill` `:60-71`.
20. `Theme.meadowGreen` `#5F8A4C` / `#6E9A58` (`Theme.swift:9`); load-bearing as tab/nav tint and `.standard` chip fill (`codebase-designsystem.md` §2 L86; `NewLook.swift:82`).
21. `Typography`: `display` 28 semibold `:21`, `largeTitle` 34 **bold** `.largeTitle` `:23`, `headline` 16 semibold `:34`, `subheadline` 14 medium `.subheadline` `:36`, `body` 16 regular `:38`, `callout` 15 regular `:40`; `UIFontMetrics` scaling `:12-17`. No 34/600 or 16/500 role exists.
22. `Metrics.minTapTarget` 44 (`Metrics.swift:10`); fixed-point doctrine comment `:47-50`.
23. Router: `SquirlApp.swift:72-76` sets `selectedTab = .checkIn; shouldAutoStartRecording = true`.
24. `WelcomeView.swift:52-53` `CrescentRing(breathing: false)` at `crescentSize` 232 (`:23`) — the only other `CrescentRing(` call site in `app-four/`.
25. `Motion.smooth` exists (`Motion.swift:12`).
26. Constitution: I HTML mockup before SwiftUI (L29, L157); III dead code / shims must not exist (L42); IV Complexity Tracking (L51).
27. PRODUCT.md: "one primary action per screen" L45; AA floor ≥ 4.5:1 body / ≥ 3:1 large+UI, 44 pt targets, AX1–AX5, Reduce Motion (L53).
28. Old DESIGN.md (`HEAD:DESIGN.md`): "settles to a check when saved" L79; "No confetti" L81; saved-state screen spec L111.
29. `constraints.md`: Q-C1 Inter vs SF (L283, §4.4 L281); Q-P4 "See You At Next Check-In" (L264); §3.9 2026-07-16 "keep Figma-locked light values 1:1, fix derived dark" (L220, L227).
30. HTML-lite re-tally (other than C2): `#fbfffc` ×2, `#2a9134` ×2, `#212529` ×15, `font-size` 34/14/16, `font-weight` 600 ×1 / 500 ×2, `line-height: 24px`, `padding: 10px 18px`, `border-radius: 999px` / `105.5px` / `21.3px`, `width: 211px` ×3, `96.946px` ×2, `49.716px`, `37.287px`.
31. Frame 3: `Hovered` `#1e6725`, `Focused` `#17501d`, `Disabled` fill `#e5e7eb` (6 variants) with `#9ca3af` label (6) — `pen/ds-html-lite/Frame-3.html`.
32. Contrast recomputed: white/`#2a9134` 4.04 · white/`#26842f` 4.75 · `#17501d`/white 9.54 (on `#fbfffc` 9.45, "within 0.1" holds) · `#1e2225`/white 16.02 · `#1e6725`/white 6.95 — all match Frame 5's cards.
33. Screen-spec numbers reused by the cross-check (211 / 12.97 / 12.66, tile 96.95, check 49.72 × 37.29, gaps 48 / 6, hero y 267 = (874 − 340)/2, CTA 342 × 44 at y 717, 110 below subtitle, 79 above the 840 home-indicator zone, back pill 42.6 at (31, 77), gradient stops and 90° rotation) agree with `out/screens/checkin-saved.md` §2 and the HTML-lite export.

Not verifiable from the repo and left as stated: Apple's Dynamic Type table values (AX5 `.largeTitle` ≈ 60 pt), the effort estimates in §7 (judgement, internally consistent with the delta), and everything marked "assumed from the A/B work" (`ProgressRing`, `NavBackPill`, `FilledButtonStyle` — none exists in code today; `grep` over `app-four/` and `Packages/` returns nothing, as the cross-check's own assumption implies).
