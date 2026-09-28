<!-- Created: 2026-09-27 22:34 (WEST) · Updated: 2026-09-27 22:34 (WEST) -->
# Cross-check — pen "iPhone 17 - 16" (Settings) vs the shipping SwiftUI

| | |
|---|---|
| Pen source | `scratchpad/out/screens/settings.md` (spec) + `pen/named/iphone17-16-settings.png` (render). The `.pen` file was not opened. |
| Code read (read-only, worktree `feat/057-ui-refresh` @ `08ba8cba` = `main`) | `app-four/Views/SettingsView.swift` · `app-four/ViewModels/SettingsViewModel.swift` · `app-four/Views/Settings/{DayCardSettingsSection,DoseGuardSection,JournalExportSection,MedicalInfoSection,MedicationBarSettingsSection,MyMedicationSection,YourDataSection}.swift` · `app-four/Views/Components/ModelDownloadRow.swift` · `app-four/Views/Components/MedicationBarView.swift` · `app-four/ViewModels/MedicationBarViewModel.swift` · `app-four/Models/{AppSettings,DoseGuardMode,PromptPace,MedicationEvent}.swift` · `app-four/Intents/DoseConfirmationCopy.swift` · `app-four/Views/RootTabView.swift` · `app-four/DesignSystem/ScreenContainer.swift` · `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/{Radius,Icons}.swift`. `feat/055-revenuecat` inspected with `git ls-tree` / `git show` only. |
| Status | Planning only. No Swift changed. Every claim about code carries `file:line`. Where the pen is ambiguous the row says so. |

---

## 1. Mapping — what implements this surface today

| Pen region | Current implementation | Notes |
|---|---|---|
| Whole screen | `SettingsView` (`app-four/Views/SettingsView.swift:4-297`) inside `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` (:45), rendering a **native `List` `.insetGrouped`** with `.scrollContentBackground(.hidden)` + `.listRowBackground(NewLook.card)` (:47-70). 14 sections in this order (:48-66): AI Models · System · Check-in · Calendar · My Medication (+ Confirmations) · Dose Guard · *(Sticker setup, unmounted)* · Medication Bar · Medication info · Accessibility · Your data · Journal export · Danger · Version. | The pen keeps 7 of these, reorders them, and draws none of the last six. |
| View model | `SettingsViewModel` (`app-four/ViewModels/SettingsViewModel.swift:5-264`), `@Observable @MainActor`. Mirrors `AppSettings` and persists via `sync*()` methods (:108-143). | Unchanged by the redesign unless "Show Taken/End Time" is added to it (it is `@AppStorage` today, not VM). |
| Persistence | SwiftData `AppSettings` (`app-four/Models/AppSettings.swift:4-48`): `downloadOverCellular` (:9), `promptPaceSeconds` (:11), `defaultMedicationName/Dose` (:15-16), `doseGuardModeRaw` (:17), `doseGuardWindowHours` (:18), `nameMedicationInConfirmations` (:19). `@AppStorage` keys: `autoExpandOnSelection`, `alwaysExpandCards` (`DayCardSettingsSection.swift:7-8`), `medicationBarVisible`, `medicationBarShowName` (`MedicationBarSettingsSection.swift:5-6`). | No schema change needed for anything drawn **except** the two new Medication Bar rows (see §3). |
| Title block | **Does not exist.** `ScreenContainer` sets `.navigationTitle("")` inline (`ScreenContainer.swift:51-52`); Settings shows no visible title. | NEW. |
| Check-In Calendar card | Two separate `Section`s: `checkInSection` `Picker("Prompt Pace")` (`SettingsView.swift:187-200`) and `DayCardSettingsSection` `Section("Calendar")` (`DayCardSettingsSection.swift:10-22`). | CHANGE (merge + restyle). |
| Voice & Storage card | `aiModelsSection` → two `ModelDownloadRow`s (`SettingsView.swift:130-169`; component `ModelDownloadRow.swift:3-190`) + `systemSection` → `LabeledContent("Storage")` and `Toggle("Download over Cellular")` (`SettingsView.swift:171-185`). | CHANGE; the LLM row is missing from the pen (REMOVE candidate, §2). |
| Confirmations card | Second `Section("Confirmations")` of `MyMedicationSection` (`MyMedicationSection.swift:64-76`) + `confirmationBanner` (:147-167). | CHANGE; the first section of the same file (My Medication picker, :21-62) is absent from the pen. |
| Dose Guard card | `DoseGuardSection` (`DoseGuardSection.swift:8-101`). | CHANGE. |
| Medication Bar card | `MedicationBarSettingsSection` (`MedicationBarSettingsSection.swift:4-23`). | CHANGE + 2 NEW rows. |
| Accessibility card | `accessibilitySection` (`SettingsView.swift:228-234`). | CHANGE (restyle only; copy identical). |
| Your Data card | `YourDataSection` (`YourDataSection.swift:7-37`) + private `AcknowledgementsView` (:41-66). | CHANGE; Privacy Policy link and ephemeral-store warning are absent from the pen. |
| Tab bar | Native `TabView` + `.tabItem` `Label`s, `.tint(Theme.meadowGreen)` (`RootTabView.swift:19-36`); opaque bar forced from each root (`ScreenContainer.swift:59-60`). SF Symbol `Icons.settings = "gear"` (`Icons.swift:9`). | NEW custom chrome (global, §4). |
| FAB | **Does not exist.** | NEW (global). |
| Medication bar overlay at top | `.medicationBarOverlay(shown: true)` via `ScreenContainer` (`ScreenContainer.swift:79-82`; `SettingsView.swift:45`). | Pen draws no bar on Settings — ambiguous (no active dose in the mock, or removed). |

Related but off-branch: `feat/055-revenuecat` adds `SubscriptionSection`, `SubscriptionSectionModel`, `CustomerCenterHost`, `LegalDocumentView` under `app-four/Views/Settings/` (`git ls-tree feat/055-revenuecat app-four/Views/Settings/`), mounts `SubscriptionSection()` first in the list (`git show feat/055-revenuecat:app-four/Views/SettingsView.swift` L27), replaces the Privacy `Link` with `NavigationLink { LegalDocumentView(document: .privacy) }` and adds a "Terms of Use" row (`git diff main feat/055-revenuecat -- app-four/Views/Settings/YourDataSection.swift`), and swaps the export button for `ExportJournalButton(style: .settingsRow, checkInCount:)`. None of that is in the pen.

---

## 2. Delta table, section by section

Legend: **KEEP** = already matches · **CHANGE** = exists, restyle/rearrange · **NEW** = does not exist · **REMOVE** = exists today, absent in the pen.

### 2.0 Page chrome

