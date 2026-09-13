<!-- Created: 2026-07-31 00:03 (WEST) · Updated: 2026-08-31 01:18 (WEST) -->
# 13 — App Intents & NFC Sticker Actions

Documents branch `main` @ `73660ced44baeb65381efe699576cdf2b08847bc` (post-1.0-submission; includes merge `3ff74b5e` `feat/030-us3-us4` and `73660ced`). All `path:line` citations are against that commit — **later than the rest of this document set** (`43eb6515`); see the README's documented-source note. Derived from feature spec 030 (`specs/030-app-intents-foundation/`). Sibling documents: [Medications](07-medications.md) (catalog, `MedicationEvent`, in-app Log Dose sheet) · [Settings & Data](08-settings-and-data.md) (remaining Settings sections) · [Data Model](09-data-model.md).

## Purpose

Expose Squirl's two highest-frequency actions as system-level verbs any trigger surface can fire (spec 030, "App Intents Foundation + NFC Sticker Actions"):

1. **Log My Meds** — record a dose of the user's one configured default medication at trigger time, without the app visibly opening (US1).
2. **Check In** — open Squirl straight into the Listening state, already recording (US2).

Around them: a user-configurable **Dose Guard** against double-logging (US3), discreet-by-default confirmation copy, and a guided **"Set up your sticker"** walkthrough that turns a blank NFC tag into a trigger via a user-created Shortcuts automation (US4). The app ships **no CoreNFC code by design** — iOS Shortcuts automations own the NFC layer; the app only exposes the verbs and the guide. An App Clip was explicitly evaluated and rejected (clips run only when the app is *not* installed; the default dose lives in the app's settings).

**Shipping status (honest, two layers).**
1. **Settings surface — live on `main`:** the "My Medication", "Confirmations", and "Dose Guard" sections and the "Set up your sticker" walkthrough **are mounted** in `SettingsView` (restored by merge `3ff74b5e`; `SettingsView.swift:54-57, 190-200`). Note: the 1.0 submission build (tag `v1.0`, `5cd7b22d`) shipped with these unmounted — the mount is post-submission.
2. **Intent engine — implemented, dormant:** both intents compile with `isDiscoverable = false` and **no `AppShortcutsProvider` exists** — `SquirlAppShortcuts.swift` was deleted by the hide commit `94a51181` ("hide hands-free logging surface for 1.0") and was **not** restored by the merge. The intents are therefore unreachable from Siri, Shortcuts, and Spotlight, and NFC stickers cannot trigger them (a sticker is just a Shortcuts automation). Restore plan (per `docs/BACKLOG.md` §"Last updated" and the commit message): `git revert 94a51181` — which re-adds the provider and flips `isDiscoverable` — plus the never-run S1–S10 device QA (`specs/030-app-intents-foundation/quickstart.md`).

This creates a **doc/code tension to flag**: the mounted Settings copy advertises "sticker, Siri, or Shortcuts" while the engine those triggers would fire is hidden — exactly the reviewer-visible-promise problem `94a51181` removed for 1.0. Any 1.1 build from `main` before the revert ships that promise with nothing answering it.

## Scope

- In scope: `LogDefaultDoseIntent`, `StartCheckInIntent`, `DoseConfirmationCopy`, `AppIntentRouter`, `DoseLogService`/`DoseLogServiceImpl`, `DoseGuardMode`, the five `AppSettings` fields, `MyMedicationSection` (+ "Confirmations" section), `DoseGuardSection`, `StickerSetupView` + its Settings entry, the `SquirlApp` dependency registrations and router wiring, and the `whispernotes://checkin` deep-link rewiring.
- Out of scope: the medication catalog and in-app Log Dose sheet ([07-medications.md](07-medications.md)); the check-in capture pipeline itself ([03-check-in-capture.md](03-check-in-capture.md)) — the intent only lands the app in it; the deleted `SquirlAppShortcuts` phrase list beyond its contract (`specs/030-app-intents-foundation/contracts/app-intents.md:41-48`).

## Actors & triggers

| Actor / trigger | Enters via |
|---|---|
| User (Settings) | "My Medication" picker, "Confirmations" toggle, "Dose Guard" rows, "Set up your sticker" NavigationLink — all mounted (`SettingsView.swift:54-57, 190-200`) |
| Siri / Shortcuts / Spotlight / NFC sticker | **Dormant** — would invoke the two intents; blocked by `isDiscoverable = false` + deleted provider (`94a51181`) |
| `whispernotes://checkin` deep link | `SquirlApp.onOpenURL` → `router.requestCheckIn()` — same choke point as the intent (`SquirlApp.swift:62-65`); see Edge cases for the dead-URL-type caveat |
| System (background intent launch) | headless launch runs `SquirlApp.init`, which registers `doseLogService` + `router` with `AppDependencyManager` before any `perform()` (`SquirlApp.swift:34-41`) |
| `Notification.Name.medicationEventsDidChange` | posted after a successful expedited log; refreshes the medication bar and timeline (`DoseLogServiceImpl.swift:62`) |

## Functional requirements

Requirement IDs follow this set's per-area convention (`FR-AI-NN`); each maps to its spec-030 FR (`FR-001`…`FR-023`) inline so both remain traceable.

### Default medication & confirmations (US1 settings)

- **FR-AI-01 — "My Medication" section (spec FR-001/FR-002).** Mounted section (`SettingsView.swift:54-55`, anchor id `"settings-my-medication"` at `:35`). Header **"My Medication"**; footer: **"Logged by the Log My Meds action — sticker, Siri, or Shortcuts. Only this medication and dose are recorded; changing it never alters past logs."** Collapsible picker row with three value states: nothing → **"Set"** (accent); name only → plain secondary; name+dose → purple semibold `"<name> · <dose>"`. Expanded: chips of all 3 catalog entries, then a "Dose" chip group once an entry is selected. **Picking a medication nils the dose** (`medicationDidChange()` — the dose takes its own explicit tap, never auto-commits). **"Clear Medication"** (destructive, only when set) clears both and collapses the picker. Persists to `AppSettings.defaultMedicationName` / `defaultMedicationDose` via `syncMyMedication()` (`MyMedicationSection.swift:20-143`; `SettingsViewModel.swift:97-107`).
- **FR-AI-02 — "Confirmations" section (spec FR-023).** Header **"Confirmations"**; toggle **"Name medication in confirmations"** (icon `quote.bubble`), **default `false`**, persisted via `syncNameInConfirmations()` → `AppSettings.nameMedicationInConfirmations`. Footer: **"Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen)."** Live preview banner (purple `pills.fill` tile + fixed sample time **"· 17:42"**) shows **"Dose logged"** when off, `"<name> <dose> logged"` when on (neutral defaults "Elvanse" / "30 mg" when unset) (`MyMedicationSection.swift:64-76, 147-176`).
- **FR-AI-03 — Five persisted fields.** All on the existing `AppSettings` singleton, all defaulted/optional, no `.unique` (Constitution IX): `defaultMedicationName: String? = nil`, `defaultMedicationDose: String? = nil`, `doseGuardModeRaw: String = "off"`, `doseGuardWindowHours: Int = 2`, `nameMedicationInConfirmations: Bool = false` (`AppSettings.swift:13-19`).

### Log My Meds intent (dormant engine)

- **FR-AI-04 — Verb declaration (spec FR-003/FR-004).** `LogDefaultDoseIntent`: title **"Log My Meds"**; description "Logs your default medication dose. Set the medication once in Squirl's settings."; `supportedModes = [.background, .foreground(.dynamic)]` (background by default; dynamic foreground serves only the not-configured path — the iOS 26 execution-mode API; `openAppWhenRun`/`ForegroundContinuableIntent` are banned on the 26 target); `authenticationPolicy = .alwaysAllowed` (locked Siri works by explicit owner decision — "worst case is journal pollution, nothing is read back"); `isDiscoverable = false` (hidden for 1.0 pending S1–S10 QA) (`LogDefaultDoseIntent.swift:8-23`).
- **FR-AI-05 — Perform = thin translation.** `perform()` calls `service.logDefaultDose(now:)`, reads `namesMedicationInConfirmations()`, composes one line via `DoseConfirmationCopy`, and returns it as an `IntentDialog` (**`full` and `supporting` carry the identical string** — the contract's spoken-vs-short-form split was not implemented). All domain rules live in the service (Constitution VIII — an intent cannot depend on a view model). Dependencies arrive via `@AppDependency` (`LogDefaultDoseIntent.swift:25-44`; registrations `SquirlApp.swift:38-41`).
- **FR-AI-06 — Not-configured continuation (spec FR-007).** On `.notConfigured`, the intent attempts `continueInForeground(dialog, alwaysConfirm: true)` and then calls `router.focusMyMedication()`; a declined or impossible transition (locked device, background-only context) is swallowed (`catch {}`) — "the calm dialog stands, never an error surface." The router arm switches the tab to Settings (`SquirlApp.swift:76-79`, `initial: true` to cover armed-before-attach on a headless launch) and `SettingsView`'s one-shot consumer scrolls to the section **and opens its picker** (`SettingsView.swift:82-88`; `AppIntentRouter.swift:54-63`).
- **FR-AI-07 — Expedited log pipeline (spec FR-003/FR-006).** `DoseLogServiceImpl.logDefaultDose(now:)` in exact order: (1) fetch-or-create the single `AppSettings`; (2) **configuration check** — requires name AND dose AND the name still resolving via `MedicationCatalog.entry(matching:)`; a dangling default degrades to `.notConfigured`; (3) **guard evaluation** — skipped entirely when mode is `.off` (never reads history); otherwise fetch `mostRecentDose()` — a fetch **error returns `.failed` (fails closed)**: an error degraded to nil would read as "no prior dose" and bypass an armed guard; blocked → `.guarded(activeSince: previous.takenAt)`; (4) **write** — `MedicationEvent(name, dose, takenAt: now, durationHours: entry.durationHours, source: .manual)` — duration from the **catalog entry**, recording nil, `isMockData` false (real-data surface); (5) **save-failure rollback** — on persist throw the inserted event is explicitly deleted (otherwise mainContext autosave would later persist it, "turning a reported failure into a silent success = a double log once the user retries") → `.failed`; (6) success posts `.medicationEventsDidChange` → `.logged(name:dose:at:)`. The resulting event is indistinguishable downstream from an in-app log (spec FR-006) (`DoseLogServiceImpl.swift:18-64`).
- **FR-AI-08 — Guard reference query (spec FR-009/FR-010 clarification).** `mostRecentDose()`: predicate `taken == true && isMockData == false`, sorted `takenAt` descending, `fetchLimit = 1` — **any medication, any logging surface, no time cutoff** (a stale latest event simply passes the guard); mock events never arm the guard (`DoseLogServiceImpl.swift:80-89`).
- **FR-AI-09 — Outcome type & confirmation copy (spec FR-005/FR-011/FR-021/FR-023).** `DoseLogOutcome` has **four** cases: `.logged(name:dose:at:)`, `.guarded(activeSince:)`, `.notConfigured`, `.failed` (`DoseLogService.swift:5-15`). `DoseConfirmationCopy.text(for:named:)` exact strings, time in system short style (locale-aware 24 h/AM-PM):

  | Outcome | `named` off (default, discreet) | `named` on |
  |---|---|---|
  | `.logged` | `"Dose logged · <time>"` | `"<Name> <dose> logged · <time>"` (e.g. "Elvanse 30 mg logged · 9:41 AM") |
  | `.guarded` | `"Your <time> dose is still active."` — names the earlier dose's **time**, never the drug | same |
  | `.notConfigured` | `"Set your medication first."` | same |
  | `.failed` | `"Couldn't save that dose — nothing was logged. Try again in the app."` | same |

  The `named` flag governs every surface uniformly; no response ever carries journal content beyond the just-logged fact (`DoseConfirmationCopy.swift:7-25`). **Haptics:** none, anywhere — per the FR-005 amendment (D9), a background intent's engine is suspended and cannot play a haptic; the acknowledgment is the system banner plus, for a voice trigger, the spoken dialog.
- **FR-AI-10 — Siri/Shortcuts/Spotlight exposure (spec FR-017/FR-018) — designed, not shipped.** The contract's `SquirlAppShortcuts` provider (exactly two `AppShortcut`s, iOS 17+ `shortTitle` initializer, phrases containing `.applicationName` — working set "Log my meds in `.applicationName`", "`.applicationName` dose", "Check in on `.applicationName`", "Start a `.applicationName` check-in") **does not exist on `main`**: deleted by `94a51181` because Siri phrases compile into binary metadata that runtime-emptying cannot be trusted to hide. Zero-setup discovery (SC-003) is therefore unmet in the shipping binary; restore = revert `94a51181` + S1–S10 device QA (`contracts/app-intents.md:41-48`; `docs/BACKLOG.md` §"Last updated").

### Dose Guard (US3)

- **FR-AI-11 — Guard modes & blocking semantics (spec FR-008..FR-012).** `DoseGuardMode` (non-persisted enum, stored as `doseGuardModeRaw`) cases `off` / `total` / `window`; unrecognized persisted raw values decode to `.off` (forward-safe). `blocksLog(previousDose:windowHours:now:)`: no previous dose → never blocks; `.off` → never blocks; `.total` → blocks while the previous dose `isActive(at: now)` — reusing `effectProgress < 1`, so it honors a **per-event edited duration**, not the catalog default; `.window` → blocks while `now - takenAt < windowHours * 3600` — purely time-since-dose. **Boundary closed:** at exactly window-end/effect-end the guard opens (strict `<`). Guards **expedited logs only** — the in-app Log Dose sheet never consults it (`DoseGuardMode.swift:6-31`).
- **FR-AI-12 — "Dose Guard" section (spec FR-008).** Mounted (`SettingsView.swift:56`). Header **"Dose Guard"**; three always-visible selectable rows (`shield` icon, checkmark + `.isSelected` trait on the selection): **"Off"** / "Every trigger logs"; **"Total"** / "Blocked while a dose is still active"; **"Time window"** / "Blocked for a set time after a dose". When `.window` is selected, an inline **"Blocked for"** segmented picker offers **1/2/3/4 h**, bound to `doseGuardWindowHours` (default **2**). Mode-aware footers always end with **" The in-app Log Dose sheet is never blocked."**: off → "Every trigger logs. Guards expedited logs only — sticker, Siri, or Shortcuts."; total → "A second log is blocked while your last dose is still active."; window → "A second log is blocked for <N> h after your last dose." Persists via `syncDoseGuard()` (`DoseGuardSection.swift:14-100`; `SettingsViewModel.swift:114-117`).

### Check In intent (dormant engine)

- **FR-AI-13 — Verb declaration (spec FR-013).** `StartCheckInIntent`: title **"Check In"**; description "Opens Squirl and starts a voice check-in, recording right away."; `supportedModes = .foreground` (the system foregrounds the app before `perform()`); **default** authentication policy — foregrounding requires unlock, which the sticker guide's copy sets as expected behavior; `isDiscoverable = false` (hidden, same as FR-AI-04) (`StartCheckInIntent.swift:8-21`).
- **FR-AI-14 — Trigger flow (spec FR-013/FR-022).** `perform()` calls `router.requestCheckIn()`: onboarding **complete** → `.started` — router sets `selectedTab = .checkIn` and arms `shouldStartCheckIn`; `SquirlApp`'s one-shot observer consumes it and sets `shouldAutoStartRecording = true` (`SquirlApp.swift:66-70`); `CheckInView.consumeAutoStart()` (on appear and on change) starts capture, landing in Listening already recording. Dialog: **"Starting your check-in."** Onboarding **incomplete** → `.gatedOnboarding` — strict gate (spec FR-022): nothing armed, no recording, the already-foregrounded app shows onboarding; dialog **"Finish setting up Squirl first."** The gate reads live `AppSettings.hasCompletedOnboarding` per call (`StartCheckInIntent.swift:26-37`; `AppIntentRouter.swift:41-46`; `AppDependencies.swift:18-23`).
- **FR-AI-15 — Re-entry protection (spec FR-014).** `consumeAutoStart()` no-ops when the view model state is `.recording`, `.paused`, or `.processing` ("already capturing — never double-start"); `.done` resets then starts; `.idle` starts. The intent's dialog still says "Starting your check-in." in this case — the router cannot see recording state, so the spoken/banner line is unconditional (`CheckInView.swift:33, 68-76`).
- **FR-AI-16 — Pipeline reuse (spec FR-015/FR-016).** The intent performs no transcription and adds no capture machinery: recordings enter the standard pipeline unchanged — JIT mic-permission guidance, storage guidance, and the record-before-model-ready queue (`SquirlApp.swift:120-130` drains on launch/foreground). Nothing about an intent-started recording is distinguishable later.
- **FR-AI-17 — One choke point with the deep link.** The legacy `whispernotes://checkin` URL is rewired through `router.requestCheckIn()` (return value discarded), so the intent and the deep link share the onboarding gate and one-shot consumption; a stale trigger can never re-fire (`SquirlApp.swift:59-65`; `AppIntentRouter.swift:48-52`).

### Guided sticker setup (US4)

- **FR-AI-18 — Settings entry (spec FR-019).** Unlabeled section between Dose Guard and Medication Bar: `NavigationLink` **"Set up your sticker"** (icon `sensor.tag.radiowaves.forward`) → `StickerSetupView`. Footer: **"Turn a blank NFC sticker into a one-tap dose log or check-in. About a minute, once per sticker."** (`SettingsView.swift:57, 190-200`).
- **FR-AI-19 — Walkthrough content (spec FR-019/FR-020).** `ScreenContainer(title: "Set up your sticker", showsMedicationBar: false)`; intro: "Turn any blank NFC sticker into a one-tap Squirl action. About a minute, once per sticker. Squirl walks you through the Shortcuts app." A segmented picker switches two paths — **"Dose sticker"** (tint `Palette.medication`, action "Log My Meds") / **"Check-in sticker"** (tint `Theme.meadowGreen`, action "Check In") — which re-tint the whole screen. "What you'll need" card: **"A blank NFC sticker"** ("Any cheap NDEF tag, nothing pre-written") plus, on the dose path only, **"A default medication set"** ("Settings › My Medication"). Five numbered steps, identical per path except step 4's action name: (1) open Shortcuts — carries the hand-off button **"Open Shortcuts"** which opens a plain `shortcuts://` URL (no automation-creation URL exists; the footnote says so honestly: "Squirl can't create the automation for you (iOS doesn't allow that)."); (2) Automation tab → + → Create Personal Automation → NFC; (3) Scan, hold the sticker to the phone, name it; (4) Add Action → search **Squirl** → choose the path's action; (5) turn **off** "Ask Before Running", confirm **Run Immediately** — badged **"Recommended"** ("the zero-tap setup"). A **"Done."** row closes the card ("Tap the sticker to log your default dose. No app-opening, no menus." / "…open Squirl already recording. No menus, no taps. Just start talking.") (`StickerSetupView.swift:13-34, 50-102, 140-164`).
- **FR-AI-20 — Honest lock-behavior callout (spec FR-020).** Card **"What to expect when you tap it"**: **Unlocked** → "It runs instantly, no prompt. This is the zero-tap setup working."; **Locked** → "iPhone shows a notification instead. Tap it and the action runs."; closing line: "The tap is never lost, and a locked phone showing a notification is just how iOS handles it, not something you did wrong." (no-shame framing). The check-in path's footnote adds: "On a locked phone it asks you to unlock first, which is expected for anything that opens Squirl." (`StickerSetupView.swift:29-33, 168-181`).
- **FR-AI-21 — NFC troubleshooting tip.** Card **"Can't get it to read?"** (icon `sensor.tag.radiowaves.forward`): "Hold the **top-back of your phone**, up by the cameras, flat against the sticker for a second. That's where the NFC reader is. A thick case or a metal surface behind the sticker can block it." Badge/icon discs scale with `@ScaledMetric` so digits never spill at accessibility text sizes; path switches animate `Motion.snappy` unless Reduce Motion (`StickerSetupView.swift:44-48, 183-191`).
- **FR-AI-22 — View-only guide.** `StickerSetupView` holds no journal behavior and no NFC code; its copy contract (the `StickerPath` enum) is `internal` specifically so `StickerSetupViewTests` can assert the honesty copy (`StickerSetupView.swift:9-13`).

### Privacy & platform floor

- **FR-AI-23 — No journal content on trigger surfaces (spec FR-021).** Every dialog contains only the just-logged fact, the earlier dose's time, or a neutral status phrase — never transcripts, notes, or history. All processing is on-device; no new entitlements or Info.plist keys; locked-voice logging (`.alwaysAllowed`) is an explicitly accepted owner decision (worst case: a stray journal entry; nothing is read back).
- **FR-AI-24 — iOS 26.0 floor.** The deployment target was raised 17.0 → 26.0 ahead of this feature (owner decision 2026-07-03, D15; device floor iPhone 11/A13+, baseline iPhone 12), enabling the modern `supportedModes`/`IntentModes` API and banning the deprecated foregrounding surfaces. iOS 26 extras deliberately not adopted: interactive snippets, `LongRunningIntent`, Liquid Glass.

## User flows

### Happy path — hands-free dose log (post-restore)

1. User sets "Elvanse · 30 mg" in Settings › My Medication (dose chip tapped explicitly).
2. User taps the pill-bottle sticker (or says the Siri phrase, or runs the shortcut); the background intent fires.
3. `logDefaultDose`: configured ✓ → guard `.off` (default) skips history → event written with catalog duration 10 h → saved → notification posted.
4. System banner (and spoken line for voice): "Dose logged · 9:41 AM" — or "Elvanse 30 mg logged · 9:41 AM" with the naming toggle on. No haptic (platform limit, D9). App never visibly opens.
5. Next app open: the medication bar and day timeline show the dose exactly as an in-app log.

### Alternate flows

- **Guarded:** guard `.total` and a dose logged 2 h ago (duration 10 h) → nothing written; dialog "Your 9:41 AM dose is still active."
- **Not configured:** no default (or a dangling one) → "Set your medication first."; `continueInForeground` offer → app opens to Settings, tab switched, My Medication scrolled into view with its picker open. Declined/locked → the dialog simply stands.
- **History unreadable with armed guard / save throw:** `.failed`, nothing durably written (insert rolled back); dialog "Couldn't save that dose — nothing was logged. Try again in the app."
- **Hands-free check-in:** trigger → app foregrounds → Listening, already recording; stop & save behaves as a normal check-in; if the model isn't installed the audio queues and transcribes later.
- **Check-in before onboarding:** strict gate — onboarding shows, no recording, "Finish setting up Squirl first."
- **Check-in while already recording:** trigger consumed, no second session; app foregrounds to the live Listening screen (dialog still claims "Starting your check-in." — FR-AI-15).
- **Sticker setup:** Settings › Set up your sticker → pick path → Open Shortcuts → create NFC personal automation on a blank tag → add the Squirl action → Run Immediately → tap to verify against the lock-behavior callout.

## UI states

- **My Medication row:** unset ("Set", accent) / name-only (secondary) / name · dose (purple semibold); picker expanded (med chips, dose chips when entry selected) / collapsed; Clear Medication only when set.
- **Dose Guard:** exactly one of three rows selected; "Blocked for" picker exists only in window mode.
- **Sticker guide:** two paths × same five steps; step numbering is keyed by offset so switching paths updates step 4 in place; hand-off button, Recommended badge, Done row, two callouts.
- **Intent outcomes (dormant):** calm dialogs only — never an error surface; `.failed` copy states nothing was logged and is always safe to retry.
- **Dormancy:** no discoverable surface exists for either intent; no Shortcuts/Spotlight/Siri entry points; the NFC layer is entirely the user's Shortcuts automation.

## Validation rules & constants

| Rule / constant | Value | Source |
|---|---|---|
| Default-medication validity | name AND dose set AND name resolves in catalog; else `.notConfigured` | `DoseLogServiceImpl.swift:21-27` |
| Guard reference event | most recent `taken && !isMockData` event, any med/surface, no cutoff | `DoseLogServiceImpl.swift:82-89` |
| Guard window options / default | 1/2/3/4 h; default 2 h | `DoseGuardSection.swift:47-53`; `AppSettings.swift:18` |
| Guard boundary | strict `<` — exactly at window/effect end the guard opens | `DoseGuardMode.swift:29` |
| Guard scope | expedited logs only; Log Dose sheet never consults it | `DoseGuardMode.swift:3-5` |
| Expedited event shape | `source: .manual`, recording nil, `isMockData` false, catalog `durationHours` | `DoseLogServiceImpl.swift:45-51` |
| Confirmations default | discreet (`nameMedicationInConfirmations = false`) | `AppSettings.swift:19` |
| Dose intent modes / auth | `[.background, .foreground(.dynamic)]`; `.alwaysAllowed` | `LogDefaultDoseIntent.swift:16-19` |
| Check-in intent modes / auth | `.foreground`; default policy (unlock required) | `StartCheckInIntent.swift:17` |
| Discoverability | `isDiscoverable = false` ×2; no `AppShortcutsProvider` (deleted `94a51181`) | both intents; `docs/BACKLOG.md` §"Last updated" |
| Hand-off URL | plain `shortcuts://` (no automation-creation URL exists) | `StickerSetupView.swift:141-143` |
| Background time ceiling | 30 s platform limit; actual work is one fetch + one insert + save | `contracts/app-intents.md:16` |
| Platform floor | iOS 26.0 (raised from 17.0, D15) | `specs/030-app-intents-foundation/plan.md:22` |
| Performance goals | trigger→ack < 3 s (SC-001); trigger→recording < 3 s on iPhone 12 (SC-002) | `specs/030-app-intents-foundation/spec.md:169-170` |

## Edge cases

- **Dangling default medication** (catalog changed after the default was set) → `.notConfigured`, treated as not-set; never a crash, never a half-configured log.
- **Unrecognized persisted `doseGuardModeRaw`** → `.off` (forward-safe decode).
- **Save-failure rollback:** a thrown save deletes the orphaned insert so mainContext autosave can't later persist it into a silent success (double log on retry).
- **Fail-closed guard:** dose history unreadable while a guard is armed → `.failed`, nothing written — never treated as "no prior dose".
- **Guard boundary:** exactly X hours after the previous dose (window mode) or exactly at effect end (total mode) → log succeeds, deterministically.
- **Rapid double-fire:** with any guard on, the second trigger is `.guarded` (the first event is now the most recent); with the guard off, two events are the user's explicit choice.
- **Mock mode:** intent logs are always real (`isMockData = false`) and the guard ignores mock events — hands-free logging works regardless of the debug toggle.
- **Changed default:** affects future logs only; past events keep their recorded name/dose (footer copy states this).
- **Locked-device triggers:** dose intent runs (`.alwaysAllowed`); check-in intent requires unlock (foreground mode); locked NFC taps degrade to a notification per iOS — community-verified behavior, device-QA item S23, guide copy matches it.
- **Not-configured continuation declined/impossible:** swallowed error; the calm dialog stands. Works spoken on locked Siri (continuation happens after unlock).
- **Already-recording check-in trigger:** no second session, but the dialog unconditionally says "Starting your check-in." (FR-AI-15).
- **Trigger while the app shows another screen/sheet:** the router only sets `selectedTab`; a modally presented sheet is not explicitly dismissed — the spec's "never a half-presented stack" requirement has no dedicated handling or test.
- **`whispernotes://checkin` may be dead at the OS level:** BACKLOG notes the `CFBundleURLTypes` entry "never parses → whispernotes:// dead, delete or re-register" — the router rewiring is correct, but the URL type itself is suspect.
- **Storage full / mic revoked:** the app surfaces its existing guidance (FR-016); the trigger never fails silently once foregrounded.
- **Stale sticker** (automation or app deleted): iOS owns that failure surface; out of scope.
- **Ephemeral-store session:** `fetchOrCreateSettings` uses `try?` throughout; on an ephemeral container the settings read still succeeds in-memory, but the dose write would fail and surface as `.failed`.

## Acceptance criteria

1. (Dormant, code-level) With a configured default and guard `.off`, `logDefaultDose` writes exactly one `MedicationEvent` (catalog duration, `.manual`, real-data), posts `medicationEventsDidChange`, and returns `.logged`; the discreet and named confirmation lines match FR-AI-09 exactly.
2. (Dormant, code-level) With guard `.window` = 2 h: a second trigger at 1:59 → `.guarded`, nothing written; at exactly 2:00 → logged. With `.total`: blocked while the previous event's **recorded** duration elapses (an edited duration is honored). With an armed guard and an unreadable history → `.failed`, nothing written. A save throw rolls back the insert before reporting `.failed`.
3. (Dormant, code-level) No default / name-only default / dangling default → `.notConfigured`; the intent's continuation arms the router, and the mounted Settings screen scrolls to "My Medication" with its picker open.
4. (Dormant, code-level) `requestCheckIn()` with onboarding incomplete arms nothing and reports `.gatedOnboarding` — for both the intent and the `whispernotes://checkin` deep link; consumption of either trigger is one-shot.
5. The mounted Settings sections match FR-AI-01/02/12 exactly (labels, footers, defaults, chip behavior, guard rows, window picker, preview banner), and "Set up your sticker" presents the FR-AI-19/20/21 content for both paths.
6. Neither intent appears in Shortcuts, Spotlight, or Siri while `isDiscoverable = false` and no `AppShortcutsProvider` exists; restoring requires reverting `94a51181` and running the S1–S10 device QA (quickstart), after which this document's "dormant" flags must be revisited.
7. No dialog or banner from any trigger path contains transcript text, notes, or historical data.

## Source references

- `app-four/Intents/LogDefaultDoseIntent.swift:8-45` · `StartCheckInIntent.swift:8-37` · `DoseConfirmationCopy.swift:7-25` · `AppIntentRouter.swift:6-63`
- `app-four/Services/DoseLog/DoseLogService.swift:5-26` · `DoseLogServiceImpl.swift:11-93`
- `app-four/Models/AppSettings.swift:13-19` · `DoseGuardMode.swift:6-31`
- `app-four/Views/Settings/MyMedicationSection.swift:9-201` · `DoseGuardSection.swift:8-101` · `StickerSetupView.swift:9-262`
- `app-four/Views/SettingsView.swift:35, 54-57, 82-88, 190-200` · `app-four/Views/CheckIn/CheckInView.swift:33, 68-82`
- `app-four/App/SquirlApp.swift:34-41, 59-79` · `app-four/Store/AppDependencies.swift:18-26` · `app-four/ViewModels/SettingsViewModel.swift:97-117`
- Hide/restore: commit `94a51181` (hide, revert to restore) · merge `3ff74b5e` (Settings restore) · `docs/BACKLOG.md` §"Last updated"
- Spec 030: `specs/030-app-intents-foundation/{spec,plan,data-model,tasks}.md` · `contracts/app-intents.md` · `quickstart.md` (S1–S26 device QA)
- Sibling FSD: [Medications](07-medications.md) · [Settings & Data](08-settings-and-data.md) · [Check-in Capture](03-check-in-capture.md) · [Data Model](09-data-model.md)
