<!-- Created: 2026-09-27 22:25 (WEST) · Updated: 2026-09-27 22:36 (WEST) -->
# Cross-check — "iPhone 17 - 4" Check-In Recording · A · idle hub vs. the shipping SwiftUI — VERIFIED

| | |
|---|---|
| Pen frame | `iPhone 17 - 4` (Figma `72:16335`) — spec `out/screens/checkin-idle.md`; PNG `pen/named/iphone17-4-checkin-recording-a.png` viewed |
| Code read | worktree `feat/057-ui-refresh` @ `08ba8cba` (= `main`, re-verified `git rev-parse`). Files opened: `app-four/Views/CheckIn/CheckInView.swift`, `CrescentRing.swift`, `TextCheckInComposer.swift`, `app-four/ViewModels/CheckInViewModel.swift`, `app-four/Views/RootTabView.swift`, `app-four/DesignSystem/ScreenContainer.swift`, `MedicationBarOverlay.swift`, `app-four/App/SquirlApp.swift`, `app-four/Intents/AppIntentRouter.swift`, `app-four/Views/Components/MedicationBarView.swift`, `MedicationLogSheet.swift`, `app-four/Views/Onboarding/WelcomeView.swift`, `app-four/Models/AppEnums.swift`, `app-four/Utils/Constants.swift`, `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/{Metrics,Buttons,Icons,Typography,NewLook,Theme,Motion,Spacing,Palette,Opacity,Color+Hex,Glyphs/CapsuleGlyph}.swift`, `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift`, `app-four/Store/RecordingStore.swift`, `app-four/ViewModels/MedicationBarViewModel.swift`, `app-four/Views/ExtractionReviewView.swift`, `app-four/Views/Components/CalendarHeaderView.swift`, `app-fourTests/Intents/AppIntentRouterTests.swift`; `gh pr view 45 --json files` |
| Status | Planning only. No Swift changed. All pen numbers are pt at 1x; every code claim carries `file:line`. **Independently verified 2026-09-27 — corrections are marked ⚠ inline and listed in "Verifier notes".** |
| Assumption for §7 | The pen palette tokens, the Filled/Outlined button styles (Frame 3) and the nav "back pill" component (design-system.md §4.5) already exist in `SquirlDesignSystem` when this screen is built. |

---

## 1. Mapping — what implements this surface today