| Item | Verdict | Exactly what changes |
|---|---|---|
| Title block "Settings" 34/600 `#17501d` + "Make The App Works For You" 16/500 `#6a6d70` at (32,74) | **NEW** | Add an in-content page-title block (pattern precedent: Insights prints its own "Insights" `Typography.text(24, .bold, .title2)`, `InsightsView.swift:53-64`). Today the nav title is `""` (`ScreenContainer.swift:51`), so VoiceOver has no screen heading. Subtitle copy needs a fix ("Make the app work for you" or drop). |
| Screen ground `#fbfffc` | **CHANGE** | Today `NewLook.screen` `#EFF2EB` (`ScreenContainer.swift:53`). Token swap (shared with every screen). |
| Native inset-grouped `List` | **CHANGE** (structural) | Replace `List` + `Section` with `ScrollView` › `VStack(spacing: 24)` of `[heading 16/600 → gap 12 → card]` groups at x 29, width 344. Card = `#ffffff`, r 24 (or 18), 0.5 pt `#000000@10%` inside stroke, shadow `#183c28@8%` (0,3,8), padding 15, inner gap 15, 1 pt `#000000@10%` dividers. **Neither `.newLookCard()` (r 20, borderless, `black@5%` shadow, `NewLook.swift:52-66`) nor `Radius.card` 16 / `Radius.newLookCard` 20 (`Radius.swift:6,14`) matches — a new card token/modifier is required in the package.** The `ScrollViewReader` scroll-to-top on tab select (`SettingsView.swift:74-79`) and the My-Medication focus anchor (:86-92) must be re-implemented with `ScrollPosition`/`scrollTo(id:)` on the `ScrollView`. |
| Medication bar overlay (top `safeAreaInset`) | **Ambiguous** | Pen shows none. Either the mock has no active dose (bar renders only when `activeDoses` is non-empty, `MedicationBarView.swift:12`) or the owner wants Settings without it. Open question 10. |
| Bottom content inset | **NEW** | ≥ 170 pt so the last card clears FAB + nav (spec §2.10). Today the List ends 36 pt above the native bar (`ScreenContainer.swift:46` `tabBarFadeHeight`). |

### 2.1 Check-In Calendar card (pen r 24)

| Pen element | Verdict | Exactly what changes |
|---|---|---|
| Group title "Voice Prompts" 14/600 `#292d32` + description "How long each prompt stays on screen during a voice check-in." 12/500 `#6a6d70` | **CHANGE** | Today: `Section` header "Check-in" + `Picker("Prompt Pace")` + footer with the **identical** description (`SettingsView.swift:188-199`). Rename "Prompt Pace" → "Voice Prompts"; footer becomes an in-card description under the group title. |
| Chips "Brisk · 6 s" / "Relaxed · 10 s" (Bill-shape, single-select, selected = `#2a9134` fill + white 12/500; unselected = white + 1 pt `#e4ece4` + `#193024`) | **CHANGE** | Native `Picker` over `PromptPace.allCases` (`SettingsView.swift:189-193`; labels `PromptPace.displayLabel` `PromptPace.swift:7-12` match verbatim) → two chips. Binding stays `$viewModel.promptPace` + `syncPromptPace()` (:194; `SettingsViewModel.swift:113-116`). **No existing chip matches**: `.newLookChip` is capsule, `Typography.caption` medium, padding 12×8, selected fill `Theme.meadowGreen` (`NewLook.swift:73-107`); pen is r 15, padding 5×15, 27 pt tall. A shared Bill-shape chip must exist first. 27 pt < 44 pt target → wrap in a ≥ 44 pt hit frame. |
| Divider | **NEW** (in this card) | Today the two settings are separate grouped sections; the pen puts them in one card with a 1 pt hairline. |
| "Calendar Cards" 14/600 + rows "Auto-expand selected day" (ON) then "Always expand cards" (OFF), labels 12/500 `#4d5154`, small toggles 34×18.31 | **CHANGE** | Today `Section("Calendar")` with `Label`s carrying SF icons `rectangle.stack` / `rectangle.expand.vertical`, order **Always expand first** (`DayCardSettingsSection.swift:11-21`), native `Toggle`s. Pen: no icons, reversed order, 12 pt labels, custom small toggle. Keys unchanged (`@AppStorage` :7-8, consumed by `CalendarLibraryView.swift:15-16,131,179`). Accessibility hints (:15, :20) must survive the restyle. |

### 2.2 Voice & Storage card (pen r 24)

| Pen element | Verdict | Exactly what changes |
|---|---|---|
| Row "Voice Transcription" (icon `vuesax/outline/voice-cricle` 21 `#212529`, 14/500 `#212529`) + trailing "● Installed" (8 Ø `#2a9134` dot + 12/500 `#2a9134`) | **CHANGE** | Today `ModelDownloadRow(title: "Voice Transcription", icon: "waveform", …)` (`SettingsView.swift:132-149`). Installed state is rendered as a **native `Toggle` ON** tinted `Theme.meadowGreen` (`ModelDownloadRow.swift:66-74`); the "Installed"/"Not installed" dot+text branch exists but is **unreachable** (rendered only inside `trailingStatus`, which shows when `isDownloading \|\| hasError`, :55-60, :115-123). The pen effectively promotes that dead branch to the installed look. **Undrawn states that exist in code and are load-bearing (CLAUDE.md: the download path "is failure-prone… Treat it as load-bearing")**: not installed → Toggle OFF + subline "~150 MB · Wi-Fi recommended" (:81-85); downloading → linear `ProgressView` 80 wide + "NN%" or spinner + "Starting…" + "Cancel" (:89-109); error → `Theme.danger` dot + message + ghost pills "Try again" / "Allow on cellular" / "Open Settings" in a `FlowLayout` (:110-114, :126-158; messages `Protocols.swift:153-164`); delete → `confirmationDialog` "<title> Options" / "Delete Model" (:30-37) triggered by flipping the toggle OFF (:44-51); VoiceOver custom actions (:174-189). All must be designed in the pen language before implementation. |
| **"Journal Insights" (LLM) row** — second `ModelDownloadRow` (`SettingsView.swift:150-167`, `icon: "brain.head.profile"`, `.llm`) | **REMOVE (absent in pen)** — **loses a function the owner almost certainly wants** | This is the only in-app way to download or delete the ~740 MB insights model after "Skip for Now" in onboarding (`AppSettings.swift:28-31`: "Settings remains the way back"; `MLXJournalService.swift:184`: never trigger an implicit download). Without it a user who skipped can never get extraction. Also the CheckIn alert "Insights Model Not Downloaded … Download it from Settings › AI Models" (`CheckInView.swift`, per code map §2) points here. **Keep; needs a second row in the same card.** Known copy bug carried over: both rows say "~150 MB" / "transcription model" (`ModelDownloadRow.swift:70-72,82,171`) while the LLM is ~740 MB (`LLMDownloadView.swift:73`) / "~1 GB" (`AppDelegate.swift:5`). |
| Row "Recording" (icon `vuesax/bold/record-circle`) + value "34MB" 12/500 `#4d5154` | **CHANGE** | Today `LabeledContent("Storage")` with value `"\(count) recording(s) · \(String(format: "%.1f", storageUsedMB)) MB"` in `NewLook.inkSecondary` (`SettingsView.swift:173-177`). Pen renames "Storage" → "Recording", drops the count, drops the decimal and the unit space. Data: `viewModel.storageUsedMB` (`SettingsViewModel.swift:21,145-148`), `recordingCount` (:39-41). Recommend `ByteCountFormatter`/`Measurement` ("34 MB") and keeping the count (owner call). |
| Row "Download Over Cellular" + description "Allow voice-model downloads using mobile Data" + small toggle ON | **CHANGE** | Today `Toggle` with `Label(…, systemImage: "antenna.radiowaves.left.and.right")`, no description (`SettingsView.swift:178-183`). Pen adds a description, swaps the icon for a bar-chart glyph, uses the small custom toggle. Binding stays `$viewModel.downloadOverCellular` + `syncDownloadOverCellular()` (`SettingsViewModel.swift:53,108-111`). **Copy defect**: "voice-model" is wrong — the same flag gates the LLM download too (`SettingsViewModel.swift:173-175` `allowsCellular` for both `AIModelType`s; background download in `SquirlApp.swift` per code map §1). Description must say "model downloads". Pen mock shows ON; default is `false` (`AppSettings.swift:37`). |

