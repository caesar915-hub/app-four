<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# 08 · Settings & Data Management

Documents branch `main` @ `43eb6515a63a0eca957a79aad257da380c73edd4`. Sibling documents: [Data Model](09-data-model.md) · [Architecture & Services](10-architecture-and-services.md) · [Non-Functional Requirements](11-nonfunctional.md).

## Purpose

Specify the Settings screen in full — every mounted section and control with its default, persistence target, and effect — plus the data-management surfaces reachable from Settings: Clear All Data, the encrypted journal export, the (dormant) feedback/issue-report flow, and the diagnostics subsystem that feeds it.

## Scope

- `SettingsView` and its mounted section views (`app-four/Views/SettingsView.swift`, `app-four/Views/Settings/*`).
- `SettingsViewModel` (`app-four/ViewModels/SettingsViewModel.swift`).
- Journal export (`app-four/Services/ExportService.swift`, `app-four/Views/Settings/JournalExportSection.swift`).
- Feedback/issue reporting (`app-four/Views/Feedback/*`) — gated and currently orphaned.
- Diagnostics (`app-four/Diagnostics/*`).
- Defined-but-unmounted settings sections (`MyMedicationSection`, `DoseGuardSection`, Confirmations toggle) — documented honestly as **Implemented, dormant in 1.0**.

Out of scope: capture-time constants (see 01-shell-capture notes / capture FSD), calendar/medication-bar runtime behavior beyond their settings toggles.

## Actors & triggers

| Actor / trigger | Enters via |
|---|---|
| User | Settings tab (`RootTabView`, tag `.settings`) |
| `LogDefaultDoseIntent` (not-configured path) | `router.focusMyMedication()` → Settings tab + scroll-to-My-Medication — **dormant**: no mounted view carries the `"settings-my-medication"` anchor on main, so the focus has no scroll target (`SettingsView.swift:35`, `:78-84`) |
| App Intent / background launch | Environment-injected singletons (`AppDependencies`) are already live |

## Functional requirements

### Screen structure

- FR-SET-01 — Settings renders as `ScreenContainer(title: "", showsMedicationBar: true, scrollable: false)` wrapping a `ScrollViewReader` + inset-grouped `List`, with hidden scroll background over `NewLook.screen` and rows on `NewLook.card`. The screen is tracked as `"SettingsView"` via `.trackScreen`. (`SettingsView.swift:46-64`, `:87`)
- FR-SET-02 — Mounted section order: **AI Models** → **System** → **Check-in** → **Calendar** → **Medication Bar** → **Medication info** → **Accessibility** → **Your data** → Journal export (unlabeled) → Danger (unlabeled) → Version footer. (`SettingsView.swift:48-61`)
- FR-SET-03 — Switching to the Settings tab scrolls back to top (anchor `"settings-top"`), unless a My-Medication focus is pending; scroll animations are gated on Reduce Motion (`Motion.smooth`). (`SettingsView.swift:65-84`)

### AI Models section

