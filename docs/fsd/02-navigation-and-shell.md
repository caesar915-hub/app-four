<!-- Created: 2026-07-27 15:10 (WEST) · Updated: 2026-07-27 15:10 (WEST) -->
# 02 — Navigation & App Shell

## Purpose

Covers everything between process launch and the first interactive screen: startup sequencing, SwiftData container open and recovery, the four-tab root shell, the first-run onboarding gate, the background Whisper model download, and all external entry points (deep link, App Intents) that route into the app.

## Scope

- **In scope:** `SquirlApp` startup and scene setup; `AppModelContainer` open/failure ladder; `RootTabView`; onboarding (`RootContainerView`, `WelcomeView`, `WelcomeViewModel`); background model download policy; `AppIntentRouter`; `StartCheckInIntent`; `LogDefaultDoseIntent`; `DoseConfirmationCopy`; the `whispernotes://checkin` deep link.
- **Out of scope:** the capture flow itself ([03-check-in-capture.md](03-check-in-capture.md)); transcription/extraction ([04-processing-and-extraction.md](04-processing-and-extraction.md)); medication dose-guard rules ([07-medications.md](07-medications.md)); schema details ([09-data-model.md](09-data-model.md)).

## Actors & triggers

- **User** — launches the app; completes onboarding; taps tabs.
- **System / OS** — foregrounds the app for a `.foreground` App Intent; delivers `scenePhase` changes; delivers `onOpenURL` deep links; data-protection lock state during pre-unlock background launches.
- **App Intents** — `StartCheckInIntent` (foreground), `LogDefaultDoseIntent` (background-first). Both are **implemented, dormant in 1.0** (`isDiscoverable = false`, no `AppShortcutsProvider`).
- **Deep link** — `whispernotes://checkin`.
- **Timers/async streams** — `connectivity.interfaceChanges` gating a deferred model download.

## Functional requirements

### Startup

**FR-NAV-01 — Storage migration runs first, unconditionally.**
Before any store or service reads disk, `init()` calls `StorageMigration.run()`, which relocates pre-1.0 user data out of the Files-app-exposed Documents directory. Documented as idempotent (`SquirlApp.swift:14`).

**FR-NAV-02 — DEBUG mock-mode default.**
In DEBUG builds, unless running under XCTest (detected via `ProcessInfo` environment key `XCTestConfigurationFilePath`), the app registers the `UserDefaults` default `"debugMockMode": true` before `AppDependencies.store` is first touched (the store reads the key eagerly), so a cold dev launch lands on a populated timeline (`SquirlApp.swift:15-22`).

**FR-NAV-03 — RELEASE mock-mode cleanup.**
In RELEASE builds, the app unconditionally removes any persisted `debugMockMode` key, so a container that ever ran a Debug build does not hide real recordings behind the mock filter (`SquirlApp.swift:23-30`).

**FR-NAV-04 — Store warm-up and metrics bootstrap.**
`init()` touches `AppDependencies.store` so stores begin observing the database, and starts `MetricManager.shared` (`SquirlApp.swift:32-33`).

**FR-NAV-05 — Background-intent dependency registration.**
`doseLogService` and `appIntentRouter` are registered with `AppDependencyManager.shared` using eagerly captured values (not MainActor-isolated accessors), because a background intent launch runs this `init()` first (`SquirlApp.swift:38-41`).

### Container open & recovery

**FR-NAV-06 — Store open: preflight and privacy.**
Opening the container: pre-creates the Application Support store directory (avoids first-launch CoreData diagnostic noise); runs `recoverInterruptedQuarantine(storeURL:)` to self-heal a quarantine cycle that died mid-flight (crash/jetsam); and on successful open sets `NSURL.isExcludedFromBackupKey = true` on the store directory — transcript and medication data are treated as sensitive health information (`AppModelContainer.swift:16-30`).

**FR-NAV-07 — DEBUG seeding.**
DEBUG only: if the `Recording` fetch count is 0, the container seeds `MockDataGenerator.generate(context:)` — 10 days of dummy data. Never in release (`AppModelContainer.swift:33-40`).

**FR-NAV-08 — Open-failure ladder (release: quarantine, never delete).**
On primary open failure (`AppModelContainer.swift:45-89`):