### 2.3 Confirmations card (pen r 18)

| Pen element | Verdict | Exactly what changes |
|---|---|---|
| Row title "Name medication in confirmations" 14/500 + 4-line description 12/500 `#6a6d70` + small toggle ON (top-aligned) | **CHANGE** | Today `Toggle` with `Label(…, systemImage: "quote.bubble")` + section **footer** with the **identical** description text (`MyMedicationSection.swift:65-76`). Pen moves the description into the card under the title, drops the icon, top-aligns the toggle. Binding stays `$viewModel.nameMedicationInConfirmations` + `syncNameInConfirmations()` (:65-68; `SettingsViewModel.swift:59,133-136`). a11y hint (:69) must survive. Text column must be 270 wide, not 280 (pen drift, spec §2.4). Mock shows ON; default `false` (`AppSettings.swift:19`). |
| Preview chip `#f4f0fb` r 12, 314×40: white 26 Ø capsule badge (0.418 pt `#000000@10%` stroke, violet-800 diagonal capsule outline) · "09:54" 14/600 `#171a1d` · 3 Ø dot · "Concerta 36 mg" 12/500 `#4d5154` | **CHANGE** | Today `confirmationBanner` (`MyMedicationSection.swift:147-167`): `pills.fill` white on `Palette.medication` r 7, 26 pt · `previewLine` (`"Dose logged"` when OFF, `"\(name) \(dose) logged"` when ON, fallback "Elvanse"/"30 mg", :171-176) `.subheadline.semibold` · literal `"· 17:42"` `.secondary` monospaced · on `Color(.tertiarySystemFill)` r 12 · a11y "Preview: … at 17:42". Pen: time-first, no "logged", violet-50 tint, white badge with a **diagonal outline capsule** (the DS `CapsuleGlyph` is a horizontal two-tone capsule, `Glyphs/CapsuleGlyph.swift` — a new glyph asset). **Two fidelity problems**: (a) the OFF-state preview is undrawn; (b) the real confirmation string is `"\(name) \(dose) logged · \(time)"` / `"Dose logged · \(time)"` with `Date.formatted(date: .omitted, time: .shortened)` (`DoseConfirmationCopy.swift:8-25`) — the pen preview neither matches the order nor the locale time style, so it would preview something the user never sees. |
| **"My Medication" section** — collapsible row `Label("Medication", "pills")` with 3-state value ("Set" / name / "Name · dose"), `MedicationCatalog` chip flow (Concerta · Ritalin · Elvanse) + dose chips, "Clear Medication", footer (`MyMedicationSection.swift:21-62,79-143,182-201`) | **REMOVE (absent in pen)** — **loses a function that is wired into an App Intent** | The default medication/dose is what the hands-free "Log My Meds" intent records (`SettingsViewModel.swift:57-58,118-131`; `AppSettings.swift:15-16`). When it is unset, `LogDefaultDoseIntent` returns `.notConfigured` and calls `router.focusMyMedication()` (`LogDefaultDoseIntent.swift:31-37`; `AppIntentRouter.swift:26,54-62`), which switches to the Settings tab and **scrolls to `myMedicationID` and expands the picker** (`SettingsView.swift:86-92`; `SquirlApp.swift` :82-85 per code map). Without this section that continuation has no target and the preview chip's "Concerta 36 mg" has no source. **Keep; needs a frame.** Also drops `SettingsChip` (med-purple selection, :182-201) — replaced by Bill-shape chips if kept. |

### 2.4 Dose Guard card (pen r 24)

| Pen element | Verdict | Exactly what changes |
|---|---|---|
| Three radio rows (title 14/600 `#292d32`, subtitle 12/500 `#6a6d70`, 20 Ø radio at x 338: off = 1 pt `#000000@10%` ring; on = 6 pt `#2a9134` ring, 8 pt white centre), no dividers, "Time Window" selected | **CHANGE** | Today `ForEach(DoseGuardMode.allCases)` `Button`s with `Label` icon `"shield"`, title + `.footnote .secondary` subtitle, trailing `checkmark` in `Color.accentColor` on the selected row, `.accessibilityAddTraits(.isSelected)` + hints (`DoseGuardSection.swift:14-41`). Pen: drop the shield icon, replace the checkmark with a custom radio (no DS component — package addition), keep whole-row tap. Copy: code "Time window" / "Every trigger logs" / "Blocked while a dose is still active" / "Blocked for a set time after a dose" (:66-80) vs pen "Time Window" / "Every Trigger Logs" / "Blocked While A **Does** Is Still Active" — code copy wins (typo + case). `Color.accentColor` (:34) goes away with the redesign (it is unverified whether it resolves to the bronze asset or the meadow tint — code map §3.2). |
| "Blocked For" 14/600 + chips "1h" · **"2h" selected with 15 Ø white check badge** · "3h" · "4h" | **CHANGE** | Today a segmented `Picker("Blocked for")` with "1 h … 4 h" labels, shown **only when `doseGuardMode == .window`** (`DoseGuardSection.swift:43-58`), binding `$viewModel.doseGuardWindowHours` + `syncDoseGuard()`. Pen: four Bill-shape chips, selected variant with a leading check badge — **that variant does not exist in DS Frame 15** (spec §2.5) → new chip state in the package. Hide/disable for Off/Total is undrawn (open question 8). Label spacing "2h" vs footnote "2 h" — code uses "2 h". |
| Footnote row: `vuesax/bold/info-circle` 21 + "A second log is blocked for 2 h after your last dose. The in-app Log Dose sheet is never blocked." 12/500 `#6a6d70` (fixed 283×45 box) | **CHANGE** | Today the section **footer** `guardFooter` with three per-mode variants (`DoseGuardSection.swift:90-100`); the `.window` variant with hours = 2 is **verbatim identical** to the pen. Pen turns it into an in-card icon+note row and draws only the window variant. Keep all three variants; text must hug, not be fixed-height (the PNG shows the collapse, spec Open Q1). |
| Card header | **CHANGE** | `Section` header "Dose Guard" (:60) → 16/600 `#212529` heading above the card. Copy identical. |

