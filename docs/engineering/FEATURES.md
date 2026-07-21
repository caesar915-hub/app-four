<!-- Created: 2026-07-11 00:00 (WEST) · Updated: 2026-07-20 09:20 (WEST) -->
# Squirl — Feature Overview

> **Current-state truth**, reconstructed from the codebase on `feat/038-icloud-sync` (`MARKETING_VERSION 0.8.0`, build 2). The branch has **no commits ahead of `main`** yet: everything below ships on `main` **except** spec-038 iCloud sync, which lives entirely in the uncommitted working tree (marked 🔭).
> Each feature describes what ships **today**; 🔭 notes flag what is planned, deferred, or scaffolded-but-not-wired, and where it lives.
> Companion to [TECH_STACK.md](TECH_STACK.md). Every claim is verified against source; where a claim rests on planning docs rather than code, it is marked.
> Status legend: ✅ Shipped · 🔶 Interim (deliberately downgraded) · 🧪 Prototype (out-of-target) · 🔭 Planned / deferred.

---

## 0. Discrepancy ledger (prior PRD feature draft vs. verified code)

These corrections are why this document exists; an earlier PRD "Key Features" draft described a target the code has since moved away from — or had not yet reached.

| Prior draft said | Verified reality | Source |
|---|---|---|
| 5.1 idle: "rotating **Fraunces** nudge prompt" | Idle headline is a **static SF Pro** "How do you feel?"; rotating nudges appear in **Listening** only. Typography migrated off Fraunces. | [CheckInView.swift:176](../../app-four/Views/CheckIn/CheckInView.swift#L176); [Typography.swift:4-8](../../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Typography.swift#L4-L8) |
| 5.1 spec-016 "**Settle morph**" (crescent morphs to check in place) shipped | **Deferred.** Saved state is a separate success view with a gradient checkmark that pops in; no in-place morph in the build. | `CheckInSavedView` (Saved branch of `CheckInView`) |
| 5.4 lexicon "**~950 entries**" | **718 entries** across **32 categories** (exact recount). | [lexicon.json](../../app-four/Resources/lexicon.json) |
| 5.5 corrections "**train the personal lexicon**" | Tags are **stored** but the loop is **not wired** — `PersonalLexiconBuilder` is never invoked; the extractor runs with no personal overlay. | grep (`PersonalLexiconBuilder` has no call site) |
| 5.2 calendar↔timeline "**two-way bound**" | **One-way** (date → timeline filter/scroll only). Day card redesigned in **spec 023**, superseding 019. | [MoodLibraryViewModel.swift](../../app-four/ViewModels/MoodLibraryViewModel.swift) |
| 5.6 onset "**~first 20 min**" | First **20% of the dose window** (`durationHours`), not a fixed 20 min. | [MedicationBarView.swift](../../app-four/Views/Components/MedicationBarView.swift) |
| 5.7 "Recognize medication names" = a live, relocated Settings control | **No user-facing control ships.** Lives only in `UserDefaults` (`medicalPromptEnabled`, default on). | [SettingsViewModel.swift:34-40](../../app-four/ViewModels/SettingsViewModel.swift#L34-L40) |
| 5.7 iCloud sync "deferred to v1.2" (framed as a Settings item) | **In progress (spec 038), uncommitted.** No longer just a backup flag: a full off-by-default service seam now exists — `CloudSyncService` protocol + CloudKit-backed `CloudSyncServiceImpl` (account gating + cloud-only `removeFromICloud`), a `SyncFlags` UserDefaults toggle, a CloudKit-compliant `SquirlSchemaV1`, and a two-config Synced/Local container partition, injected via `AppDependencies`. A Settings control + view-model now exist in the working tree (`ICloudSyncSection` + `SyncSettingsViewModel`, mounted at [SettingsView.swift:60](../../app-four/Views/SettingsView.swift#L60)); still none of it committed. | [CloudSyncServiceImpl.swift:12](../../app-four/Services/Sync/CloudSyncServiceImpl.swift#L12); [SyncSettingsViewModel.swift](../../app-four/ViewModels/SyncSettingsViewModel.swift) |
| 5.3 palette "being reworked (v0.8.1)" | **Shipped to `main`** — Meadow·Burnt palette merged; hexes pinned. (Understated, not overstated.) | [MoodLevel+Palette.swift:24-28](../../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/MoodLevel+Palette.swift#L24-L28) |

---

## 5.1 Check-In — ✅ Shipped

`CheckInView` / `CheckInViewModel` (`Tab.checkIn`). Three states:

- **Idle hub** — breathing `CrescentRing`, one big "Speak check-in", quiet "Log meds" / "Type note" secondaries, a static "How do you feel?" headline (SF Pro), medication status pill. (Rotating nudge prompts belong to Listening, not here.)
- **Listening** — rotating nudge, thin countdown bar + prompt dots, elapsed timer, single "Stop & save"; configurable `PromptPace` (relaxed 10s / brisk 6s). Transcription runs **after** save, not live. Recording auto-resumes after a phone-call/Siri interruption (handled in the audio layer; no user-facing pause control).
- **Saved** — a gradient checkmark pops in, "Captured.", single **Done**. No transcribing UI, no daily card — extraction runs silently after save, writing signals/medications onto the saved `Recording`. Capture feel hardened in spec 016: single Done, success haptic, never-lose-a-capture retry buffer, full VoiceOver, and the 8-minute soft landing ([Constants.swift:10](../../app-four/Utils/Constants.swift#L10), 480 s cap).

🔭 **Deferred:** the in-place crescent→check "Settle" morph (spec 016) was held back for on-device motion tuning and is not in the build.

## 5.2 Calendar — ✅ Shipped

`CalendarLibraryView` (VM `MoodLibraryViewModel`). Collapsible week↔month grid (`CalendarHeaderView`); horizontal drag pages months; force-collapses to a single week at accessibility text sizes; drives a month-paged, day-grouped `DayCard` timeline **one-way** (selecting a date filters + scrolls the timeline; scrolling the timeline does not move the calendar selection). **Day card** (specs 014 + 019, redesigned in spec 023): a folded mood-tinted block reads the whole day in one line, opens to time-ordered check-ins; selecting a date focuses it (filter-above + jump-to-top + auto-expand, default ON).

## 5.3 Insights — ✅ Shipped (structure + palette) · 🔭 Sleep signal planned

`InsightsView` — 5-section snapping scroll: `breakdown` (MoodBubbleChart + legend) · `signals` (glyph ramps) · `averages` · `rhythm` · `connections`. Inactive headers dim to 0.4; switching tabs snaps back to `breakdown`. Structure and the Meadow·Burnt palette both shipped to `main` (BACKLOG labels this the v0.8.1 palette milestone).

🔭 **Planned:** the Sleep ramp renders "not tracked yet" — sleep is not yet a live signal source. HealthKit sleep is a 🧪 prototype in a worktree, not in the shipping target (see [TECH_STACK §9](TECH_STACK.md)).

## 5.4 NLP Extraction Engine — ✅ Shipped (deterministic core) · 🔭 Phase D parked

Fully deterministic, on-device, instant — Apple **NaturalLanguage** (`NLTokenizer` / `NLTagger`) over a bundled lexicon, **no model load**. `NLNoteExtractor` runs off-main: `NLSummarizationService` wraps it in `Task.detached(.userInitiated)` ([NLSummarizationService.swift:26](../../app-four/Services/NLSummarizationService.swift#L26)). Whole-token / multi-word lexicon matching via `CueMatcher` (never substrings); longest-exact-phrase-wins; static-compiled regex + `NSDataDetector` + edit-distance-1 fuzzy med-typo match for structured fields; negation scan; data-driven lexicon (`Resources/lexicon.json`, **718 entries across 32 categories**). **English-only.** Shipped phases A–C+E with an eval harness (ratcheting precision/recall regression floors).

🔭 **Planned (v1.1, gated on the Gate-0 spike):** Phase D — `NLContextualEmbedding` / BERT for paraphrase + multilingual, targeting the known energy/focus, sleep-hours, and Portuguese/Spanish recall gaps. A multilingual rewrite exists on PR #14, pending a lineage decision ([TECH_STACK §9](TECH_STACK.md)). A personal-overlay hook from `RecordingTag(source: .userCorrected)` is **scaffolded but not yet active** (see 5.5).
> ⚠ Gate-0 is recorded **inconclusive / deferred** (E5 model failed to compile on the simulator, no numbers obtained), **not passed** — re-run on a physical device before any Phase-D go/no-go.

## 5.5 Editing / Review — ✅ Shipped (editing) · 🔭 training loop not wired

`ExtractionReviewView` ("Edit check-in" sheet from `RecordingDetailView`): correct date/time, mood, energy, focus, sleep, medication, emotions, side-effects. Glyph pickers with named 1–5 scale + synonym line; Sleep named scale + hour presets + custom-hours input; **Stimulants-only** medications, multi-select, removable, inline-expand (dose pills + editable duration). Edited fields persist as `RecordingTag(source: .userCorrected)`; untouched fields stay `.nlp`.

🔭 **Planned (immediate next step):** the personal-lexicon training loop is **not yet wired** — corrections are stored but `PersonalLexiconBuilder` is never invoked, so today the extractor does **not** learn from them. The mechanism exists and is the next piece to land; until then, low-friction correction is design intent, not yet a working feedback loop. (Functional rationale stands: if correcting is a chore, the NLP can never learn once the loop is connected.)

## 5.6 Medication — ✅ Shipped

Pinned, fully-interactive `MedicationBarOverlay`: capsule + single purple fill that goes **empty (just taken) → full (worn off)** over `MedicationEvent.durationHours`; onset (first ~20% of the dose window) shows a gentle pulse; worn-off → quiet (never alarms). Dose logging via a curated catalog + history picker (spec 005).

🔭 **Planned:** the catalog is a 3-stimulant **beta** set (Concerta / Ritalin / Elvanse, each with dose options, onset, duration) — broader EU stimulant coverage to follow.

## 5.7 Settings — ✅ Shipped (current controls) · 🔭 iCloud sync in progress (spec 038, uncommitted)

Prompt pace; model download with failure recovery (cancel / retry / cause-specific copy) and a **Download over Cellular** toggle ([SettingsView.swift:157](../../app-four/Views/SettingsView.swift#L157)); a "Your data" privacy statement + open-source / font acknowledgements; an encrypted single-file journal **export** (CryptoKit AES-GCM, fresh 256-bit key per export, [ExportService.swift:217-219](../../app-four/Services/ExportService.swift#L217-L219)); **Clear All Data**. The app honors the **system** Reduce Motion setting (the dead in-app toggle was removed in spec 017).

Two spec-030 sections back the hands-free App Intents (§5.8): **My Medication** — pick the default drug + dose the "Log My Meds" intent logs, plus a "name the medication in confirmations" toggle ([MyMedicationSection.swift:3](../../app-four/Views/Settings/MyMedicationSection.swift#L3)); and **Dose Guard** — off (default) / total / time-window (1–4 h) protection against a duplicate expedited dose ([DoseGuardSection.swift:4](../../app-four/Views/Settings/DoseGuardSection.swift#L4)).

The medical-vocabulary bias ("recognize medication names") ships **on by default** but has **no Settings control** — it lives in `UserDefaults` (`medicalPromptEnabled`), read by the on-device transcription engine.

🔭 **In progress (spec 038, uncommitted):** opt-in iCloud sync. The service layer is largely built, off by default, and now **surfaced in the working tree** via a consent-gated Settings control (`ICloudSyncSection` driven by `SyncSettingsViewModel`, mounted at [SettingsView.swift:60](../../app-four/Views/SettingsView.swift#L60)) — but none of it is committed (the `feat/038-icloud-sync` branch has no commits ahead of `main`). What exists in the working tree: a `CloudSyncService` seam with a CloudKit-backed `CloudSyncServiceImpl` (account-status gating, opt-in `setSyncEnabled`, cloud-only `removeFromICloud`), a `SyncFlags` UserDefaults flag read at container-build time ([SyncFlags.swift:12](../../app-four/App/SyncFlags.swift#L12)), a two-config Synced/Local container partition that flips to `cloudKitDatabase: .private(...)` only when the flag is on ([AppModelContainer.swift:35](../../app-four/App/AppModelContainer.swift#L35)), and DI injection ([AppDependencies.swift:38](../../app-four/Store/AppDependencies.swift#L38)). The prior blocker — four `@Attribute(.unique)` ids — is **resolved**: `SquirlSchemaV1` moves the synced models (Recording, TranscriptionSegment, RecordingTag, MedicationEvent) off `.unique`; only the never-synced Local models keep it. The store is still device-backup-excluded ([AppModelContainer.swift:65](../../app-four/App/AppModelContainer.swift#L65)). Remaining: iCloud entitlement wiring (none in the build target yet), owner device QA, then commit. *Target version is per planning docs, not code-pinned.*
🔭 **Candidate:** surface the medication-recognition bias as a user-facing toggle.

## 5.8 App Intents — Siri, Spotlight & Shortcuts — ✅ Shipped (spec 030)

Zero-setup system exposure via `SquirlAppShortcuts` (`AppShortcutsProvider`): from install, Siri / Spotlight / the Shortcuts app surface two shortcuts, no user setup ([SquirlAppShortcuts.swift:7](../../app-four/Intents/SquirlAppShortcuts.swift#L7)).

- **Log My Meds** (`LogDefaultDoseIntent`, US1) — logs the default dose **in the background** without opening the app; every domain rule (settings resolution, catalog re-validation, Dose Guard, write) lives in `DoseLogService`, never a view model. The not-configured path foregrounds to the My-Medication setup ([LogDefaultDoseIntent.swift:8](../../app-four/Intents/LogDefaultDoseIntent.swift#L8)).
- **Check In** (`StartCheckInIntent`, US2) — foregrounds Squirl straight into an active voice check-in, gated on onboarding (FR-022): incomplete onboarding arms nothing and opens onboarding instead ([StartCheckInIntent.swift:8](../../app-four/Intents/StartCheckInIntent.swift#L8)).

Both route through `AppIntentRouter`, a single cross-surface trigger choke point shared with the legacy `whispernotes://checkin` deep link; triggers are one-shot (consumed in [SquirlApp.swift:57](../../app-four/App/SquirlApp.swift#L57) and [SettingsView.swift:81](../../app-four/Views/SettingsView.swift#L81)), so a stale trigger can't re-fire. iOS 26 target: uses `IntentModes` foreground/background (deprecated `openAppWhenRun` / `ForegroundContinuableIntent` avoided).

🔭 **Not yet in the target:** only the two shortcuts + deep-link parity ship — no widget / Control-Center App-Intent surface exists (the 037 Live-Activity work is Figma-design-only). *Owner device QA (S1–S10) is per planning docs, not verified in code this pass.*

---

## 6. Roadmap (features verified absent / incomplete in the shipping target today)

| Item | Status | Where it lives | Next |
|---|---|---|---|
| Crescent→check "Settle" morph (5.1) | 🔭 Deferred | spec 016 notes | Tune motion on device |
| Sleep as a live signal (5.3) | 🔭 Planned | `feat+healthkit-signals` worktree (🧪) | Promote prototype → target |
| Phase D — paraphrase + multilingual (5.4) | 🔭 Parked (v1.1) | PR #14 (multilingual rewrite) | Re-run Gate-0 on device; pick `NLNoteExtractor` lineage |
| Personal-lexicon learning (5.4 / 5.5) | 🔭 Planned (next) | `PersonalLexiconBuilder` (orphaned — no call site) | Wire into the extractor build path |
| iCloud sync (5.7) | 🔭 Scaffolded (spec 038, uncommitted) | Service seam + CloudKit container partition, no UI ([CloudSyncServiceImpl.swift](../../app-four/Services/Sync/CloudSyncServiceImpl.swift)) | Build US1 Settings UI + sync VM, then commit (`.unique` blocker already resolved) |
| Medication-recognition toggle (5.7) | 🔭 Candidate | `UserDefaults.medicalPromptEnabled` only | Add a Settings control |
| Medication catalog expansion (5.6) | 🔭 Planned | Beta 3-drug set | Extend EU stimulant set |

---

## 7. Confirm before external / investor use (not code-grounded this pass)

- **Gate-0 outcome (5.4)** is recorded as *inconclusive/deferred*, and the report predates the app rename — treat "gated on Gate-0" as open, not a clean pending.
- **iCloud sync (5.7)** — the service layer is built but uncommitted and UI-less; the "v1.2" *target version* still rests on planning docs (BACKLOG / privacy policy / press kit), not code.
- **Extraction destination (5.1):** signals are written onto the persisted `Recording`; the specific Calendar/Insights surfacing was not traced end-to-end this pass.
- **Medication-recognition toggle (5.7):** confirmed absent from `main`; whether a closed/unmerged branch adds one was not diffed.

> Sourcing: claims above were verified against source on `feat/038-icloud-sync` (= `main` at v0.8.0 build 2 plus the uncommitted spec-038 sync working tree), per-claim `file:line`. Cross-checked for consistency against [TECH_STACK.md](TECH_STACK.md).
