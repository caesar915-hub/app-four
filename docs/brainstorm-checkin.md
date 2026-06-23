# Check-in — Brainstorm

> Divergent exploration (superpowers-style) from [the critique brief](ux-critique-checkin.md). Each thread ends in a **decision that's yours**. Feeds Spec Kit.


**North star:** Let an ADHD user offload "how today feels" in under a minute and walk away certain it landed — capture-and-release with a felt confirmation, never a task to complete or a habit to maintain.


## Thread 1 — The capture moment: what 'done' should feel like

**Question:** When the check-in lands, should the body feel it (haptic + a single signature ring-settles-into-check motion), and is the Saved screen a calm exit, a one-tap re-record, or a glimpse of what was heard?


*Why it matters:* The entire product reward model is 'I said it and it's captured' (DESIGN.md#L86), yet today that moment fires with zero haptic — Haptics.success() exists and is called nowhere in the flow (brief §9) — and the spec'd crescent-settles-to-a-check morph is faked as a cross-dissolve to a separate CheckInSavedView (CheckInView.swift#L75 vs DESIGN.md#L80,L92). For a time-blind, reassurance-hungry audience, an un-felt confirmation is a confirmation that doesn't fully land, and the Saved screen's two behaviorally-identical buttons (CheckInView.swift#L308-311) waste the one beat the user is paying attention.


### ▸ The Settle — signature ring→check morph + haptic, calm dead-stop exit  *(effort M)*
Build the missing signature motion: the recording crescent decelerates from its spin, contracts, and its stroke redraws into a checkmark in place (matchedGeometryEffect / single canvas), landing with one Haptics.success() tap exactly as the check completes. 'Captured.' fades in under it. Keep a single 'Done' button; drop 'Check in again' (it's identical anyway). The reward is the motion + the buzz, not a follow-up choice.
- **Pros:** Delivers the product's stated signature moment (DESIGN.md#L80,L92) that is currently unmet — the highest-identity, lowest-feature-creep win; One haptic at the exact frame the check completes is the textbook 'it landed' confirmation this audience needs; uses the already-built Haptics.success() (brief §9); Removing the redundant second button kills the false primary/secondary implication the brief flags (P2, CheckInView.swift#L308-311) and lowers decision load; A true dead-stop exit honors 'capture and release' — nothing asks the user to keep going
- **Cons:** The ring→check morph is real engineering: the spinning AngularGradient arc (CrescentRing.swift) and the separate checkmark Circle (CheckInView.swift#L286-294) must become one animatable shape — fiddly to make buttery; Must degrade gracefully under Reduce Motion (already a static-glow fallback exists at L317) — the morph needs an instant-state equivalent; Removes the one-tap re-record some power users might want (mitigated by Thread B's adaptive hub)
- **Brand fit:** Bullseye. This is the exact motion language DESIGN.md prescribes ('settles to a check when saved') and the calm, inevitable deceleration is 'effortless = inevitability' (DESIGN.md#L79). One soft haptic is on-brand reassurance, not gamification.

### ▸ The Echo — a one-breath glimpse of what was heard  *(effort L · feature)*
After the check pops, surface a single, quiet line of what the app caught — not a transcript, not a card, but one extracted hint: 'Heard you — mood, energy, and a note about work.' or the literal first ~6 words. It fades after ~2.5s into the calm 'Captured.' state. Gives proof-of-capture without reopening the editing loop the saved-state spec deliberately closes.
- **Pros:** Answers the deepest ADHD anxiety — 'did it actually get what I said?' — with evidence, the strongest possible trust signal; Pure read-only glimpse respects the locked 'no transcribing UI, no daily card on Saved' decision (DESIGN.md#L108) if scoped to a one-line echo, not a card; Differentiates first-capture-of-the-day from a calm re-entry
- **Cons:** Extraction runs in the BACKGROUND after save (CheckInViewModel.swift#L109-114) and races a 90s timeout — the signals are NOT ready at the moment Saved appears, so an instant echo is architecturally impossible without blocking, which violates the no-spinner reward model; An echo that arrives late (popping in 4s later) or says 'still listening…' reintroduces exactly the processing-status UI the product banned; Risks pulling the user back into reading/checking when the whole point was release
- **Brand fit:** Tense. The intent (trust, warmth, 'the field heard you') is deeply on-brand, but the timing fights the silent-background architecture and the locked no-status-UI decision. On-brand only if reduced to a generic, instant, non-transcript reassurance line that never shows progress.

### ▸ The Loop — Saved screen becomes a deliberate two-path fork  *(effort M)*
Keep both buttons but make them genuinely different: 'Done' returns to the calm hub; 'Add to this' (replacing 'Check in again') immediately re-enters recording and appends to the SAME check-in entry, for the user who walks away then remembers one more thing. Pair the save with a haptic regardless.
- **Pros:** Fixes the brief's P2 (two buttons, identical behavior) by giving the second a real, distinct job; Matches a real ADHD pattern: the afterthought 30 seconds later ('oh, and I forgot to take my meds'); Cheapest of the three to wire if 'append' just starts a new linked recording
- **Cons:** 'Append to same entry' is a data-model question (one Recording vs two linked) the saved-state layer can't answer alone — likely a larger change than it looks; Two buttons on the reward screen keeps decision load up at the exact moment we want the user to feel done and leave; Risks encouraging a 'did I say enough?' completionist loop — mildly against the no-pressure posture
- **Brand fit:** Neutral-to-good. Forgiving and low-stakes (DESIGN.md#L71), but two choices on a confirmation screen slightly undercuts the 'one primary action, then release' calm. Better than today's fake pair; weaker than a clean dead-stop.

**↳ Recommendation:** Ship The Settle (morph + single haptic + single Done). It is the one direction that closes a real spec gap, delivers the product's signature motion, and lands the reward in the body — all without reopening any loop the Saved state was designed to close. Treat The Echo as a tempting trap: its intent is right but it collides head-on with the silent-background architecture (CheckInViewModel.swift#L109-114) and the locked no-status-UI decision. Fold the one good idea from The Loop — a single, optional re-record path — into Thread B's adaptive hub instead of cluttering the confirmation screen.


**🟡 Your decision:** Approve building the crescent→check 'Settle' morph as the product's signature save motion with one Haptics.success() at completion, AND approve dropping 'Check in again' for a single 'Done'. Separately, rule on The Echo: do you want ANY post-save glimpse of what was heard, accepting it can only ever be a generic instant reassurance line (never live extraction), or is a pure no-echo calm exit correct?


## Thread 2 — The idle hub: orientation, the ambient ring's job, and who reaches for what

**Question:** Should the hub adapt over time — earning a first-run orientation, giving the oversized crescent an actual job, and re-weighting Speak vs Type vs Log-meds to the person's real habit — or stay a fixed, identical canvas for day 1 and day 100?


*Why it matters:* Today the hub is static: a brand-new user and a 100-day user see the identical 'Ready when you are.' with no hint that voice is the fast path (brief §9), the breathing CrescentRing eats ~40% of the screen as pure ambience that a newcomer may misread as a progress bar or a tap target (brief §5), and 'Type note' / 'Log meds' sit at equal weight below Speak regardless of which the user actually uses (seed 3, CheckInView.swift#L103-112). For an audience that abandons apps they can't immediately parse, the unguided first 3 seconds and the unexplained large ambient object are real friction.


### ▸ Whisper-once orientation — one ghost hint that never returns  *(effort S · quick)*
On the very first launch only, show a single low-contrast line under the headline: 'Tap Speak and just talk — a minute, then you're done.' It fades the first time the user starts any capture and never reappears. No coachmarks, no carousel, no demo recording. Optionally a one-time faint caption under the ring: 'just breathing — tap Speak when ready' to defuse the 'is this a button?' question.
- **Pros:** Solves the zero-orientation first-run gap (brief §9) with the lightest possible touch; Directly defuses the 'crescent looks like a progress bar / tap target' confusion (brief §5) by naming what it is once; Self-erasing — a 100-day user never sees clutter; honors 'trust discovery' for everyone after day 1; Trivial to build (a first-launch flag + a Text)
- **Cons:** A user who skips it day 1 (didn't read) loses it forever; Adds first-run state to track, however small; Doesn't address habit adaptation or the ring's ongoing ambiguity past launch
- **Brand fit:** Excellent. A single ghost line that grants permission and disappears is exactly the 'relief, then permission' first-3-seconds goal (DESIGN.md#L16) and the calm, non-naggy posture. No gamification, no checklist.

### ▸ Give the ring a job — last-check-in echo / time-of-day warmth  *(effort M)*
Make the idle crescent carry quiet meaning instead of pure decoration: a faint fill or a single word inside it reflecting continuity ('Last: yesterday morning' as a whisper, or a subtle warmth/coolness shift by time of day). Not a streak, not a count — a felt 'the field remembers you' (seed 8). The ring stops being ambiguous ambience and becomes a low-stakes mirror.
- **Pros:** Earns the 40% of screen the ring occupies (brief §5) by giving it a reason to be that big; Delivers seed 8's non-gamified continuity — 'returning feels rewarding' without streaks or shame; Makes the hub feel alive and personal rather than a blank launcher
- **Cons:** 'Last: yesterday' is one hop from a streak/recency-guilt signal — for this audience that's a live risk; 'last check-in 6 days ago' could read as reproach (directly against DESIGN.md#L86); Time-of-day warmth is subtle to the point of possibly being invisible — effort with uncertain payoff; Any text inside the ring reopens the 'is it a tap target?' read it was meant to kill
- **Brand fit:** Mixed. The 'field remembers you' intent is beautifully on-brand (a field journal that listens, DESIGN.md#L14). But ANY recency surfacing flirts with the exact shame mechanic the product is built to reject — needs extreme care, and an absolute ban on showing gaps/counts.

### ▸ Adaptive weighting — the hub learns Speak vs Type vs Log-meds  *(effort L · feature)*
After N sessions, gently re-rank the secondaries to match the person: a habitual typer sees 'Type note' promoted to equal-with-Speak weight; a meds-logger sees 'Log meds' surface first. Speak stays the default primary unless the user demonstrably never uses voice. Subtle, threshold-based, never a settings toggle.
- **Pros:** Honors seed 3 — voice is DESIGNED-for but not everyone's fast path; the hub meets the actual user; Reduces taps-to-intended-action for established habits (flexibility & efficiency, brief P2); Invisible personalization feels like the app 'gets' them
- **Cons:** Adaptive layout that shifts under the user is a known ADHD hazard — unpredictable UI placement breaks muscle memory and raises anxiety; the cure can be worse than the disease; Demoting voice contradicts the explicit design intent that voice is THE fast path (DESIGN.md#L8) — re-weighting toward typing may be optimizing for a local habit against the product thesis; Needs usage instrumentation + thresholds + a stability guarantee — meaningfully more complex than it looks
- **Brand fit:** Risky. Personalization is warm, but shifting affordances violate the calm-predictability the audience depends on, and demoting Speak fights the core posture. On-brand only if changes are rare, reversible, and never move the primary.

**↳ Recommendation:** Do Whisper-once orientation now (S, pure upside, closes the first-run gap and the ring-ambiguity in one stroke). Hold 'Give the ring a job' as a deliberate design exercise gated on one hard rule — it may surface warmth/continuity but must be physically incapable of showing a gap, a count, or a 'last seen X days ago', or it becomes the shame mechanic we banned. Decline Adaptive weighting: shifting affordances is an anti-pattern for this exact audience and demoting voice fights the product thesis; if habit-fit matters, solve it with a fixed, user-invisible default, not a moving layout.


**🟡 Your decision:** Approve the one-time whisper hint for first launch. Then make the strategic call on the idle ring: keep it purely ambient (and just caption it once), OR commission a 'field remembers you' continuity treatment under a strict no-gaps/no-counts/no-recency-guilt constraint — knowing that constraint is what keeps it on-brand.


## Thread 3 — The recording nudges: rhythm, checklist, or ignorable scenery?

**Question:** What is the rotating prompts' actual job — an ambient breathing rhythm the user can ignore, a sensed-progress checklist of the five signals, or pure scenery — and either way, how do they stop being invisible to VoiceOver, the audience most reliant on them?


*Why it matters:* The prompts ARE the recording UX, yet they rotate on a pure timer regardless of whether the user has said anything (CheckInViewModel.swift#L244-255), and they are entirely silent to VoiceOver — the progress bar and dots are accessibilityHidden, and prompt rotation posts no announcement (brief §6, P1, CheckInView.swift#L205,L245). A VoiceOver user hears the first prompt once, then nothing — the screen's whole reason for existing while recording is eyes-only. Worse, the countdown bar (CheckInView.swift#L190-201) frames the prompts as a timed task, which can pressure a time-blind user into feeling they're falling behind a clock.


### ▸ Ambient rhythm — drop the countdown, prompts drift, fully ignorable  *(effort S · quick)*
Reframe prompts as gentle scenery, not a task. Remove the per-prompt countdown progress bar (it implies a deadline); let prompts cross-fade slowly as quiet suggestions the user is free to ignore. Keep the dots only as a faint 'there's more if you want it' texture. The user talks freely; prompts are a calm metronome, never a checklist to satisfy.
- **Pros:** Removes the subtle time-pressure the countdown bar creates — critical for time-blind, overwhelm-sensitive users (DESIGN.md#L9); Matches the truth that prompts already advance regardless of answers (CheckInViewModel.swift#L244) — stops pretending they're a tracked task; Simplest mental model: 'just talk, glance if you want a nudge'; Deletes the float-drift countdown complexity the brief flags (P3, promptProgress)
- **Cons:** Loses the only on-screen sense of 'how long have I been going' the bar provided (timer still shows, so partly mitigated); Some users like a visible structure; pure ambience may feel aimless to them; Doesn't by itself fix VoiceOver — still needs an announcement layer
- **Brand fit:** Strong. 'Calm, unhurried, no you're-late alarms' (DESIGN.md#L82,L86) argues directly for removing a countdown. Ambient drift is the most on-brand posture for the nudges.

### ▸ Sensed checklist — five signals you can feel progress against  *(effort M)*
Lean the other way: make the five prompts (mood/energy/focus/sleep/feelings) a visible-but-gentle set the user senses progress through — a dot lights as each prompt passes, giving a soft 'we've covered the main things' feeling by the end, without ever requiring an answer. Pair with VoiceOver announcements per advance.
- **Pros:** Gives structure-seeking users a satisfying 'we got the important stuff' arc; Maps cleanly to the five extracted signals — the prompts mirror what the app will pull out; Sensed completeness can reduce the 'did I forget to mention something?' afterthought loop
- **Cons:** A checklist — even a gentle one — invites completionism and the guilt of 'I didn't fill all five', adjacent to the gamification the product bans (DESIGN.md#L86); Lit dots tied to a timer (not to actual answers) are dishonest — they imply the user covered focus when they didn't say a word about it; Raises pressure for the exact users who shut down under it
- **Brand fit:** Weak-to-mixed. A progress-able checklist edges toward the achievement framing the posture rejects. Only on-brand if 'progress' is framed as 'topics offered' not 'topics completed' — a fine line easy to get wrong.

### ▸ Make it heard — VoiceOver-first nudges (orthogonal, ships with either above)  *(effort M)*
Independent of the visual posture: post a polite UIAccessibility announcement on each prompt advance, group the recording crescent + timer as a single 'Recording, 0:42 elapsed' live region that updates, expose the prompt question/hint as the spoken content, and announce the state transitions ('Saving…' → 'Captured.'). This is the accessibility fix the brief rates P1 — the recording experience is currently eyes-only.
- **Pros:** Closes the screen's most serious accessibility gap (brief §6, two P1s) for an audience with high ADHD/sensory-disability overlap; Pure addition — no visual redesign; composes with whichever rhythm/checklist posture wins; Makes the guided-nudge mechanic real for VoiceOver users instead of silent (brief P1)
- **Cons:** Announcement cadence must be tuned — too frequent and it talks over the user mid-recording (ironic, since they're literally speaking); May need to suppress prompt announcements while the mic is hot to avoid the app interrupting the user's own voice note; Live-region timer updates need throttling to avoid VoiceOver chatter
- **Brand fit:** Fully on-brand by omission — accessibility is table stakes, and the existing screen already shows above-average a11y discipline (brief §3). This finishes that work.

**↳ Recommendation:** Combine Ambient rhythm (S) with Make it heard (M). Drop the countdown bar's deadline framing in favor of calm drift — it's the most honest and least pressuring posture and matches what the code already does — and layer the VoiceOver announcement set on top to close the P1 gap. Decline the Sensed checklist: tying lit progress to a timer rather than to actual answers is both dishonest and a soft reintroduction of completionist guilt, the precise failure mode the audience flees. Note for the a11y work: gate prompt announcements so the app never speaks over a user who is actively recording — likely announce only on the visual swap when speech pauses, or suppress entirely while the level meter shows active voice.


**🟡 Your decision:** Pick the nudge posture: ambient ignorable drift (recommended, removes the countdown bar) vs keep the visible countdown-and-dots structure. Then approve the VoiceOver pass (per-prompt announcements + a 'Recording, elapsed' live region + Saving/Captured announcements) as required regardless of which posture wins — and decide whether prompts should announce at all while the mic is live, or stay silent until a pause.


## Thread 4 — Interruptions, the 8-minute cliff, and the kindest 'your recording got cut off'

**Question:** When a recording is interrupted (phone call) or hits the silent 8-minute auto-stop, what's the kindest handling — a warm pre-warning, a graceful save-what-we-got, or a resume affordance — so it never reads as failure or lost work?


*Why it matters:* Today these paths are silent and rough: .paused renders IDENTICALLY to .recording with no 'paused — resume?' affordance (brief §9, CheckInView.swift#L72), the 8-minute cap (CheckInViewModel.swift#L282) cuts the user off mid-thought and drops straight to Saved with no warning, and any stop/save error silently resets to .idle with the capture discarded and no message (brief P2, CheckInViewModel.swift#L115-118). For an impulsive, time-blind audience that may be mid-thought, a silent cut-off or a vanished recording reads as the app failing them — corrosive to the trust the whole product depends on.


### ▸ Gentle approach + soft landing — warn near the cap, auto-save the rest  *(effort M)*
As the 8-minute cap nears (~last 30s), the crescent or a faint line gives a calm signal: 'wrapping up soon — say what matters.' At the cap, instead of a hard drop, finish gracefully into the same Settle/Captured moment so the user feels saved, not cut. For interruptions, on resume show a quiet 'picked back up' rather than a silent identical screen.
- **Pros:** Turns the cliff into a soft landing — the user is never surprised by a cut (brief §9, 'time's up' notice); A gentle approach indicator directly serves time-blind users who can't feel 8 minutes passing (DESIGN.md#L9); Reuses the Settle/Captured ending so even a forced stop feels like a successful capture, not a failure
- **Cons:** Any approach indicator risks reintroducing clock-pressure — must be a one-time soft cue, not a ticking countdown; 'Wrapping up soon' could rush a user who was mid-important-thought; 8 minutes is already very long; the warning may almost never fire in practice (low payoff vs effort)
- **Brand fit:** On-brand if the cue is a single warm whisper, not an alarm (DESIGN.md#L86 bans 'you're late' alarms). The soft-landing-into-Captured is squarely the calm, forgiving posture (DESIGN.md#L71).

### ▸ Never lose a capture — save-buffer + non-alarming recovery surface  *(effort M)*
Make discard structurally impossible: on any stop/save failure, keep the audio in a retry buffer and show a calm inline line — 'Couldn't save that one — tap to try again' — instead of silently resetting to idle. Mirror the existing lowDiskSpace/permission alert pattern (CheckInView.swift#L39-51) but inline and gentle. Same for a transcription failure: the recording persists and is recoverable, never vanished.
- **Pros:** Closes the brief's P2 silent-failure gap — a lost capture is currently invisible (CheckInViewModel.swift#L117); Trust-critical: 'I spoke and it's safe' breaks completely if a save can silently evaporate; Reuses an established alert/recovery pattern already in the screen — low conceptual overhead
- **Cons:** A retry buffer adds state and lifecycle to manage (where it lives, when it's cleared); Error copy, however gentle, still surfaces failure — must be worded as 'try again' not 'something went wrong'; These paths are rare, so it's insurance, not a visible everyday win
- **Brand fit:** Strong. 'Forgiving, easy undo, no penalty' (DESIGN.md#L71) demands that a capture never silently dies. Non-alarming recovery copy keeps it warm. This is the posture made real on the unhappy path.

### ▸ Resume-able pause — treat interruption as a held breath  *(effort L · feature)*
Give .paused its own real UI: the crescent stops revolving and dims to a 'held' state, the timer freezes, and a single 'Resume' / 'Stop & save' pair appears — 'Paused for a call. Pick up where you left off.' On return from the phone call the user chooses to continue the same recording or save what they have.
- **Pros:** Fills the explicit gap that .paused looks identical to .recording (brief §9, CheckInView.swift#L72); Matches reality — phone calls interrupt voice notes constantly; a resume affordance respects the user's in-progress thought; InterruptionType (phoneCall etc.) already exists in the enum (AppEnums.swift#L34) — the model anticipates this
- **Cons:** Resuming/appending to a partial audio file is non-trivial audio-engine work — bigger than a UI state; If the user forgets they were recording, a paused session lingering on return could confuse; Edge-case-heavy (call answered vs declined vs ended) for a path that may be uncommon
- **Brand fit:** On-brand intent (calm, forgiving, 'a held breath' fits the breathing-crescent metaphor), but the implementation depth makes it the least 'effortless to ship' of the three.

**↳ Recommendation:** Prioritize Never lose a capture (M) first — it's the trust-critical floor; a product whose one promise is 'it's captured' must never silently discard a capture, and the brief flags the silent reset as a real P2 today (CheckInViewModel.swift#L115-118). Add Gentle approach + soft landing (M) second so the 8-minute cliff becomes a warm landing into Captured. Treat Resume-able pause as a fast-follow, not now: it fills a real gap but the audio-append engineering is L-effort for an uncommon path — a minimally honest interim is enough (when interrupted, just show a 'paused — resume or save' state visually, even if 'resume' simply means 'keep the recording you have and finish').


**🟡 Your decision:** Approve making save-failure non-silent (retry buffer + gentle inline 'try again', never a silent reset). Then decide the 8-minute cap treatment: add a one-time soft approach whisper + graceful save-into-Captured, or leave the cap silent (accepting mid-thought cut-offs). And rule on pause: minimal honest 'paused' state now, or commit to full resume-the-same-recording (L) later?


## Wildcards

- Voice-reactive crescent as the ONLY recording feedback — kill the prompts. The audioLevelStream is already subscribed and thrown away (CheckInViewModel.swift#L290-297) and DESIGN.md#L80 explicitly specs a 'voice-level glow.' Wire the level to the ring so it breathes brighter/wider with the user's voice — making the crescent a living 'I can hear you' mirror. For some users this single honest signal ('the app is listening, here's proof') may beat five rotating text prompts entirely: less to read, less pressure, more presence. Bold because it means trusting ambient feedback over guided structure.
- Eyes-closed / heads-down recording mode — a deliberately near-blank screen while the mic is hot. Many ADHD users think out loud better without a UI watching them; an optional posture where, once recording starts, the screen goes almost dark except the breathing voice-glow and a tiny stop target invites the user to look away and just talk. The richest capture often comes when you stop performing for the interface. Risky because it hides the timer/prompts some users rely on — but it's the most radical expression of 'the app slightly calmer than you.'
- A one-line spoken send-off instead of a visual one — at the Captured moment, an optional soft audio/haptic 'got it' chime (not a voice, a single warm tone) so the user who has already looked away from the screen still feels the confirmation land. Pairs with the haptic for eyes-free/heads-down capture. Risky for a privacy-first, library-quiet app (sound in public is a liability) — must be off by default and opt-in — but for the heads-down user it completes the 'I said it and it's captured' loop without requiring them to look back at the phone.