### 2.5 Medication Bar card (pen r 24)

| Pen element | Verdict | Exactly what changes |
|---|---|---|
| "Show Medication Bar" 14/500 `#4d5154` + **large** toggle 42×22.62 ON | **CHANGE** | Today `Toggle` with `Label(…, "pills.circle")` + a11y hint (`MedicationBarSettingsSection.swift:10-13`). Drop icon; large custom toggle (second size on one screen — open question 3). Key `medicationBarVisible` unchanged (:5; read by `MedicationBarView.swift:8,12`). |
| "Show Medication Name" + large toggle ON, divider above | **CHANGE** | Today shown **only when `barVisible`** (`MedicationBarSettingsSection.swift:15-20`); pen draws all four rows unconditionally. Whether rows 2–4 hide/disable when the bar is off is undrawn. Key `medicationBarShowName` unchanged (read by `MedicationBarView.swift:9,101`). |
| "Show Taken Time" + toggle ON | **NEW** | No key, no code. The bar title line is `"HH:mm · Name Dose"` and **always** prints the taken time (`MedicationBarView.swift:96-104`, `titleLine`: `guard showName else { return time }`). Needs `@AppStorage("medicationBarShowTakenTime")` (or a VM property) + a `titleLine` branch + a decision for the case both name and time are hidden (row would be empty). Bar changes are logic → test-first (Principle X) if placed in `MedicationBarViewModel`. |
| "Show End Time" + toggle ON | **NEW** | No key. `DoseDisplay.endsAt` exists (`MedicationBarViewModel.swift:35,94`) but is rendered **only inside the VoiceOver label** (`MedicationBarView.swift:106-113`, "ends \(ends)"). A visible end time does not appear on the pen's own bar rows either ("09:54 • Concerta 36 mg" + status word, design-system.md §4.10), so the semantics are undefined. Needs key + bar rendering + a decision on where it sits. |

### 2.6 Accessibility card (pen r 18)

| Pen element | Verdict | Exactly what changes |
|---|---|---|
| Accessibility figure glyph 13.81×17 `#000000` + note 14/400 `#6a6d70`, fixed 283×51 | **CHANGE** (copy KEEP) | Today `Section("Accessibility")` › `Text` in `Typography.caption` `NewLook.inkSecondary` (`SettingsView.swift:228-234`); copy is **verbatim identical** ("Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations."). Pen adds a leading icon (the only pure-black ink on the screen — token decision), bumps to 14/400, card r 18, text must hug (PNG shows overflow). No control today either. |

### 2.7 Your Data card (pen r 18)

| Pen element | Verdict | Exactly what changes |
|---|---|---|
| Row "Acknowledgement" 14/500 + "Your recordings, check-ins, and signals stay on this device. Nothing is uploaded." 12/500 + `>` chevron | **CHANGE** | Today three distinct rows: the statement `Text` (`YourDataSection.swift:22-24`, **verbatim identical** copy, `Typography.body` `inkPrimary`), `Link("Privacy Policy", "hand.raised")` → `https://squirl.pt/privacy` (:26-28), `NavigationLink("Acknowledgements", "heart")` → `AcknowledgementsView` (:30-34; credits WhisperKit only, :41-66 — MLX/Qwen uncredited). The pen collapses statement + a disclosure into one row titled "Acknowledgement" (singular), destination ambiguous (spec Open Q7). |
| **Privacy Policy link** | **REMOVE (absent in pen)** — **loses a hard-gate surface** | CLAUDE.md §Monetization: "Privacy sequencing is a hard gate"; DESIGN.md §Paywall required furniture lists Privacy Policy. feat/055 makes it an in-app `LegalDocumentView(document: .privacy)` plus a new "Terms of Use" row (`git diff main feat/055-revenuecat -- app-four/Views/Settings/YourDataSection.swift`). **Keep; needs a row.** |
| **Ephemeral-store warning** (`AppModelContainer.isEphemeral` → "Storage couldn't be opened this session…" with `exclamationmark.triangle` in `Theme.danger`, `YourDataSection.swift:10-20`) | **REMOVE (absent in pen)** | Conditional row; the pen draws no error/warning state anywhere (design-system.md §7 item 13). Losing it hides a real "your check-ins won't be saved" notice. Keep as an undrawn state. |
| Statement copy "Nothing is uploaded." | **KEEP (but see risk)** | Becomes false once a purchase receipt goes to RevenueCat (constraints §4.6 Q-M3). Reconcile with the "one honest disclosure line". |

### 2.8 Sections the pen does not draw at all

