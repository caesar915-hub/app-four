# app-four Backlog

Single source of truth for where every feature, mockup, and idea stands.
Update the **Stage** as work moves. Keep newest activity near the top of each section.

**Stages**
- 💡 **Idea** — investigated/considered, no plan written
- 📐 **Plan** — spec and/or implementation plan exists, not built
- 🔨 **In code** — being built / on a branch, not on `main`
- ✅ **Shipped** — merged to `main`

Last updated: 2026-07-05 23:44 WEST (🔨 **Nutrition & exercise on the Day card — Spec 031 demo on `feat/nutrition-signals-demo` (stacked on `feat/healthkit-signals`, demo-only, will NOT merge to main):** four Apple Health signals — dietary kcal, protein, caffeine, active energy — on the calendar Day card. Full pipeline (4 mockups incl. Health-settings · spec+clarify · sosumi-verified plan · 50 tasks) and **all four user stories now CODE-COMPLETE** (RED→GREEN, compile-gated generic iOS): **US1** folded V3 tokens + deterministic 30-day seed; **US2** interleaved food/exercise timeline rows (`NutritionEventRow`) + per-day totals footer (`DayNutritionFooter`) via `TimelineDay.displayItems`; **US3** real HealthKit reads (food correlations→named meals, loose→hourly, workouts via `statistics(for:)`) + replace-per-day sync + silent calendar `.task`; **US4** (owner-raised) Health sync on/off gate + delete-imported-data + native `HealthSettingsSection`. New DESIGN.md lanes: nutrition clay `#B5674A`, exercise teal `#3E8E86`. Design note: branch predates spec-023 SF reversal → new rows use Fraunces/Plex to match this branch's `TimelineRow`. **Open — owner device checkpoints T021/T028/T040/T050** (runtime suite + QA) gate T041 regression + T043 PR/`/code-review`. `specs/031-nutrition-daycard-demo/`. Earlier: 🔨 **Emotions lexicon — Spec Kit 020 on `feat/rename-feelings-to-emotions` (not merged):** renamed the check-in **Feelings → Emotions** and replaced the ~60-word list with a cited **20-emotion Mood-Meter vocabulary** (How We Feel / Yale; 5 per valence×energy quadrant). Full identifier + schema + lexicon rename; no migration (pre-release wipe, Principle IX); mood cue-phrases left intact; eval re-pointed → **emotions P=1.0/R=1.0, all category floors green, full suite TEST SUCCEEDED**. Spec/plan/tasks/research in `specs/020-emotions-lexicon/`. Next: `/code-review` → PR. Earlier: **Mockup parity — Spec Kit 008 done on `feat/screen-parity` (not merged):** owner reset to a strict mockup-driven, tokens-only pass after a rushed attempt hardcoded literals into views. Full Spec Kit pipeline (`specs/008-mockup-parity/`, 29 tasks; `research.md` token-map = the "no literals" authority). **Edit sheet (`ExtractionReviewView`) rebuilt to exact §07** — hairline fields, bare-glyph pickers + name·synonym headers, Sleep pills + custom-hours, and the real **inline-expand medications** (dose pills + editable duration box); shared **`GlyphRampPicker`**; Type-note refactored; detail **Meds → single line**; one sanctioned hook **`MedEvent.durationHours`** (test-first). Verified on-sim **light + dark**; **token grep clean**; **full suite green** (+2 tests). §03b removed + Calendar unchanged (owner). Next: `/code-review` → PR. Earlier: **Screen parity — Spec Kit 007 Phases B–G done on `feat/screen-parity` (not merged):** every §04–07 screen reworked to match `squirl-design-system.html` — Check-in (B, earlier), Recording detail (§07), Edit sheet (§07), Type-note (§06 Layout A), Insights (§06), Medication bar (§04). Foundation token fixes cascade: `Palette.medication` → spec `#7E5CA8`/`#9277BE`, new `Theme.danger`, deleted the forbidden med-bar red ramp. Verified on-sim **light + dark**; **full suite TEST SUCCEEDED**. Trade-off flagged: Type-note Layout A dropped meds/sleep rows (model untouched; reachable via voice/hub/med-bar/Edit). Calendar + onboarding fixed-size fonts left out of scope. DEVLOG has the full entry. Next: `/code-review` the diff → PR. Earlier: **Feedback features 005 + 002 + 003 shipped & pushed to `origin/main`** (`4387e09`, 240/240 serial green) — 005 medication picker, 002 recording-detail-as-sheet (Calendar path), 003 "Transcribing…" name + 90s timeout + Retry button. Built end-to-end through Spec Kit, test-first for logic (Principle X). Deferred: Insights→detail sheet, 002 §1.5 spacing, 003 download-vs-transcribe phase split. Earlier: **5 TestFlight-hardening fixes landed on `main`**, verified 224/224 serial green on iPhone 17 sim — Simulator transcription hang, med-removal crash, calendar scroll-fade, orphaned-transcription recovery+queueing, med-bar full-width tap (§2.1); v0.8 TestFlight scope updated; **not yet pushed** to `origin`. Earlier: **TDD adopted in Spec Kit**: constitution → **v1.2.0** — new **Principle X · Test-First Development** (RED→GREEN→refactor; mandatory for logic = models/services/view-models/NLP extraction; SwiftUI views exempt, verified by build+run). Template-sync: `tasks-template` tests OPTIONAL→MANDATORY (RED checkpoint per story), `plan` Constitution Check now I–X, `SPECKIT.md` pipeline updated. Testing stack reconciled XCTest→Swift Testing (the v1.1.1 note below was logged but never written to the file; now folded into v1.2.0). Earlier: **Screen-recording feedback → Spec Kit**: 4 features prepared from the product-walkthrough recordings — `001-medication-picker` (spec+clarify+plan, `feat/medication-picker`) and `002`/`003` (spec+plan, `feat/feedback-specs`); mock-data crash/bar-missing kept as fix items. ⚠️ **Overlap reconciled** (2026-06-15): existing `fix/calendar-header-scroll-fade` already owns spec number `001` and the calendar scroll/fade work → feature `004` **deleted** and the §1.3 fade **removed from `002`** (now tap/placement/sheet/spacing only). Done: `001-medication-picker` **renumbered → `005`** (clears the calendar `001` collision); `003` plan now **coordinates** with `fix/orphaned-transcription-status` + `fix/whisper-simulator-compute` (those land first; 003 narrows to the "Transcribing…" name, lowering the 300s timeout, the Retry control, and the download-vs-transcribe phase split). Constitution → **v1.2.0** (the earlier v1.1.1 XCTest→Swift Testing correction is now folded in — see the TDD note at the top). Earlier: **Paper & Pollen design system** adopted via `/design-consultation` → [DESIGN.md](../DESIGN.md) + visual companion; identity/type/signal-glyphs/medication/screen specs locked; CLAUDE.md now points at DESIGN.md as the UI source of truth. Earlier: app-four fork **build/test-verified** on `main` — builds green on iPhone 17 sim; identity resolved to **Squirl** + codename app-four, broken doc links repaired; MedicationBar midnight-flaky test fixed. **suite now reliably green (212/0, two consecutive serial runs)** — the `ModelContext.reset` crash was an orphaned `AIModelServiceImpl.download()` Task writing `ModelMetadata` after teardown; fixed with a cancellation guard. **v0.8 is code-complete; Insights palette colours moved to new milestone v0.8.1.** CI's green-suite prerequisite is met.)

