<!-- Created: 2026-06-14 23:59 WEST · Updated: 2026-06-30 12:21 WEST -->
# app-four Backlog

Single source of truth for where every feature, mockup, and idea stands.
Update the **Stage** as work moves. Keep newest activity near the top of each section.

**Stages**
- 💡 **Idea** — investigated/considered, no plan written
- 📐 **Plan** — spec and/or implementation plan exists, not built
- 🔨 **In code** — being built / on a branch, not on `main`
- ✅ **Shipped** — merged to `main`

Last updated: 2026-06-30 (🎨 **Hi-fi Penpot reproduction of the whole app — 22 boards across 3 pages, code-grounded + agent-reviewed** — built in the hosted-Penpot file "New File 1" (not the codebase): **Page 1** Calendar/DayCard-folded+expanded/Recording-detail/Edit (6); **"Check-in"** idle·recording·processing·recovery·done·paused·text-composer·med-log·2 alerts (10); **"Insights"** breakdown·signals·averages·rhythm·connections·empty (6). Each page: explore→plan→independent plan-review→build→6-agent end-review→fix, all verified vs SwiftUI source. Reusable glyph/icon/chart engine + manifests in the session scratchpad. A faithful design-reference baseline (esp. for the open **Insights palette** v0.8.1 work). Penpot reconnect playbook added to CLAUDE.md. Earlier: ✅ **iOS 17.0 deployment target lowered; build errors fixed** — README.md collision + `ScrollPosition` → `ScrollViewReader` in `ScreenContainer`. Earlier: 📐 **Arc42 + C4 architecture documentation plans written and cross-reviewed** — see 📐 Plan written, not built. Earlier: 🔨 **Spec-028 weekday-average signal strips built on `feat/028-weekday-signals`** — 7 fixed Mo–Su bead slots, arithmetic averaging, 6 tests GREEN. Next: owner build + layout QA → PR. Earlier: ✅ **Spec-026 audit-critical UI fixes SHIPPED — merged to `main` via PR #22** — FR-001–019 across concurrency, view mechanics, accessibility. Earlier: 🔨 **Spec-023 DayCard redesign + SF typography built on `feat/daycard-redesign`:** SF app-wide (`UIFontMetrics`; bundled faces removed) · no-pill 4-line check-in rows · no-disc fixed-40 inline mood-glyph header · standard back button. See earlier entries for full history.)

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
| **DayCard redesign + SF typography (spec 023, supersedes 019)** | `feat/daycard-redesign` | [spec/plan](023-daycard-redesign/) · [prototype](../html-mockups/daycard-prototype-v8.html) | **Built 2026-06-26:** SF app-wide (`UIFontMetrics`; bundled faces + `SquirlFonts` + `UIAppFonts` removed); no-pill 4-line rows (mood+time / energy+focus / **med+sleep[blue]** / feelings≤4 + side-effects≤4, `+N`; topics dropped; SF context icons `capsule.righthalf.filled`/`heart.fill`/`zzz`/`medical.thermometer`); no-disc **fixed-40 inline mood-glyph header** (summary collapses, title re-centres — resolves 019-review D2/D8); `TimelineChip` deleted; **standard back button** restored (reconciles the `feat/calendar-detail-push` no-back MVP). TDD caps + `sleepLine` (3 tests RED→GREEN). **`build_sim` green; full suite 312/0/2; on-sim folded verified (light).** Gap: expanded-row + dark on-sim un-driven (`axe` disabled). **Reverses DESIGN.md §Typography** (Fraunces→SF, explicit owner decision; doc updated). Next: fuller DESIGN.md pass, `/code-review` → PR. |
| **Settings view design divergence fix** | `feat/spm-packages` · [PR #17](https://github.com/caesar915-hub/app-four/pull/17) | [plan](../.claude/plans/yea-ok-but-we-floofy-willow.md) | **Built 2026-06-25:** `.scrollContentBackground(.hidden)` + `.listRowBackground(Theme.cardBackground)` on the `List` in `SettingsView`; two raw `.secondary` → `Theme.textSecondary`; `ModelDownloadRow` bronze → `Theme.meadowGreen` (Cancel + ghost-pills); `JournalExportSection` `.plexMono(13)` → `Typography.mono12`. Build green; 309/309 tests. Verified light + dark on iPhone 17 sim. Next: `/code-review` → PR. |
| **Day-card mood-block redesign (#4, A4)** | `feat/019-daycard-mood-block` | [spec/plan/tasks](019-daycard-mood-block/) · [mockup](../mockups/summary/index.html) | **Built 2026-06-24** (Spec Kit `019`, full pipeline specify→plan→tasks→implement): ported the **"#4 Divided · Cream disc"** mockup to the SwiftUI `DayCard` — folded **mood-tinted block** + cream-disc badge + divider; unfolded **mood strip** over cream rows (mood glyph in the med-phase ring, inline time, details chevron); `MoodBanner` deleted; tint average→representative; test-first palette helper (`DayCardPaletteTests` RED→GREEN). **Build green; full serial suite 317 green** (SC-007); token audit clean (SC-006). Visual-only (no data/behaviour change). _Pending:_ owner on-device QA (this env couldn't skip onboarding via simctl + no tap MCP), then `/code-review` → PR. The deferred **A4** from [018](018-qa-review-fixes/spec.md). See DEVLOG 2026-06-24. |
| Insights palette colours (v0.8.1) | `feat/insights-palette` | [palette-FINAL](superpowers/plans/2026-06-15-palette-FINAL.html) | Meadow·Burnt mood / Lemon energy / Voltage focus; sleep deferred. See v0.8.1 milestone. |
| **Signal glyphs (Paper & Pollen)** | `feat/signal-glyphs` | [spec/plan/tasks](006-signal-glyphs/) · DESIGN.md §Iconography · [register](superpowers/plans/2026-06-16-design-decisions-ALL.html) | **Built 2026-06-17** (Spec Kit `006`): sprout/lightning/aperture + bed + horizontal-capsule as SwiftUI (`GlyphSignal`/`SignalGlyph` + 5 Canvas views), replacing SF Symbols across ~13 sites (timeline banner/chips, pickers, Insights, detail, edit). **249/249 tests green; grayscale gate (SC-001) passed; zero rendered signal SF Symbols.** Pending `/code-review` + merge. The 2026-06-16 "Bud" botanical detour was explored then reverted. |
| **Check-in capture-feel (capture that lands)** | `feat/ux-improvements-015-017` | [spec/plan/tasks](016-checkin-capture-feel/) | **Built 2026-06-24** (Spec Kit `016`): re-entry guard (P1 double-start bug killed), single "Done" + one-shot success haptic (the in-place crescent→check **Settle MORPH deferred** for on-device tuning), a **never-lose-a-capture** retry buffer + calm inline recovery (replacing the silent reset-to-idle) with a fixed SwiftData teardown-race, a full **VoiceOver pass** (active-voice announcement gate, "Recording, elapsed" live region, Saving/Captured, 44pt), the **8-minute soft landing** (one-shot cue + capped save Settles), the first-launch whisper hint, and a minimal honest `.paused` visual. Test-first for logic; **full serial suite green (293)**; extraction pipeline untouched. Pending: `/code-review` → PR, + the Settle morph. See DEVLOG 2026-06-24. |
| **Onboarding first-run (welcome + transcription queue)** | `feat/ux-improvements-015-017` | [spec/plan/tasks](015-onboarding-first-run/) | **Built 2026-06-24** (Spec Kit `015`): the 3-step setup ceremony → one warm Paper & Pollen `WelcomeView` (kills the **P0 AI-slop** first-impression); background model download (no entry gate, cellular-safe via 015's new `NWPathMonitor` `Connectivity`); a **record-before-model-ready transcription queue** (no lost audio; extraction pipeline **zero-diff**); just-in-time mic permission; de-jargoned copy. Test-first for logic; serial suite green. Pending `/code-review` → PR. See DEVLOG 2026-06-24. |
| **Settings recovery & privacy** | `feat/ux-improvements-015-017` | [spec/plan/tasks](017-settings-recovery-privacy/) | **Built 2026-06-24** (Spec Kit `017`): removed the **dead Reduce-Motion control** (P0; honor iOS only); clarity S-pass (Settings title, "Medical Context Prompt" → "Recognize medication names" relocated, motion-gated scroll, documented typography exemption); **download-failure recovery** (reuses 015 `Connectivity`; typed `ModelDownloadFailure` + cancel/retry/cause-copy + the row UI); a "Your data" privacy footer + acknowledgements; and an **encrypted single-file journal export** (CryptoKit AES-GCM, fresh CSPRNG key per export surfaced once as a user-held recovery key, restore deferred). Test-first for logic; **full serial suite green (313)**. Pending: `/code-review` → PR **and a `/security-review` on the export**. See DEVLOG 2026-06-24. |
| **Calendar day-card (`DayCard`) redesign** | `feat/daycard-update` | [spec/plan/tasks](014-daily-card/) · [decided summary](../mockups/summary/index.html) | **Built 2026-06-23** (Spec Kit `014`, full pipeline spec→clarify→plan→tasks→implement): folded `FoldedDayCardHeader` (mood circle + weekday + `mood·energy·focus·med` summary) over a tap-to-expand `DayCard` (shrink-on-open); filter-above + jump-to-top + auto-expand (`@AppStorage`, **no schema change**); `CalendarDayCell` greys future days + drops the today-ring. Test-first logic (`ExpandedDayCards` / date filter / `DayCardSummary`). **Full serial suite green; folded card verified on-sim (light + dark + Dynamic Type).** Pending: interactive expand/select + VoiceOver/greyscale on-sim (needs tap-capable MCP/owner), then `/code-review` → PR. |
| _(All 5 TestFlight-hardening fix branches merged to `main` 2026-06-16 → see ✅ Shipped.)_ | | | |

## 📐 Plan written, not built

| Item | Artifacts | Notes |
|---|---|---|
| **Codebase architecture documentation — arc42 Building Block View + C4 Component Diagram** | [arc42 plan](superpowers/plans/2026-06-28-arc42-building-block-view.md) · [C4 plan](superpowers/plans/2026-06-28-c4-component-diagram.md) | Two independent documentation plans written 2026-06-28. **arc42**: `docs/ARCHITECTURE-arc42.md` — hierarchical narrative, Level 1 system white-box → Level 2 per-layer black-box tables → Level 3 per-file detail; 9 tasks, one per layer. **C4**: `docs/ARCHITECTURE-c4.md` — Mermaid diagrams (Context → Container → Component) + prose description tables; 5 tasks. Both plans cross-reviewed by independent agents and corrected before filing (protocol names verified against source, `Container_Ext` invalid keyword fixed, missing App-layer container added, NoteExtraction count corrected 6→7, Components count corrected 17→19). Not milestone-gated — purely reference documentation. |
| **Calendar / Check-in / Settings — device QA round (spec 024)** | [spec/plan](024-calendar-checkin-settings-qa/) · narrated QA video transcript | **Spec + plan written 2026-06-26 (Spec Kit `024`, Constitution Check PASS).** From a narrated on-device QA pass (whisper-transcribed + frame-linked). **Calendar:** stop fading days (`CalendarDayCell` deEmphasis), remove the "Today" button (`CalendarHeaderView`), remove the "Entries up to <day>" caption (`CalendarLibraryView`). **Check-in (P1):** anchor the crescent at its idle centre so tapping record grows it in place — no downward jump. **Settings:** remove "Recognize medication names" (pin always-on), add "Always expand cards" (`@AppStorage`, mirrors auto-expand), remove the **crashing** feedback button (`SquirlApp:39`; keep `Views/Feedback/*`). Clarifications resolved (entries=caption; always-expand overrides; crescent=idle centre). One justified Principle-III exception (feedback code retained). Independent of the daycard redesign. Next: `/speckit-tasks` → implement (agent writes code+tests+review; owner builds/tests on device per workflow). |
| **Paper & Pollen design system** | [DESIGN.md](../DESIGN.md) · [visual companion](superpowers/plans/2026-06-15-paper-pollen-design-system.html) | Full visual system (`/design-consultation`, 2026-06-15): identity, Fraunces+DM Sans, shipped signal ramps + glyph language (sprout/lightning/aperture; sleep bed icon, med capsule), medication purple + fill-up no-alarm bar, Check-in/Type-note(A)/Detail/Edit specs. Sleep ramp deferred. Feeds per-screen Spec Kit specs. **Signal glyphs now built 2026-06-17 → see "Signal glyphs (Paper & Pollen)" in 🔨 In code.** |
| HealthKit signals (sleep, activity, heart, cycle) | [spec](superpowers/specs/2026-06-13-healthkit-signals-design.md) · [impl plan](superpowers/plans/2026-06-13-healthkit-signals-implementation.md) | New day-keyed `DailySignals` model (per-group provenance; HealthKit-wins-unless-edited). Quarantined `HealthKitService` actor + `SignalSyncCoordinator`. Read-on-open + manual refresh (no background sync v1). Dedicated Day Signals editor sheet; existing manual sleep entry moves here. All four signals end-to-end. 15-task TDD plan ready; mockup gate at Task 10. |
| Tag extraction — Phase D (paraphrase + multilingual) | [spec](superpowers/specs/2026-06-13-tag-suggestion-design.md) | NLContextualEmbedding zero-shot prototypes over CURRENT tags to close the recall gaps Phases A–C can't (energy/focus/sleep paraphrases, PT/ES). Gate-0 anisotropy spike decides go/no-go (MiniLM fallback). Phases A–C+E already in code on `feat/nlp-eval-and-precision`. |
| Check-in view redesign | [impl plan](superpowers/plans/2026-06-12-checkin-view-implementation.md) · mockups: [FINAL](superpowers/plans/2026-06-12-checkin-FINAL.html), [journeys](superpowers/plans/2026-06-12-checkin-journeys.html) | Rename Record view → "Check in" + redesign. User is bringing the design — don't build speculatively. |
## 💡 Ideas (investigated, no plan)

| Item | Notes |
|---|---|
| **MoodBubble — orbital/overlapping layout** | Explored 2026-06-27. Idea: one large dominant bubble (area-proportional, r ∝ √pct) with 4 smaller bubbles orbiting and overlapping it organically — no fixed columns, no equal y-axis. Inspired by a reference screenshot. Mockups: [`moodbubble-orbital.html`](../html-mockups/moodbubble-orbital.html) (phone frame, dark mode) · [`moodbubble-distance-table.html`](../html-mockups/moodbubble-distance-table.html) (3×6 distance-vs-data-shape matrix) · [`moodbubble-displaced.html`](../html-mockups/moodbubble-displaced.html) (6 organic layouts). The mechanical horizontal layout (the current app chart) and the orbital style were both explored and found lacking — neither felt right at this stage. Parked until the Insights section gets a proper design pass. |
| 🧹 **Post-demo code-review cleanup (2026-06-24)** | From the day-card (019) + 015/016/017 reviews — **none block the investor demo**; the 4 review **blockers were fixed and are on `main`** (crash on deleted `@Model`, calendar scroll→filter ratchet, stale med-bar, export OOM guard). **Day-card (019):** D1 `SettingsView` `title:""` reverts 017 FR-019 (visible title + VoiceOver landmark) and the comment now lies — restore title or update comment+spec; D2 header title Dynamic Type **capped at xLarge** (a11y regression) — wrap, don't cap; D3 mood word `wordColor=deepFill=color` (not actually "deeper") → low contrast on the 0.24 same-hue tint for pale moods — pick a darker word shade, verify light+dark; D4 global `.tint` accent→meadowGreen (`ScreenContainer`+`RootTabView`) vs DESIGN "green = not a flat brand fill everywhere" — confirm intent; D5 stale `Opacity.moodBlock` doc (says 0.16/inset; actual 0.24/full-bleed); D6 dead `MoodLevel.onColor` (last user removed with the bead time-label); D7 deleted `CalendarHeaderScrollFadeTests` — re-cover or confirm the header fade is intentionally gone; D8 `Text + Text` deprecation (iOS 26) in `FoldedDayCardHeader` → `AttributedString`. **015/016/017 (non-blocking):** dead `RecordingStore.createCheckInNote` + `WelcomeViewModel.didComplete`; `ExportService` add a `RecordingDTO`↔`Recording` field-parity test + wire `audioTooLarge` to a user-facing message; `SettingsViewModel.downloadModel` re-entrancy guard; `CheckInView` token literals (`.opacity(0.7/0.6)`, inline button gradient); broken VoiceOver string "…to still animations"; test gaps (transcription `markFailed` path, drain re-entrancy guard). **Warnings (~20):** Swift-6 strict-concurrency (GlyphSignal actor-isolation ×13, NetworkConnectivity `Equatable`, `ExportService.seal`, `Constants.medicalPromptEnabled`) + `+` deprecations — clear before Swift-6 language mode / App Store. |
| 🐛 `@Attribute(.unique)` on `Recording.id` — Constitution IX violation | [Recording.swift:6](../app-four/Models/Recording.swift#L6). CloudKit forbids `.unique`; this blocks the future iCloud-sync path the constitution is explicitly preserving. Remove the `.unique` attribute; SwiftData already uses `PersistentIdentifier` for uniqueness at the store level. Not a crash risk today, but must be fixed before any CloudKit wiring. |
| 🐛 delete-then-dismiss @Model pattern — crash risk at any future delete site | Fixed in `RecordingDetailView` (2026-06-17): delete now runs in `onDisappear`, after the sheet is torn down. Rule: **never `context.delete()` a `@Model` while a view rendering it is still mounted** — the `@Observable` mutation invalidates all readers, re-rendering a context-detached object → `BackingData "detached without resolving faults"` fatal. Apply the `pendingDelete + onDisappear` pattern to any future swipe-to-delete or inline delete. |
| 🐛 Test suite not parallel-safe (tech debt) | CLI `xcodebuild test` (default parallel clones) → **12 false failures**: 10 `signal trap` crashes (`DiagnosticsStore`/`ExtractionReviewVM`/`DayTimelineBuilder`) + 2 NL feeling-extraction (`inflectedVerbMatchesLexiconForm`, `metricsMeetFloors`); **all pass serially** (`-parallel-testing-enabled NO`). Shared mutable state across clones (singleton lexicon / shared NL model / in-memory `ModelContainer`), not a product regression. Not a v0.8 ship blocker (TestFlight runs no tests) but reddens any CI. **Stopgap:** parallelization off in the shared `.xctestplan`. **Real fix:** isolate per-test state. Diagnosed 2026-06-14 (memory `test-suite-not-parallel-safe`). |
| Nudge-primed vocabulary → tagging | The on-screen check-in nudges prime the user's wording ("How did you sleep?" → "restless / 3am / groggy"). Capture that likely vocab to improve extraction. **Conclusion: NOT the Whisper prompt** — common feeling-words already transcribe at ceiling; the ~224-token prompt is full of high-value med/jargon terms (evicting them is net-negative); priming common adjectives risks Whisper hallucinating them in silence. The prompt's lead sentence already bakes in mood/energy/focus/sleep ([WhisperKitTranscriptionService.swift:22](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L22)). **Real home = NLP tag lexicon**: map each nudge's likely vocab → its dimension (mood/energy/focus/sleep/feelings/side-effects); pairs with the personal-overlay lexicon. Optional: WER check + add a couple of side-effect/feeling words to the prompt's lead sentence only if a measured gap shows up. |
| Tiered NL + LLM pipeline | NL per-recording (keep) + Apple Foundation Models via BGProcessingTask for daily/weekly trend aggregation. New `DailyInsight` + `WeeklySummary` models. Pairs with calendar view. |
| User correction + learning | Remaining scope after Tag suggestion plan: phrase-selection → personal lexicon. Tag-editing half moved to 📐 Tag suggestion engine. |
| Tag provenance | Largely realised: `RecordingTag(source:confidence:)` exists; Tag suggestion plan adds suggested/confirmed/rejected lifecycle. Remaining: weighted insights. |

## ✅ Shipped (on `main`)

| Item | Notes |
|---|---|
| **Stable TestFlight channel** (2026-06-30) | Two-channel TestFlight setup: `squirl-app.app-four.stable` bundle ID, `app-four-stable` scheme, `Release-Stable` archive config, greyscale `AppIcon-Stable`, home-screen name "Squirl Stable", separate SwiftData container. Coexists on device with Dev. See OPERATIONS.md §Stable Channel. |
| **iOS 17.0 deployment target + compat fixes** (2026-06-28) | App target + SquirlSignals/SquirlDesignSystem packages lowered to iOS 17.0 (`01b316d0`, `a9976afa`). Expands install base to iPhone XS+ on iOS 17. Companion fixes: (1) 3 `README.md` files deleted from Xcode synchronized folder tree (all collided at "Multiple commands produce README"); (2) `ScreenContainer.swift` `ScrollPosition` (iOS 18+) → `ScrollViewReader` + eager sentinel — `scrollResetToken` API unchanged, zero caller changes (uncommitted). |
| **Recording Detail UX pass (spec 027)** (2026-06-27, PR #24) | `FoldedDayCardHeader` `.top`→`.center`; `ADHDSummarySection` → 4 individually-gated data cards (Medications/Sleep/Emotions/Side Effects), removed AI bullets + regen; `RecordingDetailView` — pencil-circle toolbar replaces `···` menu, visible red delete button (uses existing dialog), glyphs 26→30pt; `MedicationLogSheet` → dark-card sheet (drag indicator, sheetNav, 4 card sections, selected-chip `Palette.medication` border). |
| **Insights weekday-average signal strips (spec 028)** (2026-06-27, PR #23) | 7 fixed Mo–Su bead slots in Insights, arithmetic mean per weekday, dashed glyph for nil slots. `SignalBead.weekdayLabel`, `weekdaySignalStrips` on `InsightsViewModel`. Non-interactive `BeadSlot` replaces `BeadButton`. 6 unit tests RED→GREEN. |
| **Audit-critical UI fixes (spec 026)** (2026-06-27, PR #22) | FR-001–019: stale-array → FetchDescriptor (FR-006); preload cancel (FR-015); tick guard (FR-017); deinit cancel (FR-018); re-entry cancel (FR-019); `AnimatedArc` child `@State` + `.id(isActive)` (FR-001); 44pt tap targets (FR-002/003); delete confirmation dialog (FR-004); Reduce Motion gates (FR-005); failed-summary surface (FR-007); AX improvements (FR-009–013, 016); `@MainActor` annotation (FR-014). TDD RED→GREEN throughout. |
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
