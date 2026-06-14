# app-two DevLog

Chronological narrative of the project — the *why* behind what happened. Newest day on top.

This complements, never duplicates: **[BACKLOG.md](BACKLOG.md)** holds current *state* (stage of each item), **[specs/](superpowers/specs/)** + **[plans/](superpowers/plans/)** hold deep design records, **memory/** holds cross-session facts. Entries here link out to those rather than restating them.

**Entry types:** `Recap` (morning standup, written by `/recap`) · `Decision` (with *why:*) · `Investigation` (with outcome) · `Direction` · `Shipped` · `Open`.

---

## 2026-06-14

- **Shipped** — PR #8 (calendar day-selection) + PR #6 (debug mock-data toggle + Insights snap-scroll) **merged to `main`** (`081010d`, `bb31e38`); both were stale (16 / 59 commits behind) but merged clean (only `BACKLOG.md` conflicted; took HEAD). Resolved `main`↔origin divergence by folding the local `chore/v0.8-version-display-name` stack — incl. `ebfcb91` MARKETING_VERSION 0.8.0 + display name **"Squirl"** — into `main` and pushing. Integrated suite **213/0 green**. CodeRabbit (2 minor calendar fixes applied: guarded date math, empty-month grid). Per user: Insights palette moved v0.9 → **v0.8** (⚠️ re-opens v0.8 code-complete — colours unbuilt); iCloud Sync (PR #1) → **v1.2**.
- **Investigation** — Two NLP feeling tests (`inflectedVerbMatchesLexiconForm`, `metricsMeetFloors`) failed under parallel `xcodebuild` and traced to the verb-lemma bridge: `NLTagger`'s lemma model returns nil under parallel sim clones (the already-diagnosed [test-suite-not-parallel-safe](BACKLOG.md) artifact — pass serially, not a product bug). Fix (`ecc28f7`): a curated, model-independent `canonicalInflections` table + `Cue.altForms` so inflected feeling-verbs match deterministically in both modes. Does **not** address the 10 sibling `signal trap` crashes — that per-test-isolation fix is owned by the concurrent session. ⚠️ A live concurrent session is editing this tree (uncommitted `ARCHITECTURE.md`/`Constants.swift`, the chore branch, the parallel-safety memory) — left untouched.
- **Recap (pm)** — Since this morning's recap: only docs/process (`3283fd0` richer `/recap`, `add347a` BACKLOG reconcile), no feature code. ⚠️ `main` diverged from origin (ahead 3 / behind 1): origin `e70c9e6` (CLAUDE.md session-start rule) == uncommitted local `M CLAUDE.md` — rebase + push before anything. In flight unchanged: PR #8 calendar (v0.9, hold), #6 debug-tools (unverified), #1 iCloud (7d-stale). v0.8 code gates all met → only the non-code Apple pipeline remains (Info.plist mic/speech usage strings first — crash risk — then ASC record + archive); 18 Jun is 4 days out. Cleanup: delete 3 merged branches (actor-isolation, checkin-remove-live-transcription, med-bar). Today: fix divergence, then start the TestFlight pipeline.
- **Recap** — Since 2026-06-13: check-in "Listening…" redesign **merged to `main` + pushed** (`a0b1395`) — big-hero serif prompt, configurable prompt pace, live-transcription removal, pause/resume on interruption, Clear All Data — clearing the last v0.8 *code* gate (actor-isolation PR #5 and NLP A–C+E already on `main`, so all three v0.8 code gates met); in flight: PR #8 calendar day-selection (built+verified, v0.9), PR #6 debug-tools+snap-scroll, PR #1 iCloud (week-stale); open: Insights palette colours, Gate-0 → Phase D go/no-go; today: pivot off code to the v0.8 TestFlight pipeline (verify `Info.plist` mic/speech usage strings, then App Store Connect record + archive) — 18 Jun is 4 days out. Note: BACKLOG drifted (check-in + PR #5 still shown unshipped); current working branch `fix/checkin-remove-live-transcription` is merged/defunct.

## 2026-06-13

- **Decision** — set up this DevLog + a manual `/recap` morning ritual · *why:* BACKLOG tracks state and memory tracks facts, but nothing captured the chronological *why*; a recap needs a narrative to read from · [design](superpowers/specs/2026-06-13-devlog-and-recap-design.md)
- **Direction** — calendar day-selection: collapsible week↔month grid over the mood/med timeline, mood-colour day-dots, past/newest-first, month-paged; replaces `MonthSelectorScrollView`. Spec hardened via multi-agent review, locked N1 · branch `feat/calendar-day-selection` · [design](superpowers/specs/2026-06-13-calendar-day-selection-design.md)
- **Investigation** — NLContextualEmbedding (BERT) on-device for Phase D paraphrase/multilingual recall → E5 model won't compile on simulator; Gate-0 anisotropy spike run to decide go/no-go (MiniLM fallback) · [spec](superpowers/specs/2026-06-13-tag-suggestion-design.md) · [gate-0 report](superpowers/specs/2026-06-13-gate0-report.md)
- **Shipped** — NLP extraction quality Phases A–C+E on `feat/nlp-eval-and-precision`: eval harness (40 cases) + measured precision/recall wins (mood .60→.75, energy .13→.67, feelings .71→.94, topics fixed to 0.90/0.78, meds recall→1.0), fuzzy med matching for ASR typos, highlight dedup, clause-bounded titles · [plan](superpowers/plans/2026-06-13-nlp-extraction-quality.md)
- **Direction** — HealthKit signals (sleep/activity/heart/cycle): new day-keyed `DailySignals` model, quarantined `HealthKitService` actor + `SignalSyncCoordinator`, read-on-open + manual refresh (no background sync v1). 15-task TDD plan ready, mockup gate at Task 10 · [spec](superpowers/specs/2026-06-13-healthkit-signals-design.md)
- **Open** — Insights "Meadow" redesign: 5-section scroll structure is final & shipped, but the palette is being reworked — colours not yet resolved.
- **Open** — `fix/checkin-remove-live-transcription` and PR #5 (actor-isolation, 38→0 warnings) both awaiting merge to `main`. Active dev branch is `feat/calendar-day-selection`.

### Baseline (state as of seeding)

- **Shipped to `main`:** Insights "Meadow" 5-section redesign (palette pending) · Calendar Daylio-style mood/med timeline · NLP hardening P0+P1+P2 (lexicon-as-data +256 swarm terms, personal overlay, off-main SSOT engine, 111/111 tests).
- **In code (branches):** check-in live-transcription removal + pause/resume on interruption + nudge cadence 10s + Clear All Data · actor-isolation fix (PR #5) · debug mock-data toggle + reseed · Insights snap-to-section scroll · NLP eval & precision (Phases A–C+E).
- **Plan written, not built:** calendar day-selection · HealthKit signals · NLP Phase D (paraphrase/multilingual) · check-in view redesign (user bringing the design).