---

## 🎯 Milestones

Your roadmap. Not a feature list — a finish line. Each milestone is **one sentence of user outcome** + the backlog items that gate it. Everything not tied to a milestone is "later." Fill in the outcomes when you've thought it through.

**Focus right now: v0.8 → v0.8.1 → v0.9.** v1.0 is parked below as the destination; don't build toward it until 0.9 ships.

### v0.8 — Dogfood _(focus)_ _(TestFlight: 18 Jun 2026)_
> **Outcome:** Every day I can open the app, voice-log a check-in in under a minute, and trust it captures, transcribes, and tags every time — solid enough that I actually keep using it instead of avoiding it.
> **For:** just me.

✅ **Code-complete** (2026-06-15) — all code gates met; palette moved out to v0.8.1. Only the non-code TestFlight pipeline remains (see 🚢 Ship checklist).

🛠️ **TestFlight-hardening (2026-06-16):** 5 fixes landed on `main` and verified **224/224 serial green** on iPhone 17 sim — Simulator transcription hang (`cpuAndGPU`), med-removal crash, calendar header scroll-fade, orphaned-`.transcribing`→`.failed` recovery + back-to-back queueing, and med-bar **full-width tap** (feedback §2.1). These ship in the 18 Jun build. **Not yet pushed** to `origin`. (See ✅ Shipped for detail.)

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
- [ ] _onboarding / empty states good enough for a stranger's first run?_ — 🔨 **redesigned** on `feat/ux-improvements-015-017` (Spec Kit **015**, 2026-06-24): the 3-step setup ceremony → one warm Paper & Pollen `WelcomeView` (kills the P0 AI-slop first-impression); background model download (no entry gate, cellular-safe); a **record-before-model-ready transcription queue** (no lost audio, extraction pipeline verified zero-diff); just-in-time mic permission; de-jargoned copy. Test-first, full serial suite green. _Earlier:_ visible-name rename half (PR #6, 2026-06-17). _Remaining for this gate:_ `/code-review` → PR; empty-states beyond first-run. See DEVLOG 2026-06-24.