| Today | Where | Verdict | What is lost if removed |
|---|---|---|---|
| **Medication info** disclaimer ("Squirl is a personal journal, not medical advice. …" + footer "Talk with your clinician…") | `MedicalInfoSection.swift:6-18` | **REMOVE** | App Review Guideline 1.4.1 rationale in the file's doc comment (:3-5). Removing it re-opens a review risk for a medication-tracking app. Keep (could live inside the Confirmations/Medication group). |
| **Journal export** "Save a copy of my journal — yours to keep" (`lock.doc`) + inline `ProgressView` + footer; flow `exportJournal()` → `.fileExporter` (`EncryptedJournalDocument`, "Squirl Journal yyyy-MM-dd") → `RecoveryKeySheet` ("Keep this key safe", mono key on `tintNeutral` r 16, "Copy key"/"Copied" `.primary` meadow gradient, "Done"); failure alert "Couldn't save a copy" | `SettingsView.swift:236-267,104-125`; `JournalExportSection.swift:8-86` | **REMOVE** | CLAUDE.md: "**Export is never gated.** … Locking someone's own writing is not [acceptable]." — a non-negotiable. feat/055 replaces the button with `ExportJournalButton(style: .settingsRow, checkInCount:)`. **Must keep; needs a frame** (row + recovery-key sheet in the new language). |
| **Clear All Data** (destructive) + alert "Clear All Data?" | `SettingsView.swift:269-277,96-103`; `SettingsViewModel.swift:249-263` | **REMOVE** | The only way to wipe the journal. The pen draws no destructive control anywhere (design-system.md §1.2 "Destructive: none drawn") — a destructive token/row style is needed. Keep. |
| **Version label** "<CFBundleDisplayName> v<CFBundleShortVersionString>" | `SettingsView.swift:279-296` | **REMOVE** | Loses the only user-visible build identity (support / TestFlight triage). Cheap to keep. |
| **Subscription section** (Manage · Restore purchases · Subscribe · Try again; 7 states) + `CustomerCenterHost` | feat/055 only: `app-four/Views/Settings/SubscriptionSection.swift` L20-73, `SubscriptionSectionModel.swift` | **REMOVE / never designed** | "Restore appears twice: on the paywall and in Settings" (DESIGN.md §Paywall, App Review 3.1.1). Must exist once 055 merges; needs a frame in the pen language. |
| Sticker setup `NavigationLink` + `StickerSetupView` | `SettingsView.swift:212-222` (unmounted, :56-59) | n/a | Already unmounted for 1.1. No loss. |
| Feedback button | `Views/Feedback/FeedbackButton.swift` (unmounted, code map §6) | n/a | No loss. |
| 5-tap debug console (`TestServicesView`) | Not on this branch; **PR #41** "fix(settings): restore the 5-tap debug console" touches `app-four/Views/SettingsView.swift` + `TestServicesView.swift` (`gh pr view 41`) | n/a | Coordination risk, not a loss (see §6). |
| Orphan `medicalPromptEnabled` (UserDefaults, `SettingsViewModel.swift:43-51`, `Constants.swift:45-58`) | no row today | n/a | Nothing changes; still orphaned. |
| SF-Symbol leading icons on every row (`waveform`, `brain.head.profile`, `antenna.radiowaves.left.and.right`, `rectangle.stack`, `rectangle.expand.vertical`, `pills`, `quote.bubble`, `shield`, `pills.circle`, `pill`, `hand.raised`, `heart`, `lock.doc`, `trash`) | throughout | **REMOVE** (pen keeps icons on 5 rows only: voice-circle, record-circle, chart, info-circle, accessibility figure) | Pure restyle; the pen's vuesax set vs SF Symbols is a file-wide decision (design-system.md §5.1). |

---

## 3. Data availability — every field/label the pen shows

| Pen field | Data exists? | Path | Gap / note |
|---|---|---|---|
| "Settings" / "Make The App Works For You" | static | — | Copy fix needed. |
| "Brisk · 6 s" / "Relaxed · 10 s", selected | **yes** | `PromptPace.displayLabel` (`PromptPace.swift:7-12`); selection `viewModel.promptPace` (`SettingsViewModel.swift:54,83`) ← `AppSettings.promptPaceSeconds` (`AppSettings.swift:11`, default relaxed = 10) | Labels match the pen verbatim. |
| "Auto-expand selected day" ON | **yes** | `@AppStorage("autoExpandOnSelection")` default `true` (`DayCardSettingsSection.swift:7`) | Mock matches default. |
| "Always expand cards" OFF | **yes** | `@AppStorage("alwaysExpandCards")` default `false` (:8) | Mock matches default. |
| "Voice Transcription" → "● Installed" | **yes** | `viewModel.whisperModelInstalled` (`SettingsViewModel.swift:15`, filesystem truth :150-155, refreshed on `.aiModelAvailabilityDidChange` :90-96) | Also available but undrawn: `isDownloadingWhisper`, `whisperDownloadProgress` (:16-17), `downloadErrors[.whisper]` + `message(for:)` (:26,209-211), `canAllowCellular(for:)` (:30). |
| *(missing)* Journal Insights model state | **yes** | `llmModelInstalled`, `isDownloadingLLM`, `llmDownloadProgress` (:18-20) | Row absent in pen. |
| "Recording" → "34MB" | **yes** | `viewModel.storageUsedMB` = bytes / 1 048 576 (`SettingsViewModel.swift:21,145-148`; `AudioFileStorageService.calculateTotalStorageUsed()` `Protocols.swift:130`) ; `recordingCount` (:39-41) | Formatting only: code prints "%.1f MB"; pen "34MB". Count dropped in pen. |
| "Download Over Cellular" ON | **yes** | `viewModel.downloadOverCellular` (:53) ← `AppSettings.downloadOverCellular` (`AppSettings.swift:9`, default `false`) | Description copy "voice-model" is inaccurate (gates both models, :173-175). |
| "Name medication in confirmations" ON | **yes** | `viewModel.nameMedicationInConfirmations` (:59) ← `AppSettings.nameMedicationInConfirmations` (`AppSettings.swift:19`, default `false`) | — |
| Preview "Concerta 36 mg" | **yes, conditionally** | `viewModel.defaultMedicationName` / `defaultMedicationDose` (:57-58) ← `AppSettings.swift:15-16`; fallback "Elvanse" / "30 mg" when unset (`MyMedicationSection.swift:173-174`) | **The picker that sets these is not in the pen** (§2.3). Real doses in the catalog are "36 mg" style (`MedicationCatalog.swift:20-39` per code map). |
| Preview "09:54" | **NO (sample)** | Code hard-codes `"· 17:42"` (`MyMedicationSection.swift:156`). Real confirmations format `Date` with `.formatted(date: .omitted, time: .shortened)` (`DoseConfirmationCopy.swift:23-25`) | Decide: fixed sample, `Date.now`, or last dose (`MedicationBarViewModel.activeDoses.last?.takenAt`). Use the same formatter as the real confirmation. |
| Preview OFF state | **yes** | `previewLine` → "Dose logged" (`MyMedicationSection.swift:172`); real string "Dose logged · <time>" (`DoseConfirmationCopy.swift:12`) | Undrawn in pen. |
| Capsule badge glyph (diagonal outline) | **no matching asset** | DS `CapsuleGlyph` is a horizontal two-tone capsule (`Glyphs/CapsuleGlyph.swift`) | New vector asset if the pen's line-style capsule is kept. |
| Dose Guard "Off" / "Total" / "Time Window", selected | **yes** | `viewModel.doseGuardMode` (:60) ← `DoseGuardMode(raw:)` (`DoseGuardMode.swift:6-14`), persisted `doseGuardModeRaw` (`AppSettings.swift:17`, default "off"); titles/subtitles `DoseGuardSection.swift:66-80` | Mock shows `.window`; default is `.off`. |
| "1h … 4h", "2h" selected | **yes** | `viewModel.doseGuardWindowHours` (:61) ← `AppSettings.doseGuardWindowHours` (`AppSettings.swift:18`, default 2); choices `[1, 2, 3, 4]` (`DoseGuardSection.swift:49`) | Mock matches default. |
| Footnote "… for 2 h …" | **yes** | `guardFooter` interpolates `doseGuardWindowHours` (`DoseGuardSection.swift:90-100`) | Three variants exist; pen draws one. |
| "Show Medication Bar" ON | **yes** | `@AppStorage("medicationBarVisible")` default `true` (`MedicationBarSettingsSection.swift:5`) | — |
| "Show Medication Name" ON | **yes** | `@AppStorage("medicationBarShowName")` default `true` (:6) | — |
| "Show Taken Time" ON | **NO** | No key. Time is always shown by `titleLine` (`MedicationBarView.swift:99-104`) | Needs a key + bar branch + empty-title rule. |
| "Show End Time" ON | **NO** | No key. `DoseDisplay.endsAt` exists (`MedicationBarViewModel.swift:35,94` = `takenAt + durationHours·3600`) but only spoken (`MedicationBarView.swift:109`) | Needs a key + a visible slot on the bar that the pen's bar design does not show. |
| Reduce Motion note | static; env available | `@Environment(\.accessibilityReduceMotion)` (`SettingsView.swift:10`) | Informational only, as today. |
| "Your recordings, check-ins, and signals stay on this device. Nothing is uploaded." | static | `YourDataSection.swift:22` verbatim | See Q-M3 risk. |
| "Acknowledgement" destination | **yes (two candidates)** | `AcknowledgementsView` (`YourDataSection.swift:41-66`) or privacy URL `https://squirl.pt/privacy` (:26) / 055 `LegalDocumentView` | Ambiguous. |
| *(missing)* Ephemeral-store warning | **yes** | `AppModelContainer.isEphemeral` (`AppModelContainer.swift:10,96`) | Undrawn state. |
| *(missing)* Version | **yes** | `Bundle.main` (`SettingsView.swift:279-283`) | Row absent. |
| Tab "Settings" active | **yes** | `Tab.settings` (`RootTabView.swift:5-10`) | — |
| FAB action | **behaviour exists, control does not** | `router.requestCheckIn()` / `shouldStartCheckIn` → `selectedTab = .checkIn; shouldAutoStartRecording = true` (`SquirlApp.swift:70-75`) | A FAB can reuse this path if "+" means "new check-in" (open question 9). |