| Pen element | Current implementation | Notes |
|---|---|---|
| The whole screen (idle state) | `app-four/Views/CheckIn/CheckInView.swift` — `content` switches on `viewModel.state` (`:119-133`); every non-`.done` state renders `captureStage` (`:143-193`), a `ZStack` with the ring centred and the header pinned top. Idle pieces: `idleHeader` (`:199-221`), `idleRingCentre` (`:223-233`), `speakButton` (`:235-251`), `hubOption` (`:255-268`). | One view owns A (idle), B (recording/processing) and the save-failure state; only `.done` is a separate `CheckInSavedView` (`:456-507`). |
| Container / chrome | `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` (`CheckInView.swift:26`) → `NavigationStack` + inline empty title + `NewLook.screen` ground (`app-four/DesignSystem/ScreenContainer.swift:49-54`), forced-opaque tab bar (`:59-60`), medication bar as a top `safeAreaInset` (`:82`; `app-four/DesignSystem/MedicationBarOverlay.swift:18-23`). | The hub is **tab root #2 of 4**: `RootTabView.swift:24-26` (`Label("Check in", systemImage: Icons.checkIn)` = `"checkmark.circle"`, `Icons.swift:8`). ⚠ `ScreenContainer` owns its own `NavigationStack` (`ScreenContainer.swift:49`) — see §4 (omission O1). |
| Ring | `app-four/Views/CheckIn/CrescentRing.swift` — a **full circle stroke** in `Theme.meadowGreen` (`#5F8A4C`, `Theme.swift:9`), `lineWidth` 22, butt caps (`:30-35`); idle breathing scale 1↔1.035 / opacity 0.94↔1 over 5 s (`:43-49`); recording spin 7 s (`:37-42`); Reduce Motion gated (`:26, :40, :47`); `accessibilityHidden(true)` (`:15`). Diameter `Metrics.CheckIn.crescentDiameter` = **300** (`Metrics.swift:53`; used `CheckInView.swift:148-149, :195`). | Second consumer: onboarding `WelcomeView.swift:52-53` (`CrescentRing(breathing: false)` at 232 pt, `:23`). |
| State machine | `CheckInViewModel.state: RecordingState` (`CheckInViewModel.swift:9`); enum `idle · recording · paused · processing · done` (`app-four/Models/AppEnums.swift:18-24`). `startRecording()` `:119-188` (Whisper-model intercept `:139-142`, disk guard ⚠ `:145-150`, mic permission ⚠ `:152-157`), `cancelRecording()` `:402-413`, `reset()` `:415-420`. | `.paused` is **never assigned** in `CheckInViewModel` (grep `\.paused` across `app-four`/`app-fourTests` → the only hits are `AudioPlaybackViewModel`'s unrelated `.paused(currentTime:)` and the three `CheckInView` reads) — the "Paused" UI (`CheckInView.swift:150, :297-307`) is unreachable. ⚠ A third read sits in `consumeAutoStart()` (`:102`). `RecordingState` has exactly one consumer (`CheckInViewModel.swift:9`; not persisted), so the enum case itself can go. |
| "Speak Check-In" action | `speakButton` → `startVoiceCapture()` (`CheckInView.swift:110-113`) → `checkInHintSeen = true; viewModel.startRecording()`. | Also triggered by auto-start (`consumeAutoStart()` `:98-106`). |
| "Log Medications" action | `hubOption("Log meds", …)` → `showMedLogSheet = true` (`:225-227`) → `.sheet { MedicationLogSheet … medicationBarViewModel.logManualDose(…) }` (`:34-38`). Sheet: `app-four/Views/Components/MedicationLogSheet.swift` ("Log Dose" `:49`, bespoke **30 × 30** `xmark` nav `:36-64`, frame at `:42`). | Destination has **no pen frame** (screen spec §7). ⚠ Its 30-pt close button is under `Metrics.minTapTarget` today (omission O3). |
| "Write Notes" action | `hubOption("Type note", …)` → `showComposer = true` (`:229-231`) → `.sheet { TextCheckInComposer { draft in … viewModel.saveTextCheckIn(draft) } }` (`:39-45`). Composer: `app-four/Views/CheckIn/TextCheckInComposer.swift` ("Type a check-in" `:48`, three `SignalScaleRow`s `:63-67` + note box `:73-91` + `.checkInPrimary` "Save check-in", ⚠ `:98-120`). | Destination has **no pen frame**. |
| Back pill | **Does not exist.** Tab root; no `dismiss`, no parent. | See §4. |
| Caption under the ring | **Does not exist.** The nearest thing is the one-time first-launch hint *above* the ring (`:212-217`). | |
| Models touched | `AppSettings` (Whisper intercept reads `aiModelService.localPath(for: .whisper)` `:139`, prompt pace `loadPromptInterval()` `CheckInViewModel.swift:422-429`); `MedicationBarViewModel.activeDoses` (`app-four/ViewModels/MedicationBarViewModel.swift:23`) for the bar; `RecordingStore` for saves. | No model change is required by this frame. |

---

## 2. Delta table (top → bottom of the frame)

Legend: **KEEP** already matches · **CHANGE** exists, restyle/rearrange · **NEW** must be built · **REMOVE** exists, absent in the pen.

### 2.1 Ground, status bar, home indicator

| # | Element | Pen | Today | Verdict |
|---|---|---|---|---|
| G1 | Screen ground | `#fbfffc` (off-palette, every screen) | `NewLook.screen` `#EFF2EB` / dark `#12140F` (`NewLook.swift:13`) via `ScreenContainer.swift:53` | **CHANGE** — token swap only (`screen` → pen ground). Dark value must be derived (§5). |
| G2 | Status bar / home indicator | iOS mock, `#212529` | system | **KEEP** (nothing to build). |

### 2.2 Nav header

| # | Element | Pen | Today | Verdict |
|---|---|---|---|---|
| N1 | Back pill | 42.6 × 42.6 at (31, 77), fill `#ffffff`, stroke 1.065 `#e4ece4` inside, r 21.3; icon `vuesax/outline/arrow-left` 20 pt `#1e6725` (renders as a bare chevron), 25 pt below the status bar | none (tab root, inline empty `navigationTitle` `ScreenContainer.swift:51-52`) | **NEW** on this screen (component assumed shared). Must present as ≥ 44 pt hit area (`Metrics.minTapTarget`, `Metrics.swift:10`) — pen is 42.6. Needs a `dismiss`/pop, which only exists if the hub stops being a tab (§4). Closest existing analogue: `ExtractionReviewView.swift` ⚠ `:60-72` `cancelPill` (44-pt circle, `chevron.backward`, `NewLook.checkInGreen` on `NewLook.card`, no stroke) — different colour/stroke. |
| N2 | Title slot / trailing action | empty 128×22 slot, no trailing "…" | none | **KEEP** (empty). Open question 10 in the screen spec. |
| N3 | Tab bar | absent | system `TabView` bar, opaque `NewLook.screen`, tint `Theme.meadowGreen` (`RootTabView.swift:19-36`, `ScreenContainer.swift:59-60`) | **REMOVE from this screen** — see §4; this is a navigation-topology decision, not a restyle. |
| N4 | Medication bar overlay | absent | `MedicationBarView` as a top safe-area inset when `medicationBarVisible && !activeDoses.isEmpty` (`CheckInView.swift:26`; `MedicationBarOverlay.swift:18-23`; `MedicationBarView.swift:8, :12`) — rows "HH:mm · Name dose" (`:96-104`) + state word (`:79-86`) + `DoseTrack` (`:133-174`); tap → "Log new dose / Delete this dose" dialog (`MedicationBarView.swift:20-39`) | **REMOVE (owner decision)** — loses, *on the capture flow*, (a) visibility of an active dose and (b) the one-tap "log new dose / delete dose" management. The Calendar/Day-details frames (iPhone 17 - 1/19) still draw a medication-bar card (design-system.md §4.10), so the function survives elsewhere — but not while the user is inside a full-screen check-in. Screen-spec Open question 6. |

### 2.3 Header block (date · title · subtitle)

| # | Element | Pen | Today | Verdict |
|---|---|---|---|---|
| H1 | Eyebrow date | "Saturday, Sept 11" — Inter **12 / 500**, `#6f7f75`, sentence case, centred, 25 pt below the pill | `Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))` ⚠ → locale-ordered: **"Sun, September 27"** (en_US) / "Sun 27 September" (en_GB) for today, `Typography.label` (12/medium, `Typography.swift:46`), `.textCase(.uppercase)` (`:203`), `NewLook.inkSecondary` `#8A8A8E` (`CheckInView.swift:115-117, :201-204`) | **CHANGE** — format `.weekday(.wide).month(.abbreviated).day()` (en_US → "Sunday, Sep 27"; system style, never the literal "Sept"); drop `.textCase(.uppercase)`; colour → the pen's tertiary green-grey token. Contrast caveat §5. Size/weight already match (12/500 ≈ `label`). |
| H2 | Title | "How Do You Feel?" — Inter **34 / 600**, `#17501d` green-800, single line, centred | "How do you feel?" — `Typography.text(24, weight: .bold, relativeTo: .title2)`, `NewLook.inkPrimary` `#1C1B1F`, `.isHeader` (`:205-209`) | **CHANGE** — 24→34, bold→semibold, ink→green-800, casing (Title Case is a file-wide decision, screen spec §4.1 #2). No existing 34/semibold role: `Typography.largeTitle` is 34/**bold** (`Typography.swift:23`), `display` is 28/semibold (`:21`) → needs the "Page title 34/600" role from design-system.md §2.3 (line 238; assumed provided by the tokens ticket). Keep `.accessibilityAddTraits(.isHeader)` and `.multilineTextAlignment(.center)`. |
| H3 | Subtitle | "Take A Moment To Check In With Yourself" — Inter **16 / 500**, `#1e2225` grey-600, nowrap, exactly 320 pt wide, **always shown** | no permanent subtitle. A **one-time** hint "Say whatever's on your mind — a few words is plenty." in `Typography.callout` (15/regular, `Typography.swift:40`) `inkSecondary.opacity(0.7)`, shown until `@AppStorage("checkInHintSeen")` flips (`:16, :212-217`; set at `:41` and `:111`) | **CHANGE + REMOVE** — replace the one-time whisper with the permanent subtitle (16/500 grey-600). Removing `checkInHintSeen` deletes the US5/FR-018 "first-launch whisper" behaviour (`CheckInView.swift:14-15` doc comment; an owner-approved feature); its *message* survives as the pen's caption (C1). Log as a decision, don't drop silently. |
| H4 | Header geometry | `VStack` gap **10** (date→title group), **6** (title→subtitle); header block 320 wide centred; the whole content column is `SPACE_BETWEEN` and floats CENTER/CENTER in the safe area | `VStack(spacing: Spacing.xs = 4)` (`Spacing.swift:7`), `.padding(.top, Spacing.xl = 20)` (`Spacing.swift:15`), pinned to the *top* of the `ZStack` (`:156-159, :199-221`) while the ring is centred independently (`:147-153`) | **CHANGE** — the pen is one vertical column (header → 65 → ring → ≥35 → caption) centred as a block. Today's ZStack anchoring exists so the ring "grows in place" across idle→recording (`:137-142`); on the pen, screen B keeps the ring at the same 347 pt and swaps the header for a prompt card, so a single centred column with a state-switched header still satisfies the anchoring intent. |

### 2.4 Ring

| # | Element | Pen | Today | Verdict |
|---|---|---|---|---|
| R1 | Geometry | group **347 × 347** at (27.5, 299), i.e. 27.5-pt margins on a 402-pt frame; disc fill `#ebf8ee`; track stroke **21.33** `#bdddc0` (green-100) inside → inner Ø 304.34 | `Circle().stroke(Theme.meadowGreen, lineWidth: 22)` inset by 11 (`.padding(lineWidth / 2)`, `CrescentRing.swift:30-35`), **300 pt**, no inner disc fill, no track colour distinct from the arc | **NEW component** ("CheckInRing": disc + track + arc + shadow, states `idle / listening(progress) / saved`) replacing `CrescentRing`. Diameter must be `min(width − 2·gutter, 347)` — 347 + 55 = 402 fits only the iPhone 17 class; a 375-pt device gets 14-pt gutters. |
| R2 | Progress arc | `Ellipse 8` over the track, thickness **20.82**, **butt** ends, vertical linear gradient `#26842f` 0 % → `#3fbb4b` 50 % → `#25832e` 100 %; sweep **0° (3 o'clock) → 118.8° clockwise (≈ 33 %)** on idle; ≈ ⅝ on B; full on C | none — the stroke is uniform; "crescent" is a legacy name (`CrescentRing.swift:3-5`) | **NEW** — `Circle().trim(from:to:)` + `.rotationEffect(-90°)` (or 0° since the pen starts at 3 o'clock) with a `LinearGradient` fill; `progress: Double` input. The idle value has **no data source** (§3, Open question 2). `#3fbb4b` and `#25832e` are off-palette (screen spec §2.5). |
| R3 | Shadow | drop shadow `#000000` @ 8 %, offset (0, 2), blur 18 | none on the ring | **NEW** (one modifier); the app's card shadow is `.black.opacity(0.05) r8 y2` + `0.03 r2 y1` (`NewLook.swift:62-66`) — a different value; token it as "ring shadow" or reuse the card shadow (design-system.md §3.3 recommends one shadow token). |
| R4 | Motion | nothing specified (static frame) | idle breathing 5 s (scale 1→1.035, opacity 0.94→1), recording rotation 7 s, both Reduce-Motion gated (`CrescentRing.swift:37-49`) | **CHANGE (decision)** — either carry the old DESIGN.md §Motion rules ("breathes slowly when idle … revolves while listening") or ship static. Screen spec Open question 11. If kept, the gates at `:26/:40/:47` are the pattern to keep. |
| R5 | Accessibility | — | `accessibilityHidden(true)` (`CrescentRing.swift:15`; `CheckInView.swift:151`) | **KEEP** while decorative; if the arc gets a meaning (Q2) it needs an `accessibilityValue`. |
| R6 | Onboarding consumer | not in the pen export (no Welcome frame) | `WelcomeView.swift:52-53` renders `CrescentRing(breathing: false)` at 232 pt (`:23`); Welcome is a `fullScreenCover` from `RootContainerView` (`SquirlApp.swift:108-110`) | **CHANGE (collateral)** — migrate Welcome to the new ring (or a `progress: 0` variant) so `CrescentRing.swift` can be deleted (no dead code, Principle III). |

### 2.5 Button stack (inside the disc)

| # | Element | Pen | Today | Verdict |
|---|---|---|---|---|
| B0 | Stack | 342 × 152 frame (**clipsContent**), vertical gap **8**, centred in the ring; order **Speak → Log Medications → Write Notes** | `VStack(spacing: Spacing.s = 8)` (`Spacing.swift:9`), order **Log meds → Speak → Type note** (`CheckInView.swift:223-233`) | **CHANGE** — reorder (primary first). Do **not** reproduce `clipsContent` (it would clip at large Dynamic Type; §5). Gap already matches. |
| B1 | Speak Check-In | Filled · Medium · With Icon: fill `#2a9134` green-500, r 999, padding 10 / 18, label "Speak Check-In" Inter 16/500 lh 24 `#ffffff`, icon `vuesax/bold/microphone-2` **21** pt white, gap **3**, **fixed width 182**, height 44, no shadow | `HStack(spacing: Spacing.s = 8) { Image("mic.fill"); Text("Speak check-in").font(Typography.headline) }` — 16/**semibold** (`Typography.swift:34`), `NewLook.onSelection` (`#FFFFFF`, `NewLook.swift:35`) on `Theme.meadowGreen #5F8A4C` capsule, `.padding(.horizontal, Spacing.xl = 20)`, `minHeight: 48`, `.newLookCardShadow()`, a11y "Start voice check-in" (`:235-251`) | **CHANGE** — adopt the shared Filled/Medium style (component values: gap 8, icon 16–18, hug width — the frame's gap 3 / icon 21 / fixed 182 are detached-instance drift, screen spec §3); height 48 → 44; drop the shadow; weight semibold → medium; fill meadow → green-500 (contrast 4.04:1 — ⚠ today's meadow is **4.02:1**, the same failure; §5); icon SF `mic.fill` → vuesax bold `microphone-2` asset (NEW asset); copy casing. Keep the a11y label. |
| B2 | Log Medications | Outlined · Medium · With Icon: fill `#ffffff`, stroke 1 `#cbd5e1`, r 999, padding 10 / 18, gap 8, icon `svgexport-20 (6) 1` (imported capsule SVG, diagonal ≈45°, two-tone via path) **18** pt `#8c68d3` violet-500, label "Log Medications" 16/500 `#634a96` **violet-700**, 191 × 46 | `hubOption("Log meds", icon: Icons.medication /* "pills.fill", Icons.swift:13 */, tint: Palette.medication /* #7E5CA8, Palette.swift:12 */)` — `NewLook.card` capsule, **no stroke**, card shadow, label `Typography.headline` `inkPrimary`, `minHeight: Metrics.minTapTarget` (44), padding h `Spacing.xl` 20 (`:225-227, :255-268`) | **CHANGE** — style → shared Outlined/Medium (adds the 1-pt hairline, drops the shadow); label ink → violet-700 (a tint variant the Buttons component does **not** define — screen spec Open question 4); icon: SF `pills.fill` → capsule asset. The existing `CapsuleGlyph` (`Glyphs/CapsuleGlyph.swift:5-23`) is a **horizontal** two-tone capsule (`capW = 0.86·w`, `capH = 0.42·h`, `:10-11`) in `Palette.medication` — the pen's is diagonal with a hollow half; either restyle `CapsuleGlyph` or import the SVG as a template image (NEW asset either way). Copy "Log meds" → "Log Medications". |
| B3 | Write Notes | Outlined · Medium · With Icon: same box as B2; icon `vuesax/bold/edit-2` 18 pt `#2a9134`; label "Write Notes" 16/500 `#26842f` green-600; 155 × 46 | `hubOption("Type note", icon: "square.and.pencil", tint: nil → inkPrimary)` (`:229-231`, `:258`) | **CHANGE** — style → Outlined/Medium; icon SF → vuesax bold `edit-2` (NEW asset); label ink → green-600; copy "Type note" → "Write Notes" (plural — screen spec §4.1 #6). |
| B4 | Button heights | 44 (filled) / 46 (outlined incl. the outside stroke) → treat all as 44 | 48 / 44 / 44 (`:245`, `:262`) | **CHANGE** (speak only). |
| B5 | Pressed / disabled states | Frame 3: Filled hovered `#1e6725`, focused `#17501d`, disabled `#e5e7eb`/`#9ca3af`; Outlined hovered bg `#f8fafc` + stroke `#2a9134`, disabled bg `#f8fafc` stroke `#e2e8f0` text `#94a3b8` | `.buttonStyle(.plain)` with no pressed feedback on the hub pills (`:249, :266`); the package styles fade to 0.9 / 0.9 / 0.85 on press (`Buttons.swift:14, :34, :51`) | **CHANGE** — comes free with the shared styles; map Hovered → pressed. No disabled state is needed on the hub. |

### 2.6 Caption

| # | Element | Pen | Today | Verdict |
|---|---|---|---|---|
| C1 | "A few Words Is Enough" | Inter **14 / 500**, `#6f7f75`, centred, **67 pt** below the ring (space-between remainder; minimum 35) | none below the ring; the same message exists as the one-time hint above the ring (H3) | **NEW** (one `Text`). Fix the copy ("A Few Words Are Enough" / sentence case per Open question 8); do not ship the pen string verbatim (constraints §4.3 Q-V3 rule). Contrast §5. |

### 2.7 Things that exist today with no counterpart in the frame

| # | Element | Today | Verdict |
|---|---|---|---|
| X1 | Alerts ×7 (mic permission, storage, Whisper download prompt, model storage, download failed, memory, insights model missing) | `CheckInView.swift:46-88` | **KEEP** — system alerts, not a design surface. Carry the known copy bug "approx. 40MB" (`:67`) vs ⚠ "~150 MB" at `ModelDownloadRow.swift:82` and `DownloadPermissionView.swift:82` into the copy ticket. |
| X2 | `.paused` dim + "Paused" label + auto-start guard | ⚠ `:102`, `:150`, `:297-307`; enum case `RecordingState.paused` `AppEnums.swift:21` | **REMOVE** — unreachable (§1); Principle III (no dead code). ⚠ Three view sites, not two, plus the enum case (sole consumer `CheckInViewModel.swift:9`, never persisted) — deleting the case forces the `consumeAutoStart` switch (`:101-105`) and the a11y label (`:297-299`) to change. |
| X3 | Recording-stage chrome (prompt card, timer, Stop & save, Cancel, "Wrapping up soon", failure recovery) | `:273-449` | **KEEP for screen B** — out of this frame's scope, but it shares `captureStage`; the pen's B keeps the same "ring stays, content swaps" idea (prompt card above, timer inside). |
| X4 | Auto-start from App Intent / deep link | `shouldAutoStart` binding `:8`, `.onAppear`/`.onChange` `:32-33`, `consumeAutoStart()` `:98-106`; armed by `SquirlApp.swift:72-76` (deep link `whispernotes://checkin` `:68-71`) | **KEEP the function; CHANGE the mechanism** if the hub is no longer a tab (§4). |
| X5 | Screen tracking `.trackScreen("CheckInView")` | `:31` | **KEEP**. |
| X6 | State animation `.animation(reduceMotion ? nil : Motion.smooth, value: viewModel.state)` | `:29` (`Motion.smooth` = `.smooth(duration: 0.4)`, `Motion.swift:10-12`) | **KEEP**. |
| X7 | Hand-rolled `speakButton` / `hubOption` capsules | `:235-268` | **REMOVE** once the shared styles carry them (B1–B3). |
| X8 | `Metrics.CheckIn.crescentDiameter` (300), `Metrics.CheckIn.savedDisc/savedCheck` | `Metrics.swift:53, :64-66` | **CHANGE** — diameter becomes a max (347) with a width-relative rule; saved-state values belong to screen C (pen: 211-pt ring, 96.95 square). |
| X9 | Items from the task's checklist that are **not on this screen**: audio player, regenerate summary, transcript, medication inline-expand, sleep custom hours, DoseGuard, export, feedback button, stickers/Siri, model-download rows | — | Not applicable to A; the Whisper **download prompt** (X1) is the only model-download touchpoint here and it stays. |

### 2.8 Token/asset inventory this screen needs (none exist in code today)

| Pen value | Role on this screen | Nearest code value today | Gap |
|---|---|---|---|
| `#fbfffc` | ground | `NewLook.screen #EFF2EB` | new token |
| `#ebf8ee` | ring disc | — | new token (off-palette; green-50 is `#eaf4eb`) |
| `#bdddc0` green-100 | ring track | `NewLook.checkInGreenSoft #96C19F` (`NewLook.swift:44`) — ⚠ **not** a ring end-stop in code and **not unused**: it is the second stop of `CheckInPrimaryButtonStyle`'s gradient (`Buttons.swift:29`), consumed by `.checkInPrimary` at `TextCheckInComposer.swift:108`, `WelcomeView.swift:82`, `SiriOnboardingView.swift:42`, `DownloadPermissionView.swift:84`, `LLMDownloadView.swift:75`. No ring uses it (`CrescentRing` is a uniform `meadowGreen` stroke). | new token |
| `#26842f` / `#3fbb4b` / `#25832e` | arc gradient | `Theme.meadowGreen #5F8A4C` | new tokens (`#3fbb4b`, `#25832e` off-palette) |
| `#2a9134` green-500 | primary fill, pencil icon | `Theme.meadowGreen #5F8A4C`, `NewLook.checkInGreen #5FB36E` (`NewLook.swift:41`) | new token; retires two greens on this screen |
| `#26842f` green-600 | "Write Notes" label | — | new token |
| `#1e6725` green-700 | back chevron | — | new token |
| `#17501d` green-800 | title | `NewLook.inkPrimary #1C1B1F` | new token |
| `#1e2225` grey-600 | subtitle | `NewLook.inkPrimary #1C1B1F` | new token (or map to inkPrimary — 1-unit difference, decision) |
| `#6f7f75` | date, caption | `NewLook.inkSecondary #8A8A8E` | new token (off-palette; contrast §5) |
| `#cbd5e1` | outlined-button stroke | `NewLook.hairline #DBDDDE` (`NewLook.swift:27`) | new token (Tailwind slate-300) — or snap to one hairline |
| `#e4ece4` | back-pill stroke | `NewLook.hairline #DBDDDE` | new token — two hairlines on one screen (screen spec §2.5) |
| `#8c68d3` violet-500 / `#634a96` violet-700 | capsule icon / label | `Palette.medication #7E5CA8` | new tokens |
| Icons `microphone-2` (bold), `edit-2` (bold), `arrow-left` (outline), capsule SVG | button + pill glyphs | SF `mic.fill`, `square.and.pencil`, `chevron.backward`, `pills.fill` / `CapsuleGlyph` | 4 new template assets (vuesax is not bundled today — `app-four/Assets.xcassets` holds only `AccentColor`, `AppIcon`, `AppIcon-Stable`; `Icons.swift` holds SF names only; no `UIAppFonts`) |

---

## 3. Data availability

| Pen field / label | Exists? | Where / what is missing |
|---|---|---|
| Today's date ("Saturday, Sept 11") | **Yes** | `Date.now` formatted at `CheckInView.swift:115-117`; change the `FormatStyle` (§2.3 H1). |
| Title / subtitle / caption / three button labels | **Yes** (static copy) | literals in `CheckInView.swift:205, :213, :241, :225, :229`; copy changes only. |
| Recording state (idle vs B vs C) | **Yes** | `CheckInViewModel.state` (`:9`), `RecordingState` (`AppEnums.swift:18-24`). |
| Ring progress on **idle** (≈ 0.33) | **NO** | `CrescentRing` has no progress input (`CrescentRing.swift:8-10`: `isActive`, `lineWidth`, `breathing`). No idle datum maps to 33 %. If the owner picks: (a) *decorative* → a constant, nothing to build; (b) *recording-time budget* → idle 0, B `elapsedTime / maxDuration` (`CheckInViewModel.swift:10-11`, `maxDuration = 480` s `Constants.swift:10`) or the per-prompt `promptProgress` (`:458-460`), C = 1; (c) *today's 3 steps (spoke / logged meds / wrote a note)* → **not computed anywhere**: would need a derived "today" summary from `RecordingStore.recordings` (`Store/RecordingStore.swift:47-59`; text check-ins carry `audioFileName` prefix `"text-"`, `:143`) plus `MedicationEvent`s for today (`MedicationBarViewModel` only exposes *active* doses, `:23, :59-109`) — a new, test-first view-model property (Principle X). |
| Back destination | **NO** | Tab root; there is no `dismiss`/pop path. Exists only after the §4 change. |
| Medication on board (pen: not shown) | Yes | `MedicationBarViewModel.activeDoses` (`:23`); rendered today by the overlay (N4). |
| Mic permission / Whisper gate / disk guard (implied by "Speak") | Yes | `CheckInViewModel.startRecording()` `:139-157`; alerts `CheckInView.swift:46-78`. |
| "Log Medications" target data (catalog, doses) | Yes | `MedicationLogSheet` + `MedicationPickerViewModel` (`MedicationLogSheet.swift:6`; map: journal §5.2). |
| "Write Notes" target data (`CheckInDraft`) | Yes | `TextCheckInComposer` → `viewModel.saveTextCheckIn(draft)` (`CheckInViewModel.swift:484-508`). |
| Fields from the task checklist — "Kicking In"/"Active", "8h Sleep", "Locked In", month selector, "24 check-ins", weekday dominant level, connection thresholds, "Installed", "34MB" | n/a | **None appear on this frame.** (For the record: "Kicking In"/"Active" exist as `kicking in`/`active` in `MedicationBarView.swift:79-86`; "Locked In" is `FocusLevel.displayLabel` (`Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift:119`); the rest belong to the Insights/Settings cross-checks.) |

---

## 4. Navigation delta

| Aspect | Today | Pen (as drawn) | Delta |
|---|---|---|---|
| Topology | Tab root #2 in a native `TabView(selection:)` (`RootTabView.swift:19-35`), tab "Check in" with SF `checkmark.circle`, tint `Theme.meadowGreen` (`:36`); tab bar forced opaque `NewLook.screen` from inside every tab root (`ScreenContainer.swift:57-60`). | **Full-screen pushed/covered flow**: back pill, **no tab bar, no FAB**, empty title slot. Frame 4 still defines a `Status=Check In` tab variant and Frame 15 defines a violet `+` FAB on Calendar/Insights/Settings — the pen does not say which one opens this hub (screen spec Open question 1). | Undecided topology. Three readings: (a) Check In tab shows the hub *with* the pill bar and *no* back pill (deviates from the frame); (b) tab and FAB both present the hub full-screen (`fullScreenCover` or a push on the presenting tab's `NavigationStack`); (c) the tab is dropped and the FAB is the only entry. ⚠ **O1:** `ScreenContainer` creates its own `NavigationStack` (`ScreenContainer.swift:49`). A *push* onto another tab's stack therefore cannot reuse `ScreenContainer` (nested `NavigationStack`s are unsupported); a `fullScreenCover` can. Reading (b)-push means the hub leaves `ScreenContainer` entirely — an extra refactor the §7 estimate must include. |
| Tab bar style | native, system icons, labels on every tab | Frame 4 custom pill bar 346 × 60 white r 75, shadow `0 8 24 #183c28@0.16`, active pill `#2a9134` r 44 icon + 12/500 label, inactive icons `#999b9d`; compact 274 × 60 + 50-pt FAB variant | Not this screen's delta (the bar is absent here) but the hub's *absence* of the bar presupposes the bar is custom or hidden via `.toolbar(.hidden, for: .tabBar)` on a pushed route. A hand-rolled bar replaces `TabView` and must re-implement tab a11y semantics — separate ticket. |
| Back gesture | n/a | pill only; swipe-back works only if pushed in a `NavigationStack` | If `fullScreenCover`: the pill is the sole exit (screen spec §7). |
| App Intent / deep link → listening | `router.requestCheckIn()` sets `selectedTab = .checkIn; shouldStartCheckIn = true` (`AppIntentRouter.swift:41-46`); `SquirlApp.swift:72-76` switches the tab and arms `shouldAutoStartRecording`; `CheckInView.consumeAutoStart()` starts capture (`:98-106`). Tests pin `router.selectedTab == .checkIn` (`app-fourTests/Intents/AppIntentRouterTests.swift:15, :56`). | Not drawn. | If (b)/(c): `Tab.checkIn` goes away or stops being the landing target; the router must arm a "present check-in and auto-start" flag consumed by `RootContainerView` (`SquirlApp.swift:90-224`), and the two router tests change. Siri phrase "Hey Siri, check in on Squirl" (onboarding copy) must still land on **B · listening**. |
| Sheets from the hub | `.sheet` `MedicationLogSheet` (`CheckInView.swift:34-38`), `.sheet` `TextCheckInComposer` (`:39-45`) | no frames | **KEEP** as sheets over the hub; their restyle is their own ticket (screen spec Open question 7). ⚠ **O3:** `MedicationLogSheet`'s close button is a fixed 30 × 30 (`MedicationLogSheet.swift:42`) — below `Metrics.minTapTarget`; `TextCheckInComposer`'s is 44 (`:40`). A live a11y defect on a hub destination; carry it into Q9's ticket. |
| FAB | none | not on this screen | n/a here; but if the FAB opens *this* hub, "one primary action per screen" (PRODUCT.md) is satisfied only if the tab and the FAB don't both exist (constraints §4.5 Q-L1). |
| Medication bar | top safe-area inset on every tab root incl. this one | absent | see N4. |

---

## 5. Accessibility · Dynamic Type · dark mode (this screen)

**Touch targets**
- Back pill 42.6 pt < 44 (PRODUCT.md floor; `Metrics.minTapTarget` `Metrics.swift:10`). Render the visual at 42.6 inside a 44-pt hit area, or size it 44.
- Buttons 44 pt ✓ (today `speakButton` is 48, `hubOption` 44 — `CheckInView.swift:245, :262`).

**Contrast (light; WCAG relative-luminance formula, re-computed)**
- `#6f7f75` on `#fbfffc` = **4.19 : 1** — fails AA at 12 pt (date) and 14 pt (caption). Today's `inkSecondary #8A8A8E` is *worse* (3.04 on `screen` / 3.44 on `card`, owner-locked `NewLook.swift:22-24`), so the pen improves but still fails. Options: grey-300 `#6a6d70` (5.21 : 1 on white) or grey-400 `#4d5154` (8.01 : 1).
- White on green-500 `#2a9134` = **4.04 : 1** — AA for large text only; the 16/500 "Speak Check-In" label is not large. ⚠ **This is not a regression:** today's `speakButton` is white on `Theme.meadowGreen #5F8A4C` = **4.02 : 1** — the same failure, un-excepted. Either fill primaries with green-600 `#26842f` (4.75 : 1) or record an exception (a *new* exception on top of the 2026-07-12 `inkSecondary` ruling).
- `#634a96` violet-700 on white 7.12 : 1 ✓; `#26842f` on white 4.75 : 1 ✓; `#17501d` on `#fbfffc` 9.45 : 1 ✓; `#1e2225` on `#fbfffc` 15.9 : 1 ✓. ⚠ Added: `#8c68d3` violet-500 capsule icon on white = 4.17 : 1 — passes the 3 : 1 non-text floor.
- Note: the pen's *stroke-only* outlined buttons rely on a 1-pt `#cbd5e1` hairline (**1.48 : 1** vs white, 1.47 vs `#fbfffc`) — under the 3 : 1 UI-component floor; the label carries the affordance, so acceptable, but Increase Contrast should thicken/darken it. ⚠ Added: the back pill's `#e4ece4` stroke is **1.21 : 1** on white and **1.19 : 1** on the `#fbfffc` ground — the pill is effectively borderless; only the chevron (9.45 : 1) carries the affordance.

**Dynamic Type**
- Today every text role scales through `UIFontMetrics` (`Typography.swift:12-17`) and the title wraps (`multilineTextAlignment(.center)`, `CheckInView.swift:208`). The pen's text layers are all `nowrap`; the subtitle already spans the full 320 pt at 16 pt.
- The button stack sits inside a **fixed** disc (inner Ø 304) and, in the pen, a **clipping** 342-pt frame. Today the pills hug their content with 20-pt side padding inside a 300-pt ring — the same overflow exists today at AX sizes; the pen makes it worse (191-pt "Log Medications" at 16 pt already).
- Rule the plan must state: at `dynamicTypeSize >= .accessibility1` (precedent: `CalendarHeaderView.swift:20` `forceWeek`), move the three buttons **below** the ring (or replace the ring with a compact 120-pt disc), let title/subtitle wrap, never clip. `lineLimit(1)` + `minimumScaleFactor` on button labels is a corner-cut, not a solution.
- Ring diameter must be width-relative (`min(width − 55, 347)`) — 402-pt frames only.

**VoiceOver**
- Keep: header trait on the title (`:209`), "Start voice check-in" (`:250`), hub labels (`:267`), ring hidden (`:151`). Add: back pill "Back" (label + `.isButton`), caption as plain text. If the arc becomes meaningful (Q2) give the ring an `accessibilityValue` and drop `accessibilityHidden`.
- The "Saving…" / "Captured." announcements (`:186-192`) are B/C-state behaviour; untouched.

**Reduce Motion**
- Pen: static. If breathing/rotation are kept (Open question 11) the existing gates (`CrescentRing.swift:26, :40, :47`; `CheckInView.swift:29`) are the pattern; the old rule "breathing collapses to a static glow" needs a pen-language equivalent (there is no glow in the pen).

**Dark mode**
- Not designed (constraints §4.4 Q-C10). Every colour on this screen is new and needs a derived dark pair, in code as `Color(lightHex:darkHex:)` (`Color+Hex.swift:7-11`, the pattern all `NewLook` tokens use): ground `#fbfffc`, disc `#ebf8ee`, track `#bdddc0`, arc stops, white button fills, two hairlines, `#6f7f75`, and **green-800 `#17501d` for the title** — near-invisible on a dark ground; the dark pair must climb to ≈ green-200/300. Precedent for "Figma light only, dark derived": spec 033 (constraints §3.9, 2026-07-16 row).

**Typeface**
- Pen is Inter throughout; the app is native SF (spec 023; `Typography.swift:4-8`). Map 34/600 · 16/500 · 14/500 · 12/500 to SF at the same size/weight — no `UIAppFonts`. Owner decision Q-C1 applies file-wide, not here.

---

## 6. Risks and open questions

### Risks
1. **Navigation topology is the load-bearing unknown.** Tab vs pushed changes `RootTabView`, `AppIntentRouter` (⚠ `:23, :43`), `SquirlApp.swift:72-76`, two router tests, and how Siri/deep links land on B. Every other line in this file is a restyle; this one is architecture. Do not start the screen until Open question 1 is answered. ⚠ A push (not a cover) also forces the hub off `ScreenContainer` (§4 O1).
2. **`CrescentRing` has two consumers.** Replacing it for the hub also changes onboarding Welcome (`WelcomeView.swift:52`); the Welcome frame is not in the pen export.
3. **Fixed 347-pt ring.** Fits the 402-pt artboard only; ≤ 375-pt devices and AX text sizes overflow/clip unless the plan writes the width-relative + AX-breakpoint rules (§5).
4. ⚠ **AA failures carried over, not introduced** (`#2a9134` fill 4.04 : 1 vs today's 4.02 : 1; `#6f7f75` text 4.19 : 1 vs today's 3.04 : 1). They still contradict PRODUCT.md's "AA as a hard floor" unless explicitly excepted — and this screen is the app's front door. The refresh is the moment to fix them, not to re-inherit them.
5. **Token sprawl.** Seven off-palette values on one screen (`#fbfffc`, `#ebf8ee`, `#3fbb4b`, `#25832e`, `#6f7f75`, `#cbd5e1`, `#e4ece4`) → Complexity Tracking row (constitution IV) or snap to the ramp.
6. **Silent feature loss.** Medication bar (N4) and the first-launch hint (H3) are owner-approved behaviours that the frame simply omits; both need a dated decision, not an implicit drop.
7. **Detached-instance drift.** The frame's "Speak Check-In" (gap 3, icon 21, fixed 182) contradicts the Buttons component (gap 8, icon 16–18, hug). Build the component, not the frame, or the B screen's instances won't match A.
8. **Pen copy defects** ("A few Words Is Enough", "Sept", Title-Case sentences) must be normalised, not transcribed (constraints Q-V3).
9. ⚠ **Merge conflicts.** Open PR #45 (`fix/audit-high-medium`) does **not** touch `CheckInViewModel.swift` (`gh pr view 45 --json files`, 34 files; `constraints.md:330` is wrong on this). It *does* touch the hub's save path — `app-four/Store/RecordingStore.swift` (`persistCheckInNote`/`addRecording`), `Services/Audio/AudioRecordingServiceImpl.swift`, `Services/Audio/AudioFileStorageServiceImpl.swift` — and **`DESIGN.md`, which is deleted on this worktree** (`git status`: `D DESIGN.md`): a guaranteed delete/modify conflict the moment #45 lands. 055 (constitution 3.0.0, Swift skills) must land first (constraints §5.2). This is post-Shipaton work regardless (release train passed, constraints §2.1).
10. **`inkSecondary` precedent.** Adopting `#6f7f75` here while ⚠ **106** other references (grep, excluding `NewLook.swift`; 10 of them in `CheckInView.swift`) keep `#8A8A8E` creates a third secondary grey app-wide unless the tokens ticket retires `inkSecondary`.

### Open questions for the owner (only the ones that block this screen)
1. **Tab or pushed?** (a) Check In tab keeps the hub with the tab bar and no back pill; (b) tab + FAB both present it full-screen — and if (b), **cover or push?** (push = hub leaves `ScreenContainer`); (c) tab dropped, FAB only. Also: what does the `+` FAB open — this hub, Log Dose, or a menu?
2. **What does the idle arc (≈ 33 %) mean** — decorative constant, recording-time budget (then idle = 0 %), or "today's 3 steps"? Only (c) needs new data.
3. **Medication bar on the hub** — deliberately removed, or not drawn yet? If removed, is dose management while inside the check-in flow acceptable to lose?
4. **First-launch hint** — retire `checkInHintSeen` (US5 / FR-018) in favour of the permanent caption?
5. **Contrast** — accept 4.04 : 1 white-on-green-500 buttons (today: 4.02 : 1) and 4.19 : 1 `#6f7f75` text, or shift to green-600 / grey-300?
6. **Violet outlined button** — sanction `Tint = Medication` on the Outlined style (label violet-700, icon violet-500), or keep "Log Medications" green like "Write Notes"?
7. **Motion** — carry the idle breathing (5 s) and listening rotation (7 s), or ship the ring static as drawn?
8. **Copy** — Title Case file-wide? "A Few Words Are Enough"? "Check-In" vs the tab's "Check In"? "Write Notes" vs "Write a Note"?
9. **Log Medications / Write Notes destinations** — reuse `MedicationLogSheet` and `TextCheckInComposer` restyled in their own tickets (no frames exist), or are frames coming? (Fold the 30-pt close-button fix, O3, into that ticket.)
10. **Dark mode** — derive per token with device QA sign-off (spec-033 precedent), or light-only for 1.x?

---

## 7. Effort (senior SwiftUI engineer; tokens, button styles and the back-pill component already exist)

| Bucket | Item | Hours |
|---|---|---|
| **NEW** | `CheckInRing` component: disc + track + gradient `trim` arc + shadow, `progress`, `idle/listening/saved` variants, Reduce-Motion gate, `#Preview`; migrate `WelcomeView` | 5.0 |
| NEW | Full-screen presentation + back pill placement + router rewiring (`requestCheckIn` → present + auto-start), update `AppIntentRouterTests` ×2, remove/retain `Tab.checkIn` — **only if Q1 = pushed** (1.0 if it stays a tab). ⚠ Add ≈ 1.0 if Q1 = *push* rather than *cover* (hub leaves `ScreenContainer`, O1). | 4.0 (+1.0) |
| NEW | Icon assets: `microphone-2` bold, `edit-2` bold, `arrow-left` outline, capsule SVG → template images at 18/20/21 pt | 1.5 |
| NEW | Caption text + Outlined-style `tint` variant (violet) | 1.0 |
| | **NEW subtotal** | **11.5** (12.5 if push) |
| **CHANGE** | Header: date `FormatStyle`, 34/600 green-800 title, permanent subtitle, gaps 10/6 | 1.0 |
| CHANGE | Button stack: reorder, shared Filled/Outlined styles, 44 pt, no shadow, copy, a11y labels | 1.5 |
| CHANGE | Layout: single centred column (header → 65 → ring → caption), 30-pt gutters, width-relative ring | 1.5 |
| CHANGE | Dynamic Type strategy (AX breakpoint moves the stack out of the disc; wrap rules) | 2.0 |
| CHANGE | Dark-mode pairs for the ~10 screen tokens (documented, device-checked) | 1.0 |
| CHANGE | Build + simulator run (Principle II) + on-device QA notes for this screen | 1.0 |
| | **CHANGE subtotal** | **8.0** |
| **REMOVE** | `checkInHintSeen` (4 references: `:16, :41, :111, :212`), `.paused` UI (⚠ 3 view sites `:102, :150, :297-307` + `RecordingState.paused` enum case `AppEnums.swift:21`), medication-bar flag on this screen, hand-rolled `speakButton`/`hubOption`, `Metrics.CheckIn.crescentDiameter` | 1.0 |
| REMOVE | Delete `CrescentRing.swift` after the Welcome migration | 0.5 |
| | **REMOVE subtotal** | **1.5** |
| | **Total** | **≈ 21 h** (22 h if Q1 = push; 18 h if the hub stays a tab; +2 h for the mandatory HTML mockup, Principle I, not counted above) |

---

## Verifier notes (2026-09-27, independent pass)

Method: every `file:line` claim was opened in the worktree at `08ba8cba`; contrast ratios were recomputed with the WCAG relative-luminance formula; the date format was executed with `swift` for en_US/en_GB/en_AU; PR #45's file list was pulled with `gh pr view 45 --json files`; the PNG was compared against §2 for missed elements. **No Swift was changed.**

### Corrections (claim → correction → evidence)

| # | Original claim | Correction | Evidence |
|---|---|---|---|
| C1 | §1 State machine: `startRecording()` "mic permission `:150-154`" | Disk guard is `:145-150`; mic permission is `:152-157`. | `CheckInViewModel.swift:145-157` |
| C2 | §2.3 H1: current format "→ 'Sat 27 September'" | Wrong weekday and locale-bound order. 27 Sep 2026 is a **Sunday**; `.dateTime.weekday(.abbreviated).day().month(.wide)` renders **"Sun, September 27"** in en_US and "Sun 27 September" in en_GB. The proposed `.weekday(.wide).month(.abbreviated).day()` renders "Sunday, Sep 27" (en_US). | `CheckInView.swift:116`; `swift` run of both `FormatStyle`s under `Locale("en_US"/"en_GB")` |
| C3 | §2.8: `NewLook.checkInGreenSoft #96C19F` "(ring end-stop, unused in app)" | It is **used**: second stop of `CheckInPrimaryButtonStyle`'s gradient, consumed by five `.checkInPrimary` call sites. No ring uses it — `CrescentRing` is a uniform `meadowGreen` stroke. | `Buttons.swift:29`; `TextCheckInComposer.swift:108`, `WelcomeView.swift:82`, `SiriOnboardingView.swift:42`, `DownloadPermissionView.swift:84`, `LLMDownloadView.swift:75`; `CrescentRing.swift:30-35` |
| C4 | §6 Risk 9: "`CheckInViewModel.swift` is touched by open PR #45" | **Refuted.** PR #45 (`fix/audit-high-medium`, 34 files) does not include `CheckInViewModel.swift`. It touches `RecordingStore.swift`, `AudioRecordingServiceImpl.swift`, `AudioFileStorageServiceImpl.swift`, `RecordingDetailViewModel.swift`, `FoldedDayCardHeader.swift`, `TimelineRow.swift`, tests, docs — and `DESIGN.md`. `constraints.md:330` carries the same error. | `gh pr view 45 --json files`; `constraints.md:330` |
| C5 | §6 Risk 4 / §5: "AA **regressions** on new tokens" | Not regressions. Today's `speakButton` (white on `#5F8A4C`) is **4.02 : 1** — the pen's 4.04 : 1 is the same failure; `#6f7f75` (4.19) *improves* on `inkSecondary` (3.04). Reworded as carried-over failures. | `CheckInView.swift:243-246`; `Theme.swift:9`; recomputed ratios |
| C6 | §7 REMOVE: "`.paused` UI (2 sites)" | Three view sites (`:102` in `consumeAutoStart`, `:150`, `:297-307`) plus the enum case `RecordingState.paused`; `RecordingState` has one consumer and is never persisted, so the case can be deleted, which forces the `:101-105` switch and the `:297-299` a11y label to change. | `CheckInView.swift:102, :150, :297-307`; `AppEnums.swift:21`; grep `RecordingState` → only `CheckInViewModel.swift:9` |
| C7 | §6 Risk 10: "105 other call sites keep `#8A8A8E`" | 106 references outside `NewLook.swift` (10 in `CheckInView.swift`). Immaterial to the argument; corrected for exactness. | `grep -rn inkSecondary app-four Packages` |
| C8 | §2.2 N1: analogue "`ExtractionReviewView.swift:60-84` `cancelPill`" | `cancelPill` is `:60-72`; `:74-84` is `savePill`. Colour is `NewLook.checkInGreen` on `NewLook.card`, no stroke. | `ExtractionReviewView.swift:60-84` |
| C9 | §1 "Write Notes": composer save `:95-120` | `saveButton` is `:98-120` (`:96` is the MARK). | `TextCheckInComposer.swift:96-120` |
| C10 | §6 Risk 1: "`AppIntentRouter` (`:24, :43`)" | `selectedTab` is declared at `:23`; `:43` is correct. | `AppIntentRouter.swift:23, :43` |

### Omissions added

| # | Omission | Where added | Evidence |
|---|---|---|---|
| O1 | `ScreenContainer` owns its own `NavigationStack`; a *pushed* hub cannot reuse it (nested stacks), a `fullScreenCover` can. Constrains Q1 and adds ≈ 1 h if push. | §1 Container row, §4 Topology, Risk 1, Q1, §7 | `ScreenContainer.swift:49` |
| O2 | PR #45 modifies `DESIGN.md`, which is **deleted** on this worktree → certain delete/modify conflict. | Risk 9 | `gh pr view 45 --json files`; `git status` (`D DESIGN.md`) |
| O3 | `MedicationLogSheet` close button is a fixed 30 × 30 (< 44 pt) while `TextCheckInComposer`'s is 44 — a live a11y defect on a hub destination. | §1 Log Medications row, §4 Sheets, Q9 | `MedicationLogSheet.swift:42`; `TextCheckInComposer.swift:40` |
| O4 | Back-pill stroke `#e4ece4` is 1.21 : 1 on white / 1.19 : 1 on `#fbfffc` — effectively borderless; `#8c68d3` icon on white is 4.17 : 1 (passes the 3 : 1 non-text floor). | §5 Contrast | recomputed ratios |
| O5 | The "40MB vs 150 MB" copy conflict now carries its evidence: `ModelDownloadRow.swift:82` "~150 MB · Wi-Fi recommended", `DownloadPermissionView.swift:82` "Download Now (~150 MB)". | §2.7 X1 | those files |

### Confirmed without change (selection of the load-bearing ones)
`CheckInView` structure and all cited ranges (`:26, :29, :31-33, :34-45, :46-88, :98-113, :115-117, :119-133, :143-193, :199-268, :273-449, :456-507`); `CrescentRing` stroke/breathing/spin/gates (`:15, :26, :30-35, :37-49`); `Metrics.CheckIn.crescentDiameter = 300` (`Metrics.swift:53`), `savedDisc/savedCheck` (`:64-66`), `minTapTarget = 44` (`:10`); `Icons.checkIn = "checkmark.circle"` (`:8`), `Icons.medication = "pills.fill"` (`:13`); `Typography.label` 12/medium (`:46`), `largeTitle` 34/bold (`:23`), `display` 28/semibold (`:21`), `headline` 16/semibold (`:34`), `callout` 15/regular (`:40`), `UIFontMetrics` scaling (`:12-17`), SF-only (`:4-8`); `NewLook.screen #EFF2EB/#12140F` (`:13`), `inkPrimary #1C1B1F` (`:17`), `inkSecondary #8A8A8E` + owner lock (`:22-25`), `hairline #DBDDDE` (`:27`), `onSelection #FFFFFF` (`:35`), `checkInGreen #5FB36E` (`:41`), card shadow (`:62-66`); `Theme.meadowGreen #5F8A4C` (`Theme.swift:9`); `Palette.medication #7E5CA8` (`Palette.swift:12`); `Spacing.xs/s/xl = 4/8/20`; `Buttons.swift` press opacities (`:14, :34, :51`); `CapsuleGlyph` horizontal two-tone (`:5-23`); `RecordingState` cases (`AppEnums.swift:18-24`); `LayoutConstants.maxRecordingDuration = 480` (`Constants.swift:10`); `promptProgress` (`CheckInViewModel.swift:458-460`), `saveTextCheckIn` (`:484-508`), `loadPromptInterval` (`:422-429`), `cancelRecording` (`:402-413`), `reset` (`:415-420`), Whisper intercept (`:139-142`); `RecordingStore.loadRecordings` (`:47-59`), `"text-"` prefix (`:143`); `MedicationBarViewModel.activeDoses` (`:23`), `refresh` (`:59-109`); `MedicationBarView` guard (`:12`), dialog (`:20-39`), state words (`:79-86`); `ScreenContainer` (`:49-54, :57-60, :82`); `MedicationBarOverlay` (`:18-23`); `RootTabView` (`:19-36`); `AppIntentRouter.requestCheckIn` (`:41-46`); `SquirlApp` deep link + arming (`:68-76`), `RootContainerView` (`:90-224`); router tests (`:15, :56`); `WelcomeView` ring (`:23, :52-53`); `CalendarHeaderView.forceWeek` (`:20`); `Color(lightHex:darkHex:)` (`Color+Hex.swift:7-11`); `FocusLevel.displayLabel` "Locked In" (`Levels.swift:119`); no vuesax assets / no `UIAppFonts`; PNG matches §2 (arc 3 → ~7 o'clock, button order, caption, back pill, no tab bar, no medication bar) — nothing on the render is missing from the delta table.