1. **DEBUG:** wipe the store trio (schema-churn convenience) and retry (`AppModelContainer.swift:50-55`).
2. **RELEASE:** if `isStoreContentReadable` is true (the store can be opened for reading but was rejected — genuinely unopenable, as opposed to data-protection-locked), quarantine the store trio — **rename, never delete** — into `Quarantine/<ISO8601-stamp with ":"→"-">/` under a `pending` marker, then retry a fresh open. If the retry also fails, `undoQuarantine` restores the original files (`AppModelContainer.swift:56-78`). A locked/unreadable store (pre-unlock background launch) is left untouched and degrades to in-memory (`AppModelContainer.swift:57-63` comment).
3. **Last resort:** run on a non-persistent in-memory container with `isEphemeral = true`; the `try!` is justified as impossible to fail on a valid schema. Launch never crashes; on-disk data is untouched or quarantined — never deleted in release (`AppModelContainer.swift:80-88`).

Quarantine protocol details: the marker is committed before any file move; sidecars (`-wal`, `-shm`) move before `default.store` so a snapshot containing the store file is provably complete; `undoQuarantine` sets aside (renames to `dead-<stamp>/`, never deletes) live files when restoring; `recoverInterruptedQuarantine` reads the marker on next launch and hands the marked snapshot to `undoQuarantine` (`AppModelContainer.swift:105-249`).

**FR-NAV-09 — Ephemeral-mode surfacing.**
`AppModelContainer.isEphemeral` (`static private(set) var`, default `false`) is true when the primary store could not be opened and the app runs on the in-memory container. Writes in this state do not survive relaunch; the UI is expected to surface this condition (`AppModelContainer.swift:6-10`).

### Tab shell

**FR-NAV-10 — Four-tab root.**
The root UI is `RootTabView` with `enum Tab: Hashable { calendar, checkIn, insights, settings }` (enum-keyed tags, "no magic integers"). Tabs (`RootTabView.swift:5-35`):

| Tab | Content | Item label |
|---|---|---|
| `.calendar` | `CalendarLibraryView` | `Label("Calendar", systemImage: Icons.calendar)` |
| `.checkIn` | `CheckInView(store:services:shouldAutoStart:)` | `Label("Check in", systemImage: Icons.checkIn)` |
| `.insights` | `InsightsView` | `Label("Insights", systemImage: Icons.insights)` |
| `.settings` | `SettingsView` | `Label("Settings", systemImage: Icons.settings)` |

Tab tint is `Theme.meadowGreen` (`RootTabView.swift:36`). The default selected tab at launch is `.calendar` (`SquirlApp.swift:7`). `RootTabView` takes `@Binding selectedTab: Tab` and `@Binding shouldAutoStartRecording: Bool` from the app scene (`RootTabView.swift:12-16`, `SquirlApp.swift:7-8, 46-49`).

### Onboarding / first run

**FR-NAV-11 — Onboarding gate.**
`RootContainerView` queries `AppSettings` and computes `hasCompletedOnboarding = settingsQuery.first?.hasCompletedOnboarding ?? false`. On `.task` it sets `showOnboarding = !hasCompletedOnboarding`; when true, a `fullScreenCover` presents `WelcomeView` over `RootTabView`. `.onChange(of: hasCompletedOnboarding)` dismisses the cover when the flag flips to true (`SquirlApp.swift:84-115, 131-133`).

**FR-NAV-12 — DEBUG onboarding bypass.**
In DEBUG, onboarding is skipped if launch arguments contain `-skipOnboarding` **or** `debugMockMode` is true (mock-dev mode implies a returning user) (`SquirlApp.swift:106-114`).

**FR-NAV-13 — Welcome screen content (exact copy).**
A single first-run screen — warm background, breathing `CrescentRing` hero (232×232 pt, `accessibilityHidden(true)`), no microphone step, no model-download gate (permission is just-in-time; the model downloads in the background). Exact strings (`WelcomeView.swift:42-64`):

- Headline: **"Welcome to Squirl"** (`Typography.largeTitle`, `.isHeader` trait)
- Subhead: **"A calm place to speak your day. Everything stays on this device."**
- Caption: **"Squirl is a journal — it doesn't give medical advice."**
- Button: **"Start"** (style `.checkInPrimary`), accessibility hint **"Opens your check-in"**

Layout: `GeometryReader` + `ScrollView` with `minHeight: geo.size.height` so the crescent and Start button stay reachable under large Dynamic Type (AX5); background `NewLook.screen.ignoresSafeArea()`; content capped at `Metrics.maxContentWidth` (`WelcomeView.swift:23-31`).