Not on this screen (from the task's checklist): medication status "Kicking In"/"Active", "8h Sleep", focus "Locked In", month selector, "24 check-ins", weekday dominant level, connection unlock thresholds — none appear on the Settings frame (spec §6). "Installed" and "34MB" are covered above.

---

## 4. Navigation delta

| Aspect | Pen | Today | Delta |
|---|---|---|---|
| Tab bar | Floating white pill 346×60 r 75 at (28,1809), shadow `#183c28@16%` (0,8,24); active item = `#2a9134` pill 118×44 with **bold** vuesax `setting-2` 24 white + "Settings" 12/500 white; inactive = outline/linear icons `#999b9d`, **no labels**. Variant `Status=Settings, Mode=Light`. | Native `TabView(selection:)` with four `.tabItem { Label(_, systemImage:) }` (`RootTabView.swift:19-35`), `.tint(Theme.meadowGreen)` (:36); every root forces an **opaque** `NewLook.screen` bar via `.toolbarBackground(…, for: .tabBar)` + `.toolbarBackgroundVisibility(.visible, for: .tabBar)` (`ScreenContainer.swift:57-60`). SF Symbols `calendar` / `checkmark.circle` / `chart.bar.fill` / `gear` (`Icons.swift:5-9`); labels always shown. | **NEW global chrome**: either (a) keep `TabView` for state/lifecycle, hide its bar (`.toolbarVisibility(.hidden, for: .tabBar)` on each root) and overlay a custom pill bar + FAB in `RootContainerView`, or (b) native iOS 26 tab bar with green tint (not what is drawn). Icon set change (vuesax vs SF) is file-wide. Inactive icons at `#999b9d` = 2.79:1 (below 3:1 non-text). Counted outside this screen's estimate. |
| FAB | 50 Ø `#8c68d3` at (309,1745), `vuesax/twotone/add`, shadow `#000000@17%` (0,7,17); floats above the nav's right end; overlaps the Your Data card by 35 pt at scroll end (JSON). | None. | **NEW global**. Action undefined (Q-L1); at rest it covers the Confirmations toggle (spec §2.10). |
| Screen title / back | Large in-content title; no nav bar, no back pill (root tab). | `NavigationStack` with inline empty title (`ScreenContainer.swift:49-52`); system back appears on pushed `AcknowledgementsView` (`YourDataSection.swift:43`, `ScreenContainer(title: "Acknowledgements")`). | Root: matches (no back). Pushed Acknowledgements/legal screens would inherit the pen's **back pill** grammar (design-system.md §4.5) — undrawn for Settings' children. |
| Scroll container | One `ScrollView`, 7 card groups, content 159→1780, floating chrome pinned. | `List` (`.insetGrouped`) with `ScrollViewReader` anchors `settings-top` / `settings-my-medication` (`SettingsView.swift:33-34,48-54,74-92`). | Port scroll-to-top-on-tab-select and the intent focus anchor to `ScrollView` + `ScrollPosition`/`.scrollTo(id:)`; `ScreenContainer` already owns a `ScrollPosition` when `scrollable: true` (`ScreenContainer.swift:37,68-78`) — Settings could switch to `scrollable: true` and drop its own reader, but then the fade mask (:78) and inset need the pen's 170 pt bottom clearance. |
| Sheets / alerts / dialogs | None drawn. | `.alert("Clear All Data?")` (:96-103), `.fileExporter` (:104-117), `.sheet(RecoveryKeySheet)` (:118-120), `.alert("Couldn't save a copy")` (:121-125), `ModelDownloadRow` `confirmationDialog` "Delete Model" (`ModelDownloadRow.swift:30-37`). | All belong to rows the pen omits; they survive if those rows are kept. No pen language for alerts/sheets exists. |
| Medication bar overlay | Not drawn. | `safeAreaInset(edge: .top)` `MedicationBarView` (`ScreenContainer.swift:79-82`). | Ambiguous (§2.0). |
| Tint | green-500 `#2a9134`. | `Theme.meadowGreen` `#5F8A4C` on the stack and TabView (`ScreenContainer.swift:56`, `RootTabView.swift:36`). | Token swap (global). |

---

## 5. Accessibility · Dynamic Type · dark mode (this screen)

**Controls**
- The pen replaces three native controls — `Toggle` (10 instances, 2 sizes: 34×18.31 and 42×22.62), segmented `Picker` (Blocked for), and a `Picker` (Prompt Pace) — plus the checkmark rows with a 20 Ø radio. iOS's switch is 51×31; every pen control is under the 44×44 pt floor (PRODUCT.md). Recommendation to carry into the plan: **native `Toggle` with `.tint(green-500)`** (keeps VoiceOver "switch, on/off", Switch Control, and the HIG size for free; the pen's knob shadow and pill shape are what iOS draws anyway) and **one size**. If the owner insists on the drawn sizes, the row must be the hit target (`.contentShape(Rectangle())` + `.frame(minHeight: 44)`), with `.accessibilityRepresentation { Toggle(...) }`.
- Radio group: keep today's `Button` rows with `.accessibilityAddTraits(.isSelected)` and hints (`DoseGuardSection.swift:39-40`) — they already meet the semantics; wrap the three in `.accessibilityElement(children: .contain)` labelled "Dose Guard" so VoiceOver announces the group.
- Chips (27 pt tall): the Prompt Pace pair and the 1h–4h quartet need ≥ 44 pt tappable frames and `.accessibilityAddTraits(.isSelected)`; consider `.accessibilityRepresentation { Picker(...) }` so the group reads as one picker.
- Section headings: native `Section` headers carried the header trait implicitly; custom 16/600 headings must add `.accessibilityAddTraits(.isHeader)`. Same for the page title (the screen currently has **no** heading at all because the nav title is `""`).
- Toggle rows with a description: `.accessibilityElement(children: .combine)` so title + description + state read as one element (precedent: `confirmationBanner` a11y label, `MyMedicationSection.swift:165-166`).
- Existing hints to preserve verbatim: `DayCardSettingsSection.swift:15,20`; `MedicationBarSettingsSection.swift:13,19`; `MyMedicationSection.swift:69`; `DoseGuardSection.swift:55,82-88`; `ModelDownloadRow.swift:70-72,160-189`.

