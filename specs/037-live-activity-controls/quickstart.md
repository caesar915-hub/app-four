<!-- Created: 2026-07-16 19:03 (WEST) · Updated: 2026-07-16 19:03 (WEST) -->
# Quickstart: Device QA — Live Activity Recording Controls

**Feature**: [spec.md](spec.md) · **Contracts**: [contracts/recording-lifecycle.md](contracts/recording-lifecycle.md) · **Research**: [research.md](research.md)

Owner-run validation on a physical iPhone (baseline iPhone 12, iOS 26). Unit tests cover the pure seams (state→ContentState mapping, controller lifecycle + idempotent finalize, intent routing — data-model §5); these scenarios validate the surfaces no simulator or unit test reaches: the Lock Screen, the Dynamic Island, background execution while locked, and the audio-session lifecycle across lock. Per project workflow: **no simulator**.

## Prerequisites

- Build installed from `feat/037-live-activity-controls`; full test suite green first (Constitution II).
- **Mock mode OFF** and **onboarding complete** (Settings → debug sheet, or a non-DEBUG build) — same footgun as spec 030: mock mode hides state that intents read.
- **Detach the Xcode debugger** for the locked-device scenarios — an attached debugger changes suspension/background timing and can mask the exact behavior we are validating (research D9). Launch from the Home Screen, then lock.
- A device that has passed **at least one unlock since boot** (required for the `.completeUntilFirstUserAuthentication` store to be readable — research D13).
- A Dynamic Island device for section C (iPhone 14 Pro+); section A/B/E work on any iPhone.

## A — Core: control from the Lock Screen without unlocking (US1 / US2, FR-005)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| L1 | Activity appears on start | Start a check-in in the app | Live Activity appears on the Lock Screen within ~1 s (SC-002); shows a recording indicator + running elapsed time |
| L2 | **Elapsed timer runs without the app** | Start recording → lock the phone → watch the Lock Screen for ~30 s | Timer keeps advancing while locked (self-updating `Text(timerInterval:)`, no app wake — research D4); audio keeps capturing (FR-006) |
| L3 | **Stop-and-save while locked, no unlock** | While locked, tap **Stop** on the Lock Screen activity | Recording ends; activity clears within a few seconds (SC-005); **phone never unlocks** (FR-005); unlock later → a saved journal entry exists, equivalent to an in-app stop (FR-003, SC-003) |
| L4 | Pause while locked | Start → lock → tap **Pause** | Timer **freezes**; indicator shows a paused (not recording) state (FR-008); capture suspended |
| L5 | Resume while locked | From L4, tap **Resume** | Timer resumes; indicator shows recording again; on later Stop the saved audio contains pre- and post-pause speech, paused gap excluded (SC-008) |
| L6 | Model-absent stop | Delete/without Whisper model → record → Stop from Lock Screen | Capture saved as pending; transcribes automatically after model download (FR-012, parity with 030/US3) |

## B — Load-bearing platform checks (research open items — do these carefully)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| P1 | **Locked SwiftData save succeeds** (research D13) | With the debugger detached, lock → record → **Stop from Lock Screen** → keep locked ~30 s → unlock | The `Recording` row **and** audio file persisted. If missing → the store/audio file is on `FileProtectionType.complete` (locked write blocked); fix the protection class per research D13. This is the single most important check. |
| P2 | **Auto-stop at cap while locked** (FR-011, research D17) | Set/reach the max-duration cap while locked & backgrounded (record past it with the phone locked) | Recording auto-stops-and-saves while locked (`record(forDuration:)` + finish delegate); activity shows ended, then clears. If it only stops on next foreground → the cap fell back to the degraded path; note it. |
| P3 | No-unlock is really no-unlock | Repeat L3 and confirm no Face ID/passcode prompt appears at any point of the Stop | Runs headless (`.alwaysAllowed` default — research D8) |
| P4 | Data-protection entitlement audit (build-time, not runtime) | Inspect Signing & Capabilities / entitlements | **No** `com.apple.developer.default-data-protection = Complete` (research D13) |

## C — Dynamic Island (US3, research D5)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| D1 | Compact presence while in another app | Start recording → open another app | Dynamic Island shows a recording glyph + live elapsed time (compact = **display only**) |
| D2 | Expanded controls | Long-press / expand the Dynamic Island | Pause/Resume + Stop buttons present; behave identically to the Lock Screen controls (D3 equivalence) |
| D3 | Compact has no controls | Confirm the compact/minimal region shows no buttons | Correct — interactive controls are Lock Screen + expanded only (research D5) |

## D — Edge cases & recovery (research D15/D16)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| E1 | Stopped in-app clears the activity | Start → return to app → Stop **in-app** while the Lock Screen activity shows | Activity removed promptly; never contradicts the app (FR-007) |
| E2 | Interruption (phone call) | Start recording → receive a call | Activity reflects paused/interrupted (not "recording"); after the call, on Stop the finalize saves what was captured (finalize-what-exists, research D16); no crash, no empty file |
| E3 | **Terminated-app recovery** | Start recording → force-terminate the app (or induce a jettison) → relaunch | No stale "recording" activity lingers (ended on launch); the in-progress capture is recovered/saved or cleanly discarded if unusable — never silently lost (FR-007, research D15) |
| E4 | Re-entry guard | With a recording active, trigger another start (e.g. check-in verb) | No second recording; at most one activity (FR-010) |
| E5 | Live Activities disabled | Settings → disable Live Activities for Squirl → record + stop in-app | Recording works fully; no activity appears; no error (FR-014, SC-007) |
| E6 | Reduce Motion | Enable Reduce Motion → start recording | Recording indicator is static, not animated (FR-015) |
| E7 | Privacy | Inspect the Lock Screen activity in every state | Only elapsed time + phase shown — never transcript, mood, or medication content (FR-016, SC-006) |

## E — Regression & gate

| # | Scenario | Steps | Expected |
|---|---|---|---|
| R1 | In-app check-in unchanged | Run a normal in-app check-in start→stop | Identical to before this feature (the controller extraction must not change in-app behavior) |
| R2 | Full suite + build | `xcodebuild` test (serial) on the branch | Green — PR gate (Constitution II) |

**Sign-off note**: P1 (locked save) and P2 (`audioRecorderDidFinishRecording` fires while locked) are the two claims that could not be proven without hardware (research D13/D17). Treat FR-003/FR-011 as fully closed only after P1/P2 pass on-device; if either fails, the fix (protection class / cap fallback) ships in the same PR and research.md is corrected to match observed reality — spec and behavior must not drift.
