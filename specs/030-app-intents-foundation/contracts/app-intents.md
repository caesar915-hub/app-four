<!-- Created: 2026-07-03 18:51 (WEST) · Updated: 2026-07-03 19:15 (WEST) -->
# Interface Contracts: App Intents Foundation + NFC Sticker Actions

**Feature**: [spec.md](../spec.md) · **Data model**: [../data-model.md](../data-model.md) · **Research**: [../research.md](../research.md)

The feature's external interface is the pair of system verbs (what Siri/Shortcuts/Spotlight/NFC automations can invoke) plus the internal seams they depend on. Semantic contracts only — bodies belong to implementation.

## Verb 1 — `LogDefaultDoseIntent`

| Aspect | Contract |
|---|---|
| Title | "Log My Meds" (final copy at implementation) |
| Execution | `static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]` — background by default; app may be launched headless (D1/D2 rev.) |
| Lock policy | `authenticationPolicy = .alwaysAllowed` (explicit; also the platform default — D8) |
| Conditional foreground | `.foreground(.dynamic)` + `continueInForeground()` solely for the not-configured path (D9 rev.; replaces the deprecated `ForegroundContinuableIntent`) |
| Time budget | Well under the 30 s ceiling (one fetch + one insert + save) |

**Behavior** (`perform()` is a thin translation over `DoseLogService.logDefaultDose(now:)` → [DoseLogOutcome](../data-model.md)):

1. `logged(name:dose:at:)` → `.result(dialog:)` per the confirmation copy matrix (named vs discreet per `nameMedicationInConfirmations`). `full` = spoken sentence; `supporting` = short visual form.
2. `guarded(activeSince:)` → no write occurred; calm dialog naming the earlier dose's **time** only ("Your 14:00 dose is still active."). Never alarming language (FR-011).
3. `notConfigured` → no write; calm dialog then `continueInForeground()` (dynamic mode); on continuation the app opens and the router focuses the "My medication" setting (FR-007). Works spoken on locked Siri (dialog speaks; continuation happens after unlock).
4. Any thrown persistence error → dialog states the log did not happen (honest failure, SC-007); never a silent no-op.

**Guarantees**: event written exactly as in [data-model.md](../data-model.md) (`source: .manual`, `recording: nil`, `isMockData: false`, catalog `durationHours`); `.medicationEventsDidChange` posted after save (FR-006); no journal content in any response beyond the just-logged fact (FR-021).

## Verb 2 — `StartCheckInIntent`

| Aspect | Contract |
|---|---|
| Title | "Check In" (final copy at implementation) |
| Execution | `static let supportedModes: IntentModes = .foreground` — system foregrounds the app before `perform()` (D2 rev.; the deprecated `openAppWhenRun` is banned on the 26 target) |
| Lock policy | Default (foregrounding requires unlock — expected, matches guide copy) |

**Behavior** (`perform()` runs on MainActor; delegates to the router):

1. Onboarding complete → router sets check-in tab + auto-start; the app lands in Listening with recording active via the existing `consumeAutoStart()` path and its spec-016 re-entry guard (FR-013/FR-014). Recording enters the standard pipeline — JIT mic permission, storage check, model-absent queue — unchanged (FR-015/FR-016).
2. Onboarding incomplete → **strict gate** (FR-022): no recording, app opens showing onboarding, dialog "finish setting up Squirl first" (calm).
3. Recording already in progress → no-op on the session (guard consumes the trigger); the app simply foregrounds to the live Listening screen.

## `SquirlAppShortcuts: AppShortcutsProvider`

- Exactly two `AppShortcut`s (well under the 10-shortcut cap), using the **iOS 17.0+ initializer** with `shortTitle` + `systemImageName`.
- Every phrase contains `.applicationName`; lean lists (~3–5 per verb) suffice under iOS 17 flexible matching. Working set (final copy at implementation):
  - Dose: "Log my meds in `.applicationName`", "`.applicationName` dose", "Log my dose in `.applicationName`"
  - Check-in: "Check in on `.applicationName`", "Start a `.applicationName` check-in"
- No parameters → no `updateAppShortcutParameters()`.
- Zero-setup exposure from install: Siri, Spotlight (Top Hit), Shortcuts app (FR-017/SC-003). Surfaces on both bundle IDs (dev + stable channel).

## Internal seam — `DoseLogService` (protocol, `Services/`)

```
protocol DoseLogService  (actor-friendly seam; exact isolation at implementation)
  func logDefaultDose(now: Date) async -> DoseLogOutcome
```

- Owns: settings resolution (fetch-first-or-create `AppSettings` singleton), catalog re-validation (`entry(matching:)`), guard evaluation ([data-model.md](../data-model.md) semantics, boundary closed), event write + save, `.medicationEventsDidChange` post.
- Injected via `AppDependencyManager.shared` in `SquirlApp.init`; resolved in the intent with `@AppDependency` (D11). Mockable for the intent-free unit tests (D14).
- NOT consumed by the in-app Log Dose sheet (clarification Option A; Constitution IV — no retrofit).

## Internal seam — intent router (`@MainActor @Observable`)

- Owns cross-surface navigation/trigger state: `requestCheckIn()` (gated on `hasCompletedOnboarding` — the FR-022 choke point), `focusMyMedication()` (Settings tab + one-shot focus flag).
- `SquirlApp`/`RootContainerView` observe it and drive the existing `selectedTab` / `shouldAutoStartRecording` state; the legacy `whispernotes://checkin` `onOpenURL` handler is rewired through `requestCheckIn()` (closing the shipped ungated path — D4).
- Consumption is one-shot (flags reset on consume) so a stale trigger can never re-fire a recording.

## Settings surfaces (UI contracts — HTML mockups gate the SwiftUI, Constitution I)

| Control | Contract |
|---|---|
| "My medication" | Pick exactly one catalog medication + one of its dose options; clearable; persists to `AppSettings` (FR-001/002) |
| "Dose guard" | Off (default) / Total / Time-window with 1·2·3·4 h picker (visible only in window mode) (FR-008) |
| "Name medication in confirmations" | Toggle, default OFF (FR-023) |
| "Set up your sticker" | Guided walkthrough, one path per sticker; hand-off button opens `shortcuts://` (plain — no automation-creation URL exists, D12); honest lock-behavior copy; recommends Run Immediately (FR-019/020) |

Placement: alongside the existing medication-bar section pattern in `SettingsView` (self-contained section views in `app-four/Views/Settings/`).