**FR-NAV-14 — Completion is resilient.**
Tapping Start: `Haptics.success()`, then `withAnimation(Motion.smooth) { viewModel.complete(modelContext:) }`, then `onComplete()` — the cover dismisses immediately without waiting on persistence (`WelcomeView.swift:70-76`). `WelcomeViewModel.complete` fetches existing `AppSettings` (sets `hasCompletedOnboarding = true`, else inserts a new `AppSettings(hasCompletedOnboarding: true)`) and saves via a `try?` — **a save failure is swallowed and `didComplete` is still set true; the user is never stranded on an undismissable cover** (`WelcomeViewModel.swift:21-30`). The operation is idempotent. A `@ObservationIgnored var persist` closure is the test seam (`WelcomeViewModel.swift:19`).

### Background model download

**FR-NAV-15 — Download never gates first-run UI.**
After onboarding dismisses, `RootContainerView` kicks off the Whisper model download exactly once per launch (`@State downloadKicked`). If `aiModelService.localPath(for: .whisper) != nil`, nothing happens. Otherwise it downloads via `aiModelService.download(.whisper)`, consumes the progress stream, and afterwards drains the pending-transcription queue (`SquirlApp.swift:117-167`). Download failure is only logged (`"Background model download failed: \(error)"`) — never surfaced as a first-run error; the model stays retryable from Settings (`SquirlApp.swift:162-166`).

**FR-NAV-16 — Interface policy for downloads.**
`NetworkConnectivity.shouldStartDownload` (`NetworkConnectivity.swift:38-44`): `.unsatisfied` → false; `.cellular` → the user's `downloadOverCellular` preference (re-read live on each call, so toggling it on unblocks a deferred download); `.wifi` / `.other` → true. Preference default when no `AppSettings` row exists: `false` (`SquirlApp.swift:169-176`). If the current interface forbids the download, the app waits on `connectivity.interfaceChanges` until a permitted interface appears, then re-checks the model still is not installed before downloading (`SquirlApp.swift:148-155`). `NetworkInterface` cases: `wifi`, `cellular`, `other`, `unsatisfied` (`Protocols.swift:9-14`).

**FR-NAV-17 — Pending-transcription drain triggers.**
The pending-transcription queue is drained on launch (`.task`), on every foreground (`scenePhase == .active`), and on background-download completion (`SquirlApp.swift:125-130, 161`). The drain itself no-ops unless the model is installed and coalesces concurrent triggers into a single serialized pass; see [04-processing-and-extraction.md](04-processing-and-extraction.md).

### External entry points

**FR-NAV-18 — Single choke point: AppIntentRouter.**
`AppIntentRouter` (`@Observable @MainActor`) is the single cross-surface trigger/navigation choke point shared by App Intents and the legacy deep link (`AppIntentRouter.swift:11-21`). State: `selectedTab: Tab = .calendar`; `private(set) shouldStartCheckIn = false`; `private(set) shouldFocusMyMedication = false` (`AppIntentRouter.swift:23-26`). Triggers are **one-shot**: `consumeCheckIn()` returns the flag once and clears it (`defer`), so a stale trigger can never re-fire (`AppIntentRouter.swift:48-52`); `consumeMyMedicationFocus()` is the equivalent consumer for the settings focus (`AppIntentRouter.swift:59-63`).

**FR-NAV-19 — Strict onboarding gate for external triggers.**
`requestCheckIn() -> CheckInStart` (`enum CheckInStart { started, gatedOnboarding }`): if onboarding is incomplete it returns `.gatedOnboarding` **without arming anything**; otherwise it sets `selectedTab = .checkIn`, `shouldStartCheckIn = true`, and returns `.started` (`AppIntentRouter.swift:40-46`). The gate is an injected `isOnboardingComplete: @MainActor () -> Bool` closure that **defaults to `true`** so tests/previews arm normally; production injects a live SwiftData read of `AppSettings.hasCompletedOnboarding` (`AppIntentRouter.swift:28-35`). This gate applies to the deep link as well as the intents.

**FR-NAV-20 — Scene-level trigger consumption.**
In the app scene: `.onChange(of: router.shouldStartCheckIn)` — when armed and `router.consumeCheckIn()` returns true, sets `selectedTab = .checkIn` and `shouldAutoStartRecording = true` (`SquirlApp.swift:66-70`). `.onChange(of: router.shouldFocusMyMedication, initial: true)` — switches `selectedTab = .settings` when armed; `initial: true` covers a trigger armed before the body attached (background intent launch); consumption is left to `SettingsView` (`SquirlApp.swift:71-79`).

**FR-NAV-21 — Deep link.**
`.onOpenURL` accepts only `whispernotes://checkin` (scheme `whispernotes`, host `checkin`) and routes through `router.requestCheckIn()` — the same choke point as the App Intent, so the FR-NAV-19 gate applies (`SquirlApp.swift:62-65`). All other URLs are ignored.

