<!-- Created: 2026-07-03 18:51 (WEST) · Updated: 2026-07-03 19:15 (WEST) -->
# Quickstart: Device QA — App Intents Foundation + NFC Sticker Actions

**Feature**: [spec.md](spec.md) · **Contracts**: [contracts/app-intents.md](contracts/app-intents.md)

Owner-run validation on a physical iPhone (baseline: iPhone 12). Unit tests cover guard math/copy/gate logic; these scenarios validate the system surfaces no simulator or unit test can reach (Siri, Shortcuts, NFC, lock screen). Per project workflow: no simulator.

## Prerequisites

- Build installed on device from the feature branch; full test suite green first (Constitution II). Device must run **iOS 26** (deployment target raised — D15; iPhone 12 baseline qualifies).
- **Mock mode OFF** (Settings → debug sheet, or a non-DEBUG build): DEBUG defaults `debugMockMode` ON, which (a) hides intent-created real events from the med bar and (b) bypasses the onboarding cover — S16/S17 are invalid with mock mode on.
- One blank NDEF NFC sticker (any cheap tag).
- Siri enabled; device language English.
- For S16: a way to reset to first-run (fresh install or Clear All Data).

## A — Zero-setup exposure (SC-003)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| S1 | Shortcuts app lists both verbs | Install → open Shortcuts → search "Squirl" | Both actions listed with titles/icons; no enablement step |
| S2 | Spotlight | Pull-down search → type "Squirl" / "check in" | App Shortcuts appear near the app's Top Hit; tapping the check-in one runs it |
| S3 | Siri phrase, no setup | "Hey Siri, log my meds in Squirl" (unlocked, default NOT configured yet) | Intent runs — calm "Set your medication first." spoken/shown; **no crash, no dead end** |

## B — Default medication + expedited dose log (US1)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| S4 | Configure default | Settings → My medication → pick Elvanse 30 mg | Persists across app relaunch |
| S5 | Not-configured continuation (FR-007) | Before S4 (or after clearing default): run dose verb from Shortcuts → tap continue on the prompt | App opens **into Settings with My medication focused** |
| S6 | Log from Shortcuts app | Run dose verb (unlocked) | Banner "Dose logged · HH:MM" (discreet default); app does NOT visibly open; med bar shows the dose on next open (FR-006); event visible in day timeline |
| S7 | Siri unlocked | "Log my meds in Squirl" | Same as S6, confirmation spoken |
| S8 | **Siri locked** (A3) | Lock phone → "Hey Siri, log my meds in Squirl" | Dose logged WITHOUT unlock; Siri speaks the discreet confirmation |
| S9 | Named confirmations (FR-023) | Toggle "Name medication in confirmations" ON → repeat S6 | "Elvanse 30 mg logged · HH:MM"; toggle OFF → discreet again |
| S10 | Timestamp = now (FR-003) | Log via verb; open app | Event's time = trigger time (system short style), duration = catalog (Elvanse 10 h) |

## C — Dose guard (US3)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| S11 | Guard OFF double-log | Guard off → run dose verb twice within a minute | **Two** events exist (user's explicit choice) |
| S12 | Total guard blocks | Guard = Total → log once → run verb again | No second event; calm "Your HH:MM dose is still active."; nothing red/alarming |
| S13 | Total guard respects edited duration | With active dose, edit its duration down so it's expired → run verb | Logs normally (guard uses the event's actual duration) |
| S14 | Window guard | Guard = Time-window 1 h → log → immediate re-run (blocked) → after >1 h re-run (logs) | Block then allow; boundary behavior itself is unit-tested (exact-hour timing not device-testable) |
| S15 | In-app sheet never blocked (Option A) | With guard active and a dose active → open Log Dose sheet in-app → log | Sheet logs normally; guard message never appears in-app |

## D — Onboarding gate + check-in (US2, FR-022)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| S16 | **Strict gate on fresh install** | Fresh first-run (onboarding not completed, mock mode off) → run check-in verb from Shortcuts/Siri | App opens showing **onboarding**; NO recording starts; calm "finish setting up" dialog. Also verify the legacy path: `whispernotes://checkin` from Safari — same gate (pre-existing hole closed) |
| S17 | Check-in via verb | Onboarding complete → run check-in verb (app killed) | App opens directly in **Listening, already recording** (timer running); stop & save behaves like a normal check-in |
| S18 | Re-entry guard (FR-014) | While recording, run the verb again | No second recording; app foregrounds to the live session unaffected |
| S19 | Model-absent queue (FR-015/SC-006) | Delete/without Whisper model → record via verb → save | Capture saved as pending; transcribes automatically after model download; extraction lands |
| S20 | Mic revoked (FR-016) | iOS Settings → revoke mic → run check-in verb | App opens with the existing mic-permission guidance; nothing silent |

## E — NFC stickers (US4)

| # | Scenario | Steps | Expected |
|---|---|---|---|
| S21 | Guided setup ≤ 2 min (SC-004) | Settings → Set up your sticker → dose path → follow steps with a blank tag (hand-off opens Shortcuts; create NFC automation → dose verb → Run Immediately) | Working sticker in under 2 minutes following only the guide |
| S22 | Zero-tap sticker (A1/SC-001) | Phone unlocked, screen on → tap sticker | Dose logged + banner within ~3 s; zero taps; no confirmation prompt |
| S23 | **Locked tap degrades** (A2/C3) | Lock phone (screen on) → tap sticker | No immediate log; behavior matches guide copy (notification path; runs after unlock — community-verified precondition: at least one unlock since boot). Confirm guide wording matches observed reality — adjust copy if the OS behaves differently |
| S24 | Check-in sticker | Second automation → check-in verb → tap (unlocked) | App opens into active recording (S17 equivalence) |

## F — Regression

| # | Scenario | Steps | Expected |
|---|---|---|---|
| S25 | Med bar + insights unchanged | After several verb-logged doses: bar fill/onset pulse, day timeline, Insights | Indistinguishable from sheet-logged doses (FR-006) |
| S26 | Full suite + build | `xcodebuild` test (serial) on the branch | Green — gate for the PR (Constitution II) |

**Sign-off note**: S23's exact lock-screen behavior is the one community-verified (not Apple-documented) claim in this feature — if observed behavior differs, fix the guide copy AND the spec assumption in the same PR (they must not drift).
