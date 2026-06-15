# app-four Backlog

Single source of truth for where every feature, mockup, and idea stands.
Update the **Stage** as work moves. Keep newest activity near the top of each section.

**Stages**
- 💡 **Idea** — investigated/considered, no plan written
- 📐 **Plan** — spec and/or implementation plan exists, not built
- 🔨 **In code** — being built / on a branch, not on `main`
- ✅ **Shipped** — merged to `main`

Last updated: 2026-06-15 (**Calendar header scroll-fade** — first feature through full Spec Kit; → 🔨 In code on `fix/calendar-header-scroll-fade`, suite 223/0 green, on-device verify pending. Whisper simulator-compute fix split to its own branch. // **Swipeable nudges** spec filed → new **v1.1.2** milestone + 📐 Plan row. app-four fork **build/test-verified** on `main` — builds green on iPhone 17 sim; identity resolved to **Squirl** + codename app-four, broken doc links repaired; MedicationBar midnight-flaky test fixed. **suite now reliably green (212/0, two consecutive serial runs)** — the `ModelContext.reset` crash was an orphaned `AIModelServiceImpl.download()` Task writing `ModelMetadata` after teardown; fixed with a cancellation guard. **v0.8 is code-complete; Insights palette colours moved to new milestone v0.8.1.** CI's green-suite prerequisite is met.)

---

## 🎯 Milestones

Your roadmap. Not a feature list — a finish line. Each milestone is **one sentence of user outcome** + the backlog items that gate it. Everything not tied to a milestone is "later." Fill in the outcomes when you've thought it through.

**Focus right now: v0.8 → v0.8.1 → v0.9.** v1.0 is parked below as the destination; don't build toward it until 0.9 ships.

### v0.8 — Dogfood _(focus)_ _(TestFlight: 18 Jun 2026)_
> **Outcome:** Every day I can open the app, voice-log a check-in in under a minute, and trust it captures, transcribes, and tags every time — solid enough that I actually keep using it instead of avoiding it.
> **For:** just me.

✅ **Code-complete** (2026-06-15) — all code gates met; palette moved out to v0.8.1. Only the non-code TestFlight pipeline remains (see 🚢 Ship checklist).

Gates — the core loop, clean and reliable:
- [x] Actor-isolation fix (PR #5) — clean warning-free baseline
- [x] Check-in "Listening…" redesign — core capture loop finished + merged
- [x] NLP extraction quality (Phases A–C+E) merged to `main`
- [x] Fork build/test-verified + identity resolved to Squirl (2026-06-15, `976482d`)

### v0.8.1 — Insights palette _(focus, no date — follow-up to v0.8)_
> **Outcome:** When I open Insights, the colours read clearly and feel intentional — mood, energy, focus and sleep are instantly distinguishable, not a muddy gradient.
> **For:** just me (carries into v0.9 for others).

Gates:
- [ ] **Insights palette colours** — 🔨 **in code** on `feat/insights-palette`. Design picked (2026-06-15): **Meadow·Burnt** mood (level-2 amber `#EDA94A`), **Lemon** energy, **Voltage/blue** focus; sleep deferred (no ramp yet). Focus loses its light/dark graphite inversion (now static blue). Final swatches: [palette-FINAL](superpowers/plans/2026-06-15-palette-FINAL.html). _(Was a v0.8 gate; → v0.8.1 on 2026-06-15.)_

### v0.9 — Private beta _(focus)_ _(TestFlight: 24 Jun 2026)_
> **Outcome:** Someone I hand the app to can install it, figure out what to do on first launch without me explaining, log check-ins, and see their own mood and sleep patterns in Insights — without hitting anything confusing or broken.
> **For:** me + 1–2 trusted users.

Gates — everything in v0.8, plus what makes it usable by someone else:
- [x] Calendar day-selection & navigation — merged to `main` (PR #8, 2026-06-14)
- [ ] _onboarding / empty states good enough for a stranger's first run?_ — ⚠️ onboarding hero still hardcodes **"Welcome to Whisper Notes"** (Squirl rename missed it; seen on sim launch 2026-06-15). Fix as part of this gate.

_(Insights palette: v0.9 → v0.8 on 2026-06-14, then → v0.8.1 on 2026-06-15.)_

### v1.0 — App Store _(App Store release: 6 Jul 2026)_
> **Outcome:** _TBD_  ·  **Target user:** _TBD (strangers)_

Heavier intelligence layer — only after 0.9 proves the core:
- [ ] HealthKit signals (sleep, activity, heart, cycle) — needs privacy policy + extra App Review scrutiny
- [ ] Tiered NL + LLM pipeline (daily/weekly aggregation)

### v1.1 — Post-launch _(later, no date)_
- [ ] Tag extraction — Phase D (paraphrase + multilingual) — **gated on the Gate-0 embedding spike**; cut from v1.0 to de-risk the 6 Jul date. Ships once the spike proves on-device.

### v1.1.2 — Recording polish _(later, no date)_
> **Outcome:** While I'm voice-recording a check-in, I can swipe the on-screen nudge to the prompt I want instead of waiting for the timer — and the timer resets so I get a full beat on the new one.
> **For:** me (carries to others post-launch).

Gates:
- [ ] **Swipeable nudges** — 📐 plan written. Timer still auto-advances; a left/right swipe jumps to a prompt early and re-bases the interval clock. Wrap-around carousel. [spec](superpowers/specs/2026-06-15-swipeable-nudges-design.md). _(Filed 2026-06-15 at user request; the only patch-level milestone — rest are x.y.)_

### v1.2 — Later _(no date)_
- [ ] iCloud Sync (Backup & Restore) — `feature/icloud-sync` · PR #1 (open). Deferred here: gates no near-term outcome; parked to stop accruing merge-conflict risk against `main`. Rebase when v1.2 starts; keep the PR open as the design surface or close and reopen later.

---

## 🚢 Ship checklist (the non-code Apple pipeline)

Opus does the code; **these are yours** (App Store Connect, hosting, copywriting). Long-lead items first. Tackle the v1.0 block early — it's the July 6 long pole, not the features.

**Foundation (do once, before v0.8 — needed for *any* TestFlight)**
- [x] Apple Developer Program membership active
- [ ] App record created in App Store Connect (bundle ID, app name reserved)
- [ ] Signing sorted (automatic signing in Xcode is fine for TestFlight)
- [ ] `Info.plist` usage strings present — **`NSMicrophoneUsageDescription`** + speech-recognition string (missing → app crashes on launch at review)

**v0.8 — Internal TestFlight (18 Jun)** — no Apple review; live in minutes
- [ ] Archive built + uploaded (Xcode Organizer or `xcodebuild -archive` + `altool`/`notarytool`)
- [ ] Yourself added as internal tester

**v0.9 — beta with 1–2 others (24 Jun)**
- [ ] Decide: add testers as **internal** users (skip review) vs **external** (needs ~24h Beta App Review)
- [ ] Test-info / "what to test" notes filled in

**v1.0 — App Store (submit by ~1 Jul for a 6 Jul live date)** — review is 24–48h, budget for one rejection
- [ ] HealthKit entitlement + `NSHealthShareUsageDescription` strings
- [ ] **Privacy policy URL hosted** (mandatory for HealthKit; mandatory for App Store)
- [ ] App Privacy "nutrition labels" filled — declare audio + health + derived mood data
- [ ] App icon 1024px · screenshots per device size · description · keywords · support URL · age rating
- [ ] Export compliance answer (standard crypto → exempt declaration)
- [ ] Build submitted for review **by ~1 Jul**

---

## ⏭️ Next up (priority order)

Ranked shortlist — what to pick up next, not everything in flight. Reorder freely. Each row carries **Added** (first logged here) and **Updated** (last changed). `/recap` reads this to suggest a focus.

| # | Item | Added | Updated | Why now |
|---|---|---|---|---|
| 1 | **v0.8 TestFlight pipeline** (non-code, yours) | 2026-06-14 | 2026-06-15 | 18 Jun long pole: App Store Connect record + signing + archive/upload. Manual upload is fastest for 18 Jun; CI/CD is a later investment. See 🚢 Ship checklist. |
| 2 | **Insights palette colours** (v0.8.1) | 2026-06-14 | 2026-06-15 | Structure shipped; colours unresolved across 9+ mockup variants. Needs a design pick before build. |
| 3 | **Git remote + Xcode Cloud CI/CD** | 2026-06-15 | 2026-06-15 | ✅ green-suite prerequisite now met. Next: create remote, then PR→build/test, tag→TestFlight. Auto-signing erases the hard part. Don't block 18 Jun on it. |
| 4 | **HealthKit signals** | 2026-06-14 | 2026-06-14 | 15-task TDD plan ready; bigger lift, do after the pipeline. |

---

## 🔨 In code (on a branch, not on `main`)

| Item | Branch / PR | Artifacts | Notes |
|---|---|---|---|
| Calendar header scroll-fade | `fix/calendar-header-scroll-fade` (PR pending) | [spec](../specs/001-calendar-header-scroll-fade/spec.md) · [plan](../specs/001-calendar-header-scroll-fade/plan.md) · [tasks](../specs/001-calendar-header-scroll-fade/tasks.md) · [mockup](superpowers/plans/2026-06-15-calendar-scroll-fade-header.html) | Header moved into the timeline `ScrollView`; offset-driven fade to nothing, day row tappable until faded, scroll-to-top recovery; med bar unaffected. First feature through full Spec Kit. Sonnet sub-agent implemented; parent caught + fixed a dual-`scrollPosition` integration bug (unit-test-invisible) and split out 2 undisclosed out-of-scope agent changes. Suite **223/0 green** (serial). ⚠️ **on-device unverified** (month-paging swipe vs scroll pan; status-bar-tap recovery) — verify before merge. |
| Whisper simulator compute fix | `fix/whisper-simulator-compute` (PR pending) | — | `.cpuAndGPU` under `targetEnvironment(simulator)` (no ANE → ANE-targeted Whisper hangs/crawls). Split from the calendar-fade branch (was an undisclosed agent change). 1 commit. |

## 📐 Plan written, not built

| Item | Artifacts | Notes |
|---|---|---|
| HealthKit signals (sleep, activity, heart, cycle) | [spec](superpowers/specs/2026-06-13-healthkit-signals-design.md) · [impl plan](superpowers/plans/2026-06-13-healthkit-signals-implementation.md) | New day-keyed `DailySignals` model (per-group provenance; HealthKit-wins-unless-edited). Quarantined `HealthKitService` actor + `SignalSyncCoordinator`. Read-on-open + manual refresh (no background sync v1). Dedicated Day Signals editor sheet; existing manual sleep entry moves here. All four signals end-to-end. 15-task TDD plan ready; mockup gate at Task 10. |
| Tag extraction — Phase D (paraphrase + multilingual) | [spec](superpowers/specs/2026-06-13-tag-suggestion-design.md) | NLContextualEmbedding zero-shot prototypes over CURRENT tags to close the recall gaps Phases A–C can't (energy/focus/sleep paraphrases, PT/ES). Gate-0 anisotropy spike decides go/no-go (MiniLM fallback). Phases A–C+E already in code on `feat/nlp-eval-and-precision`. |
| Check-in view redesign | [impl plan](superpowers/plans/2026-06-12-checkin-view-implementation.md) · mockups: [FINAL](superpowers/plans/2026-06-12-checkin-FINAL.html), [journeys](superpowers/plans/2026-06-12-checkin-journeys.html) | Rename Record view → "Check in" + redesign. User is bringing the design — don't build speculatively. |
| Swipeable nudges (recording) — v1.1.2 | [spec](superpowers/specs/2026-06-15-swipeable-nudges-design.md) | Swipe the recording nudge left/right to jump to a prompt early; timer keeps auto-advancing but re-bases on swipe (full fresh interval). Wrap-around. Core change: prompt index goes from pure-clock-derived → anchored (`baseIndex`+`anchorTime`), collapsing to today's behavior when untouched so existing deterministic test stays green. |

## 💡 Ideas (investigated, no plan)

| Item | Notes |
|---|---|
| 🐛 Test suite not parallel-safe (tech debt) | CLI `xcodebuild test` (default parallel clones) → **12 false failures**: 10 `signal trap` crashes (`DiagnosticsStore`/`ExtractionReviewVM`/`DayTimelineBuilder`) + 2 NL feeling-extraction (`inflectedVerbMatchesLexiconForm`, `metricsMeetFloors`); **all pass serially** (`-parallel-testing-enabled NO`). Shared mutable state across clones (singleton lexicon / shared NL model / in-memory `ModelContainer`), not a product regression. Not a v0.8 ship blocker (TestFlight runs no tests) but reddens any CI. **Stopgap:** parallelization off in the shared `.xctestplan`. **Real fix:** isolate per-test state. Diagnosed 2026-06-14 (memory `test-suite-not-parallel-safe`). |
| Nudge-primed vocabulary → tagging | The on-screen check-in nudges prime the user's wording ("How did you sleep?" → "restless / 3am / groggy"). Capture that likely vocab to improve extraction. **Conclusion: NOT the Whisper prompt** — common feeling-words already transcribe at ceiling; the ~224-token prompt is full of high-value med/jargon terms (evicting them is net-negative); priming common adjectives risks Whisper hallucinating them in silence. The prompt's lead sentence already bakes in mood/energy/focus/sleep ([WhisperKitTranscriptionService.swift:22](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L22)). **Real home = NLP tag lexicon**: map each nudge's likely vocab → its dimension (mood/energy/focus/sleep/feelings/side-effects); pairs with the personal-overlay lexicon. Optional: WER check + add a couple of side-effect/feeling words to the prompt's lead sentence only if a measured gap shows up. |
| Tiered NL + LLM pipeline | NL per-recording (keep) + Apple Foundation Models via BGProcessingTask for daily/weekly trend aggregation. New `DailyInsight` + `WeeklySummary` models. Pairs with calendar view. |
| User correction + learning | Remaining scope after Tag suggestion plan: phrase-selection → personal lexicon. Tag-editing half moved to 📐 Tag suggestion engine. |
| Tag provenance | Largely realised: `RecordingTag(source:confidence:)` exists; Tag suggestion plan adds suggested/confirmed/rejected lifecycle. Remaining: weighted insights. |

## ✅ Shipped (on `main`)

| Item | Notes |
|---|---|
| Test suite green (isolation fix) | 2026-06-15. Suite **212/0**, two consecutive serial runs. Root cause: `AIModelServiceImpl.download()` spawned an `AsyncStream` Task that wrote `ModelMetadata` (`isDownloaded`/`isCorrupted`) on the success/error path *after* the owning `ModelContext` was torn down → non-deterministic `ModelContext.reset` crash (moving victim) even serially. Fixed by guarding both writes with `Task.isCancelled` (also a production correctness win: a cancelled download no longer flags the model corrupt). Clears CI's green-suite prerequisite. |
| app-four fork bring-up (verify + identity) | Merged to `main` (2026-06-15, `976482d`). Build verified green on iPhone 17 sim. Identity → **Squirl** (dynamic version label replacing hardcoded `WhisperNotes v1.0.0`; mic/speech prompts), codename app-four, 37 broken `../app-two/` doc links repaired. MedicationBar midnight-flaky test fixed (injectable clock). CodeRabbit clean (limited mode, no remote). |
| Calendar day-selection & navigation | Merged via **PR #8** (2026-06-14). Collapsible week↔month calendar over the mood/med timeline: N1 month grid, mood-colour day-dots, past/newest-first, month-paged, all days shown (empty = "No check-ins"), two-way scroll-sync, force-week + a11y at AX sizes. Replaces `MonthSelectorScrollView`. 29/29 unit tests; CodeRabbit review fixes applied (guarded date math, empty-month grid). Integrated suite 213/0 green. |
| Debug mock-data toggle + reseed | Merged via **PR #6** (2026-06-14). Mock Mode toggle + Seed/Wipe&Reseed in a hidden debug sheet; `isMockData` flag filters queries; `#if DEBUG`-only `MockDataGenerator`. Verified green in the integrated suite (was unverified on-branch). |
| Insights snap-to-section scroll | Merged via **PR #6** (2026-06-14). Pinned selector, dimmed peek. Verified green in the integrated suite. |
| Check-in "Listening…" redesign | Merged to `main` (`a0b1395`). Big-hero serif prompt over breathing crescent; live-transcription removal + interruption pause/resume; configurable `PromptPace` (Relaxed 10s / Brisk 6s); Clear All Data. Opus-reviewed (7 a11y/polish fixes). Tests green on iPhone 17 sim. |
| Actor-isolation warnings fix (PR #5) | Merged. 38 → 0 main-actor isolation warnings; behaviour unchanged. |
| NLP extraction quality (Phases A–C+E) | Merged. Eval harness (40 cases) + precision/recall wins (mood .60→.75, energy .13→.67, feelings .71→.94, topics →0.90/0.78, meds recall→1.0), fuzzy med matching, highlight dedup, clause-bounded titles. Gate-0 spike run → Phase D go/no-go pending. |
| DevLog + `/recap` morning standup (dev-process) | [design](superpowers/specs/2026-06-13-devlog-and-recap-design.md) · [DEVLOG](DEVLOG.md). Chronological project narrative (`docs/DEVLOG.md`) + `/recap` slash command. Complements BACKLOG (state) / specs (design) / memory (facts). |
| Insights "Meadow" redesign | 5-section scroll layout shipped & verified. ⚠️ Palette being reworked — structure is final, colours are not. |
| Calendar Daylio-style mood/med timeline | Full-width mood bar, ring-in-circle, per-day grouping. |
| NLP extraction hardening (P0+P1+P2) | Correctness fixes, off-main engine refactor (SSOT), lexicon-as-data (+256 swarm terms), personal overlay. 111/111 tests. |

---

## How to use this

- New thought? Add a row under **💡 Ideas**.
- Wrote a spec/plan? Move it to **📐 Plan** with a link.
- Started building? Move it to **🔨 In code** with the branch/PR.
- Merged? Move it to **✅ Shipped**.
- Keep **⏭️ Next up** to 3–5 ranked items; reorder as priorities shift.
- **Date convention:** stamp **Added** when an item first enters Next up and **Updated** whenever its row changes (also for any dated row added going forward). Existing pre-2026-06-14 rows aren't backfilled — their dates weren't tracked.

Claude updates this file whenever a feature changes stage (see CLAUDE.md → Backlog).
