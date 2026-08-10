<!-- Created: 2026-07-05 12:27 (WEST) · Updated: 2026-07-05 17:53 (WEST) -->
# Squirl — Master Functional Specification (FSD)

> **Status: v0.2 HIGH-LEVEL DRAFT — deep-review corrections applied 2026-07-05; for owner analysis, not yet approved.**
> This document describes how Squirl behaves from the user's perspective, across everything shipped and everything planned. It is the umbrella: per-feature Spec Kit specs in [specs/](../specs/) remain the executable source of truth for build work; [DESIGN.md](../DESIGN.md) remains the visual source of truth; the Constitution ([.specify/memory/constitution.md](../.specify/memory/constitution.md)) gates every spec.
>
> **Grounding.** Current-state claims are baselined on **branch `main`** and come from the code-verified audit in [FEATURES.md](engineering/FEATURES.md), [DATA_MODEL.md](engineering/DATA_MODEL.md), [README.md](../README.md), [PRODUCT.md](../PRODUCT.md), and [BACKLOG.md](BACKLOG.md) (stage registry) — then re-verified by a 26-agent deep review (2026-07-05: 20 dimension reviewers + adversarial verification against source, git/PR state, specs, and Apple docs). Key correction from that review: **nothing is wired on `main`, but three integrations are already implemented on unmerged branches** — EventKit (spec 029, `feat/029-calendar-day-context`, no PR), HealthKit (Spec Kit 009, **PR #8 open**), WeatherKit (spec 023-weather-checkin, **PR #16 open**); App Intents (030) is design-stage (uncommitted docs) and CloudKit has no artifacts in this repo. Apple-framework claims cite official documentation (fetched 2026-07-05 via the sosumi.ai mirror of developer.apple.com).

---

## 1. Purpose & scope

**In scope:** the complete functional surface of the Squirl iOS app — capture, transcription, extraction, review, calendar, insights, medication, settings — plus the six planned platform integrations (EventKit, App Intents/NFC, HealthKit, CloudKit, WeatherKit, Foundation-Models trend aggregation) and cross-cutting non-functional requirements.

**Out of scope:** visual design specification (DESIGN.md), implementation architecture (docs/engineering/), per-feature acceptance detail (specs/NNN). This FSD states *what the user can do and what the system guarantees*; it links down rather than duplicating.

## 2. Product overview

Squirl is an **on-device, privacy-first iOS check-in journal for ADHD adults** ([README](../README.md), [PRODUCT.md](../PRODUCT.md)). The user voice-logs (or types) a daily check-in in under a minute; the app transcribes locally (WhisperKit) and deterministically extracts structured signals — the seven user-editable ones (mood, energy, focus, sleep, medications, emotions, side effects) plus supporting outputs (activities, topics, an auto-generated title, highlight cues) — then surfaces the day on a calendar timeline and patterns in Insights.

- **North star:** *effortless* — in and out in under a minute, always slightly calmer than before.
- **No account, no server, no cloud by default.** All audio, transcripts, and signals stay on device.
- **Non-judgmental by construction:** no streaks, badges, gamification, or medication alarms.

### 2.1 Users & personas ([PRODUCT.md](../PRODUCT.md))

| Persona | Sketch | What they need |
|---|---|---|
| Alex | Medicated daily checker | Fast dose + state logging; med-effect visibility |
| Jordan | Streak-burned sporadic tracker | Zero shame on gaps; instant value on return |
| Sam | Privacy-absolutist paper journaler | Verifiable on-device promise; exportable data they own |

ADHD is a functional constraint, not flavor: low cognitive load, one primary action per screen, fast clear reward.

### 2.2 Product principles (gate every requirement below)

1. Effortless over complete — sub-minute capture, progressive disclosure.
2. Non-judgmental by construction — the reward is "I said it and it's captured."
3. Privacy by architecture, not policy.
4. Deterministic over probabilistic · auditable over opaque · instant over eventual.
5. Color is never the only cue (glyph shape + fill; colorblind/grayscale-safe).

## 3. System context

- **Platform:** iOS 17.0+ on `main` (all four `IPHONEOS_DEPLOYMENT_TARGET` = 17.0). ⚠ An owner-decided raise to **iOS 26.0** is in flight — [PR #25](https://github.com/caesar915-hub/app-four/pull/25) `feat/ios26-target` (decision 2026-07-03, spec 030 research D15; device floor becomes iPhone 11/A13+, dropping iPhone XS/XR). Several planned integrations (029/030) were planned against the 26.0 target; reconcile before v1.0.
- **Architecture:** MVVM + centralized `RecordingStore` + environment DI; heavy services actor-isolated ([ARCHITECTURE.md](engineering/ARCHITECTURE.md)).
- **Shell:** 4-tab app (Calendar · Check-in · Insights · Settings, [RootTabView.swift](../app-four/Views/RootTabView.swift)) with a global medication bar overlay; the only external network traffic today is the one-time Whisper model download ([FEATURES.md](engineering/FEATURES.md)).
- **Status baseline:** `main` = tag `v0.8.0` + 158 commits, untagged (BACKLOG pends a `v0.8.1` tag). v0.8 (dogfood) is **code-complete (2026-06-15) but not uploaded to TestFlight** — the BACKLOG ship-checklist (App Store Connect record, signing, archive upload, internal tester) is entirely unchecked. Focus per [BACKLOG.md](BACKLOG.md): v0.8.1 (Insights palette) → v0.9 (private beta) → v1.0 (App Store).

## 4. Functional areas — current app

Status legend: ✅ shipped on `main` · 🔶 partial (shipped with a known gap) · 🔨 in code on a branch (not on `main`) · 📐 planned with spec · 💡 planned, no spec.
IDs are stable handles for analysis; one line each — detail lives in the linked spec/doc.

### FA-1 · Onboarding & first run — ✅ (spec 015)
- **FA-1.1** ✅ Single warm welcome screen; no setup ceremony; Start lands on Calendar.
- **FA-1.2** ✅ Whisper model downloads in the background (cellular-safe); the app is usable immediately.
- **FA-1.3** ✅ Recordings made before the model is ready queue losslessly and transcribe when it lands.
- **FA-1.4** ✅ Microphone permission is requested just-in-time (first capture), never up front.

### FA-2 · Check-in capture — ✅ (spec 016; [FEATURES.md §5.1](engineering/FEATURES.md))
- **FA-2.1** ✅ Voice check-in: one tap → Listening (rotating nudge prompts, elapsed timer, 8-minute soft cap with calm wind-down) → single "Stop & save" → Saved confirmation.
- **FA-2.2** ✅ Text check-in: signal-first composer (mood/energy/focus pickers + free note). Meds and sleep are *not* entered in the composer — they're captured by voice, the hub's separate "Log meds" action, or the Edit sheet.
- **FA-2.3** ✅ Capture is never lost: retry buffer + inline recovery on save failure; call/Siri interruptions pause-and-preserve the recording, auto-resuming when the system permits (`.shouldResume`) — the capture is never discarded either way.
- **FA-2.4** ✅ Re-entry guard prevents double-starts; success haptic on save.
- **FA-2.5** 🔶 Crescent→check "Settle" morph deferred (separate saved view ships instead).

### FA-3 · Transcription — ✅ (spec 003, 024-whisper-model-integrity)
- **FA-3.1** ✅ On-device Whisper Small via WhisperKit; transcription runs after save, never live.
- **FA-3.2** ✅ Lifecycle states (`recorded → transcribing → completed/failed`, plus `pendingTranscription` for pre-model captures, drained once the model lands) with orphan recovery (launch-time sweep of stale `.transcribing` → `.failed` only — never `.pendingTranscription`) and back-to-back queueing.
- **FA-3.3** ✅ Medication-vocabulary bias prompt improves drug-name recognition (on by default; no user control yet — 💡 candidate toggle).

### FA-4 · Signal extraction (NLP) — ✅ core · 📐 multilingual undecided (spec 020; [FEATURES.md §5.4](engineering/FEATURES.md))
- **FA-4.1** ✅ Deterministic, instant, on-device extraction from the transcript (718-entry lexicon, 32 categories; negation-aware; English-only): the seven user-editable signals — mood, energy, focus, sleep, medications, emotions, side effects (FA-5.1) — plus supporting outputs (activities, task/win/overwhelm cues, appointments, topics, highlights).
- **FA-4.2** ✅ Eval harness with ratcheting precision/recall floors guards regressions.
- **FA-4.3** 📐 Two undecided multilingual tracks in flight, neither merged: **(a) Phase D embeddings** (v1.1) — paraphrase + multilingual recall, gated on the Gate-0 device spike (recorded inconclusive, must re-run); **(b) lexicon-pack demo** — spec 021, [PR #14](https://github.com/caesar915-hub/app-four/pull/14) `feat/nlp-multilang-demo` (en/pt-PT/es-ES/es-MX, demo-grade: vocabulary only, eval stays English), now `CONFLICTING` with main's merged PR #13 recall rewrite. What's outstanding is an owner lineage decision, not a technical blocker.
- **FA-4.4** 🔶 Personal-lexicon learning from corrections: tags stored, training loop **not wired** (`PersonalLexiconBuilder` orphaned).
- **FA-4.5** ✅ Every transcript also gets an on-device extractive title + highlight sentences. The persisted title favors a "Mood · Energy · Focus" composite when those signals were found (extractive title as fallback) and is the detail screen's headline; highlight bullets are persisted (`summaryBulletsJSON`) but not rendered in any current view.

### FA-5 · Review & correction — ✅ (spec 027)
- **FA-5.1** ✅ Every signal surfaced in the Edit sheet is user-correctable (date/time, mood, energy, focus, sleep, meds, emotions, side effects). All corrections persist; mood, energy, focus, meds, and emotions additionally carry provenance tags (`.userCorrected` vs `.nlp`) — sleep, side-effect, and date/time edits persist *without* provenance (a gap feeding FA-4.4). The extractor's other outputs (auto title, topics, activity/task arrays) are not user-editable.
- **FA-5.2** ✅ Recording detail: playback + transcript cards, up to 4 conditional signal cards (medication, sleep, emotions, side effects — each renders only if extracted), visible delete (deferred-delete pattern — never delete a mounted @Model).

### FA-6 · Calendar & timeline — ✅ (specs 014, 019, 023)
- **FA-6.1** ✅ Collapsible week↔month calendar drives a day-grouped, month-paged day-card timeline (one-way: date → filter/scroll).
- **FA-6.2** ✅ Folded day card reads the whole day in one line; expands to time-ordered check-ins; auto-expand on date select.
- **FA-6.3** 🔨 Day context line from device calendar — see INT-1.

### FA-7 · Insights — ✅ structure · 📐 sleep signal
- **FA-7.1** ✅ Five snapping sections scoped to a month: mood bubble chart · weekday signal strips (spec 028) · averages · daily rhythm matrix · connections.
- **FA-7.2** 📐 Sleep renders "not tracked yet" — becomes live with INT-3: Spec Kit **009** (spec + implementation on `feat/healthkit-signals`, PR #8 open — not on `main`) covers both HealthKit import and manual sleep entry via the Day Signals editor.
- **FA-7.3** 💡 Day tap-through to detail is scaffolded but unreachable (wire or delete — Constitution no-dead-code).

### FA-8 · Medication tracking — ✅ (specs 002, 005)
- **FA-8.1** ✅ Global medication bar: purple fill runs empty→full over the dose's effect window; onset pulse; worn-off goes quiet, never alarms.
- **FA-8.2** ✅ Dose logging via curated stimulant catalog (Concerta/Ritalin/Elvanse beta set) + history picker; transcript-extracted doses reconcile with manual ones.
- **FA-8.3** 💡 Catalog expansion to broader EU stimulant coverage.

### FA-9 · Settings & data control — ✅ (spec 017)
- **FA-9.1** ✅ Model download management with typed failure recovery (cancel/retry/cause copy).
- **FA-9.2** 🔶 Encrypted single-file journal export (AES-GCM, fresh 256-bit key shown once as a recovery key); restore deferred. Known gap: the archive is built wholly in memory, so export refuses journals with >200 MB total audio (OOM guard for the A14 floor) — chunked/large-journal export is open.
- **FA-9.3** ✅ "Your data" privacy statement, acknowledgements, Clear All Data.
- **FA-9.4** ✅ Prompt pace, day-card/med-bar toggles; system Reduce Motion honored (no in-app duplicate).
- **FA-9.5** ⚠ Undocumented `TestServicesView` debug console — 5-tap on the Settings version label, gated `#if DEBUG || TESTFLIGHT`. Exposes ungated actions against real data (Delete All without confirmation, mock-data seed/wipe, live recording start). Verify the `TESTFLIGHT` flag never reaches App Store archives — flag for hard DEBUG-only gating or removal before submission.

### FA-10 · Accessibility (cross-cutting) — 🔶 contract with a known gap
- **FA-10.1** 🔶 WCAG 2.1/2.2 AA is the design contract ([PRODUCT.md](../PRODUCT.md)): contrast ≥4.5:1 body, ≥44pt targets (code-enforced via `Metrics.minTapTarget`), VoiceOver labels, Dynamic Type AX1–AX5, Reduce Motion fallbacks. Known shipping gap (documented in the source): muted ink `#7A7361` fails AA for small text on paper and is in use — darken or restrict per PRODUCT.md's own caveat.
- **FA-10.2** ✅ Every signal is encoded by glyph shape + fill, not color alone.

## 5. Planned platform integrations

Ordered by maturity. Each keeps the privacy invariant: **integration data is read into the on-device store or written from it; no Squirl server exists.**

### INT-1 · Calendar day context — EventKit — 🔨 in code on a branch (v1.1)
*"What was my day actually like?"* — the memory prosthesis. [Spec 029](../specs/029-calendar-day-context/spec.md) · [design](superpowers/specs/2026-07-03-calendar-integration-design.md). Spec + plan + 45 tasks are committed to `main`; the **full implementation (foundation → US1 → US2/US3 → polish, 11 commits, 2026-07-03) sits on unmerged `feat/029-calendar-day-context`** — no PR opened, owner device QA pending (QA build branch `qa/device-ios26-029`).

- **INT-1.1** On check-in days, capture a snapshot of the day's device-calendar events; render a classified context line on the day card ("3 meetings · Dentist · Mum's birthday" — events with invited attendees fold to a "N meetings" count, other events are named by title; with title capture off the line is counts-only, e.g. "3 meetings · 2 events"; attendee identities/locations/notes are never captured).
- **INT-1.2** Grant flow with pre-grant explainer (title-capture choice up front); historical backfill on grant; Settings control: per-calendar picker, purge, explicit re-capture.
- **INT-1.3** Later phases (own specs): Insights correlations (live-query, ADHD-safe observation-only copy) → med-coverage vs today → opt-in check-in markers written to a dedicated Squirl calendar.
- **Framework facts** ([EventKit docs](https://developer.apple.com/documentation/eventkit)): iOS 17+ splits **full access** (`requestFullAccessToEvents()`, `NSCalendarsFullAccessUsageDescription`) from **write-only** (`NSCalendarsWriteOnlyAccessUsageDescription`); events queried from the local store via date-range predicates. Phase 1 needs full access; the local store already contains Google/Exchange/iCloud events synced by iOS itself — fully on-device, Constitution VI holds.

### INT-2 · App Intents foundation + NFC sticker actions — 📐 spec + plan + tasks ready (v1.1)
*Zero-tap capture.* [Spec 030](../specs/030-app-intents-foundation/spec.md) — full pipeline exists (spec, plan, research D1–D15, data-model, contracts, quickstart, tasks T001–T040), but unlike 029 **all 030 artifacts are uncommitted working-tree docs**.

- **INT-2.1** Expedited dose log: background intent logs the user's predefined default med+dose from Siri/Shortcuts/NFC sticker — works from the lock screen (`.alwaysAllowed`); acknowledges with a system banner (spoken when voice-triggered), a haptic only when the app is foreground — background intents cannot play haptics (FR-005 amendment pending owner sign-off, 030 research D9). If no default is configured the action never dead-ends: it creates nothing and calm guidance deep-links to the "My medication" setting, incl. for locked/voice triggers (FR-007).
- **INT-2.2** Hands-free check-in: intent foregrounds the app directly into Listening, already recording.
- **INT-2.3** Dose guard as a user Setting (off / total / 1–4h window) — governs expedited logs only; the in-app sheet is never blocked.
- **INT-2.4** Guided sticker setup (user-created Shortcuts NFC automations; honest lock-state copy).
- **Constraints (decided):** App Clip rejected — clips only run when the app is *not* installed, and the default dose lives in app Settings. Mic can never run in a background intent, so check-in must foreground. Deployment target raised 17.0 → 26.0 for this feature onward (owner decision 2026-07-03, research D15; executed on `feat/ios26-target`, PR #25 — see §3).
- **Existing foothold:** a `whispernotes://checkin` URL scheme already deep-links into the Check-in tab and auto-starts recording ([SquirlApp.swift](../app-four/App/SquirlApp.swift)) — the deep-entry recording path the spec presumes has a code-level starting point.

### INT-3 · HealthKit signals — 🔨 in code on a parked branch (v1.0 milestone per BACKLOG)
*Signals the user doesn't have to speak.* Spec Kit **009** (spec + implementation on `feat/healthkit-signals`, **[PR #8](https://github.com/caesar915-hub/app-four/pull/8) open**, currently conflicting with `main`; reviewed via review-swarm 2026-06-20, ~34 tests). Supersedes the earlier superpowers [design](superpowers/specs/2026-06-13-healthkit-signals-design.md) + [15-task plan](superpowers/plans/2026-06-13-healthkit-signals-implementation.md).

- **INT-3.1** Read sleep, activity, heart, and cycle into a day-keyed `DailySignals` model with per-group provenance; HealthKit-wins-unless-edited; read-on-open + manual refresh (no background sync v1).
- **INT-3.2** Sleep becomes the live Insights signal (closes FA-7.2); dedicated Day Signals editor sheet absorbs manual sleep entry.
- **INT-3.3** 💡 *New opportunity, undecided:* **State of Mind** (`HKStateOfMind`, iOS 18+) records a `kind` (`.dailyMood` vs `.momentaryEmotion`), `valence` + classification, emotion `labels`, and optional life-area `associations` (18 cases — family, work, health, money…) in Health ([docs](https://developer.apple.com/documentation/healthkit/hkstateofmind)) — Squirl's extracted mood/emotions could write to (or read from) it, though `kind` and `associations` are product decisions Squirl doesn't currently model. Min-OS question dissolves once PR #25 (iOS 26 target) merges.
- **Framework facts** ([HealthKit docs](https://developer.apple.com/documentation/healthkit)): entitlement `com.apple.developer.healthkit`; `NSHealthShareUsageDescription` (+ `NSHealthUpdateUsageDescription` if writing); per-type user grants via `requestAuthorization(toShare:read:)`; relevant types: `sleepAnalysis`, `stepCount`/`activeEnergyBurned`, `heartRate`/`heartRateVariabilitySDNN`, `menstrualFlow`. App Review consequences already on the ship checklist: hosted privacy policy mandatory ([BACKLOG §Ship checklist](BACKLOG.md)).
- **⚠ Known conflict:** the 2026-06-13 plan's `@Attribute(.unique)` upsert **must not be copied** — it predates Constitution IX (see INT-4). The 009 implementation already avoids it (store-level invariant instead).

### INT-4 · iCloud sync (backup & restore) — CloudKit — 💡 idea (v1.2), stale BACKLOG references
*The journal survives a lost phone — without a Squirl server.* ⚠ **No branch or PR for this exists in this repo**: BACKLOG's v1.2 row cites `feature/icloud-sync` · PR #1, but this repo's PR #1 is an unrelated **closed** calendar fix, and no iCloud/CloudKit branch, spec, or plan exists on any ref — the reference predates the app-two → app-four fork. Re-point or re-plan when v1.2 opens.

- **INT-4.1** Opt-in sync/backup of the SwiftData store via the user's private iCloud database; off by default (privacy promise: cloud is a user choice, never a default).
- **INT-4.2** Restore path onto a fresh install.
- **Framework facts** ([SwiftData+CloudKit docs](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)): iCloud/CloudKit entitlement + container + remote-notification background mode; **CloudKit cannot enforce the `unique` attribute option (`@Attribute(.unique)`)**; all relationships must be optional; no `deny` delete rules; schema changes are additive-only once in production.
- **⚠ Blockers in code:** four `@Attribute(.unique)` ids must be dropped first (e.g. [Recording.swift:6](../app-four/Models/Recording.swift#L6)) — Constitution IX exists precisely to keep this path open. The store directory is currently *excluded* from iCloud backup; that flag inverts under this feature. (An unused `cloudSyncStatus` field already sits on `Recording` — the only cloud-adjacent trace in the schema.)

### INT-5 · Weather day context — WeatherKit — 📐 parked branch with spec (PR #16 open; unscheduled)
*Weather as ambient day context alongside calendar events.* A full Spec Kit spec (`specs/023-weather-checkin` on `origin/feat/023-weather-checkin` — ⚠ number collides with main's `023-daycard-redesign`) plus a prototype implementation with tests and its own entitlements sits on **[PR #16](https://github.com/caesar915-hub/app-four/pull/16), open and parked**; nothing is in the shipping target. Planned-set attribution: [DEVLOG 2026-07-03 17:14](DEVLOG.md) names "the planned CloudKit/HealthKit/WeatherKit/EventKit set" (sourced from the owner's Master PRD, which lives outside this repository).

- **INT-5.1** Attach day-level weather (condition, temperature) to check-in days as context on day cards — same day-keyed pattern as INT-1's `DayCalendarContext`.
- **INT-5.2** 💡 Possible later: weather ↔ signal correlations in Insights (same ADHD-safe observation-only copy rules as INT-1.3).
- **Framework facts** ([WeatherKit](https://developer.apple.com/weatherkit/)): iOS 16+; requires Apple Developer Program membership; **500,000 API calls/month included**, paid tiers above; **attribution is mandatory** (Apple Weather mark + legal link). Swift + REST APIs; current conditions, hourly/10-day forecast, historical comparisons.
- **⚠ Open questions:** WeatherKit is a *network* service — the app's second network dependency after the model download — and needs location (or a user-set home location); historical backfill needs per-day historical queries. Both need an explicit privacy-story decision; PR #16 needs a revive-or-close call.

### INT-6 · Tiered NL + LLM trend aggregation — Apple Foundation Models — 💡 idea, no spec (v1.0 milestone gate per BACKLOG)
*A second intelligence tier above FA-4's per-recording extraction: daily/weekly pattern summaries.* [BACKLOG v1.0 gates + 💡 Ideas row](BACKLOG.md).

- **INT-6.1** Keep FA-4.1's deterministic per-recording extraction unchanged; add Apple Foundation Models via `BGProcessingTask` to summarize daily/weekly signal trends. New models: `DailyInsight`, `WeeklySummary`. Pairs with the calendar view (FA-6).
- **⚠ Known device conflict, unresolved:** the extractor-eval investigation (DEVLOG 2026-06-23) recorded that the real target hardware — iPhone 12 (A14) — rules out Apple Foundation Models (needs A17 Pro/M-series). The BACKLOG idea doesn't carry this caveat; no spec exists to resolve it. This is simultaneously an unchecked v1.0 gate and a "no plan" Ideas row — the least-developed v1.0 commitment.

💡 **WidgetKit + ActivityKit** — named alongside App Intents in the brainstorm that produced INT-2 (DEVLOG 2026-07-03 17:14: "tiered result WidgetKit → App Intents → ActivityKit first"); App Intents was carried into spec 030, but WidgetKit/ActivityKit have no spec, plan, BACKLOG row, or code — formalize or drop (OQ8).

## 6. Non-functional requirements

| ID | Requirement | Source |
|---|---|---|
| NFR-1 | **Privacy:** audio, transcripts, signals never leave the device; no account, no third-party analytics/crash SDK; the only egress is user-initiated encrypted export (+ one-time model download; + WeatherKit *if* INT-5 proceeds; + opt-in private-iCloud sync of the store *if* INT-4 proceeds, off by default) | [README §Privacy](../README.md) |
| NFR-2 | **Speed:** check-in loop completes in under a minute; extraction is instant (no model load) | [PRODUCT.md](../PRODUCT.md) |
| NFR-3 | **Reliability:** a capture, once started, is never lost (retry buffer, pending queue, interruption pause-and-preserve) | specs 015/016 |
| NFR-4 | **Accessibility:** WCAG AA contract with one known shipping gap (FA-10 🔶) | [PRODUCT.md](../PRODUCT.md) |
| NFR-5 | **Determinism:** extraction is deterministic and auditable; probabilistic features require explicit gating (Constitution) | [FEATURES.md §5.4](engineering/FEATURES.md) |
| NFR-6 | **Localization:** English-only shipped on `main`; two undecided multilingual tracks in flight (Phase D embeddings · spec 021 lexicon packs, PR #14) — see FA-4.3 | [FEATURES.md](engineering/FEATURES.md) |
| NFR-7 | **Releasability:** `main` always releasable; every code change via PR + review + owner device QA | [CLAUDE.md](../CLAUDE.md) |

## 7. Data model (summary)

Today's schema on `main` ([DATA_MODEL.md](engineering/DATA_MODEL.md)): `Recording` (central check-in: transcript, signals, JSON-encoded extraction fields) · `MedicationEvent` · `RecordingTag` (provenance) · `TranscriptionSegment` · `ModelMetadata` · `AppSettings`.

**Built, unmerged:** `DayCalendarContext` (INT-1 — day-keyed, store-enforced one-per-day, **no** unique constraint; implemented + tested on `feat/029-calendar-day-context`, incl. export DTO `formatVersion` 1→2 — `main` is still v1) · `DailySignals` (INT-3 — day-keyed, per-group provenance; implemented + tested on `feat/healthkit-signals`, PR #8 open). **Planned-only:** weather context (INT-5 — no model on any branch; would follow the day-keyed pattern) · `DailyInsight`/`WeeklySummary` (INT-6).

## 8. Explicitly out of scope / rejected

- Streaks, badges, gamification, confetti; emoji-face mood ratings ([PRODUCT.md §Anti-references](../PRODUCT.md)).
- Medication reminders/alarms — a worn-off dose goes quiet.
- App Clip for NFC actions — rejected with rationale (INT-2).
- Cloud-by-default anything; no third-party analytics/crash SDK. First-party diagnostics *are* wired and stay on-device: a MetricKit subscriber logs Apple's metric/diagnostic payloads to console at every launch, and `DiagnosticsStore` keeps a rolling 50-entry local session buffer; the feedback UI meant to surface/email them (`Views/Feedback/*`) is built but unmounted since spec 024.
- Live transcription during recording (transcription is post-save by design).

## 9. Traceability

| FSD area | Spec Kit / plan | Stage ([BACKLOG](BACKLOG.md) + git/PR state) |
|---|---|---|
| FA-1 | 015 | ✅ |
| FA-2 | 016 | ✅ |
| FA-3 | 003 · 024-whisper-model-integrity | ✅ |
| FA-4 | 020 · Phase D design · 021 (PR #14, conflicting) | ✅ / 📐 |
| FA-5 | 027 | ✅ |
| FA-6 | 014 · 019 · 023 | ✅ |
| FA-7 | 007 · 028 · 009 (sleep — PR #8) | ✅ / 📐 |
| FA-8 | 002 · 005 | ✅ |
| FA-9 | 017 | ✅ |
| INT-1 | **029** (spec+plan+45 tasks on `main`; impl on `feat/029-calendar-day-context`, no PR) | 🔨 v1.1 |
| INT-2 | **030** (spec+plan+40 tasks, uncommitted) | 📐 v1.1 |
| INT-3 | **009** (spec+impl on `feat/healthkit-signals`, PR #8 open) · superpowers 2026-06-13 plan | 🔨 v1.0 |
| INT-4 | none in this repo — BACKLOG v1.2 row is stale/pre-fork | 💡 v1.2 |
| INT-5 | **023-weather-checkin** (spec+prototype on branch, PR #16 open; number collision with 023-daycard-redesign) | 📐 parked, unscheduled |
| INT-6 | none (BACKLOG v1.0 gate + Ideas row only) | 💡 v1.0 gate |

## 10. Open questions (for this draft's analysis)

1. **Unmerged-integration triage:** three integrations sit implemented on unmerged branches — 029 EventKit (no PR, QA pending), 009 HealthKit (PR #8, conflicting), 023-weather (PR #16, parked). Merge order? Revive-or-close for #16? And the 023 spec-number collision needs resolving.
2. **PR #25 (iOS 17→26 target):** merging it dissolves the HKStateOfMind min-OS question (INT-3.3) and matches 029/030 planning assumptions, but drops iPhone XS/XR — decide before v1.0.
3. **INT-4 sequencing:** dropping the four `.unique` attributes is cheap and unblocks CloudKit — do it before v1.0 (schema is additive-only once shipped)? Also re-point the stale BACKLOG v1.2 row.
4. **INT-6 vs hardware:** the Foundation-Models aggregation gate conflicts with the recorded iPhone 12/A14 floor — respec, defer, or cut from v1.0 gates.
5. **FA-4.3 lineage:** Phase D embeddings vs PR #14 lexicon packs — owner decision pending; PR #14 rots (conflicting) meanwhile.
6. **FA-4.4:** wire the personal-lexicon loop (FEATURES.md calls it "the next piece") — schedule it?
7. **Monetization:** free/subscription/IAP undecided ([docs/product/README.md](product/README.md)) — gates the App Store listing; does the FSD need a licensing/paywall functional area?
8. **Housekeeping before v1.0:** FA-9.5 Test Services gating; FA-7.3 wire-or-delete; FA-10.1 muted-ink AA fix; WidgetKit/ActivityKit — formalize or drop.
9. Does the owner want this FSD to absorb the Master PRD's business/market sections, or stay strictly functional (current cut)?
