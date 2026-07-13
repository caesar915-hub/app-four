<!-- Created: 2026-07-03 18:51 (WEST) · Updated: 2026-07-03 19:15 (WEST) -->
# Phase 0 Research: App Intents Foundation + NFC Sticker Actions

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Date**: 2026-07-03

Two parallel research passes: (A) codebase integration points (every claim `file:line`-verified against source), (B) Apple-documentation verification of the App Intents API surface (every verdict URL-cited; community-verified facts labeled as such). Findings consolidated into numbered decisions. **2026-07-03 19:15: deployment target raised 17.0 → 26.0 by owner decision (D15) — D2/D9 revised to the iOS 26 execution-mode API; original 17-era decisions preserved inline as history.**

## Decisions

### D1 — Intents live in the app target; no extension

**Decision**: Both intents are defined in the `app-four` target itself. No App Intents extension.
**Rationale**: In-app intents run in the app's own process; when the app isn't running, the system launches it in the background "without scenes being brought up" ([WWDC22 10032](https://developer.apple.com/videos/play/wwdc2022/10032/)). `SquirlApp.init` is scene-free and headless-safe — it touches `AppDependencies.store` (forces `AppModelContainer.container` + `RecordingStore` recovery) and `MetricManager.shared.start()` only ([SquirlApp.swift:15-21](../../app-four/App/SquirlApp.swift#L15-L21)); no UIKit scene dependency found. An extension would add a target, duplicate the data stack, and buy nothing at this scale.
**Alternatives considered**: App Intents extension (avoids launching the full app for background intents — a performance optimization Apple recommends for large apps; rejected: launch cost is acceptable, and the dose write needs the same SwiftData container anyway).

### D2 — Foregrounding: `supportedModes` / `IntentModes` (iOS 26 API) — REVISED 2026-07-03 19:15

**Decision** *(revised after the owner raised the deployment target to iOS 26 — see D15; the original decision pinned `openAppWhenRun` under the 17.0 target)*: `StartCheckInIntent` declares `static let supportedModes: IntentModes = .foreground` (immediate foregrounding — the system brings the app forward before `perform()`). `LogDefaultDoseIntent` declares `[.background, .foreground(.dynamic)]` — background by default, with the *intent itself* deciding at run time whether to continue into the foreground (used only by the not-configured path, D9).
**Rationale**: On an iOS 26 target, `supportedModes`/`IntentModes` is the current API and both `openAppWhenRun` and `ForegroundContinuableIntent` are deprecated in its favor ([Apple: supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes), [Apple: IntentModes](https://developer.apple.com/documentation/appintents/intentmodes), [WWDC25 275](https://developer.apple.com/videos/play/wwdc2025/275/)). Constitution I (modern APIs, no deprecated APIs) now *requires* the new surface.
**Alternatives considered**: `openAppWhenRun`/`ForegroundContinuableIntent` (correct on 17, deprecated on 26 — rejected with the target raise); `.foreground(.deferred)` (for intents that foreground *eventually* — wrong shape for mic capture, which needs the app up before recording).

### D3 — Intent→UI bridge: a shared `@MainActor` router, folding in the existing deep-link path

**Decision**: A small `@MainActor @Observable` router object (registered via `AppDependencyManager`, see D11) carries "start a check-in" and "open My medication" requests. `RootContainerView`/`SquirlApp` observe it; the existing private `@State` plumbing (`selectedTab`, `shouldAutoStartRecording`) is driven from it. The legacy `whispernotes://checkin` `onOpenURL` handler routes through the same router.
**Rationale**: The exact foreground auto-record flow already ships: `whispernotes://checkin` → `selectedTab = .checkIn` + `shouldAutoStartRecording = true` ([SquirlApp.swift:38-42](../../app-four/App/SquirlApp.swift#L38-L42)), consumed by `CheckInView.consumeAutoStart()` through the spec-016 re-entry guard ([CheckInView.swift:68-83](../../app-four/Views/CheckIn/CheckInView.swift#L68-L83)). The intent reuses this proven path; the router just makes the trigger state reachable from outside `SquirlApp`'s private scope and gives FR-022's gate a single choke point.
**Alternatives considered**: NotificationCenter signal (stringly, no state ownership); intent returns `OpenURLIntent(whispernotes://checkin)` (indirection through the URL layer for no benefit); duplicating trigger state per surface (two gates to keep in sync — rejected outright).

### D4 — FR-022 gate lives in the router; fixes a pre-existing ungated path

**Decision**: The onboarding gate (check `AppSettings.hasCompletedOnboarding`; incomplete → open app to onboarding, never record, calm dialog) is enforced in the router — the single point through which both the intent and the legacy URL path now flow.
**Rationale**: Research surfaced that **the shipped deep-link path has no onboarding gate**: `onOpenURL` doesn't consult `hasCompletedOnboarding`, and `CheckInView` lives under the `fullScreenCover`, so `whispernotes://checkin` can start a recording *behind the onboarding cover* today. FR-022's gate, placed in the router, closes both surfaces at once. Surfaced per Constitution III rather than silently widening scope: the fix is congruent (same gate, same function) and costs one condition.
**Alternatives considered**: gate only the new intent (leaves a shipped hole that contradicts the spec's own edge case — rejected).

### D5 — Dose write path: new `DoseLogService` protocol in `Services/`

**Decision**: A `DoseLogService` protocol + implementation owns the expedited-log pipeline: resolve default med/dose from `AppSettings` → evaluate the dose guard → insert `MedicationEvent(source: .manual, recording: nil, isMockData: false)` → save → post `.medicationEventsDidChange`. Returns a `DoseLogOutcome` (logged / guarded(activeSince) / notConfigured). The intent is its only consumer today.
**Rationale**: Today the standalone dose write is view-model-direct — `MedicationBarViewModel.logManualDose` builds the event and writes the ModelContext itself ([MedicationBarViewModel.swift:111-123](../../app-four/ViewModels/MedicationBarViewModel.swift#L111-L123)). An intent must not depend on a UI view-model; Constitution VIII requires new capabilities behind a `Services/` protocol via DI. The service is *not* retrofitted into the Log Dose sheet (guard doesn't apply there — clarification Option A — and Constitution IV says don't refactor what the task doesn't need); the sheet's path is unchanged.
**Alternatives considered**: calling `logManualDose` from the intent on MainActor (couples intent to a UI VM and drags the guard into VM territory); a store method on `RecordingStore` (dose events without recordings aren't its aggregate).

### D6 — Guard semantics: reuse the shipped boundary math verbatim

**Decision**: "Most recent dose event" = fetch `taken == true && isMockData == false`, sort `takenAt` descending, limit 1 — any medication, any logging surface (clarification Q3=A). Total guard blocks while `event.isActive(at: now)`; time-window guard blocks while `now < takenAt + X·3600`. At the exact boundary both treat the window as **closed** (log succeeds).
**Rationale**: The codebase already encodes boundary-exact-equals-expired in two places: `MedicationEvent.isActive` via `effectProgress < 1` ([MedicationEvent.swift:68-77](../../app-four/Models/MedicationEvent.swift#L68-L77)) and the med bar's strict `>` comparison ([MedicationBarViewModel.swift:75](../../app-four/ViewModels/MedicationBarViewModel.swift#L75)). FR-012 matches the shipped convention exactly — zero new math, one deterministic rule. No 24h fetch cutoff (the bar's cutoff is a display concern; the guard evaluates the latest event regardless of age — stale events simply pass).
**Alternatives considered**: boundary-open (blocks at exactly X — contradicts both shipped precedents); per-medication guard (rejected at clarify time).

### D7 — Settings storage: five defaulted fields on `AppSettings`

**Decision**: Extend the existing `AppSettings` `@Model` ([AppSettings.swift](../../app-four/Models/AppSettings.swift)) with five fields, all defaulted (see [data-model.md](data-model.md)): `defaultMedicationName: String?`, `defaultMedicationDose: String?`, `doseGuardModeRaw: String = "off"`, `doseGuardWindowHours: Int = 2`, `nameMedicationInConfirmations: Bool = false`.
**Rationale**: The repo convention is clear — durable, data-layer prefs read by services/VMs live on `AppSettings` via ModelContext (onboarding flag, prompt pace, cellular); `@AppStorage` is for per-view display toggles. A background intent reads settings without SwiftUI, exactly like `SettingsViewModel.appSettings`'s fetch-first-or-create pattern ([SettingsViewModel.swift:47-56](../../app-four/ViewModels/SettingsViewModel.swift#L47-L56)). All fields defaulted keeps Constitution IX (CloudKit-compatible; no `.unique`; schema mismatch still recoverable by wipe-and-rebuild pre-release).
**Alternatives considered**: `UserDefaults` (would work for nonisolated access — the `medicalPromptEnabled` precedent — but these are durable health-adjacent prefs, and that precedent is itself flagged as UI-orphaned; not a pattern to extend); a new `@Model` type (a second singleton for five scalars — rejected, minimal surface).

### D8 — `authenticationPolicy`: the default is already `.alwaysAllowed`; declare it anyway

**Decision**: `LogDefaultDoseIntent` explicitly declares `static var authenticationPolicy = IntentAuthenticationPolicy.alwaysAllowed`. `StartCheckInIntent` declares nothing (foregrounding forces unlock regardless).
**Rationale**: Apple documents the **default** as `.alwaysAllowed` — "allows the intent to run without authentication, including when the device is locked" ([Apple: authenticationPolicy](https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy)). The owner's accepted decision (locked-Siri works; worst case is journal pollution; nothing read back) is therefore the platform default; declaring it explicitly turns an implicit behavior into documented intent — the declaration is self-explanatory, no comment needed.
**Alternatives considered**: `.requiresAuthentication` (would kill A3 locked-Siri logging — explicitly rejected by the owner, twice).

### D9 — Acknowledgment: `IntentDialog(full:supporting:)`; **background haptic is impossible** → FR-005 amendment proposed

**Decision**: Success/guarded/not-configured responses use `IntentDialog(full:supporting:)` — `full` is what Siri speaks (incl. on the lock screen), `supporting` pairs with visual surfaces ([Apple: IntentDialog.init](https://developer.apple.com/documentation/appintents/intentdialog/init(full:supporting:))). The not-configured path uses the intent's `.foreground(.dynamic)` mode *(revised with D2)*: `perform()` calls `continueInForeground()` after surfacing the calm dialog, and the app opens routed to the "My medication" setting (FR-007's "opens on tap" — [WWDC25 275](https://developer.apple.com/videos/play/wwdc2025/275/): dynamic mode + `continueInForeground` replace `ForegroundContinuableIntent`). **The haptic clause of FR-005 cannot be honored from a background intent**: an Apple Frameworks Engineer states haptics "will not produce … when your app is not in the foreground active state" ([Apple Dev Forums, staff answer](https://developer.apple.com/forums/thread/681512)); Core Haptics documents engine suspension in background ([Apple: applicationSuspended](https://developer.apple.com/documentation/corehaptics/chhapticengine/stoppedreason/applicationsuspended)).
**Rationale**: Constitution III — surface the tradeoff, don't fake it. The felt feedback on a zero-tap sticker log comes from the system surfaces (Shortcuts banner, Siri spoken dialog), not from Squirl.
**Owner sign-off required (spec wording amendment, carried as a task)**: FR-005 "accompanied by a haptic" → "accompanied by a haptic where the platform allows (app in foreground); background acknowledgments are the system banner/spoken dialog." SC-001 is unaffected (banner within 3 s stands).
**Alternatives considered**: a local notification with sound as a pseudo-haptic (adds notification permission to a feature that needs none — rejected); silently dropping the haptic claim (violates Constitution III).

### D10 — `AppShortcutsProvider`: two shortcuts, iOS 17 initializer, `.applicationName` phrases

**Decision**: One `AppShortcutsProvider` exposing both intents with the **iOS 17.0+** `AppShortcut(intent:phrases:shortTitle:systemImageName:)` initializer (the iOS 16 variant is deprecated). Phrases all contain `.applicationName` (platform requirement); lean phrase lists suffice — iOS 17 does on-device flexible phrase matching ([WWDC23 10102](https://developer.apple.com/videos/play/wwdc2023/10102/)). No `updateAppShortcutParameters()` (no parameterized phrases). Caps are far away (10 shortcuts / 1,000 phrases per app).
**Rationale**: Zero-setup exposure from install (Siri, Spotlight Top Hit, Shortcuts app) is documented behavior ([Apple: App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts)) — this is FR-017/SC-003 with no additional mechanism. Note: the provider surfaces on both bundle IDs (dev + the stable channel present in the pbxproj).
**Alternatives considered**: none viable — this is the only zero-setup mechanism.

### D11 — DI into intents: `AppDependencyManager` + `@AppDependency`

**Decision**: `SquirlApp.init` registers the intent-facing dependencies (`DoseLogService`, the router) with `AppDependencyManager.shared`; intents resolve them via the `@AppDependency` property wrapper.
**Rationale**: This is Apple's sanctioned dependency-handoff for App Intents ([Apple: AppDependencyManager](https://developer.apple.com/documentation/appintents/appdependencymanager)); registration in `init` is guaranteed to precede any `perform()` because a background intent launch runs the full app init first (D1). Coexists cleanly with the app's own `AppDependencies` enum — the manager is the bridge, not a replacement.
**Alternatives considered**: intents reaching directly into `AppDependencies` statics (works — same process — but bypasses the framework's lifecycle guarantees and is harder to fake in tests; the service seam via the manager keeps both).

### D12 — Sticker guide hand-off: plain `shortcuts://`; no automation-creation URL exists

**Decision**: The guided "Set up your sticker" screen deep-links with plain `shortcuts://` (opens the Shortcuts app) and carries the full illustrated manual steps. It must NOT promise automation creation.
**Rationale**: Apple documents `shortcuts://`, `shortcuts://create-shortcut`, `shortcuts://open-shortcut`, `shortcuts://run-shortcut` in the Shortcuts **User Guide** ([Apple Support: shortcuts URL schemes](https://support.apple.com/guide/shortcuts/open-create-and-run-a-shortcut-apda283236d7/ios)) — but **no URL opens or creates an automation** (verified absence across the guide). `create-shortcut` creates a shortcut, not an automation — wrong artifact; linking it would strand users in the wrong flow.
**Alternatives considered**: `shortcuts://create-shortcut` (wrong artifact); x-callback-url (documented for running, not automations); no link at all (worse — the plain link at least lands users one tap from the Automation tab).

### D13 — Not-configured routing: Settings tab + My medication focus

**Decision**: The not-configured continuation (D9) and any in-app "set your medication first" affordance route via the router to `selectedTab = .settings` with a one-shot focus flag for the "My medication" control.
**Rationale**: Tab selection is a plain `@State` binding threaded `SquirlApp → RootContainerView → RootTabView` ([RootTabView.swift:19](../../app-four/Views/RootTabView.swift#L19)); the router already owns cross-surface navigation state (D3). Never a dead end (FR-007/SC-007).

### D15 — Deployment target raised to iOS 26.0 (owner decision, 2026-07-03 19:15) — REVISES D2/D9

**Decision**: `IPHONEOS_DEPLOYMENT_TARGET` 17.0 → **26.0** on the app target (all four configs incl. the Stable channel) **and both local SPM packages** (`SquirlSignals`, `SquirlDesignSystem` → `.iOS("26.0")` — owner: "all ios26"). *(Updated 2026-07-03 19:30: executed ahead of this feature on branch `feat/ios26-target` — worktree off `main` — together with reverting the iOS-17 `ScrollViewReader` shim in `ScreenContainer` back to `ScrollPosition` and deleting the dead iOS-16 guard + `vm_statistics64` fallback in `SessionSnapshot`. Spec-030's former T002 becomes a verification step.)* Swift language mode unchanged (Swift 5 + MainActor-default + Approachable Concurrency).
**Rationale**: owner instruction ("change target to ios26"), superseding the 2026-06-28 lowering. Consequences accepted and surfaced: device floor rises to iPhone 11/A13+ (**drops iPhone XS/XR**); the Master PRD §3/§10 (which document the 17.0 reach rationale) need a reconciliation pass — flagged, out of this feature's scope. Unblocks-but-does-not-adopt: Liquid Glass, iOS 18+ SwiftData `#Index`, iOS 26 interactive snippets, `LongRunningIntent` — all deliberately NOT taken (Constitution IV; the dose fetch touches tens of rows, an index buys nothing; snippets are UI surface the spec doesn't ask for).
**Alternatives considered**: staying at 17.0 (the prior default — overruled by owner); raising packages in lockstep (nothing in them needs 26 yet — YAGNI).

### D14 — Test strategy: logic in service/router, `perform()` thin

**Decision**: All testable logic — default resolution, guard evaluation (incl. boundary), outcome mapping, confirmation copy (named/discreet), onboarding gate — lives in `DoseLogService`/router/pure helpers, built RED-first with Swift Testing + in-memory `ModelContainer` (inline `ModelConfiguration(isStoredInMemoryOnly: true)` per repo convention — no shared helper exists). Intent `perform()` bodies stay thin translation layers (resolve dependency → call service → map outcome to dialog), verified by build + device QA per Constitution X's view-exemption spirit.
**Rationale**: Intent execution contexts aren't unit-testable in-process; the repo's closest shape precedents: [SettingsViewModelTests.swift](../../app-fourTests/ViewModels/SettingsViewModelTests.swift) (settings round-trip), [MedicationBarViewModelTests.swift](../../app-fourTests/ViewModels/MedicationBarViewModelTests.swift) (event/duration math), [AppSettingsTests.swift](../../app-fourTests/Models/AppSettingsTests.swift) (fresh-defaults Mirror pattern for new fields). Suites touching mock-mode-predicated fetches call `TestSupport.useRealData()` first ([TestSupport.swift:18-20](../../app-fourTests/TestSupport.swift#L18-L20)).

## Device-QA caveats (carried into quickstart)

- **DEBUG mock mode hides intent events**: `debugMockMode` defaults ON in DEBUG builds ([SquirlApp.swift:15-17](../../app-four/App/SquirlApp.swift#L15-L17)); intent-created events set `isMockData = false`, so the med bar won't show them until mock mode is off. QA with mock mode OFF.
- **Locked-NFC preconditions** (community-verified, Apple-undocumented): automations fire on a locked phone only after first-unlock-since-boot and with the screen on; a foreground step (check-in) prompts to unlock. Guide copy and QA expectations must match observed behavior.
- **Onboarding-gate QA**: the DEBUG bypass (`-skipOnboarding` or mock mode ON) skips the cover ([SquirlApp.swift:69-77](../../app-four/App/SquirlApp.swift#L69-L77)) — test the gate with mock mode off on a fresh install.
- **30-second ceiling** for intent execution (Apple, WWDC26 session 345 stating the standing constraint) — irrelevant to a SwiftData write in practice; noted for completeness.

## Pre-existing inconsistencies noted (not this feature's scope)

- `medicalPromptEnabled` has a VM property + tests but **no Settings row renders it** — don't copy that pattern; every new setting here ships with its visible control.
- `AppSettings.id` carries a legacy `@Attribute(.unique)` (Constitution IX violation tracked in BACKLOG) — untouched by this feature; the five new fields add no constraint.