**Dynamic Type** (pen is Inter at fixed sizes; app roles scale via `UIFontMetrics`, `Typography.swift`)
- Role mapping that keeps scaling: 34/600 → `Typography.text(34, .semibold, relativeTo: .largeTitle)` (`largeTitle` is bold 700, weight mismatch) · 16/600 heading → `Typography.headline` (16 semibold ✓) · 16/500 subtitle → `text(16, .medium, .body)` · 14/600 → `text(14, .semibold, .subheadline)` (`subheadline` is medium) · 14/500 → `Typography.subheadline` ✓ · 14/400 → `text(14, .regular, .subheadline)` · 12/500 → `Typography.label` ✓ (no uppercase) · 12/400 → `Typography.caption` ✓.
- The two fixed-height text boxes (Dose Guard footnote 283×45, Accessibility 283×51) must hug: `.fixedSize(horizontal: false, vertical: true)`. The PNG already shows them collapsing at 1× (spec Open Q1).
- Trailing-control rows ("Name medication in confirmations" 229 wide + 34 toggle, "Show Medication Name" 159 wide) collide first at larger sizes: switch the `HStack` to a `VStack` at `dynamicTypeSize >= .accessibility1` (precedent `CalendarHeaderView:20` per code map §4). `ModelDownloadRow` already reflows its pills with `FlowLayout` (`ModelDownloadRow.swift:133-143`) — keep.
- Chip rows: 205 / 225 of 314 pt used at 1×; at AX sizes they need wrap (`FlowLayout`, `TagFlowView.swift`) — pen draws no wrap rule (design-system.md §7 item 10).
- The "34MB" value and the "Installed" status should use `.monospacedDigit()` as the code does for "17:42" and "NN%".

**Contrast (Frame 5 figures)**
- `#6a6d70` on white 5.21:1 ✓ (12 pt descriptions) · `#4d5154` 8.01 ✓ · `#212529` 15.43 ✓ · `#193024` ✓.
- `#2a9134` on white **4.04:1** ✗ at 12 pt for "Installed" → use green-600 `#26842f` (4.75) or green-700 `#1e6725` (6.95); white on `#2a9134` 4.04 ✗ for 12 pt chip labels and the nav "Settings" label (file-wide exception to rule on, spec Open Q16); `#999b9d` inactive tab icons 2.79 ✗ (<3:1 non-text); `#babbbd` OFF track 1.92 (conventional for switches).
- The pen retires `NewLook.inkSecondary` `#8A8A8E` (3.4:1, owner-accepted 2026-07-12) on this screen — `#6a6d70` is compliant; that is an improvement worth logging.

**Dark mode** — the pen is light-only (Frame 4 variant name `Mode=Light` implies a dark nav exists; nothing else). Today every token is `Color(lightHex:darkHex:)` with derived dark values (`NewLook.screen` dark `#12140F`, `card` `#1C1E19`, `hairline` `#33362F`; code map §3.1). For this screen the plan must derive: ground `#fbfffc` → ?, card `#ffffff` → ?, the 0.5 pt `#000000@10%` stroke and 1 pt dividers → white-alpha equivalents, `#183c28@8%` shadows (invisible on dark — drop or lighten), violet-50 preview chip `#f4f0fb` → a dark violet tint (precedent `Palette.medication` dark `#957BC1`), the pure-black accessibility figure → ink token, toggle OFF `#babbbd` → darker grey. Precedent: spec 033 "Figma specs light only; dark is derived" — same ruling, documented per token.

**Motion** — nothing specified. Keep today's Reduce-Motion gating (`reduceMotion ? nil : Motion.snappy` on radio/med-picker changes, `DoseGuardSection.swift:16`, `MyMedicationSection.swift:23,50,111,134`; scroll `SettingsView.swift:76,89`) and gate chip/toggle fill animations the same way.

---

## 6. Risks and open questions