- FR-SET-04 — The section contains a single `ModelDownloadRow` titled **"Voice Transcription"** with icon `waveform`. Install state is **filesystem truth** (`aiModelService.localPath(for: .whisper) != nil`), never the SwiftData `ModelMetadata.isDownloaded` flag — "a SwiftData flag can lie if files were evicted, partially downloaded, or restored without metadata." (`SettingsView.swift:127-128`; `SettingsViewModel.swift:126-130`)
- FR-SET-05 — Idle state renders as a Toggle bound to `isInstalled`. Switching ON starts the download immediately; switching OFF opens confirmation dialog **"Voice Transcription Options"** with destructive **"Delete Model"** and **"Cancel"** — Cancel leaves the switch on. Accessibility hints: `"Removes the on-device transcription model"` / `"Downloads the on-device transcription model, about 150 megabytes"`. (`ModelDownloadRow.swift:30-37`, `:44-51`, `:66-73`)
- FR-SET-06 — When not installed and no error, the subline reads **"~150 MB · Wi-Fi recommended"**. Idle status dot: green (`Theme.statusDone`) **"Installed"** / amber (`Theme.statusInProgress`) **"Not installed"**. (`ModelDownloadRow.swift:82`, `:115-123`)
- FR-SET-07 — Downloading state shows a linear 80pt progress bar + `"N%"` (or a spinner + **"Starting…"** at 0 progress) and a **"Cancel"** button. Cancellation is treated as user cancel with no error surface. (`ModelDownloadRow.swift:89-109`; `SettingsViewModel.swift:132-162`, `:166-171`)
- FR-SET-08 — Download failure stores a `ModelDownloadFailure` and shows a red 8pt dot + red plain-language message + ghost-pill actions **"Try again"** and, only when the cause is `.cellularDisabled` (`canAllowCellular`), **"Allow on cellular"** (sets `downloadOverCellular = true`, syncs, retries) and **"Open Settings"** (opens `UIApplication.openSettingsURLString`). Ghost pills use `Metrics.minTapTarget` (44pt) and `FlowLayout` so they reflow at large Dynamic Type. (`ModelDownloadRow.swift:110-143`; `SettingsViewModel.swift:26`)
- FR-SET-09 — Per-cause error copy (`SettingsViewModel.message(for:)`, `:175-186`):

  | Cause (`ModelDownloadFailure`) | Exact message |
  |---|---|
  | `.noNetwork` | `"No connection. Reconnect to the internet, then try again."` |
  | `.insufficientSpace` | `"Not enough space on this device. Free up some room, then try again."` |
  | `.cellularDisabled` | `"You're on cellular and downloads over cellular are off. Switch to Wi-Fi, or allow cellular below."` |
  | `.other` | `"The download didn't finish. Try again in a moment."` |

  Unknown errors are mapped to `.other(String(describing: Swift.type(of: error)))` — content-free by design. (`SettingsViewModel.swift:158-161`; `Protocols.swift:142-147`)
- FR-SET-10 — Model deletion goes through `aiModelService.delete(_:)`; failure is only logged. After every download/cancel/delete the filesystem is re-checked. (`SettingsViewModel.swift:196-203`)

### System section

- FR-SET-11 — A read-only storage row shows `"N recording(s) · X.X MB"` — count from `viewModel.recordingCount`, MB from `storageUsedMB` (sum of recording `fileSize` values ÷ 1,048,576). (`SettingsView.swift:148-162`)
- FR-SET-12 — Toggle **"Download over Cellular"** (icon `antenna.radiowaves.left.and.right`), bound to `viewModel.downloadOverCellular`, persisted via `syncDownloadOverCellular()` → `AppSettings.downloadOverCellular`. **Default: false.** Effect: gates whether the Whisper model may download over a cellular interface via `NetworkConnectivity.shouldStartDownload` (`.unsatisfied` → false; `.cellular` → this preference; `.wifi`/`.other` → true). (`SettingsView.swift:148-162`; `NetworkConnectivity.swift:38-44`)

### Check-in section

- FR-SET-13 — Picker **"Prompt Pace"** offers all `PromptPace` cases: **"Relaxed · 10 s"** (default) and **"Brisk · 6 s"**, persisted via `syncPromptPace()` → `AppSettings.promptPaceSeconds` (raw `Int`, default 10). Footer: `"How long each prompt stays on screen during a voice check-in."` Effect: seconds each nudge prompt stays on screen during voice capture. (`SettingsView.swift:164-177`; `PromptPace.swift:3-14`)

### Calendar section

- FR-SET-14 — `Section("Calendar")` with two `@AppStorage` (UserDefaults) toggles whose keys are shared with `CalendarLibraryView` so changes apply immediately:

  | Label | Key | Default | Hint |
  |---|---|---|---|
  | `"Always expand cards"` (icon `rectangle.stack`) | `alwaysExpandCards` | `false` | `"When on, every day's check-ins stay open in the calendar."` |
  | `"Auto-expand selected day"` (icon `rectangle.expand.vertical`) | `autoExpandOnSelection` | `true` | `"When on, tapping a date opens that day's check-ins automatically."` |

  (`DayCardSettingsSection.swift:7-20`)

### Medication Bar section

