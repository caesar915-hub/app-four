# Swipeable Nudges (Recording) — Design Spec

**Date:** 2026-06-15
**Status:** Spec only — no implementation plan, no code yet.
**Milestone:** v1.1.2 (Post-launch polish).
**Touches:** [CheckInViewModel.swift](../../../app-four/ViewModels/CheckInViewModel.swift) (timing core), [CheckInView.swift](../../../app-four/Views/CheckIn/CheckInView.swift) (gesture + transition).

## Goal

While voice-recording a check-in, let the user **swipe the on-screen nudge card
left/right to jump to another prompt early**. The nudges still auto-advance on the
timer; a manual swipe just moves to the chosen prompt sooner **and resets the
timer**, so the newly-shown prompt gets a full fresh interval before the next
auto-advance.

Today the prompt is purely timer-driven (slides right→left every `promptInterval`
seconds) with no manual control. This adds finger control without removing the
hands-free default.

## What a nudge is

The five rotating voice prompts shown during recording
([CheckInViewModel.swift:220-226](../../../app-four/ViewModels/CheckInViewModel.swift#L220-L226)):
mood → energy → focus → sleep → strong-feelings. Each is a question + hint, with a
countdown progress bar ([promptProgressBar](../../../app-four/Views/CheckIn/CheckInView.swift#L191))
and a 5-dot indicator ([promptDots](../../../app-four/Views/CheckIn/CheckInView.swift#L236)).

## Decisions (locked)

1. **Timer stays on; swipe re-bases it.** Auto-advance is unchanged in cadence. A
   swipe jumps to the target prompt and **resets the interval clock** so the new
   prompt is shown for a full `promptInterval` before auto-advancing again. This is
   "move it earlier with my finger, timer resets" — not pause, not disable.
2. **Wrap-around (carousel).** Swiping past the last nudge (strong-feelings) loops
   to the first (mood), and vice-versa. Matches the timer's existing modulo wrap
   ([currentPromptIndex](../../../app-four/ViewModels/CheckInViewModel.swift#L231-L235)).
3. **Swipe direction = page metaphor.** Swipe **left** → next prompt (content moves
   left, forward), swipe **right** → previous. Consistent with the existing
   right-to-left auto-advance transition
   ([heroPrompt transition](../../../app-four/Views/CheckIn/CheckInView.swift#L216-L219)).
4. **Both dots and progress bar follow.** After a swipe the active dot moves to the
   new index and the progress bar resets to 0 for the fresh window (the bar already
   keys on `currentPromptIndex`, [line 202](../../../app-four/Views/CheckIn/CheckInView.swift#L202)).

## Timing model (the core change)

The current index is **stateless** — derived from the clock:

```
currentPromptIndex = Int((elapsedTime + ε) / promptInterval) % count
promptProgress     = (elapsedTime mod promptInterval) / promptInterval
```

To let a swipe override the clock without cancelling/restarting any Timer, introduce
an **anchor**: store the index the user last landed on and the `elapsedTime` at which
they landed there.

```
// new stored state
baseIndex: Int = 0
anchorTime: TimeInterval = 0   // elapsedTime at last manual (or session) anchor

currentPromptIndex = (baseIndex + Int((elapsedTime - anchorTime + ε) / promptInterval)) mod count
promptProgress     = ((elapsedTime - anchorTime) mod promptInterval) / promptInterval

func advancePrompt(by delta: Int) {   // delta = ±1
    baseIndex  = wrap(currentPromptIndex + delta)   // wrap = ((x % count) + count) % count
    anchorTime = elapsedTime
}
```

- **No swipe ⇒ identical to today.** With `baseIndex = 0, anchorTime = 0`, the
  formula collapses to the current one — so the existing deterministic-clock test
  ([CheckInViewModelTests](../../../app-fourTests/ViewModels/CheckInViewModelTests.swift), index
  sequence 0→1→4→wrap + normalized progress) stays green unchanged.
- **Reset is one subtraction.** Anchoring `anchorTime = elapsedTime` gives the new
  prompt a full interval for free — no separate timer object to cancel/restart.
- `anchorTime` resets to 0 on `startRecording()` (fresh session).

## Behavior spec

- **Auto-advance:** unchanged cadence (`promptInterval` from `PromptPace`,
  Relaxed 10s / Brisk 6s).
- **Swipe left/right:** horizontal `DragGesture` on the hero prompt card. On end, if
  `|translation.width| > threshold` (≈ 50pt), call `advancePrompt(by: ±1)`. Below
  threshold, snap back (no change).
- **Transition:** reuse the existing slide+opacity transition; a left-swipe animates
  the same direction as an auto-advance, a right-swipe mirrors it. Honor
  `accessibilityReduceMotion` (no transition when set), as today.
- **Progress bar + dots:** reset/move to the new prompt immediately on swipe.

## Accessibility

- The prompt card already exposes a combined label
  ([line 232-233](../../../app-four/Views/CheckIn/CheckInView.swift#L232-L233)). Add
  **accessibility adjustable action** (swipe up/down in VoiceOver) mapping to
  `advancePrompt(by: ±1)`, so the manual control isn't gesture-only.
- Dots stay `accessibilityHidden` (decorative); the adjustable action announces the
  new prompt via the existing label.
- Reduce Motion: jump with no slide, same as auto-advance.

## Edge cases

- **Swipe during the ε-boundary tick:** `advancePrompt` reads `currentPromptIndex`
  *before* re-basing, so a swipe landing exactly on an auto-advance boundary still
  moves exactly ±1 from what's on screen (no double-jump).
- **Rapid multi-swipe:** each swipe re-anchors; N quick left-swipes = +N prompts
  with wrap. Fine — last anchor wins.
- **Paused recording:** `elapsedTime` is frozen while paused, so swipes still work
  (index moves, clock delta is 0 until resume). Confirm against the pause/resume
  path.

## Test contract

1. **Regression:** existing auto-advance sequence + normalized progress tests pass
   unchanged (proves the no-swipe collapse).
2. **Swipe forward/back:** from a known `elapsedTime`, `advancePrompt(by: +1)` moves
   index +1 and resets `promptProgress` to ~0; `by: -1` moves −1 with wrap (index 0
   → 4).
3. **Timer reset:** after a swipe at `elapsedTime = t`, the next auto-advance occurs
   at `t + promptInterval` (not at the next absolute interval mark).
4. **Wrap:** `advancePrompt(by: +1)` at index 4 → index 0; `by: -1` at index 0 → 4.

## Out of scope

- Changing auto cadence, `PromptPace`, or the nudge copy.
- Reordering / editing / adding nudges.
- Vertical gestures other than the VoiceOver adjustable action.
- Any haptics (could be a follow-up; not required for v1.1.2).

## Accepted tradeoff

Introducing `baseIndex`/`anchorTime` makes the prompt index **stateful** where it was
a pure function of the clock. Justified: manual override is impossible without state
that can diverge from the timer. The anchor design keeps that state minimal (two
fields) and preserves the pure-clock behavior exactly when untouched.
