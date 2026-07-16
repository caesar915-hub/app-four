<!-- Created: 2026-07-16 19:03 (WEST) · Updated: 2026-07-16 19:03 (WEST) -->
# Contract: Recording Lifecycle & Live Activity Control

**Feature**: [spec.md](../spec.md) · **Research**: [research.md](../research.md) · **Data model**: [data-model.md](../data-model.md)

Two new `Services/` protocols (Constitution VIII) injected via `AppDependencies` and registered with `AppDependencyManager` (research D11), plus the behavioral contract of the three control intents. Signatures are the *contract shape*, not final code — the implementation is built test-first per Constitution X.

## 1. `RecordingSessionController` (process-level lifecycle owner)

The single owner of the active check-in recording. Both `CheckInView` (via `CheckInViewModel`, which delegates) and the background `LiveActivityIntent`s drive it — one source of truth for start/pause/resume/stop + finalize (research D10/D14).

```
@MainActor protocol RecordingSessionController: Sendable {
    var state: RecordingState { get }                 // authoritative; .paused now user-reachable (D19)
    var captureID: UUID? { get }                      // idempotency key for finalize (D14)

    func start() async throws                         // foreground only; starts recorder with record(forDuration: cap) (D17), starts the Live Activity (D3)
    func pause() async                                // FR-004; updates activity → .paused (D4 pauseTime)
    func resume() async throws                        // FR-004; updates activity → .recording
    func stopAndSave() async                          // FR-003; idempotent finalize (D14), background-task-wrapped (D9)
    func recoverIfNeeded() async                      // launch reconcile: end stale activities, recover orphaned capture (D15)
}
```

**Contract obligations**:
- `stopAndSave()` MUST produce a saved `Recording` **identical** to an in-app stop (SC-003) — it wraps the *existing* finalize pipeline (`attemptSave` / `pendingSave` buffer / transcription chaining), not a copy (Constitution III).
- `stopAndSave()` MUST be idempotent by `captureID` — STOP, cap-finish delegate, and launch recovery may all fire; the record is saved once (D14).
- `stopAndSave()` MUST hold a `beginBackgroundTask` assertion across deactivation→save-commit, fully awaited before returning; audio session stays active until save completes (D9).
- Model-absent path MUST queue the capture as pending, identical to `CheckInViewModel` today (FR-012).
- Exactly one active recording/activity at a time (FR-010) — `start()` is a no-op / re-entry-guarded if already recording (parity with the 030 FR-014 guard).

## 2. `LiveActivityController` (ActivityKit surface)

Owns the ActivityKit lifecycle and the state→`ContentState` mapping. Isolated behind a protocol so the controller logic is testable with a mock and the app degrades when Live Activities are disabled (FR-014).

```
@MainActor protocol LiveActivityController: Sendable {
    func begin(startedAt: Date, cap: TimeInterval) async   // Activity.request; no-op if unavailable/disabled (FR-014)
    func update(_ phase: RecordingActivityPhase, pausedAt: Date?) async   // activity.update (D3/D4)
    func end() async                                        // activity.end(.immediate) (D3, SC-005)
    func endAllStale() async                                // launch cleanup (D15)
}
```

**Contract obligations**:
- `begin` MUST no-op (not throw) when Live Activities are unavailable/disabled — recording proceeds without the surface (FR-014, SC-007).
- The emitted `ContentState` MUST NOT carry transcript/mood/med content (FR-016, SC-006) — enforced by the pure derivation + its test (data-model §5).
- `end()` MUST use `.immediate` dismissal so the surface clears within seconds (SC-005).

## 3. Control intents (`LiveActivityIntent`s)

Three intents back the Lock Screen / expanded-Dynamic-Island buttons. Each is thin: resolve the controller via `@AppDependency`, call one method, return. They run in the app process, no unlock (research D7/D8).

| Intent | Button | Calls | Modes / auth |
|---|---|---|---|
| `PauseRecordingIntent` | Pause | `controller.pause()` | `LiveActivityIntent`; `supportedModes` background-capable; `authenticationPolicy` default `.alwaysAllowed` |
| `ResumeRecordingIntent` | Resume | `controller.resume()` | same |
| `StopRecordingIntent` | Stop & save | `controller.stopAndSave()` | same |

**Contract obligations**:
- MUST NOT set `authenticationPolicy = .requiresAuthentication`/`.requiresLocalDeviceAuthentication` (would force unlock, breaking FR-005) — keep the default (research D8).
- MUST NOT foreground the app (no `.foreground(.immediate)`-only mode) — the whole point is background control (FR-005).
- `perform()` MUST fully `await` its controller call before returning (D9); no detached, un-awaited `Task`.
- Each intent's `perform()` is trivial routing; the tested logic is the controller + the routing decision (data-model §5), not the intent body.

## 4. Info.plist / target deltas (research D1/D12)

- App target Info.plist: **add** `NSSupportsLiveActivities = YES`. (`UIBackgroundModes = [audio]` already present.)
- New `SquirlWidgets` WidgetKit extension target (project's first extension); `CheckInActivityAttributes` in a shared local Swift package imported by both app + extension (research D2).
- Audit: assert the app has **no** `com.apple.developer.default-data-protection = NSFileProtectionComplete` entitlement; pin store + audio file to `.completeUntilFirstUserAuthentication` (research D13).