- FR-SET-15 — `Section("Medication Bar")`:

  | Label | Key | Default | Hint | Visibility |
  |---|---|---|---|---|
  | `"Show Medication Bar"` (icon `pills.circle`) | `medicationBarVisible` | `true` | `"Shows a medication progress bar at the top of each screen."` | always |
  | `"Show Medication Name"` (icon `pill`) | `medicationBarShowName` | `true` | `"Displays the medication name and dose in the bar."` | only when the bar toggle is on |

  `medicationBarVisible` is read by `MedicationBarView` (`MedicationBarView.swift:8`). (`MedicationBarSettingsSection.swift:5-20`)

### Medication info section (disclaimer)

- FR-SET-16 — Header **"Medication info"**. Body: `"Squirl is a personal journal, not medical advice. Dose lists and effect times are typical values from the manufacturer's product information — your prescription and response may differ."` Footer: `"Talk with your clinician or pharmacist before changing how you take medication."` Exists for App Review guideline 1.4.1. (`MedicalInfoSection.swift:9-15`)

### Accessibility section

- FR-SET-17 — Informational text only: `"Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations."` (`SettingsView.swift:188-194`)
- FR-SET-18 — **Gap (honest documentation):** the medical-prompt opt-out (`UserDefaults.medicalPromptEnabled`, default `true`, biases the Whisper prompt toward ADHD/medication vocabulary; `Constants.swift:25-34`, `WhisperKitTranscriptionService.swift:130-136`) has **no visible toggle** in `SettingsView` on main, although the transcription service's comment says the opt-out lives in "Settings → Accessibility". The setting is effective (readable/writable via defaults, honored off-main by the transcription actor) but user-reachable only via defaults tooling. **Implemented, dormant in 1.0.**

### Your data section

- FR-SET-19 — When `AppModelContainer.isEphemeral` is true, a warning row (icon `exclamationmark.triangle`, `Theme.danger`) shows: `"Storage couldn't be opened this session, so new check-ins won't be saved. Restarting the app usually fixes this."` — the combined accessibility label is the same string prefixed with `"Warning:"`. (`YourDataSection.swift:10-20`)
- FR-SET-20 — A privacy restatement row: `"Your recordings, check-ins, and signals stay on this device. Nothing is uploaded."` (`YourDataSection.swift:22`)
- FR-SET-21 — A `Link` **"Privacy Policy"** (icon `hand.raised`) opens `https://squirl.pt/privacy`; a `NavigationLink` **"Acknowledgements"** (icon `heart`) pushes `AcknowledgementsView`, which lists one credit — **"WhisperKit"**: `"On-device speech recognition that turns your voice into text without leaving the device."` (`YourDataSection.swift:26-34`, `:41-66`)

### Danger section — Clear All Data

- FR-SET-22 — Row: destructive `Label("Clear All Data", systemImage: "trash")`. Confirmation alert: title **"Clear All Data?"**, message `"This permanently deletes all your recordings and check-ins. Your downloaded transcription model and preferences are kept. This can’t be undone."`, buttons **"Clear All Data"** (destructive) and **"Cancel"**. (`SettingsView.swift:91-98`, `:229-237`)
- FR-SET-23 — `SettingsViewModel.clearAllData()` deletes every recording via `storageService.deleteRecording` (so audio **files** are removed too — explicitly not `store.deleteRecording`), then fetches and deletes all remaining standalone `MedicationEvent` rows, saves, reloads the store, posts `.medicationEventsDidChange`, and refreshes the storage total. SwiftData cascade on `Recording` removes its segments, tags, and linked medication events. The downloaded model and all preferences are intentionally kept. (`SettingsViewModel.swift:218-232`)

### Journal export section

