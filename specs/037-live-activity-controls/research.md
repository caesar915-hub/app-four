<!-- Created: 2026-07-16 19:03 (WEST) · Updated: 2026-07-16 19:03 (WEST) -->
# Phase 0 Research: Live Activity Recording Controls for Check-In

**Feature**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md)

Method: a 14-agent research workflow (`wf_b4118568-561`) — 4 research passes (ActivityKit lifecycle · LiveActivityIntent process model · local code grounding · background-finalize edge cases) with adversarial verification of every load-bearing decision. Platform claims are grounded in `developer.apple.com`, the **on-machine iOS 26.5 SDK** (`iPhoneOS26.5.sdk` swiftinterface/headers), WWDC pages, and Apple DTS forum answers; code claims are `file:line`-verified. Items that could not be proven without a device (no simulator per project workflow) are marked **device-verify**.

Verification outcome: of the load-bearing decisions, all survived adversarial refutation except one nuance correction (D10 — on view teardown *both* the hardware session and the orchestration survive, not just the hardware). The background-finalize agent's first structured pass was a degenerate placeholder; it was re-run standalone and its findings (D13–D17) are the corrected, grounded results.

---

## Platform & Structure

### D1 — Live Activities require a new WidgetKit extension target (the project's first extension)

**Decision**: Add a WidgetKit (Widget) Extension target (`SquirlWidgets`) with "Include Live Activity". The Live Activity UI is declared with `ActivityConfiguration(for:content:dynamicIsland:)` — a `WidgetConfiguration` in a `WidgetBundle` — which only the widget-extension process renders; it **cannot** live in the app target. Add `NSSupportsLiveActivities = YES` to the **app** target's Info.plist (confirmed absent today). The extension carries its own template-generated Info.plist.

**Rationale**: Apple: *"To offer Live Activities, add code to your existing widget extension or create a new widget extension if your app doesn't already include one … select 'Include Live Activity'."* and *"add the Supports Live Activities entry … on the iOS app target"* ([ActivityKit: Displaying live data](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)). No special entitlement is needed for local (on-device) activities.

**Alternatives**: None — there is no API to present an `ActivityConfiguration` from the app target. (Optional `NSSupportsLiveActivitiesFrequentUpdates` applies only to high-frequency **push** updates, which this feature does not use — updates are local.)

### D2 — Share `ActivityAttributes` via a small local Swift package, not per-target file membership

**Decision**: Define `CheckInActivityAttributes` (with nested `ContentState: Codable & Hashable`) once in a **local Swift package** imported by both the app and the widget extension. The app calls `Activity.request/update/end` against it; the extension references it in `ActivityConfiguration(for:)`.

**Rationale**: Under Xcode 16 synchronized folders (objectVersion 77, which this project uses — 7 `PBXFileSystemSynchronizedRootGroup` refs), a synced folder binds its files to **one** target's build phase. A shared type therefore wants a package (or framework), which sidesteps folder-to-target binding and produces no pbxproj membership churn. The project already ships local packages (`SquirlDesignSystem`, `SquirlSignals` on `feat/spm-designsystem`), so this fits precedent.

**Alternatives**: (a) local SPM package — **chosen** (one source of truth, zero pbxproj target-membership edits). (b) shared framework — equivalent, heavier. (c) single file with dual target membership via `PBXFileSystemSynchronizedBuildFileExceptionSet` — works but writes an exception set into the pbxproj per file, partially defeating the folder-sync conflict-reduction goal. (d) duplicating the file per target — **rejected** (two sources of truth; `Codable`/type-identity mismatch across the app/extension boundary).

### D3 — Live Activity lifecycle: request (sync, throws) → update (async) → end (async, immediate dismissal on stop)

**Decision**: Start with `Activity.request(attributes:content:pushType:)` (iOS 16.1+, `pushType: nil` for local) when recording begins; reflect pause/resume with `await activity.update(_:)`; on stop `await activity.end(_:dismissalPolicy: .immediate)` so the Lock Screen surface clears within seconds (SC-005). Set a `staleDate` on the content so an un-updated activity self-labels as outdated.