**FR-NAV-22 — StartCheckInIntent ("Check In").** *Implemented, dormant in 1.0.*
Title **"Check In"**; description **"Opens Squirl and starts a voice check-in, recording right away."** `supportedModes = .foreground` (the system foregrounds the app before `perform()`; default auth policy — foregrounding requires unlock). **`isDiscoverable = false`** — 1.0 ships hands-free check-in hidden (no `AppShortcutsProvider`; not discoverable in Shortcuts/Spotlight) pending device QA (`StartCheckInIntent.swift:9-21`). `perform()`: on `.started` replies with dialog **"Starting your check-in."** — the consume chain lands the app in Listening with recording active, and is a no-op if already recording; on `.gatedOnboarding` replies **"Finish setting up Squirl first."** — nothing is recorded and the app foregrounds to onboarding (`StartCheckInIntent.swift:25-37`).

**FR-NAV-23 — LogDefaultDoseIntent ("Log My Meds").** *Implemented, dormant in 1.0.*
Title **"Log My Meds"**; description **"Logs your default medication dose. Set the medication once in Squirl's settings."** `supportedModes = [.background, .foreground(.dynamic)]` — background by default; dynamic foreground only for the not-configured path. `authenticationPolicy = .alwaysAllowed` — locked Siri works; the worst case is journal pollution, nothing is read back. **`isDiscoverable = false`** (same 1.0 hiding) (`LogDefaultDoseIntent.swift:9-23`). `perform()` calls `service.logDefaultDose(now: .now)`, reads `service.namesMedicationInConfirmations()`, and builds the dialog via `DoseConfirmationCopy.text(for:named:)` (`LogDefaultDoseIntent.swift:28-33`). On `.notConfigured`: `try await continueInForeground(dialog, alwaysConfirm: true)` then `router.focusMyMedication()`; a declined or impossible transition is swallowed (`catch {}`) and the calm dialog stands — never an error surface (`LogDefaultDoseIntent.swift:35-43`). `DoseLogOutcome` cases: `.logged(name:dose:at:)`, `.guarded(activeSince:)`, `.notConfigured`, `.failed` (`DoseLogService.swift:5-16`).

**FR-NAV-24 — Dose confirmation copy (exact strings).**
`DoseConfirmationCopy.text(for:named:)` (`DoseConfirmationCopy.swift:8-20`):

- `.logged(name, dose, at)`: named → `"<name> <dose> logged · <time>"`; unnamed → `"Dose logged · <time>"`
- `.guarded(activeSince)`: `"Your <time> dose is still active."` — names the earlier dose's **time**, never the drug
- `.notConfigured`: `"Set your medication first."`
- `.failed`: `"Couldn't save that dose — nothing was logged. Try again in the app."`

Times use the system short time style (locale-aware 24h/AM-PM) via `date.formatted(date: .omitted, time: .shortened)` (`DoseConfirmationCopy.swift:22-25`). Confirmations never include journal content beyond the just-logged fact, and the `named` flag (the "Name medication in confirmations" setting) governs every surface uniformly (`DoseConfirmationCopy.swift:3-7`).

## User flows

### Cold launch, first run
1. `StorageMigration.run()` → release cleans `debugMockMode` → store open (with quarantine self-heal) → metrics start.
2. `hasCompletedOnboarding == false` → `WelcomeView` full-screen cover over the Calendar tab.
3. User taps **"Start"** → success haptic → flag persisted (failure swallowed) → cover dismisses.
4. Background: model download starts when the interface policy permits; pending queue drains afterwards.

### Cold launch, returning user
Onboarding cover is not presented; the app lands on the Calendar tab (`.calendar` default). Pending-transcription drain runs on launch and on each foreground.

### Deep link / intent check-in
1. `whispernotes://checkin` or `StartCheckInIntent` → `router.requestCheckIn()`.
2. Onboarding incomplete → `.gatedOnboarding`: nothing armed; intent replies "Finish setting up Squirl first."
3. Onboarding complete → router armed; scene observes, consumes one-shot, switches to the Check-in tab with `shouldAutoStartRecording = true`; capture auto-starts (see [03-check-in-capture.md](03-check-in-capture.md), FR-CAP-02).

## UI states

| State | Surface |
|---|---|
| First run | `WelcomeView` full-screen cover over `RootTabView` |
| Normal shell | Four tabs; default `.calendar`; tint `Theme.meadowGreen` |
| Ephemeral store | In-memory container; `isEphemeral = true`; UI expected to surface non-persistence |
| Model downloading | No first-run UI; progress consumed in the background; retryable from Settings |
| Intent gated | App foregrounds to onboarding; dialog "Finish setting up Squirl first." |