### Risks
1. **The pen Settings is incomplete against product rules, not just restyled.** Implemented literally it removes: journal export (CLAUDE.md "Export is never gated" — non-negotiable), Privacy Policy (privacy-sequencing hard gate), Restore purchases (App Review 3.1.1, on feat/055), the medical disclaimer (1.4.1 rationale, `MedicalInfoSection.swift:3-5`), Clear All Data, the LLM model row (only way back after "Skip for Now", `AppSettings.swift:28-31`), and My Medication (App Intent continuation target, `LogDefaultDoseIntent.swift:31-37` → `SettingsView.swift:86-92`). The spec must add these as required rows before `/speckit-plan`.
2. **Undrawn model-row states.** Not-installed / downloading / error / delete are the hardened, failure-prone paths (specs 041/044; `ModelDownloadRow.swift:44-51,89-158`). Shipping the pen's single "Installed" look without the others regresses onboarding recovery. Design them first.
3. **Reverses a logged decision.** DESIGN.md 2026-06-24 kept Settings on the native grouped `List` on purpose; `MyMedicationSection.swift:4` and `DoseGuardSection.swift:3` cite it. Needs a dated reversal in the new Decisions Log, and those doc comments go.
4. **Branch sequencing.** feat/055 (unmerged, 63 commits) mounts `SubscriptionSection` first, changes `YourDataSection` and the export button — all on this screen. PR #41 (open) also edits `SettingsView.swift`. Re-skinning on `main` now guarantees a three-way conflict; constraints §5.2 says 055 lands first, then re-cut.
5. **New DS components with no source component in the pen**: card (r 24/18 + stroke + `#183c28` shadow), Bill-shape chip with check-badge state, toggle S/L, radio, info row, preview chip. "Assuming tokens + shared components exist" in §7 assumes these are built in the tokens/chrome slice; if not, add ~8 h here.
6. **Preview chip fidelity.** The drawn preview ("09:54 • Concerta 36 mg") is not the string `DoseConfirmationCopy.text` produces ("Concerta 36 mg logged · 9:54 AM"/"09:54" per locale). A preview that misrepresents the lock-screen banner defeats the setting's purpose (discreet vs named).
7. **"Show Taken Time" / "Show End Time"** add persisted state and change `MedicationBarView`/`MedicationBarViewModel`, i.e. logic with tests (`MedicationBarViewModelTests`, 14 tests) — test-first under Principle X, and the bar design on the other frames does not show an end time to toggle.
8. **`Color.accentColor`** (`DoseGuardSection.swift:34`, `MyMedicationSection.swift:94`) — asset catalog is bronze, live tint is meadow; the redesign replaces both uses, but device QA should confirm nothing else depends on the asset.
9. **Pen render ≠ JSON** (Dose Guard card 284 vs 312, Accessibility 45 vs 81): building from the PNG would bake in collapsed rows.
10. **Copy defects to normalise, not copy**: "Claendar", "Does", "Make The App Works For You", "mobile Data", Title Case vs sentence case, "34MB", "2h"/"2 h", "voice-model downloads" (wrong scope). Code copy is the baseline (`DoseGuardSection.swift:66-80`, `SettingsView.swift:179,198`).
11. **Existing tests** stay green if the VM is untouched (`SettingsViewModelTests`, 22; `AppSettingsTests`, 4; `ConfirmationCopyTests`); no view tests exist for Settings (code map §8), so the restyle is verified by build + simulator + device QA only.

### Open questions for the owner (only the ones that block the spec)
1. Which of the undrawn rows are deliberate cuts vs still-to-draw: LLM model row · My Medication picker · Medication info · Journal export · Clear All Data · Privacy Policy / Terms · Version · Subscription/Restore? Export, Privacy and Restore are non-negotiable — who designs them, in the pen language?
2. Model row states: approve a design for not-installed (size + Wi-Fi line), downloading (progress + Cancel), error (message + Try again / Allow on cellular / Open Settings) and delete; and the LLM row's own size copy (~740 MB).
3. Toggles: native `Toggle` tinted green-500 (one size, 44 pt, VoiceOver for free) or the drawn custom 34×18 / 42×22 pair?
4. Confirm the reversal of the 2026-06-24 "Settings stays native `List`" decision, to be logged.
5. "Show Taken Time" / "Show End Time": what exactly do they toggle on the bar (title line? a trailing end-time?), and do rows 2–4 hide/disable when "Show Medication Bar" is off (code hides "Show Medication Name")?
6. Preview chip: mirror `DoseConfirmationCopy` exactly (order, "logged", locale time) or keep the drawn layout; what does OFF show; fixed sample time vs now vs last dose?
7. "Acknowledgement" row: opens open-source credits, the privacy policy, or a data explainer? Where do Privacy Policy / Terms rows go (055 makes them in-app `LegalDocumentView`)?
8. "Blocked For" chips when mode ≠ Time Window: hidden (code), disabled, or always shown? Footnote per mode (3 variants) or only the window one?
9. FAB on Settings: what does "+" do (new check-in via `router.requestCheckIn()`?), and accept that at rest it covers the Confirmations toggle, or add a bottom inset ≥ 170 pt / move it?
10. Keep the medication-bar overlay on Settings (it is just absent from the mock) or drop it here?
11. Copy policy for this screen: sentence case (code) vs Title Case (pen); keep the recording count; "34 MB" via formatter.
12. Dark mode: derive per token now (spec-033 precedent) or ship light-only for the first refresh build?
13. Contrast: darken 12-pt green text ("Installed") to green-600/700, and rule on white-on-green-500 labels?

---

## 7. Effort — senior SwiftUI engineer, tokens + shared components (card, Bill-shape chip incl. check state, toggle, radio, section heading, page-title block, custom tab bar, FAB) already built

| Bucket | Item | Hours |
|---|---|---|
| **NEW** | Settings scaffold: `List` → `ScrollView` + card groups; port scroll-to-top and My-Medication focus anchor to `ScrollPosition`; bottom inset for floating chrome | 3.0 |
| NEW | Page title block + subtitle (header trait) | 0.5 |
| NEW | `ModelDownloadRow` rewrite in the new language incl. all four states + delete dialog + VoiceOver actions (both rows) | 4.0 |
| NEW | Confirmation preview chip (violet-50 chip, white capsule badge, new capsule vector, OFF state, shared formatter with `DoseConfirmationCopy`) | 1.5 |
| NEW | Info row (icon + hugging note) used by Dose Guard footnote and Accessibility | 1.0 |
| NEW | "Show Taken Time" / "Show End Time": 2 keys, `titleLine`/bar rendering, empty-title rule, VM tests first | 3.0 |
| NEW (contingent on owner designs, Q1) | Rows the pen omits but must ship: My Medication chip flow (3.0) · export row + `RecoveryKeySheet` restyle (2.0) · Clear All Data + version + Privacy/Terms/Acknowledgements rows (2.0) · Medication info (0.5) | 7.5 |
| **CHANGE** | Check-In Calendar card (chips + 2 toggle rows, reorder, divider) | 1.5 |
| CHANGE | Voice & Storage card (storage row, cellular row + description, dividers) | 1.0 |
| CHANGE | Confirmations card (top-aligned toggle row + description) | 1.0 |
| CHANGE | Dose Guard card (3 radio rows, 4 chips w/ check, conditional rules, 3 footnotes) | 2.5 |
| CHANGE | Medication Bar card (4 large-toggle rows, dividers, dependency rule) | 1.0 |
| CHANGE | Accessibility + Your Data cards | 1.0 |
| CHANGE | Dynamic Type / AX layouts (stack at AX1+, chip wrap, hugging text), VoiceOver headings + combined rows | 3.0 |
| CHANGE | Dark-mode pass for this screen's derived tokens | 2.0 |
| **REMOVE** | Delete `List` sections, SF-icon `Label`s, dead "Installed" branch, `SettingsChip`; update doc comments citing the List decision | 1.0 |
| Verification | Build, simulator run at 1× / AX5 / dark, full test run, device-QA checklist for the owner | 2.0 |
| | **Total** | **≈ 36.5 h** (≈ 29 h without the contingent undrawn rows; ± 20 %) |

Excluded: the custom tab bar + FAB (global chrome slice), the token set (`#fbfffc`, green/violet/grey ramps, card modifier, chip/toggle/radio components), and any spec/mockup/plan writing. If the shared card/chip/toggle/radio components do **not** exist when this slice starts, add ≈ 8 h.