**Rationale**: These are the documented ActivityKit calls; the default dismissal policy leaves an *ended* activity on the Lock Screen up to four hours, so `.immediate` is required for prompt removal ([ActivityState.stale](https://developer.apple.com/documentation/activitykit/activitystate/stale)). `request` is synchronous+throwing; `update`/`end` are async.

### D4 — Elapsed timer: `Text(timerInterval:pauseTime:)` self-updates on-device; freeze via `pauseTime` (ProgressView correction)

**Decision**: Render elapsed time with `Text(timerInterval:pauseTime:countsDown:showsHours:)` (iOS 16.0+). The system re-renders the digits in the widget process — **the app pushes no per-second updates** (meets SC-004 without waking the app). To FREEZE the timer for the paused state, pass `pauseTime`.

**Correction (verified)**: `ProgressView(timerInterval:pauseTime:)` **does not exist** — `ProgressView`'s `timerInterval` initializers have `countsDown` but no `pauseTime`. Only `Text` supports in-place freezing. If a paused progress bar is ever wanted, swap to a static determinate `ProgressView(value:total:)` for the paused state.

**Rationale**: Confirmed against the iOS 26.5 SDK SwiftUI/SwiftUICore swiftinterface. This is why the plan does not need push updates or a background timer for the display.

### D5 — Dynamic Island: buttons on Lock Screen + **expanded** region only, not compact/minimal

**Decision**: Declare the Dynamic Island via `DynamicIsland(expanded:compactLeading:compactTrailing:minimal:)`. Put the Pause/Resume/Stop `Button(intent:)` controls in the **expanded** region (`DynamicIslandExpandedRegion`) and on the Lock Screen presentation. Compact/minimal are **display-only** (a recording glyph + elapsed time) — interactive controls are not allowed there.

**Rationale**: Interactive `Button`/`Toggle` backed by App Intents are allowed on the Lock Screen and expanded Dynamic Island since iOS 17, but not in compact/minimal regions (ActivityKit/WidgetKit docs). This shapes US3 (compact = glance, expand = control).

### D6 — iOS 26 ActivityKit deltas are additive, none required

**Decision**: No iOS 26-specific ActivityKit adoption is required. iOS 26 adds automatic CarPlay Dashboard presentation, a landscape Dynamic Island style, and macOS/watchOS surfaces (WWDC25 s278); broadcast/channel push landed in iOS 18. None are needed for a local, single-device recording activity.

---

## App Intents & Process Model (the crux)

### D7 — `LiveActivityIntent.perform()` runs in the MAIN APP process — background stop-and-save is genuinely reachable

**Decision**: Back each Live Activity button with a `LiveActivityIntent` (iOS 17.0+). Its `perform()` runs in the **app's own process**, not the widget extension. If the app is suspended or terminated, tapping the button **launches/wakes the app process in the background WITHOUT foregrounding**, then runs `perform()` — so it can reach the app-process singletons (audio session, live `AVAudioRecorder`, SwiftData `ModelContext`).

**Rationale**: Doubly confirmed — the iOS 26.5 SDK `AppIntents.swiftinterface` groups `LiveActivityIntent`/`AudioPlaybackIntent`/`AudioRecordingIntent` as `SystemIntent`s, and Apple's WidgetKit interactivity doc states ordinary widget intents run in the extension but these protocols move execution to the app process ([LiveActivityIntent](https://developer.apple.com/documentation/AppIntents/LiveActivityIntent); [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)). This is *the* reason P1 (background stop-and-save from the Lock Screen) is a real capability, not a degraded fallback.

**Alternatives / note**: `AudioRecordingIntent` (iOS 18+) is the domain-specific protocol and Apple couples it to Live Activities (it *requires* an active Live Activity while recording). It is the correct protocol if we ever move recording *start* under an intent; for controlling an already-running recording, plain `LiveActivityIntent` control buttons are sufficient and simpler. Recorded here as a considered option, not adopted for the control buttons.

### D8 — No unlock required: keep `authenticationPolicy` at the `.alwaysAllowed` default; set `supportedModes` background-capable

**Decision**: Do **not** set `authenticationPolicy` (the default `.alwaysAllowed` runs while locked with no Face ID/passcode — satisfies FR-005). Separately, declare a background-capable `supportedModes` (iOS 26 `IntentModes`, e.g. `.background`, or `[.background, .foreground(.dynamic)]` if any path should optionally open the app). The two knobs are orthogonal: `authenticationPolicy` gates *locked execution*, `supportedModes` gates *background vs foreground*.

**Rationale**: Apple documents `.alwaysAllowed` as running *"without authentication, including when the device is locked"* ([authenticationPolicy](https://developer.apple.com/documentation/appintents/appintent/authenticationpolicy)). This mirrors spec 030 D8 (dose intent), verified there too.

### D9 — Finalize budget is ample; wrap the awaited finalize in `beginBackgroundTask`

**Decision**: Inside `perform()`, take a `UIApplication.beginBackgroundTask` assertion, then fully `await` the finalize (stop recorder → persist file → SwiftData `save()` → `activity.end` → deactivate session), then `endBackgroundTask` (via `defer`). Never return from `perform()` before the awaits complete; never spawn a detached, un-awaited `Task`.

**Rationale**: `perform()` runs in the app process, so `beginBackgroundTask` (an app-process API) is available. Apple documents the contract *"run all necessary code before you return"* but publishes **no numeric budget**; DTS's general ~30 s background-assertion window (community-measured, do not branch on `backgroundTimeRemaining`) dwarfs a sub-second finalize ([Extending background execution time](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time); [Quinn, thread/85066](https://developer.apple.com/forums/thread/85066)). The real risk is **suspension the instant the audio session is deactivated mid-await**, not the budget — hence the assertion spanning the deactivation→save-committed window.

### D10 — Recording ownership is split; extract a process-level `RecordingSessionController`

**Decision**: The `AVAudioRecorder` + `AVAudioSession` already live in a **process-level singleton** (`AudioRecordingServiceImpl`, `AppDependencies.audioService` — `AudioRecordingServiceImpl.swift:6`, `:64`; `AppDependencies.swift:10`). But the **orchestration** (state machine, elapsed timer, level monitoring, save/transcribe pipeline) lives in a **view-coupled `@MainActor CheckInViewModel`** created in `CheckInView.init`. Extract the recording *lifecycle ownership + finalize* into a process-level, injectable `RecordingSessionController` that both `CheckInView` (via the view-model, which delegates) and the background intents drive.

**Rationale**: A background `LiveActivityIntent` has no view-model instance, yet must pause/resume and finalize the live recording. **Verified nuance (the one refuted claim)**: on `CheckInView` teardown, **both** the hardware session and the orchestration survive (the view-model is `@State`; there is no `.onDisappear` stopping it) — so today a dismissed view leaves a running recorder with a live orchestrator but no UI, and the file can be orphaned. Either way the conclusion holds: a background-safe controller must own the lifecycle, not a view. This is the plan's central Constitution VIII extraction.

**Alternatives**: (a) duplicate finalize logic inside the Stop intent → two drifting paths (rejected, Constitution III/IV). (b) 030's router-flag-only pattern → requires the app foreground/awake to consume the flag, defeating background stop (rejected).

### D11 — The 030 intent→app seam exists but only *arms start*; reuse the DI registration, add a control path

**Decision**: Register the new `RecordingSessionController` (and a `LiveActivityController`) with `AppDependencyManager.shared.add(dependency:)` in `SquirlApp.init` (the exact pattern 030 uses for the router and dose service), and resolve them in the intents via `@AppDependency`. Do not route control through the existing router one-shot flag.

**Rationale**: 030's `AppIntentRouter` uses `@Observable @MainActor` one-shot flags consumed by a SwiftUI `.onChange` binding — it can only *arm* a start that the foreground view then performs; it cannot reach the live recording to pause/stop from the background (`AppIntentRouter.swift`, `SquirlApp.swift:52-60`). The DI *registration* mechanism is reusable; the *flag* mechanism is not.

### D12 — Info.plist / pbxproj current state (ground truth)

**Decision/finding**: `UIBackgroundModes = [audio]` is already present (`app-four/Info.plist:7-10`) — recording legitimately continues while locked/backgrounded. `NSSupportsLiveActivities` is **absent** (must add). There is **no** widget/app-extension target — only two `PBXNativeTarget`s (the app + the unit-test bundle); `objectVersion = 77` with `FileSystemSynchronized` groups (adding source files does not touch the pbxproj, but adding a *target* does).

---

## Correctness & Privacy Edge Cases

### D13 — Data protection while locked: the default (`CompleteUntilFirstUserAuthentication`) already permits the locked save; verify the app hasn't opted into `Complete`, and pin the class (load-bearing)

**Decision**: Rely on `FileProtectionType.completeUntilFirstUserAuthentication` for the SwiftData store (`.sqlite` + `-wal` + `-shm`) and the finalized audio file — but treat it as an explicit, verified guarantee, not an assumption: (a) **audit entitlements** for `com.apple.developer.default-data-protection` and assert it is absent or `CompleteUntilFirstUserAuthentication` (never `Complete`); (b) **pin explicitly** on the audio file (`URLResourceValues.fileProtection` / `FileManager .protectionKey`) and on the store files after container init.

**Rationale**: The iOS 26.5 SDK header (`Foundation/NSURL.h`) documents `Complete` as *"cannot be read from or written to while the device is locked"* and `CompleteUntilFirstUserAuthentication` as accessible after the first post-boot unlock *"even if the user subsequently locks the device."* Apple's Platform Security guide names `CompleteUntilFirstUserAuthentication` the **default for all third-party app data**, and Core Data (which backs SwiftData) uses it when `NSPersistentStoreFileProtectionKey` is unset ([Data Protection classes](https://support.apple.com/guide/security/data-protection-classes-secb010e978a/web); [NSPersistentStoreFileProtectionKey](https://developer.apple.com/documentation/coredata/nspersistentstorefileprotectionkey)). Under `Complete`, a locked `save()` fails with `SQLITE_AUTH` (Apple's own [thread/682074](https://developer.apple.com/forums/thread/682074)) **and the already-open recording file would stop accepting writes ~10 s after lock** — so the fact that locked recording works at all is evidence the app is not on `Complete`.

**Privacy tradeoff (surfaced, Constitution VI)**: `CompleteUntilFirstUserAuthentication` keeps data encrypted at rest and inaccessible before first post-boot unlock, but readable while merely locked *after* that unlock — strictly weaker than `Complete` (which re-locks the key ~10 s after every lock). For sensitive health/mood/med data this is a real downgrade against a "seized while locked, post-first-unlock" adversary — but `Complete` is **incompatible** with the feature (no locked recording, no locked save). So `CompleteUntilFirstUserAuthentication` is the **safest class that still lets the feature work**. iCloud-backup exclusion (`isExcludedFromBackupKey`) is orthogonal and kept regardless.

**Caveat (device-verify)**: SwiftData's `ModelConfiguration` exposes **no** file-protection knob. Pinning the store therefore means either a Core Data `NSPersistentStoreDescription` with `NSPersistentStoreFileProtectionKey`, or `FileManager`/`URLResourceValues` protection applied to the store URL's three files post-init. The audio-file pin is straightforward. Confirm the locked `save()` succeeds on hardware.

### D14 — One idempotent, capture-id-keyed finalize, invoked from four entry points

**Decision**: Build a single idempotent finalize (keyed by capture id) shared by: (1) Live Activity STOP, (2) the `beginBackgroundTask` expiration handler, (3) `audioRecorderDidFinishRecording` (cap + interruption), and (4) next-launch recovery. Every edge below reduces to "call finalize, safely, exactly once."

**Rationale**: These four paths can race (e.g. cap-finish and a manual STOP); id-keyed idempotency is what prevents double-writes and lost captures. This is the cross-cutting primitive the whole design rests on.

### D15 — Terminated-app recovery: persist an in-progress marker; reconcile + end stale activities on launch

**Decision**: Write a lightweight "capture in progress" marker at record-start (id, file URL, start time, cap); clear it atomically in the finalize transaction. On every launch/foreground: end (`.immediate`) any recording activity not mapping to a live capture, and recover any marker whose audio file is closed+valid but has no saved `Recording` (route through the existing `pendingSave` buffer / `PendingTranscriptionService`). Validate the file (non-zero, decodable header) before recovering.

**Rationale**: If iOS jettisons the app under memory pressure after recording ended, `perform()` never runs and the Live Activity does **not** self-dismiss — there is no on-jettison hook ([thread/732418](https://developer.apple.com/forums/thread/732418)). Launch reconciliation is mandatory. The app already has `pendingSave` + `PendingTranscriptionService`; this is the same "downstream steps didn't complete" shape and reuses that machinery (D18 seam).

### D16 — Interruption can end the recording before STOP; the finalize path must tolerate an already-stopped recorder

**Decision**: Observe `AVAudioSession.interruptionNotification`. On `.began`, treat recording as suspended and update the activity to a paused/interrupted presentation (not "recording"). On `.ended`, resume only if `options.contains(.shouldResume)` **and** `setActive(true)` succeeds; else stay paused and require explicit user action. Make finalize state-tolerant (skip `stop()` if already stopped; persist the existing closed file). v1 policy: **finalize-what-exists** (not resume-and-append).

**Rationale**: An interruption deactivates the session and closes the recorder's file (SDK `AVAudioRecorder.h`; [Handling audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)). So by STOP time the recorder may already be stopped — a finalize assuming an active recorder misbehaves. The Live Activity is a separate surface and won't sync automatically; a "recording 04:12" pill during a call is the bad state to prevent.

### D17 — Cap while locked IS enforceable (premise corrected); use `record(forDuration:)`

**Decision**: Enforce the max-duration cap with `AVAudioRecorder.record(forDuration:)` set to the cap, finalizing from `audioRecorderDidFinishRecording(_:successfully:)` via the shared idempotent path (D14). Retire the 0.1 s `Task` tick as the *enforcement* mechanism (keep a coarse timer for UI elapsed display only). Add a foreground clamp as a degraded backstop.

**Rationale (corrects the plan's earlier premise)**: A suspended process doesn't execute — **but an actively-recording app under the `audio` background mode is not suspended**; active audio I/O is exactly what keeps it alive, so an in-process timer *would* keep ticking while locked. The cleaner mechanism is still `record(forDuration:)`: the SDK header states the recorder *"will stop when it has recorded this length of audio"* and fires the finish delegate, offloading the cap to the audio subsystem (no drift, lock-agnostic). **FR-011 verdict**: fully deliverable in the normal locked/backgrounded case; the only gap is an OS memory-pressure jettison before the cap, which degrades to next-launch recovery (D15). **Device-verify** that `audioRecorderDidFinishRecording` fires while the device is *locked*.

---

## Testing & Cross-Cutting

### D18 — Testable seams (Constitution X)

**Decision**: Test-first (Swift Testing) these pure seams, following existing precedent: (1) **recording state → Live Activity `ContentState`** derivation (idle/recording/paused/processing/done + elapsed → attributes) — like the pure `AudioRecordingServiceImpl.interruptionResponse(...)` tested by `AudioInterruptionPolicyTests`; (2) the **intent → control-command** routing (stop/pause/resume) — like `AppIntentRouterTests`; (3) the **`RecordingSessionController` lifecycle state machine + idempotent finalize routing** against a **mock** `AudioRecordingService`/`RecordingStore`/`TranscriptionService` (existing mock patterns in `app-fourTests/Mocks`). The WidgetKit + Dynamic Island SwiftUI views are the exempt surface (build + device QA).

### D19 — Pause/resume are currently dead code — this feature is their first real caller

**Finding**: `AudioRecordingService` declares `pauseRecording()`/`resumeRecording()`, but there is **no production caller**; `CheckInViewModel` never sets `state = .paused`, and the `.paused` branches in `CheckInView` are reachable only via the service's internal interruption handlers (dead in practice). This feature (US2) is the first real user-facing pause/resume — the plan should treat the pause path as new behavior to build+test, not merely surface.

---

## Open items carried to device QA (quickstart)

1. **Locked SwiftData `save()` succeeds** under the default protection class (D13) — the single most load-bearing device check.
2. **`audioRecorderDidFinishRecording` fires while locked** (D17) — gates FR-011 being fully closed vs. a known jettison-only gap.
3. **Suspension timing at session deactivation** (D9) — confirm the `beginBackgroundTask`-wrapped finalize commits before suspension when STOP is tapped on a locked device (debugger detached).
4. Confirm the app has **no** `com.apple.developer.default-data-protection = Complete` entitlement (D13) — a build/settings audit, not a runtime test.