## Validation & constants

| Item | Value | Source |
|---|---|---|
| Default tab at launch | `.calendar` | `SquirlApp.swift:7` |
| Deep link | `whispernotes://checkin` (scheme + host) | `SquirlApp.swift:62-64` |
| Mock-mode key | `"debugMockMode"` (DEBUG default true; removed in release) | `SquirlApp.swift:20-29` |
| Onboarding skip launch arg | `-skipOnboarding` (DEBUG) | `SquirlApp.swift:110` |
| Welcome crescent size | 232×232 pt | `WelcomeView.swift:17, 37-39` |
| `downloadOverCellular` default (no settings row) | `false` | `SquirlApp.swift:173` |
| Store backup | store directory excluded from iCloud backup | `AppModelContainer.swift:28-30` |
| Quarantine location | `Quarantine/<ISO8601-stamp with ":"→"-">/` + `pending` marker | `AppModelContainer.swift:105-249` |
| Intent discoverability | `isDiscoverable = false` on both intents (dormant in 1.0) | `StartCheckInIntent.swift:18-21`, `LogDefaultDoseIntent.swift:20-23` |

## Edge cases

- **Store open fails (release, readable):** quarantine → retry → on retry failure, restore originals; never delete.
- **Store locked by data protection (pre-unlock background launch):** left untouched; degrade to in-memory ephemeral mode.
- **Quarantine interrupted mid-flight (crash/jetsam):** `recoverInterruptedQuarantine` completes the restore on next launch via the pending marker.
- **Onboarding save fails:** cover still dismisses; user is never stranded.
- **Trigger armed before scene body attached:** `initial: true` on the my-medication observer handles background intent launches.
- **Stale trigger re-firing:** impossible — consumption is one-shot (`defer`-cleared).
- **Deep link during onboarding:** gated identically to intents (`.gatedOnboarding`, nothing armed).
- **Cellular-only network with preference off:** download deferred until a permitted interface appears; preference re-read live.
- **Model deleted mid-download-wait:** the model-still-missing re-check runs before the download starts.

## Acceptance criteria

- A first-run launch shows the Welcome cover with the exact strings in FR-NAV-13; tapping Start dismisses it even if the settings save fails.
- A returning launch lands on the Calendar tab with no cover.
- In a release build, `debugMockMode` is absent from `UserDefaults` after launch; in a debug build (non-XCTest) a cold launch shows the seeded timeline.
- Corrupting the on-disk store and relaunching a release build results in a quarantined store trio (renamed, not deleted) and a working app; `isEphemeral` reflects any in-memory fallback.
- `whispernotes://checkin` on a fresh install does not start a check-in; after onboarding it switches to the Check-in tab and auto-starts recording. Any other URL is ignored.
- Both App Intents exist in the binary but are not discoverable in Shortcuts/Spotlight (1.0); invoking them programmatically produces the dialogs in FR-NAV-22/23/24.

## Source references

- `app-four/App/SquirlApp.swift:11-42` — startup sequence; `:44-81` scene body; `:62-65` deep link; `:66-79` trigger observers; `:84-134` onboarding gate; `:117-176` background download & interface policy
- `app-four/App/AppModelContainer.swift:6-10` ephemeral flag; `:13-90` container creation & failure ladder; `:105-249` quarantine protocol
- `app-four/Views/RootTabView.swift:5-36` — tab enum, four tabs, tint
- `app-four/Views/Onboarding/WelcomeView.swift:4-8, 17, 23-31, 37-39, 42-64, 70-76` — welcome design intent, layout, copy, start
- `app-four/Views/Onboarding/WelcomeViewModel.swift:9-30` — completion & swallowed save failure
- `app-four/Intents/AppIntentRouter.swift:6-9, 11-35, 40-63` — choke point, gate, one-shot consumption
- `app-four/Intents/StartCheckInIntent.swift:9-37` — title, modes, `isDiscoverable = false`, dialogs
- `app-four/Intents/LogDefaultDoseIntent.swift:9-43` — modes, auth policy, perform flow
- `app-four/Intents/DoseConfirmationCopy.swift:3-25` — exact confirmation strings, time formatting
- `app-four/Services/DoseLog/DoseLogService.swift:5-16` — `DoseLogOutcome` cases
- `app-four/Services/Connectivity/NetworkConnectivity.swift:38-44` — download interface policy
- `app-four/Services/Protocols.swift:9-14` — `NetworkInterface` cases