_(Insights palette: v0.9 → v0.8 on 2026-06-14, then → v0.8.1 on 2026-06-15.)_

### v1.0 — App Store _(App Store release: 6 Jul 2026)_
> **Outcome:** _TBD_  ·  **Target user:** _TBD (strangers)_

Heavier intelligence layer — only after 0.9 proves the core:
- [ ] HealthKit signals (sleep, activity, heart, cycle) — needs privacy policy + extra App Review scrutiny
- [ ] Tiered NL + LLM pipeline (daily/weekly aggregation)

### v1.1 — Post-launch _(later, no date)_
- [ ] Tag extraction — Phase D (paraphrase + multilingual) — **gated on the Gate-0 embedding spike**; cut from v1.0 to de-risk the 6 Jul date. Ships once the spike proves on-device.

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

> **⚠️ Landed on `main` 2026-06-24 (investor-demo build):** `feat/ux-improvements-015-017` (**015** onboarding · **016** check-in capture-feel · **017** settings recovery/privacy) and the **day-card 019** redesign were merged to `main` (`3229d986`), plus the 4 cherry-picked review-blocker fixes (deleted-`@Model` crash, calendar scroll→filter ratchet, stale med-bar, export OOM guard) and the test-isolation fix. **Not gated by a `/code-review` PR** — reviewed post-hoc (see the 🧹 cleanup item in 💡 Ideas). Pending: on-device smoke-test → tag `v0.8.1`. The In-code rows below predate this merge and are now on `main`.