- FR-SET-24 — Row button `Label("Save a copy of my journal — yours to keep", systemImage: "lock.doc")` shows an inline `ProgressView` while preparing and is disabled during preparation. Footer: `"Saves one encrypted file you can keep or share. We’ll show you a key to open it — keep it safe. If you lose the key, the backup can’t be recovered — not even by us."` (`SettingsView.swift:196-211`)
- FR-SET-25 — Export produces one AES-GCM-sealed file (formatVersion 1 DTO graph — see [Encrypted export format](#encrypted-export-format) below). The bytes are wrapped in `EncryptedJournalDocument` (`readableContentTypes: [.data]`, write-only `FileDocument`) and presented via `.fileExporter` with default filename `"Squirl Journal yyyy-MM-dd"`. (`SettingsView.swift:213-227`; `JournalExportSection.swift:8-32`, `:99-104`)
- FR-SET-26 — **No import/restore path exists:** `EncryptedJournalDocument.init(configuration:)` throws `CocoaError(.featureUnsupported)` — "Import/restore is a future spec; this document is write-only for now." (`JournalExportSection.swift:17-20`)
- FR-SET-27 — The Recovery Key sheet is shown **only after a successful save** ("the user has the backup in hand before being shown its only key"). On export failure: alert **"Couldn’t save a copy"** / `"Something went wrong preparing your backup. Please try again."` / **"OK"**. (`SettingsView.swift:106-120`)
- FR-SET-28 — `RecoveryKeySheet`: NavigationStack sheet titled **"Keep this key safe"**; body `"This file can only be opened by a future version of Squirl, using this exact key. If you lose the key, the backup can't be recovered — not even by us. Save it somewhere only you can reach."` The Base64 key renders in `Typography.mono12`, `.textSelection(.enabled)`, on a `NewLook.tintNeutral` rounded card; accessibility label `"Recovery key"` with the key as value. (`JournalExportSection.swift:30-86`)
- FR-SET-29 — **"Copy key"** copies via `UIPasteboard` with `.localOnly: true` and a **120-second expiration**; the label flips to **"Copied"** with a checkmark. Toolbar **"Done"** dismisses. The key lives only in transient `@State` in `SettingsView` — never persisted (no Keychain, no UserDefaults, no file). (`JournalExportSection.swift:30-86`; `SettingsView.swift:13-20`)

### Version footer & debug entry

- FR-SET-30 — Centered footer `"<CFBundleDisplayName ?? Squirl> v<CFBundleShortVersionString ?? —>"`. In `DEBUG || TESTFLIGHT` builds only, **5 taps** on the version label opens the `TestServicesView` debug sheet (title **"Service Debug"**; the toolbar "Done" button is a no-op). (`SettingsView.swift:239-259`, `:88-90`; `TestServicesView.swift:154-156`)
- FR-SET-31 — The debug sheet offers: **Filesystem & Storage** ("Test Disk Check", "Create Fake Recording" — writes a fake temp .m4a saved as a 10 s recording, "Calculate Total Storage"); **Metadata & List** (recording count + title/filename rows from `@Query`); **Mock Data** ("Mock Mode" toggle `@AppStorage("debugMockMode")` default false, "Seed Mock Data", destructive "Wipe & Reseed"); **Exports & Actions** ("Export Last", "Delete All"); **Audio & AI Models** ("Test Whisper Status", "Start Real Recording" / "Stop Recording"); plus a red last-error section. (`TestServicesView.swift`)

### Dormant sections — Implemented, dormant in 1.0

- FR-SET-32 — `MyMedicationSection` (`app-four/Views/Settings/MyMedicationSection.swift:9`), `DoseGuardSection` (`app-four/Views/Settings/DoseGuardSection.swift:8`), and the **"Confirmations"** toggle section are **defined but NOT instantiated anywhere** in `SettingsView`'s List on main (zero instantiation sites). `SettingsView` still carries the plumbing: `medicationPickerExpanded` state (`:9`), the `"settings-my-medication"` anchor id (`:35`), and the `router.shouldFocusMyMedication` scroll/expand task (`:78-84`) — dead on main.
- FR-SET-33 — (Dormant) `MyMedicationSection`: header **"My Medication"**, footer `"Logged by the Log My Meds action — sticker, Siri, or Shortcuts. Only this medication and dose are recorded; changing it never alters past logs."` Accordion **"Medication"** row with three-state value (accent **"Set"** when unset; plain name when set without dose; purple semibold `"<name> · <dose>"` when both). Expanded: medication chips from `MedicationCatalog.all` (Concerta 18/27/36/54 mg, Ritalin 5/10/20 mg, Elvanse 20/30/40/50/60/70 mg), then dose chips. Picking a medication **nils the dose** (`medicationDidChange()` — "the default the hands-free action logs must be re-confirmed with an explicit dose tap — never auto-committed"). **"Clear Medication"** (destructive, visible only when set) clears name+dose. (`MyMedicationSection.swift:48-97`, `:182-201`; `SettingsViewModel.swift:97-107`)
- FR-SET-34 — (Dormant) **"Confirmations"** section: toggle **"Name medication in confirmations"** (icon `quote.bubble`), **default `false`**, persisted via `syncNameInConfirmations()` → `AppSettings.nameMedicationInConfirmations`. Footer: `"Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen)."` Live preview banner shows `"Dose logged"` when off, or `"<name> <dose> logged"` (example `"Elvanse 30 mg logged"` when unset) with fixed sample time `"· 17:42"`. (`MyMedicationSection.swift:64-75`, `:147-167`)
- FR-SET-35 — (Dormant) `DoseGuardSection`: header **"Dose Guard"**, three always-visible selectable rows (exactly one selected): **"Off"** / `"Every trigger logs"` (default, persisted raw `"off"`); **"Total"** / `"Blocked while a dose is still active"`; **"Time window"** / `"Blocked for a set time after a dose"`. When `.window`: inline segmented picker **"Blocked for"** with 1/2/3/4 hours (default 2 h from `AppSettings.doseGuardWindowHours`). Mode-aware footers always end with `"The in-app Log Dose sheet is never blocked."` Guard semantics: closed boundary, expedited logs (sticker/Siri/Shortcuts) only. (`DoseGuardSection.swift:13-58`, `:90-100`; `DoseGuardMode.swift:21-31`)

### Encrypted export format

- FR-SET-36 — `JournalArchive: Codable` is the plaintext that gets encrypted; it never touches disk unsealed. Shape: `formatVersion` (`currentFormatVersion = 1`, "bumped if the on-disk shape ever changes, so a future importer can branch"), `exportedAt: Date`, `recordings: [RecordingDTO]` (fetched sorted `createdAt` ascending). (`ExportService.swift:11-18`, `:123-141`)
- FR-SET-37 — `RecordingDTO` carries every `Recording` scalar (id, createdAt, updatedAt, audioFileName, duration, fileSize, status rawValue, fullTranscriptText, title, isFavorite, summary fields, all ADHD-journal fields including all JSON blobs) plus `audioBase64: String?` (Base64 of the audio file; nil for text check-ins and missing files), `segments: [SegmentDTO]`, `tags: [TagDTO]`, `medicationEvents: [MedicationEventDTO]` — DTOs mirror model attributes 1:1. (`ExportService.swift:20-91`)
- FR-SET-38 — Encryption: a fresh `SymmetricKey(size: .bits256)` from CryptoKit's CSPRNG is generated **per export and never persisted**. `AES.GCM.seal` with an auto random nonce produces the `combined` blob (nonce + ciphertext + tag); `combined == nil` → `ExportError.sealFailed`. `ExportResult` carries `data` + `key` + computed `keyBase64` "so callers never handle key material". JSON encoding runs on the main actor; sealing runs in a detached `.userInitiated` task. (`ExportService.swift:101-110`, `:123-211`, `:217-224`)
- FR-SET-39 — Size guard: the whole archive is buffered in memory (audio base64 + JSON + AES-GCM ≈ 3–4× raw audio); if `Σ max(0, fileSize)` exceeds **200 MiB** (`200 * 1_024 * 1_024`), export throws `ExportError.audioTooLarge(totalBytes:limitBytes:)` instead of risking an uncatchable OOM on the A14 minimum target. (`ExportService.swift:142-149`, `:226-234`)

### Feedback / issue reporting — gated and orphaned

- FR-SET-40 — All feedback UI lives under `app-four/Views/Feedback/`, wrapped in `#if DEBUG || TESTFLIGHT`. `FeedbackButton` (floating 48pt circular button, icon `exclamationmark.bubble`, accessibility label `"Report an issue"`) is **not mounted anywhere on main** — orphaned/dead UI. It was unmounted per spec 024 "because it crashed the app"; files retained. (`FeedbackButton.swift:3,32`; `SquirlApp.swift:58`)
- FR-SET-41 — (Dormant) `IssueReportView`: NavigationStack form titled **"Report Issue"** (inline), toolbar **"Cancel"** / **"Send"**; Send disabled while the trimmed description is empty. Sections: **"What went wrong?"** (TextEditor, min height 120); **"Auto-captured context"** (Screen from `ScreenTracker.currentScreen`, App Build `"<version> (<build>)"`, Device `UIDevice.current.model`, iOS version; from the latest snapshot: Thermal, `"Available RAM"` MB, and `"Last Whisper"` ms only when `whisperDurationMs > 0`); **"Include Sensitive Data?"** with three toggles **all default OFF** — `"Include Transcription Text"`, `"Include Summary Text"`, `"Include Audio File"` (each reveals a DisclosureGroup naming its attachment: `transcription.txt`, `summary.txt`, `audio.m4a`); **"Diagnostics"** with `"Include Recent Logs"` defaulting ON. (`IssueReportView.swift:6-132`)
- FR-SET-42 — (Dormant) Composition: plain-text body with `--- User Description ---`, `--- System Context ---`, `--- Attachments ---`. Attachments: `screenshot.png` (PNG of the key window) and, when logs are on, `sessions.json` (JSON `SessionSnapshotArchive` of the 5 recent snapshots). **Note:** transcription/summary/audio attachments are placeholders — `transcription.txt`/`summary.txt` contain literal bracketed placeholder text and `audio.m4a` is zero bytes ("real app would fill these from current recording"). (`IssueReportView.swift:144-216`)
- FR-SET-43 — (Dormant) Send path: if `MFMailComposeViewController.canSendMail()` → `MailComposeView` (plain-text, `isHTML: false`) to `"caesar915@icloud.com"`, subject `"Squirl Beta Feedback — Build <appBuild>"`; else share-sheet fallback. Mail result: `.sent` → dismiss; `.saved`/`.cancelled` → stay; `.failed` → share sheet. (`IssueReportView.swift:220-249`; `MailComposeView.swift`)
- FR-SET-44 — (Dormant) `ScreenshotCapture.capture()` sets `isCapturing = true`, sleeps 50 ms (one render cycle "so the feedback button hides"), then renders the key window via `UIGraphicsImageRenderer` + `drawHierarchy`. **Doc/code mismatch on main:** `FeedbackButton` claims it "hides itself during screenshot capture" but contains no such logic — if mounted, it would appear in captured screenshots. (`ScreenshotCapture.swift`; `FeedbackButton.swift:9`)

### Diagnostics

- FR-SET-45 — `SessionSnapshot` (`Codable, Sendable`): id, timestamp, thermalState (`"nominal"/"fair"/"serious"/"critical"/"unknown"`), availableMemoryMB (via `os_proc_available_memory()`), whisperDurationMs, transcriptionTokenEstimate, summaryTokenEstimate, iOSVersion (`"M.m.p"`), appBuild (`"<shortVersion> (<bundleVersion>)"`), screenName (default `"unknown"`). **Intentionally never includes transcript text, summary text, or audio file paths.** (`SessionSnapshot.swift:8-59`)
- FR-SET-46 — `DiagnosticsStore` (actor) keeps a rolling buffer of the last **50** snapshots (`maxSnapshots = 50`), persisted as plain JSON to `AppPaths.diagnostics/sessionSnapshots.json` — plain file, not SwiftData, to keep I/O off the main actor. API: `record(_:)` (append, trim oldest, atomic write via utility-priority detached task), `recentSnapshots(limit: 50)` (newest first), `clear()` (empties buffer + deletes file). Load/decode failures → empty, logged. Injected via `EnvironmentValues.diagnosticsStore`. (`DiagnosticsStore.swift:8-9`; `EnvironmentKeys.swift`)
- FR-SET-47 — `MetricManager` (singleton `.shared`, `MXMetricManagerSubscriber`) subscribes to MetricKit from `SquirlApp.init` (skipped under XCTest). It **only logs** payloads — no UI, no permission, no upload: jetsam counts, CPU-exception exits, cumulative disk writes MB, launch-metric presence, cellular-condition metrics; diagnostic payloads for hangs, CPU exceptions (duration + call stack), disk-write exceptions (MB + call stack). Rationale comment: MetricKit's 24 h delay can't catch per-operation timing/thermal/RAM (hence SessionSnapshot), and email was chosen over a backend because "the app has no backend and the prompt explicitly forbids auto-upload." (`MetricManager.swift:5-25`; `SquirlApp.swift:33`)
- FR-SET-48 — `ScreenTracker` (`@Observable @MainActor`) holds `currentScreen: String = "unknown"`, written by the `.trackScreen(_:)` modifier on view appear and read by the issue-report context and diagnostic snapshots. (`ScreenTracker.swift`; `View+Tracking.swift:6-19`)

## User flows

### Flow A — Install the transcription model from Settings
1. Settings → AI Models → toggle **"Voice Transcription"** ON.
2. Download starts; progress bar shows `"N%"` (or `"Starting…"`); user may **"Cancel"**.
3. On success the row flips to green **"Installed"** (filesystem re-check).
4. On failure the row shows the per-cause message (FR-SET-09) with **"Try again"**; if the cause is cellular policy, **"Allow on cellular"** / **"Open Settings"** also appear.

### Flow B — Export an encrypted journal backup
1. Settings → tap **"Save a copy of my journal — yours to keep"**; row shows progress, disabled meanwhile.
2. Service snapshots the model graph, encodes JSON, seals off-main (fresh AES-GCM key); guard aborts >200 MiB (FR-SET-39).
3. `.fileExporter` presents with default name `"Squirl Journal yyyy-MM-dd"`.
4. Only after a successful save: **"Keep this key safe"** sheet shows the Base64 key; user copies it (local-only clipboard, 120 s expiry) or selects it; **"Done"** acknowledges.
5. Failure path: **"Couldn’t save a copy"** alert; nothing is written, no key is shown.

### Flow C — Clear All Data
1. Settings → **"Clear All Data"** → confirm in the alert.
2. All recordings (rows + audio files), segments, tags, and medication events are deleted; the downloaded model and preferences survive; storage row refreshes to `0 recording(s)`.

### Flow D — Report an issue (DEBUG/TestFlight only, currently unreachable UI)
1. (If mounted) tap the floating feedback button → **"Report Issue"** sheet.
2. Describe the problem; optionally enable sensitive-data toggles (all OFF by default).
3. **"Send"** → mail compose to the beta address, or share-sheet fallback when mail is unavailable.

## UI states

| Surface | States |
|---|---|
| Model row | idle-installed / idle-not-installed (with `"~150 MB · Wi-Fi recommended"` subline) / downloading (`"N%"` or `"Starting…"`) / error (red dot + message + ghost pills) |
| Your data | normal / ephemeral-store warning row prepended |
| Export row | enabled / preparing (spinner, disabled) / failure alert / post-save key sheet |
| Recovery key sheet | `"Copy key"` / `"Copied"` (checkmark) |
| Issue report (dormant) | Send disabled while description empty; per-toggle DisclosureGroups; mail vs share-sheet |

## Validation rules & constants

| Item | Value | Source |
|---|---|---|
| Download over Cellular default | `false` | `AppSettings.swift:9` |
| Prompt Pace options / default | `relaxed = 10` ("Relaxed · 10 s", default) / `brisk = 6` ("Brisk · 6 s") | `PromptPace.swift:3-14` |
| `alwaysExpandCards` default | `false` | `DayCardSettingsSection.swift:12-15` |
| `autoExpandOnSelection` default | `true` | `DayCardSettingsSection.swift:17-20` |
| `medicationBarVisible` default | `true` | `MedicationBarSettingsSection.swift:10-13` |
| `medicationBarShowName` default | `true` | `MedicationBarSettingsSection.swift:15-20` |
| `medicalPromptEnabled` default (no visible toggle) | `true` | `Constants.swift:25-34` |
| Export format version | `1` | `ExportService.swift:13` |
| Export size guard | 200 MiB (`200 * 1_024 * 1_024`) summed `fileSize` | `ExportService.swift:142-149` |
| Export key | AES-256 (`SymmetricKey(size: .bits256)`), fresh per export, never persisted | `ExportService.swift:101-110` |
| Clipboard copy | `.localOnly: true`, 120 s expiry | `JournalExportSection.swift:30-86` |
| Default export filename | `"Squirl Journal yyyy-MM-dd"` | `SettingsView.swift:99-104` |
| Debug entry | 5 taps on version label, `DEBUG \|\| TESTFLIGHT` only | `SettingsView.swift:252-254` |
| Diagnostics buffer | last 50 snapshots, JSON at `AppPaths.diagnostics/sessionSnapshots.json` | `DiagnosticsStore.swift:9` |
| Sensitive-data toggles (dormant issue report) | all default OFF; `"Include Recent Logs"` default ON | `IssueReportView.swift:14-18` |
| Storage display | MB = Σ`fileSize` ÷ 1,048,576 | `SettingsView.swift:148-162` |
| Dose-guard window options (dormant) | 1/2/3/4 h, default 2 h | `DoseGuardSection.swift:43-58` |

## Edge cases

- **Model files evicted/restored without metadata** — install state follows the filesystem, so the row self-corrects (FR-SET-04).
- **Download failure of unknown type** — mapped to `.other(<type name>)`; message is generic, never leaks error internals (FR-SET-09).
- **Cellular toggle mid-download-deferral** — `shouldStartDownload` re-reads the preference live, so enabling cellular unblocks a deferred background download (`SquirlApp.swift:169-176`).
- **Export with >200 MiB of audio** — refused up front with `audioTooLarge`; the failure alert (FR-SET-27) is the only surface.
- **Key sheet dismissed without copying** — the key is unrecoverable by design; the sheet copy states this twice ("not even by us").
- **Clear All Data with mock mode on** — deletes flow through the store's mock-partitioned view; standalone `MedicationEvent` rows are deleted without a mock partition filter (fetches *all* remaining standalone events).
- **Ephemeral session** — writes this session do not survive relaunch; the Your-data warning (FR-SET-19) is the only in-Settings surface.
- **Orphaned feedback button in screenshots** — the claimed hide-on-capture behavior is not implemented (FR-SET-44).

## Acceptance criteria

- Every mounted Settings control matches the labels, defaults, hints, and persistence targets in FR-SET-11…FR-SET-23.
- Turning the model toggle OFF requires the destructive confirmation; cancelling leaves the model installed.
- Each `ModelDownloadFailure` cause renders its exact string from FR-SET-09; `"Allow on cellular"` appears only for `.cellularDisabled`.
- An exported file is unreadable without the displayed key; the key appears nowhere on disk, in UserDefaults, or in the Keychain; clipboard copies expire after 120 s and are local-only.
- Exporting with summed audio > 200 MiB fails with the failure alert and writes nothing.
- Clear All Data empties the library and medication history, deletes audio files from disk, and preserves the model and all preferences.
- `MyMedicationSection`, `DoseGuardSection`, and the feedback UI remain unreferenced by any mounted view on main; this document marks them dormant, and any future mount requires an FSD update.
- Diagnostics snapshots contain no transcript text, summary text, or audio paths; the buffer never exceeds 50 entries.

## Source references

| Area | Files (branch `main`) |
|---|---|
| Settings screen | `app-four/Views/SettingsView.swift:9-259` |
| Settings VM | `app-four/ViewModels/SettingsViewModel.swift:7-232` |
| Model row | `app-four/Views/Components/ModelDownloadRow.swift:30-143` |
| Sections | `app-four/Views/Settings/{DayCardSettingsSection,MedicationBarSettingsSection,MedicalInfoSection,YourDataSection,MyMedicationSection,DoseGuardSection,JournalExportSection}.swift` |
| Export service | `app-four/Services/ExportService.swift:11-234` |
| Feedback | `app-four/Views/Feedback/{FeedbackButton,IssueReportView,MailComposeView,ScreenshotCapture,ShareSheetView}.swift` |
| Diagnostics | `app-four/Diagnostics/{SessionSnapshot,DiagnosticsStore,MetricManager,ScreenTracker}.swift` |
| Connectivity policy | `app-four/Services/Connectivity/NetworkConnectivity.swift:38-44` |
| Debug screen | `app-four/Views/TestServicesView.swift` |
| Constants | `app-four/Utils/Constants.swift:3-38`, `app-four/Models/PromptPace.swift:3-14`, `app-four/Models/DoseGuardMode.swift:6-31` |