| Item | Branch / PR | Artifacts | Notes |
|---|---|---|---|
| **Day-card mood-block redesign (#4, A4)** | `feat/019-daycard-mood-block` | [spec/plan/tasks](019-daycard-mood-block/) · [mockup](../mockups/summary/index.html) | **Built 2026-06-24** (Spec Kit `019`, full pipeline specify→plan→tasks→implement): ported the **"#4 Divided · Cream disc"** mockup to the SwiftUI `DayCard` — folded **mood-tinted block** + cream-disc badge + divider; unfolded **mood strip** over cream rows (mood glyph in the med-phase ring, inline time, details chevron); `MoodBanner` deleted; tint average→representative; test-first palette helper (`DayCardPaletteTests` RED→GREEN). **Build green; full serial suite 317 green** (SC-007); token audit clean (SC-006). Visual-only (no data/behaviour change). _Pending:_ owner on-device QA (this env couldn't skip onboarding via simctl + no tap MCP), then `/code-review` → PR. The deferred **A4** from [018](018-qa-review-fixes/spec.md). See DEVLOG 2026-06-24. |
| Insights palette colours (v0.8.1) | `feat/insights-palette` | [palette-FINAL](superpowers/plans/2026-06-15-palette-FINAL.html) | Meadow·Burnt mood / Lemon energy / Voltage focus; sleep deferred. See v0.8.1 milestone. |
| **Signal glyphs (Paper & Pollen)** | `feat/signal-glyphs` | [spec/plan/tasks](006-signal-glyphs/) · DESIGN.md §Iconography · [register](superpowers/plans/2026-06-16-design-decisions-ALL.html) | **Built 2026-06-17** (Spec Kit `006`): sprout/lightning/aperture + bed + horizontal-capsule as SwiftUI (`GlyphSignal`/`SignalGlyph` + 5 Canvas views), replacing SF Symbols across ~13 sites (timeline banner/chips, pickers, Insights, detail, edit). **249/249 tests green; grayscale gate (SC-001) passed; zero rendered signal SF Symbols.** Pending `/code-review` + merge. The 2026-06-16 "Bud" botanical detour was explored then reverted. |
| **HealthKit signals (sleep, activity, heart, cycle)** | `feat/healthkit-signals` | [Spec Kit 009](009-healthkit-signals/) · [design spec](superpowers/specs/2026-06-13-healthkit-signals-design.md) | **In code 2026-06-20** (Spec Kit `009`): `DailySignals` (CloudKit-safe, no `@Attribute(.unique)`) + `SignalsStore`; `HealthDataReading` + `HealthKitServiceImpl` actor; `SignalSyncCoordinator` per-group HealthKit-wins-unless-edited merge; manual editor + summary surfaced in DayDetailSheet; access primer; read-on-open sync. **~34 signals tests + full suite green.** Sleep = bed icon + named scale (colour ramp deferred per DESIGN.md; A6). **Reviewed via `/review-swarm` (2026-06-20) — all findings fixed:** wired the auth/primer flow (import was non-functional — `requestAuthorization` was never called), editor Save error-handling (was silent data-loss), auth-aware sync, `try?`→logged, deterministic flow sample, once-per-day sync guard, entitlement wired into pbxproj, +~13 coverage tests. Pending: on-device HealthKit verification, Xcode HealthKit capability toggle, merge. |
| **Check-in capture-feel (capture that lands)** | `feat/ux-improvements-015-017` | [spec/plan/tasks](016-checkin-capture-feel/) | **Built 2026-06-24** (Spec Kit `016`): re-entry guard (P1 double-start bug killed), single "Done" + one-shot success haptic (the in-place crescent→check **Settle MORPH deferred** for on-device tuning), a **never-lose-a-capture** retry buffer + calm inline recovery (replacing the silent reset-to-idle) with a fixed SwiftData teardown-race, a full **VoiceOver pass** (active-voice announcement gate, "Recording, elapsed" live region, Saving/Captured, 44pt), the **8-minute soft landing** (one-shot cue + capped save Settles), the first-launch whisper hint, and a minimal honest `.paused` visual. Test-first for logic; **full serial suite green (293)**; extraction pipeline untouched. Pending: `/code-review` → PR, + the Settle morph. See DEVLOG 2026-06-24. |
| **Onboarding first-run (welcome + transcription queue)** | `feat/ux-improvements-015-017` | [spec/plan/tasks](015-onboarding-first-run/) | **Built 2026-06-24** (Spec Kit `015`): the 3-step setup ceremony → one warm Paper & Pollen `WelcomeView` (kills the **P0 AI-slop** first-impression); background model download (no entry gate, cellular-safe via 015's new `NWPathMonitor` `Connectivity`); a **record-before-model-ready transcription queue** (no lost audio; extraction pipeline **zero-diff**); just-in-time mic permission; de-jargoned copy. Test-first for logic; serial suite green. Pending `/code-review` → PR. See DEVLOG 2026-06-24. |
| **Settings recovery & privacy** | `feat/ux-improvements-015-017` | [spec/plan/tasks](017-settings-recovery-privacy/) | **Built 2026-06-24** (Spec Kit `017`): removed the **dead Reduce-Motion control** (P0; honor iOS only); clarity S-pass (Settings title, "Medical Context Prompt" → "Recognize medication names" relocated, motion-gated scroll, documented typography exemption); **download-failure recovery** (reuses 015 `Connectivity`; typed `ModelDownloadFailure` + cancel/retry/cause-copy + the row UI); a "Your data" privacy footer + acknowledgements; and an **encrypted single-file journal export** (CryptoKit AES-GCM, fresh CSPRNG key per export surfaced once as a user-held recovery key, restore deferred). Test-first for logic; **full serial suite green (313)**. Pending: `/code-review` → PR **and a `/security-review` on the export**. See DEVLOG 2026-06-24. |
| **Calendar day-card (`DayCard`) redesign** | `feat/daycard-update` | [spec/plan/tasks](014-daily-card/) · [decided summary](../mockups/summary/index.html) | **Built 2026-06-23** (Spec Kit `014`, full pipeline spec→clarify→plan→tasks→implement): folded `FoldedDayCardHeader` (mood circle + weekday + `mood·energy·focus·med` summary) over a tap-to-expand `DayCard` (shrink-on-open); filter-above + jump-to-top + auto-expand (`@AppStorage`, **no schema change**); `CalendarDayCell` greys future days + drops the today-ring. Test-first logic (`ExpandedDayCards` / date filter / `DayCardSummary`). **Full serial suite green; folded card verified on-sim (light + dark + Dynamic Type).** Pending: interactive expand/select + VoiceOver/greyscale on-sim (needs tap-capable MCP/owner), then `/code-review` → PR. |
| _(All 5 TestFlight-hardening fix branches merged to `main` 2026-06-16 → see ✅ Shipped.)_ | | | |

## 📐 Plan written, not built

| Item | Artifacts | Notes |
|---|---|---|
| **Paper & Pollen design system** | [DESIGN.md](../DESIGN.md) · [visual companion](superpowers/plans/2026-06-15-paper-pollen-design-system.html) | Full visual system (`/design-consultation`, 2026-06-15): identity, Fraunces+DM Sans, shipped signal ramps + glyph language (sprout/lightning/aperture; sleep bed icon, med capsule), medication purple + fill-up no-alarm bar, Check-in/Type-note(A)/Detail/Edit specs. Sleep ramp deferred. Feeds per-screen Spec Kit specs. **Signal glyphs now built 2026-06-17 → see "Signal glyphs (Paper & Pollen)" in 🔨 In code.** |
| Tag extraction — Phase D (paraphrase + multilingual) | [spec](superpowers/specs/2026-06-13-tag-suggestion-design.md) | NLContextualEmbedding zero-shot prototypes over CURRENT tags to close the recall gaps Phases A–C can't (energy/focus/sleep paraphrases, PT/ES). Gate-0 anisotropy spike decides go/no-go (MiniLM fallback). Phases A–C+E already in code on `feat/nlp-eval-and-precision`. |
| Check-in view redesign | [impl plan](superpowers/plans/2026-06-12-checkin-view-implementation.md) · mockups: [FINAL](superpowers/plans/2026-06-12-checkin-FINAL.html), [journeys](superpowers/plans/2026-06-12-checkin-journeys.html) | Rename Record view → "Check in" + redesign. User is bringing the design — don't build speculatively. |
## 💡 Ideas (investigated, no plan)

| Item | Notes |
|---|---|
| 🧹 **Post-demo code-review cleanup (2026-06-24)** | From the day-card (019) + 015/016/017 reviews — **none block the investor demo**; the 4 review **blockers were fixed and are on `main`** (crash on deleted `@Model`, calendar scroll→filter ratchet, stale med-bar, export OOM guard). **Day-card (019):** D1 `SettingsView` `title:""` reverts 017 FR-019 (visible title + VoiceOver landmark) and the comment now lies — restore title or update comment+spec; D2 header title Dynamic Type **capped at xLarge** (a11y regression) — wrap, don't cap; D3 mood word `wordColor=deepFill=color` (not actually "deeper") → low contrast on the 0.24 same-hue tint for pale moods — pick a darker word shade, verify light+dark; D4 global `.tint` accent→meadowGreen (`ScreenContainer`+`RootTabView`) vs DESIGN "green = not a flat brand fill everywhere" — confirm intent; D5 stale `Opacity.moodBlock` doc (says 0.16/inset; actual 0.24/full-bleed); D6 dead `MoodLevel.onColor` (last user removed with the bead time-label); D7 deleted `CalendarHeaderScrollFadeTests` — re-cover or confirm the header fade is intentionally gone; D8 `Text + Text` deprecation (iOS 26) in `FoldedDayCardHeader` → `AttributedString`. **015/016/017 (non-blocking):** dead `RecordingStore.createCheckInNote` + `WelcomeViewModel.didComplete`; `ExportService` add a `RecordingDTO`↔`Recording` field-parity test + wire `audioTooLarge` to a user-facing message; `SettingsViewModel.downloadModel` re-entrancy guard; `CheckInView` token literals (`.opacity(0.7/0.6)`, inline button gradient); broken VoiceOver string "…to still animations"; test gaps (transcription `markFailed` path, drain re-entrancy guard). **Warnings (~20):** Swift-6 strict-concurrency (GlyphSignal actor-isolation ×13, NetworkConnectivity `Equatable`, `ExportService.seal`, `Constants.medicalPromptEnabled`) + `+` deprecations — clear before Swift-6 language mode / App Store. |
| 🐛 `@Attribute(.unique)` on `id` — Constitution IX violation (4 models) | `Recording`, `AppSettings`, `ModelMetadata`, `TranscriptionSegment` all carry `@Attribute(.unique) var id: UUID` ([Recording.swift:6](../app-four/Models/Recording.swift#L6) et al.) — confirmed across all four by 009-healthkit-signals research (D1). CloudKit forbids `.unique`; this blocks the future iCloud-sync path the constitution preserves. Remove the `.unique` attribute (UUID defaults already give practical uniqueness; SwiftData uses `PersistentIdentifier` at the store level). `DailySignals` (009) deliberately avoids the pattern. Not a crash risk today; must be fixed before any CloudKit wiring. |
| 🐛 delete-then-dismiss @Model pattern — crash risk at any future delete site | Fixed in `RecordingDetailView` (2026-06-17): delete now runs in `onDisappear`, after the sheet is torn down. Rule: **never `context.delete()` a `@Model` while a view rendering it is still mounted** — the `@Observable` mutation invalidates all readers, re-rendering a context-detached object → `BackingData "detached without resolving faults"` fatal. Apply the `pendingDelete + onDisappear` pattern to any future swipe-to-delete or inline delete. |
| 🐛 Test suite not parallel-safe (tech debt) | CLI `xcodebuild test` (default parallel clones) → **12 false failures**: 10 `signal trap` crashes (`DiagnosticsStore`/`ExtractionReviewVM`/`DayTimelineBuilder`) + 2 NL feeling-extraction (`inflectedVerbMatchesLexiconForm`, `metricsMeetFloors`); **all pass serially** (`-parallel-testing-enabled NO`). Shared mutable state across clones (singleton lexicon / shared NL model / in-memory `ModelContainer`), not a product regression. Not a v0.8 ship blocker (TestFlight runs no tests) but reddens any CI. **Stopgap:** parallelization off in the shared `.xctestplan`. **Real fix:** isolate per-test state. Diagnosed 2026-06-14 (memory `test-suite-not-parallel-safe`). |
| Nudge-primed vocabulary → tagging | The on-screen check-in nudges prime the user's wording ("How did you sleep?" → "restless / 3am / groggy"). Capture that likely vocab to improve extraction. **Conclusion: NOT the Whisper prompt** — common feeling-words already transcribe at ceiling; the ~224-token prompt is full of high-value med/jargon terms (evicting them is net-negative); priming common adjectives risks Whisper hallucinating them in silence. The prompt's lead sentence already bakes in mood/energy/focus/sleep ([WhisperKitTranscriptionService.swift:22](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L22)). **Real home = NLP tag lexicon**: map each nudge's likely vocab → its dimension (mood/energy/focus/sleep/feelings/side-effects); pairs with the personal-overlay lexicon. Optional: WER check + add a couple of side-effect/feeling words to the prompt's lead sentence only if a measured gap shows up. |
| Tiered NL + LLM pipeline | NL per-recording (keep) + Apple Foundation Models via BGProcessingTask for daily/weekly trend aggregation. New `DailyInsight` + `WeeklySummary` models. Pairs with calendar view. |
| User correction + learning | Remaining scope after Tag suggestion plan: phrase-selection → personal lexicon. Tag-editing half moved to 📐 Tag suggestion engine. |
| Tag provenance | Largely realised: `RecordingTag(source:confidence:)` exists; Tag suggestion plan adds suggested/confirmed/rejected lifecycle. Remaining: weighted insights. |

## ✅ Shipped (on `main`)

| Item | Notes |
|---|---|
| **Feedback features 005 + 002 + 003** (2026-06-16, `4387e09`) | Built through Spec Kit, merged + **pushed** to `origin/main`, **240/240 serial green**. **005** medication picker (3-med catalog Concerta/Ritalin/Elvanse + picker VM + rewritten Log-Dose sheet w/ dose options·onset·editable duration + duration plumbing; ExtractionReview chips repointed at the catalog). **002** recording detail opens as a swipe-down sheet, no back button, bar pinned (Calendar path). **003** "Transcribing…" name in timeline/detail, timeout 300s→90s, Retry button. Test-first for logic (Principle X). _Deferred:_ Insights→detail sheet, 002 §1.5 spacing, 003 download-phase split. See DEVLOG 2026-06-16. |
| **TestFlight-hardening fixes** (5 · 2026-06-16) | Landed to `main`, verified **224/224 serial green** on iPhone 17 sim (local merges, **not yet pushed**). **(1)** `fix/whisper-simulator-compute` — `cpuAndGPU` on Simulator (no ANE), kills the "Transcribing… forever" hang. **(2)** `fix/med-crash-mvp` — med-removal Index-out-of-range crash fixed (element-based `ForEach` + `Hashable`) + 3-med MVP chip picker (Concerta/Ritalin/Elvanse). **(3)** `fix/calendar-header-scroll-fade` (spec `001-calendar-header-scroll-fade`) — header scrolls-into-content & fades (recover via scroll-to-top); med bar independent (+`CalendarHeaderScrollFadeTests`). **(4)** `fix/orphaned-transcription-status` — finalize status on cancel + recover orphaned `.transcribing`→`.failed` at launch + queue back-to-back recordings (+`RecordingStoreTests`). **(5)** `fix/med-bar-tap-target` — `.contentShape` so the whole med-bar row is tappable (feedback §2.1). Merged via `fix/orphaned…` (supersets the calendar branch); `+12` tests. |
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
