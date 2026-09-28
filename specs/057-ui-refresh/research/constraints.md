<!-- Created: 2026-09-27 22:12 (WEST) · Updated: 2026-09-27 22:12 (WEST) -->
# UI-refresh plan — process, product and timeline constraints (with sources)

Planning input only. No Swift was touched; no repo file was modified. Every quote below is verbatim from the file named, at the branch/commit stated. Where the repo contradicts itself, both versions are quoted and the contradiction is flagged rather than resolved.

**Repo state at read time (2026-09-27 22:12 WEST):** worktree `feat/057-ui-refresh` at `08ba8cba` (= `main`, 0 commits ahead). Working tree: `D DESIGN.md` (uncommitted deletion) and untracked `outsource_design/` (8 SVGs: `iPhone 17 - 1/4/5/6/7/16/18/19.svg`). `DESIGN.md` quotes below come from `git show HEAD:DESIGN.md`.

---

## 1. Process gates the plan must pass

### 1.1 Constitution (`.specify/memory/constitution.md`, **v2.2.0 on `main`**; **v3.0.0 on `feat/055-revenuecat`**, see §1.2)

Every spec and plan carries a Constitution Check: *"All specs and plans MUST include a Constitution Check gate that verifies compliance with Principles I–XI before Phase 0 research proceeds."* (Governance)

| # | Principle | Exact rule the refresh must satisfy |
|---|---|---|
| I | SwiftUI-First (NON-NEGOTIABLE) | *"All UI MUST be implemented in SwiftUI using modern APIs (iOS 26+ / SwiftData / Swift Concurrency). UIKit is permitted only where SwiftUI has no equivalent API. No backwards-compatibility shims, no deprecated APIs, no `@objc` bridging unless unavoidable. **New views MUST start as an HTML mockup before SwiftUI implementation.**"* |
| II | Test-Build-Ship (NON-NEGOTIABLE) | *"Every code change MUST pass a build and the full test suite before being reported as done. This is non-negotiable and non-skippable — no exceptions for 'small' changes. Use `ios-debugger-agent` (XcodeBuildMCP) to verify. A PR is not ready until CI is green on the branch."* |
| III | Correctness Over Speed | *"No silent corner-cutting: if a tradeoff is made it MUST be surfaced explicitly. Dead code, backwards-compat shims, and placeholder stubs MUST NOT be merged. Comments are written only when the WHY is non-obvious"* |
| IV | Minimal Surface | *"Features MUST NOT introduce abstractions, helpers, or error-handling paths beyond what the task explicitly requires. Three similar lines beat a premature abstraction. No half-finished implementations, no feature flags for hypothetical future requirements. Complexity MUST be justified in the Complexity Tracking table of the plan before it is introduced."* → a refresh that adds a second token set (pen palette next to `NewLook`/`Theme`/`Palette`) must justify it in Complexity Tracking, and dead tokens must go (III). |
| V | Solo Git Discipline | *"`main` MUST always be releasable. Every code change MUST go through a feature branch (`feat/…` or `fix/…`) and a PR with `/code-review` run before merging. Trivial non-code changes (typos, BACKLOG.md, CLAUDE.md) MAY go directly to `main`. TestFlight uploads MUST be tagged (`git tag vX.Y.Z`) immediately after the upload commit. Feature branches MUST NOT stack unmerged for long — growing merge-conflict risk MUST be flagged."* |
| VI | On-Device Privacy (NON-NEGOTIABLE) | *"All transcription, extraction, and storage MUST run on-device. There is no account, no server, and no cloud by default. … Diagnostics and logging MUST record counts, durations, and token estimates ONLY — never transcript text or medication content."* |
| VII | On-Device LLM Extraction | *"Signal output MUST be validated against `Levels.swift` enum rawValues — any value not in the canonical set is clamped to `nil`."* → the UI may not invent level names that are not in `Levels.swift` (see §4.3 for the pen's vocabulary). |
| VIII | Service-Oriented Architecture | *"ViewModels MUST be `@MainActor @Observable`, hold no persistence logic, and dispatch CPU/IO-heavy work off the main actor."* |
| IX | Pre-Release Data Posture (2.2.0) / Data Posture (3.0.0) | 2.2.0: *"a schema conflict is recovered by wiping and rebuilding the store"*. **3.0.0 (feat/055, 2026-09-02) redefines it:** *"the store MUST NOT be wiped in a release build, because user journals and the grandfather signal are irreplaceable."* The refresh should not need a schema change; if it does (e.g. persisting a new UI preference in `AppSettings`), the 3.0.0 text applies once 055 merges. |
| X | Test-First Development (NON-NEGOTIABLE) | *"Testable logic — SwiftData `@Model` types, `Services/` implementations, `@MainActor @Observable` view-models, and the `MLXJournalService` extraction pipeline — MUST be built test-first … **SwiftUI views are EXEMPT from unit-test-first: they are verified by build + on-simulator run (Principle II) and an HTML mockup (Principle I); snapshot tests are encouraged, not required.** Tests use **Swift Testing** (`@Test`, `#expect`/`#require`)."* |
| XI | Architectural Exhaustiveness | *"Plans and specs must not leave implementation details to the imagination. Every edge case, error state, and data structure must be explicitly defined before proceeding to tasks. Summaries are strictly forbidden; exhaustive detail is required."* |

Development Workflow (same file): *"**New UI**: HTML mockup MUST precede SwiftUI implementation."* · *"**Spec-kit flow**: `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement`. Run `/speckit-clarify` before specifying if intent is underspecified."* · *"**PR flow**: Branch → build + tests pass → open PR → `/code-review` → human approves/merges. No force-push to `main`."*

Sprint override in the same section: *"For the duration of the Shipaton sprint the backlog is `shipaton_plan/BACKLOG.md`, the devlog is `shipaton_plan/DEVLOG.md`, and the plan of record is `shipaton_plan/SEPTEMBER_PLAN.md`. The `docs/` pair is FROZEN — read for history, never edit. … Reverts via the exit ritual on 2026-10-01."*

### 1.2 Constitution version drift (must be resolved before the refresh's Constitution Check)

- `main`: **2.2.0**, last amended 2026-08-31.
- `feat/055-revenuecat` (commit `d15580c5 constitution(3.0.0): redefine Principle IX — Data Posture (RC-35)`): **3.0.0**, last amended 2026-09-02. Its SYNC IMPACT REPORT: *"MAJOR per Governance because a principle is redefined."* and records debt: *"`AppSettings.id` carries a pre-existing `@Attribute(.unique)`, which predates and violates the CloudKit clause; it is grandfathered as known debt, not licensed by this amendment."*
- The October-1 exit ritual (SEPTEMBER_PLAN §October 1) says *"revert the constitution amendment (2.2.0 → 2.3.0 with rationale)"* — that number is stale once 055 merges (it would be 3.0.0 → 3.1.0). The refresh plan's Constitution Check must cite whichever version is on the branch it is cut from.
- `docs/SPECKIT.md` still says the constitution is *"(v1.2.0)"* and that the plan gate is *"Constitution Check (I–X) must PASS"* — stale by two principles (XI exists since 2.1.0). Follow the constitution, not SPECKIT.md, for the gate.

### 1.3 Spec Kit operating rules (`docs/SPECKIT.md`)

- *"**Spec Kit is the main, end-to-end workflow for this project.** Every feature goes through it: spec → plan → tasks → implement."*
- *"**superpowers (`/spec`, `/design-*`, HTML mockups) is design only.** … Those are inputs a Spec Kit spec references — they are NOT a parallel build workflow."*
- *"**One feature per spec.** `/speckit-specify` takes a single feature → one `specs/NNN-slug/`. Don't bundle two milestones into one spec."* → an 8-screen refresh is several specs (or one spec with strictly separable user stories), not one.
- *"**Don't hand-edit the spec markdown.** Pass clarifications back as chat messages so the agent updates the file"*
- *"**One task per session.** Open a fresh session per task … Never run multiple tasks in one session"*
- *"**Split fat tasks.** Any task touching more than one layer (model + view + test) is too big — split it."*
- *"**MCP hygiene.** Load planning-phase MCP servers (web search, docs) only when strictly needed … Drop them after `/speckit-plan`."* → the `pencil` MCP is a planning-phase server.
- Pipeline table, step 3: *"`/speckit-plan` → `plan.md`, `research.md`, `data-model.md`, contracts"*; step 4: *"`tasks.md` (numbered, TDD-ordered) — Tests are **MANDATORY + test-first** for logic … SwiftUI views exempt (build + run)."*
- Standing PRD inputs: *"Hard constraints: On-device only · SwiftUI + SwiftData + Swift 6 (strict concurrency) · iOS 26+"*; *"Out of scope (now): HealthKit · LLM trend summaries · iCloud sync · multilingual"*.
- Spec numbering: `specs/` on `main` ends at `044`; `053`/`054` live on their branches/stash; `055-revenuecat-paywall` on `feat/055`; **`056` is taken** by PR #46 `feat(056): Gemma 4 E2B extraction via LiteRT-LM`. `057` is free and already matches the branch name `feat/057-ui-refresh`. `.specify/feature.json` still points at `{"feature_directory":"specs/043-mlx-journal-service"}` — `/speckit-specify` must move it.

### 1.4 CLAUDE.md — Process, Git, design-system and markdown rules

Process:
- *"**Before touching any Swift file**: confirm the request explicitly asks for code, not just a mockup/design update. When in doubt, ask. 'Update the view' or 'add X' without 'implement' or 'code it' means HTML mockup only. Never infer code permission from a UI description."* — the owner's request is explicit: *"NO SWIFTCODE CHANGES / NO IMPKEMENTATION YET"*.
- *"For new UI: HTML mockup before SwiftUI — see memory."*
- *"Plan → surface assumptions → execute. No mid-task interruptions."*
- *"Log at real checkpoints … **During the September sprint the log is `shipaton_plan/DEVLOG.md`**; outside it, `docs/DEVLOG.md`."*
- *"After any git commit … regenerate `docs/WORKLOG.md` by running `scripts/worklog.sh` … Commit spec/plan/tasks files before regenerating so they appear in the log."*
- *"Always build and run tests after code changes before reporting done. Never ask — just do it. Use the `ios-debugger-agent` skill (XcodeBuildMCP)."* — **that skill is not on this branch**: `.claude/skills/` contains only `deep-plan-review`. The Swift skills CLAUDE.md lists (`swiftui-pro`, `swiftui-design-principles`, `swift-architecture-skill`, `swift-concurrency-pro`, `swift-concurrency-expert`, `swiftui-liquid-glass`) were vendored on `feat/055` (`020527cf chore(skills): vendor the Swift/SwiftUI skills into .claude/skills`, `690796b8 … vendor swiftdata-pro`). The feat/055 BACKLOG row says: *"⚠️ The Swift skills named in CLAUDE.md are not installed in this environment — install before T004."* Implementation on this branch needs those commits (merge 055 first, or cherry-pick).
- *"`NEXTDAY.md` is retired … never create, read, update, or cite it"*.
- Communication: *"Whenever a subagent is spawned … state which model it runs on — Sonnet, Opus, or Fable — in the same message as the spawn."* and the mandatory closing block *"What / Why / How / Next Action"*.

Git Workflow:
- *"Branch per feature/fix off `main` (`feat/…`, `fix/…`). Never commit code straight to `main`."*
- *"Open a PR for every code change; run `/code-review` on the diff and surface findings before merging."*
- *"**No PR is merged without both:** (1) `/code-review` completed and findings addressed, AND (2) manual human QA on device by the owner. Never merge on code review alone — device QA is non-negotiable."*
- *"Keep `main` always releasable: no half-finished work merged. One PR = one revertable feature."* → per-screen (or per-language-layer) PRs, not one 8-screen PR.
- *"When a commit on `main` is uploaded to TestFlight, tag it"*; *"Don't let feature branches stack unmerged for long — flag growing merge-conflict risk."* (see §5: 055, #44, #45, #46, #42, #41 are all unmerged today).

Design System (CLAUDE.md §Design System) — the rule the refresh is rewriting:
- *"`DESIGN.md` (repo root) is the source of truth for all visual/UI decisions — aesthetic ('Paper & Pollen'), typography (**native SF app-wide**; hierarchy via weight/size, not face), color (signal ramps + medication purple), the signal glyph language (sprout/lightning/aperture; sleep bed icon, med capsule), spacing, layout, motion, and per-screen specs. Read it before writing or changing any SwiftUI. Don't deviate without explicit approval; flag mismatches in design/QA review."*
- *"Typography reversal (spec 023, 2026-06-26): the original Fraunces + DM Sans + IBM Plex Mono system was dropped for native SF — bundled faces, `UIAppFonts`, and `SquirlFonts` registration removed."*
- Session Start: *"At the start of every session, read `DESIGN.md` plus the current board and log."* → **deleting DESIGN.md without landing the replacement in the same commit breaks this instruction and 79 tracked references** (`git grep -l 'DESIGN\.md'` excluding WORKLOG/.gems = 79 files, incl. `CLAUDE.md` L82/103/104/108, `PRODUCT.md` L4, `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift`, `app-four/Views/Components/CalendarDayCell.swift`, `app-four/Views/Settings/MyMedicationSection.swift`, `design-database/*`). CLAUDE.md's Design System paragraph itself (Paper & Pollen, sprout/lightning/aperture, bed icon) must be rewritten in the same change or it contradicts the new doc.
- Stack note: *"**Design tokens:** `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/` (`Palette`, `Typography`, …) — *not* `app-four/DesignSystem/`"*. Files present: `Buttons.swift Card.swift Color+Hex.swift GlyphSignal.swift Glyphs/ Haptics.swift Icons.swift Metrics.swift MoodLevel+Palette.swift Motion.swift NewLook.swift Opacity.swift Palette+Signals.swift Palette.swift Radius.swift Reexport.swift SignalGlyph.swift SignalLevel.swift Spacing.swift Theme.swift Typography.swift`.

Markdown rule (applies to the new `DESIGN.md`, any `shipaton_plan/*.md` edits, spec-kit files are exempt):
- *"Every **hand-maintained** `.md` file … starts with a timestamp comment as its **first line**, above the H1 … `<!-- Created: YYYY-MM-DD HH:MM (TZ) · Updated: YYYY-MM-DD HH:MM (TZ) -->` … Set both fields when creating the file; bump `Updated` (never `Created`) on every edit. Get the time with `date "+%Y-%m-%d %H:%M %Z"`; recover an existing file's true `Created` with `git log --diff-filter=A --format=%ai -- <file> | tail -1`."* The old DESIGN.md's `Created` is `2026-06-18 12:13 (WEST)`; a rewritten file at the same path should decide whether it is a new file (new `Created`) or an edit (keep `Created`, bump `Updated`) — flag for the owner.
- Backlog rule: *"Update it whenever work changes stage … When starting work, check the backlog first; when finishing a stage, move the item before reporting done."*

Monetization guardrails that touch UI (CLAUDE.md §Monetization; all bind the refresh's Settings/onboarding screens):
- *"**Hard paywall + 7-day free trial** … The whole app sits behind the trial for new users."*
- *"**Fail open — non-negotiable** … If entitlement can't be verified, grant access."*
- *"**Export is never gated.** It works with no active subscription. Locking the app is acceptable; locking someone's own writing is not."*
- *"**Existing 1.0 users are grandfathered** and never see the paywall."*
- *"**All purchase code sits behind a `PurchaseService` protocol** … Views and ViewModels never touch `Purchases.shared`."*
- *"**No dark patterns.** No countdown timers, fake scarcity, guilt copy, or streak-loss threats. The paywall obeys the Product Posture rules in `DESIGN.md`."* ← a live cross-reference into the file being deleted.
- *"**Privacy sequencing is a hard gate:** the privacy policy, `PrivacyInfo.xcprivacy`, and the App Store nutrition label change *before* the build with RevenueCat in it is submitted."*

### 1.5 PRODUCT.md rules the plan inherits

- Users: *"Adults (18+) with ADHD … low cognitive load, minimal friction, no overwhelm, fast and clear reward."*
- Purpose: *"North star: **effortless** — in and out in under a minute, the app always slightly calmer than you. First three seconds read as *relief, then permission*."*
- Anti-references (verbatim list): *"The mood-tracker category's blue/purple 'calm' palettes and emoji-face mood rating. · Streaks, badges, gamification, confetti — shame mechanics that get these apps deleted. · Red 'you're late' medication alarms; a worn-off dose just goes quiet. · Surveillance imagery of any kind … · Pure white / pure black surfaces (light = warm paper, dark = warm loam)."*
- Design Principles 1–5: *"Effortless over complete — one primary action per screen"*; *"Non-judgmental by construction — no streaks, no nags, no faces"*; *"Privacy by architecture … The *only* datum that leaves the device is the App Store purchase receipt"*; *"Auditable over opaque · correctable over final · instant over eventual … every inferred signal is shown plainly, attributed, and one tap from correction"*; *"**Color is never the only cue** — every signal is also encoded by glyph shape + fill (colorblind- and grayscale-safe)."*
- Accessibility: *"WCAG 2.1/2.2 AA as a hard floor: contrast ≥ 4.5:1 body / ≥ 3:1 large+UI, touch targets ≥ 44×44 pt, VoiceOver labels on all controls, Dynamic Type AX1–AX5, Reduce Motion fallbacks (breathing/rotation collapse to static). Known token caveats: muted ink `#7A7361` fails AA for small text on paper …; meadow amber is decorative-only, never text."*
- PRODUCT.md L4 says it is *"Synthesized from the canonical Master PRD … and [DESIGN.md](DESIGN.md)"* — the Brand Personality paragraph (*"Warm pressed paper ('Paper & Pollen'), a field journal that listens"*) will be false after the refresh and needs the same rewrite.

---

## 2. Timeline reality (today = Sunday 2026-09-27)

### 2.1 The release train has already passed

`shipaton_plan/SEPTEMBER_PLAN.md` §Release train:

| Week | Dates | Work | Gate | Status on 2026-09-27 |
|---|---|---|---|---|
| 1 | Aug 31 – Sep 4 | RevenueCat 1.1 | **Submit Fri Sep 4** | **Missed** — 1.1 not submitted (README) |
| 2 | Sep 7 – 11 | 1.1 goes live · UI build | — | 1.1 not live; UI never scoped |
| 3 | Sep 14 – 18 | UI 1.2 | Submit ~Sep 15 | **Passed, nothing submitted** |
| 4 | Sep 21 – 25 | LLM 1.3 | **Last safe submission ~Sep 23** | **Passed** |
| 5 | Sep 28 – 30 | Demo video · Devpost write-ups | **Devpost closes Wed Sep 30, 11:45pm PDT** | 3 days away (= Thu Oct 1 07:45 WEST) |

*"Anything that must be **live** by Sep 30 has to be submitted by ~Sep 23."* — CLAUDE.md: *"**The binding constraint is App Review, not Devpost.**"* Consequence: **no part of the UI refresh can be in a Shipaton-judged App Store build.** The refresh is post-Shipaton work; anything it produces this week is planning artefacts (spec, DESIGN.md, mockups), not a release.

### 2.2 Where the plan and tickets must live

Until 2026-10-01 (CLAUDE.md sprint section + constitution 2.2.0 override):
- Plan of record: `shipaton_plan/SEPTEMBER_PLAN.md`. It already has the slot: *"## Epic UI — UI Refresh *(placeholder)* — 📋 **Not scoped.** To be filled after RC ships. Seeds: 053 insights shape views (parked in `stash@{0}`), 054 settings topic hub."* with one assigned row: `UI-01 | *TBD — scope after Sep 4* | — | — | — | RC epic | Must submit by ~Sep 15 to be live in week 3`. *"Ticket IDs are stable once assigned — never renumber."* → `UI-01` exists and must be re-described, not reissued; new tickets are `UI-02…`.
- Ticket table format (exported to JIRA as-is): columns **`ID | Summary | Type | Est | Owner | Depends | Acceptance criteria`**; Type ∈ {Story, Task, Design}; Est in focused hours; Owner ∈ {Owner, Claude}. JIRA mapping: *"ID → Issue key · Summary → Summary · Type → Issue Type · Est → Original Estimate · Owner → Assignee · Depends → Linked issue (blocks / is blocked by) · Acceptance criteria → Description · Epic → Epic Link / Parent"*, and *"**UI** → 'UI Refresh'"*.
- Stage board: `shipaton_plan/BACKLOG.md` (stages *"💡 Idea → 📐 Planned → 🔨 In code → ✅ Shipped · 🧊 Deferred to October"*; changelog *"Keep to 15 rows"*). Its row today: `UI-01 | *TBD — scope after Sep 4* | RC epic` under 📐 Planned.
- Why-log: `shipaton_plan/DEVLOG.md` (*"the why, not every edit"*).
- *"New specs this month log to `shipaton_plan/`, not `docs/`."*
- Only `/morning` and `/evening` may touch SEPTEMBER_PLAN's `## Today` block — and that block **still reads "Monday 2026-08-31"** on both `main` and `feat/055` (the cadence lapsed after 2026-09-05). Do not hand-edit it.

From 2026-10-01 (SEPTEMBER_PLAN §October 1 — exit ritual, verbatim):
1. *"Merge `✅ Shipped` rows from BACKLOG.md into `docs/BACKLOG.md`; move `🧊 Deferred to October` rows into its Next-up / Ideas sections."*
2. *"Append one summary `Direction` entry to `docs/DEVLOG.md` linking this sprint log."*
3. *"Remove the freeze banners from both `docs/` files; delete the 'September 2026 — Shipaton sprint' section from `CLAUDE.md`; revert the constitution amendment (2.2.0 → 2.3.0 with rationale)."*
4. *"Keep `shipaton_plan/` as a frozen archive — do not delete it."*

So the refresh tickets written this week into Epic UI will be carried into `docs/BACKLOG.md` by step 1 in four days; the spec-kit artefacts go to `specs/057-ui-refresh/` regardless of date. **Practical instruction for the plan:** write the Epic UI table now (IDs stable), mark rows `🧊 Deferred to October` on the board, and note that implementation sessions start under the post-ritual rules (`docs/` pair live again, CLAUDE.md sprint section gone).

### 2.3 State of RC / 1.1 (facts, with sources)

- `README.md` (main, L12–14): **1.0** *"tag `v1.0` — On the App Store. Free, no paywall. Signals extracted with Apple's NaturalLanguage framework."* · **1.1** *"`main` — **Not submitted.** Replaces the extractor with an on-device LLM (Qwen2.5-1.5B via MLX)."* · **RevenueCat paywall** *"`feat/055-revenuecat` — **Implemented, not approved by App Review.** Not in any App Store build yet."* L17: *"Installing Squirl from the App Store today gets you 1.0 — none of the LLM or RevenueCat work below."*
- `git log --oneline main..feat/055-revenuecat`: **63 commits**, last `9564e392 docs: regenerate WORKLOG.md` at 2026-09-06 13:27. No PR exists for it (`gh pr list --state all`). Highlights: `35179e8e spec(055)`, `568ae695 plan(055)`, `cba4745f tasks(055): 43 TDD-ordered tasks`, `d15580c5 constitution(3.0.0)`, `490e45b1 docs(055): log full RC paywall implementation (T001-T039, 630 green)`, `c6ffc876 feat(055): switch to RevenueCatUI paywall + Customer Center, add Lifetime plan`, `aad46e09 feat(055): wire the real appl_ App Store key (Release); RC-03b/RC-04 done`, `28b0efd4 docs(055): RC test procedure (RC-24/28)`.
- feat/055 DEVLOG 2026-09-04: *"Owner reversed three verified 09-02 design decisions: the custom SwiftUI paywall → **RevenueCatUI** (dashboard Paywalls v2), no Customer Center → **add it**, monthly+annual only → **add a Lifetime** non-consumable."* and *"RevenueCatUI reintroduces issue **#6018** (its 58 MB→1 GB paywall memory regression) next to the 740 MB LLM — flagged"*. *"_what stays custom (not dead):_ the onboarding paywall step, the screen-C fail-open card, and the shared export/legal components remain the custom SwiftUI"*. **This contradicts SEPTEMBER_PLAN on `main`**, which still locks *"Custom SwiftUI paywall"*, *"Monthly + annual"*, and lists RevenueCatUI and Customer Center under *"Explicitly cut to fit 5 days"*.
- feat/055 DEVLOG 2026-09-05: RevenueCat project `proj074664e3` configured live; entitlement `pro`; offering `default` with Annual/Monthly/Lifetime (Test-Store prices $9.99 / $79.99 / $99.99); Paywalls-v2 paywall left as **DRAFT** (*"do not publish the paywall yet"*); *"_owner-blocked:_ … the real `appl_` key + ASC products + offer code (RC-03b…07, RC-40)"* — later `aad644cf` wired the `appl_` key. Owner device QA (RC-24/28), ASC screenshots (RC-26) and submission (RC-29) have no completion record.
- feat/055 BACKLOG ✅ Shipped section: *"Nothing yet — the sprint opens 2026-09-01."* (never updated).
- `main`'s `shipaton_plan/BACKLOG.md` (Updated 2026-08-31 01:39) knows none of the above; only `shipaton_plan/DEVLOG.md` on `main` has a 2026-09-27 entry (repo made public; Anthropic keys in history *"must be confirmed revoked"*).

Implication for the refresh: the paywall/Settings-subscription/onboarding-paywall surfaces exist **only on `feat/055`** and are New-Look styled; the pen file does not design them (§4.6). The refresh cannot be finished against `main` as it stands.

---

## 3. Carry-over content for the new DESIGN.md (verbatim, from `git show HEAD:DESIGN.md`)

The owner asked to delete DESIGN.md and rewrite from the pen. The sections below are **not visual** and have no source in the pen file; they must be carried (or explicitly retired with a CLAUDE.md/PRODUCT.md edit in the same commit). Old line numbers in brackets.

### 3.1 §Product Context [L7–11] — carry, with one correction (tokens path stays; platform line stays)

> - **What:** on-device, privacy-first iOS journal. The user voice-logs (or types) a daily check-in in under a minute; the app transcribes it (**WhisperKit**, `openai_whisper-small`) and extracts structured signals (mood, energy, focus, sleep, medications, side-effects, emotions) with an **on-device LLM** (`mlx-community/Qwen2.5-1.5B-Instruct-4bit` via MLX, two-pass: narrative summary → strict-JSON signals), then surfaces personal patterns. Extraction is probabilistic, so every inferred value must render as *reviewable and correctable*, never as settled fact.
> - **Who:** ADHD adults. The audience is a *functional* constraint, not flavor — low cognitive load, minimal friction, no overwhelm, fast/clear reward.
> - **Platform:** SwiftUI, iOS 26 (Liquid Glass). Tokens live in `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/` (`Palette`, `Typography`, `Spacing`, `Radius`, `Motion`, `Haptics`, `Icons`).
> - **North star (the one thing to remember):** **effortless** — in and out in under a minute, the app always slightly calmer than you.

### 3.2 §Color — the one non-visual rule [L50]

> Rule: **color is never the only cue.** Every signal level is also encoded by glyph shape + fill (below), so it survives colorblindness and grayscale.

### 3.3 §Iconography — the emoji rationale [L62]

> Glyphs encode level by **shape + hue + fill simultaneously** (triple-redundant; verified grayscale/colorblind-safe via a single-ink silhouette test). No emoji faces anywhere — faces impose a self-judgment ("am I a frowny-face today?") that adds affective load; abstract growth glyphs are lower-stakes and faster to scan.

### 3.4 §Motion [L77–82] — carry the rules; the crescent specifics are a pen question (§4.5 Q-M1)

> - **Approach:** intentional; "effortless = inevitability." Everything decelerates gently; nothing snaps hard.
> - **Crescent (`CrescentRing`):** breathes slowly when idle (~5s scale 1→1.035); revolves while listening (~7s/rev) with a voice-level glow; settles to a check when saved.
> - **Settle transitions** (spring, gentle damping) for section/tab changes.
> - **No confetti, no streak celebration, no "you're late" alarms.** Honor Reduce Motion (breathing collapses to a static glow).
> - **Easing:** enter ease-out · exit ease-in · move ease-in-out. **Duration:** micro 50–100ms · short 150–250ms · medium 250–400ms.

### 3.5 §Product Posture (non-negotiable) [L84–89] — carry unchanged (CLAUDE.md L82 cites it by name)

> - **No streaks, no gamification.** A broken streak is a shame spiral for ADHD users and the #1 reason these apps get deleted. The reward is "I said it and it's captured."
> - **Medication never nags.** No red, no "you're late." A worn-off dose just goes quiet.
> - **Glyphs, not emoji faces** (see Iconography).
> - **Privacy-first.** On-device; the store is excluded from iCloud backup. Nothing here invites surveillance imagery.
> - **The paywall obeys every rule above.** It is a screen in this app, not an exception to it. No countdown timers, no fake scarcity, no guilt copy, no "you'll lose your progress." If a growth tactic contradicts the four rules above, the rules win.

### 3.6 §Paywall & Purchase [L91–108] — carry, then reconcile with feat/055 (RevenueCatUI + Lifetime + Customer Center)

> ## Paywall & Purchase (spec TBD — RevenueCat)
>
> > Added 2026-08-30, revised for the **hard paywall** decision. Mockup: [055-paywall.html](../html-mockups/055-paywall.html) (4 screens, dark + Dynamic Type toggles).
> >
> > **Placement:** after Welcome, **before** the ~500 MB model download — so a bounce costs the user no bandwidth and nobody waits through a long download only to be asked for money.
> >
> > **Four screens are required, not three.** Beyond the paywall (A), trial-ended (B) and Settings (D), screen **C · fail-open** is mandatory: when entitlement cannot be verified the app *unlocks*. Under a hard paywall, empty offerings or purchases-ios #4623 would otherwise lock a paying user out of their own on-device journal. Screen B also offers **export without subscribing** — the app may lock, the user's writing may not.
>
> - **Surface.** `NewLook.screen` ground, one `NewLook.card` panel per plan option, `NewLook.hairline` borders. **New Look, not Paper & Pollen** — spec 033 made New Look the app-wide language and it is what ships (`inkSecondary` 105 uses, `inkPrimary` 66, `card` 17, `screen` 13 across `app-four/Views/`). No full-bleed marketing hero; this app does not shout.
> - **Type.** Native SF throughout, hierarchy by weight/size (§Typography). Price is the largest numeral on the screen; nothing competes with it.
> - **Color.** The recommended plan is filled with `NewLook.selection` and labelled with `NewLook.onSelection` — the established fill+label grammar, which is also the only AA-safe way to use that green (as a fill; `#54B492` measures 2.52:1 as text and must never carry copy). **`NewLook.checkInGreen` is out of scope** — it is scoped to the capture flow (check-in · onboarding · recording-detail edit) and the paywall is not capture. Amber is decorative-only and must never carry paywall text. Never use `Theme.danger` to pressure a choice.
> - **⚠️ Contrast exception to rule on.** `NewLook.inkSecondary` `#8A8A8E` is a known light-mode AA failure (3.0:1 sage / 3.4:1 white), accepted app-wide on 2026-07-12 for Figma fidelity. **Paywall fine print is the one place that ruling should not extend**: price terms, trial length and cancellation copy are legally load-bearing and are exactly what a reviewer scrutinises. Recommendation — render paywall pricing terms in `inkPrimary`, reserving `inkSecondary` for genuinely secondary labels. Owner decision required.
> - **Required furniture** (App Review Guideline 3.1.1 — omission is an automatic rejection): exact price · billing period · trial length if any · Restore Purchases · Terms (EULA) · Privacy Policy · plain-language how-to-cancel.
> - **Restore appears twice**: on the paywall and in Settings, matching the existing section pattern in `app-four/Views/Settings/`.
> - **Selection is explicit.** Plan choice uses the established chip grammar — fill + label, never colour alone (§Color, principle 5).
> - **Accessibility is a hard gate.** The pricing screen must survive Dynamic Type AX5 without truncation or overlap — plan options stack vertically before they clip. VoiceOver reads plan → price → period → savings as one label, not four fragments. Touch targets ≥ 44×44 pt.
> - **A dismissed paywall stays dismissed.** No re-presenting on every launch; that is a nag, and nags are banned above.
> - **One honest disclosure line**, because the privacy policy promises the app says when anything leaves the device: *"Purchases are verified by our payments provider. Your journal never leaves this device."*

The **Surface / Type / Color / Contrast** bullets are visual and reference `NewLook.*` tokens the refresh will retire — rewrite those four in the pen language; keep Placement, Four screens, Required furniture, Restore twice, Selection explicit, Accessibility gate, Dismissed stays dismissed, Disclosure line as-is. Also fold in the 09-04 owner reversal (RevenueCatUI remote paywall for root/Settings; custom SwiftUI stays for onboarding step, fail-open card, export/legal), or the section describes a paywall that no longer exists on the implementation branch.

### 3.7 §Screen Specs — two non-visual decisions worth carrying [L114, L116]

> - **Calendar.** **Unchanged** (collapsible week↔month over the mood/med timeline). Owner-preferred; do not redesign without explicit ask.

(The pen file *does* redesign the Calendar — `iPhone 17 - 19` — so this is superseded by the owner's "pen file is the source of truth"; log it as a dated decision rather than silently dropping it.)

> - **Edit sheet (`ExtractionReviewView`).** … "Save corrections" writes `RecordingTag(source: .userCorrected)` → trains the personal lexicon. Low friction here is functional: if correcting is a chore, the personal lexicon that steers the LLM's extraction never improves.

### 3.8 §Typography — the reversal record [L19–21] (history for the Decisions Log)

> - **Reversal (spec 023, 2026-06-26):** dropped the original **Fraunces + DM Sans + IBM Plex Mono** system — including the earlier rule *"do not use SF/system as display or body, the 'gave up on typography' signal"* — for native SF app-wide, an explicit owner decision. The bundled faces, `UIAppFonts`, and `SquirlFonts` registration were removed. (Settings was already SF-exempt; it now matches the rest of the app.)

### 3.9 §Decisions Log [L182–205] — carry verbatim as history, then start new dated rows

> | Date | Decision | Rationale |
> |------|----------|-----------|
> | 2026-08-30 | Doc corrected to match `main`: extraction is an **on-device LLM** (Qwen2.5-1.5B-Instruct-4bit via MLX, two-pass), not the old NaturalLanguage/NLP path (`NLSummarizationService` is now test-only); token path fixed `app-two/DesignSystem/` → `Packages/SquirlDesignSystem/…`. Added **Paywall & Purchase** posture + structural spec ahead of the RevenueCat build | The md files had drifted from the code; `main` is the source of truth. Paywall spec written before any SwiftUI so the HTML-mockup-first rule has something to check against, and so growth tactics can be ruled out by design rather than argued about later |
> | 2026-07-18 | §Signal ramps energy/focus hexes corrected to the shipped `Palette+Signals.swift` values; design-audit remediations approved: `ink/destructive` light `#E0443A`→`#D54037` (5% darker, clears AA 4.55:1 on card), new `accent/medicationText` `#6B4E8F` for medication text on tinted surfaces (extends the R09 darker-word-color precedent), crescent gradient mid `#97C2A0`→`#96C19F` (code parity), Tiimo Colors gains a Dark mode (documented values only). Accepted-as-is: inkSecondary on tint bands/wells (extends the 2026-07-12 ruling), white-on-mood-5 bubble labels (ramp is three-way consistent; legend is redundant) | Full three-dimension design audit of the v3 catalog (`design-database/` audits №1–3, R22–R28); owner accepted the audit's judgment 2026-07-18. Code follow-ups (Theme.danger retint, medication text role) flagged, not yet implemented |
> | 2026-07-16 | Capture-flow surfaces (check-in · onboarding · recording-detail **edit**) adopt one green — `NewLook.checkInGreen` `#5FB36E`, the day-card "Good"-mood green — replacing the mint `selection` + meadow-gradient mix | Owner wanted these three to match the day check-in card, which has no fixed green (mood ramp), so its "Good" green was chosen. **Scoped, not app-wide** (owner call): new token + `.checkIn` chip role + `CheckInPrimaryButtonStyle` (green-only gradient); Insights chips and other primary buttons keep `selection`/meadow. `selectionSoft` → `checkInGreenSoft`. Landed straight to `main` per owner. |
> | 2026-07-16 | Contrast ruling on the spec-033 review's 8 WCAG findings: **fix derived dark-mode values, keep Figma-locked light values 1:1 and log them** | Figma specs light only; dark is derived, so fixing it isn't a deviation. Fixed: `onSelection` label token (dark ink on selection/medication fills in dark), medication dark `#9277BE`→`#957BC1`, Taken/Missed toggle re-grammar (`tintNeutral`+ink). Kept+logged: selection-green light family (chip label 2.52:1, green-on-white text, ramp ring, gradient/groove 2.14:1) — see palette note. |
> | 2026-07-12 | Keep `NewLook.inkSecondary` at Figma value `#8A8A8E` despite light-mode WCAG AA failure (3.0:1 sage / 3.4:1 white, need 4.5:1) | Owner chose Figma fidelity over the contrast fix when the spec-033 accessibility audit surfaced it app-wide. Documented as a known limitation (see palette note above); dark mode unaffected (~7:1). A compliant alternative (~`#6C6C70`) is on record if revisited. |
> | 2026-07-11 | Adopt "New Look" as the app-wide visual language (spec 033), superseding spec 032's two-screen pilot scope | Two-screen pilot (Edit check-in, Recording detail) validated the language; owner approved app-wide rollout. `Theme` retained only for accent/meadow/status/danger semantic colours — every other screen migrates to `NewLook.screen` / `NewLook.card` / `.newLookCard()`. |
> | 2026-07-10 | Adopt "New Look" as a second visual language for Edit check-in + Recording detail (spec 032); dark tokens derived now; mixed P&P/New-Look shipped, no toggle | Owner adoption call after the Figma a-screens reached presentation grade; two lowest-risk screens prove the language before wider rollout. Calendar (a01) gated on spec-029. |
> | 2026-06-15 | Adopt "Paper & Pollen" design system | `/design-consultation`. Warm-paper organic identity differentiates from the blue/purple category; "refine Meadow, don't replace." |
> | 2026-06-15 | Keep shipped signal ramps; Energy stays Lemon | Owner override of the proposed Energy→Ember swap. Mood/Focus untouched. |
> | 2026-06-15 | Signal glyphs = sprout / lightning / aperture | Distinct shapes make the four signals colorblind- and grayscale-safe; chosen over sun/eye/etc. |
> | 2026-06-15 | Sleep = single bed icon, ramp deferred | One icon now (like meds' capsule); add a bluer 5-step ramp later to clear med purple. |
> | 2026-06-15 | Medication = purple `#7E5CA8`, capsule, fill-up no-alarm bar | Purple is the only unused hue; the bar fills empty→full over the dose; never alarms. |
> | 2026-06-15 | Check-in saved state shows no transcribing/card | Capture is the job of that moment; extraction is silent, results appear later. |
> | 2026-06-15 | Type-note = Layout A (signals first) | Fewest taps for daily use; glyph pickers as input. |
> | 2026-06-15 | No streaks / no gamification / no med alarms | Removes the dominant reason ADHD users delete these apps. |
> | 2026-06-15 | Detail: no back button (swipe-left); pencil → "Edit check-in" button | From the owner screen-recording; the pencil was inconsistent with the interface. |
> | 2026-06-15 | Edit pickers keep named 1–5 scale + synonyms (Mood/Energy/Focus); Sleep drops synonyms + adds custom-hours input | Owner kept the named scale as "correct"; synonyms help mood/energy/focus, add noise on sleep. |
> | 2026-06-15 | Edit Medications: Stimulants only, multi-select, removable, P1 inline-expand, independent events, no limit | Non-stimulants/Off-label deferred (too complex now); inline-expand chosen over per-med sheet/table for the frictionless flow. |
> | 2026-06-16 | Glyph redesign "Bud" botanical (pod/seedhead) — explored, then **REVERTED** | Owner returned to the canonical sprout/lightning/aperture set. Net glyph change for Mood/Energy/Focus: none. Full register: [design-decisions-ALL](superpowers/plans/2026-06-16-design-decisions-ALL.html). |
> | 2026-06-17 | Sleep = bed, Medication = **horizontal** capsule, Mood icon **fixed** (selectable set removed) | Literal icons for the two non-self-state signals; one fixed Mood glyph. **Build target:** port all signal glyphs from SF Symbols → SwiftUI `Shape`s. |
> | 2026-06-24 | Settings is **exempt** from the "no SF/system as display or body face" rule | Settings deliberately uses the native iOS grouped-`List` chrome (system-font section headers, rows, footers). It is HIG-aligned and more learnable than a custom-typeface settings screen; the Fraunces/DM Sans rule governs Squirl's own content surfaces, not OS-standard utility chrome. |

Note: the log's link `superpowers/plans/2026-06-16-design-decisions-ALL.html` **does not exist** in `docs/superpowers/plans/` (checked with `find`); the surviving registers are `design-database/` (README, rules.csv R01–R32, four audit CSVs, REMEDIATION-PLAN.md) and `docs/superpowers/specs/*-design.md`.

### 3.10 What can be dropped (visual, pen-sourced)
§Aesthetic Direction, §Typography (except the reversal record), §Color tables and ramps, §Iconography glyph shapes, §Spacing, §Layout & Components, §Screen Specs (except the two rows above), §New Look (spec 033) token table. Each of these has a pen counterpart (Frames 2/3/4/5/12/15 + the 8 screens). The spec-033 contrast exceptions (`#8A8A8E`, `#54B492`) become moot only if the new palette stops using those values — `#8a8a8e` still appears in the pen (§4.4 Q-C6).

---

## 4. Product rules that constrain the pen design — and pen elements that may conflict (questions, not verdicts)

Rules in force (sources: PRODUCT.md §Anti-references / §Design Principles / §Accessibility; DESIGN.md §Product Posture, §Paywall; CLAUDE.md §Monetization): **no streaks/badges/gamification/confetti · meds never nag, no red, worn-off goes quiet · no emoji faces · privacy-first, nothing invites data-sharing · export never gated · hard paywall + 7-day trial with 4 screens incl. fail-open · check the entitlement, never product IDs · colour never the only cue · WCAG AA (4.5:1 body, 3:1 large/UI, 44×44 pt, AX1–AX5, Reduce Motion) · amber never carries text · never pure white / pure black surfaces · one primary action per screen · every inferred signal reviewable and one tap from correction.**

Pen facts below are quoted from the exports (`figma/screen-texts.md`, `pen/ds-html-lite/Frame-5.html`, the PNG renders). Node ids are Figma ids from the JSON.

### 4.1 Mood / gamification / judgment cues

- **Q-P1 — red "Low" mood.** `iPhone 17 - 19` renders `Low` in **`#842626`** (14/600 at `78:12087`, 16/600 at `78:12239`) with a red sprout glyph; Frame 12 row 3 level-1 sprout is red. The old mood ramp deliberately started at burnt orange `#DA7A2A` ("burnt-low → green-high") and PRODUCT.md lists red only as a medication anti-reference. Question: is a red Low a judgment cue for an ADHD user on a bad day, or acceptable data encoding? Note the pen is internally inconsistent: the Insights bubble `Low` is `#da7a2a` (`bubble/Low`) and `Flat` in Previous Days is `#da7a2a` (`78:12315`) while the bubble `Flat` is `#eda94a`.
- **Q-P2 — "unlock" copy + padlock tiles in Connections.** `78:11140` *"Patterns across signals — 3 or more days to unlock"*; `78:11162` *"Note 1 More Good Sleep Day & 3More Poor-Sleep Days To Unlock This Connection"*; `78:11170` *"Log High Energy 2 More Days To Unlock This Connection"*; each row has a padlock in a violet tile. Question: does "unlock" + a lock icon read as progression/achievement (gamification) and does "log N more days" read as a logging nudge (a nag)? Sub-question: the SLEEP × MOOD line asks the user to have *3 more poor-sleep days* — copy that literally wants the user to sleep badly. The 053 branch already ships an `InsightGatedCard` (commit `5419aaee refactor(insights): T003 extract InsightGatedCard component`) — its gating copy should be compared before either is chosen.
- **Q-P3 — counts and percentages.** `78:10643` *"24 check-ins"*, bubbles *"8% Low · 17% Flat · 33% Okay · 29% Good · 13% Great"*, legend *"Low (2) · Flat (4) · Okey (8) · Good (7) · Great (3)"*, `78:11149` *"On Medication Days, Sharp Focus Appeared 75% Of The Time."* with a bar labelled `70%` (`78:11154`). Question: is a monthly check-in count a streak proxy (scorekeeping) or neutral context? And 75% vs 70% on the same card is a data-consistency defect to resolve in the spec.
- **Q-P4 — "See You At Next Check-In".** `72:16440` saved-state copy *"A Moment For Yourself, Captured. See You At Next Check-In"* with `72:16443` *"Go Back Home"*. DESIGN.md's saved state was *"Captured." with **Done** leading and "Check in again" secondary — no transcribing UI, no daily card*. Question: is "see you at next check-in" a return nudge (nag) or acceptable warmth? And is "Go Back Home" the "Done" affordance?
- **Q-P5 — "Missed" chip.** Edit Check-In medication toggle `Missed` (`I78:11508`) / `Taken` (`I78:11509`). This already exists in code (spec 033 "Taken/Missed toggle re-grammar"), so it is not new — but "Missed" is judgment vocabulary next to "Medication never nags". Keep, rename, or drop?

### 4.2 Medication and sleep semantics

- **Q-P6 — green status words on the medication bar.** `Active` (`78:11963`) and `Kicking In` (`78:11978`) in green-500 `#2a9134`. DESIGN.md: *"One consistent purple — only the fill changes, so onset and fading never share a color."* The bars themselves fill violet (`#8061bf→#8c68d3`, Concerta 51.6 %, Vyvanse 6.25 %) — consistent with "fills empty→full". Question: is a *worn-off* state designed, and does it stay quiet (no red, no alarm)? It is not in the pen.
- **Q-P7 — violet is no longer medication-only.** Medication purple was chosen because *"Purple is the only unused hue"*. In the pen, violet also carries the **`+` FAB** (Frame 15 Add Button), the **AI sparkle** on the day-details summary, the **Connections lock tiles** and their `#7f5fc0` eyebrows (`MEDICATION × FOCUS`, `SLEEP × MOOD`, `ENERGY × MOOD`), and the **sleep moon** glyph (Frame 12 row 4). Question: does purple keep its "medication" meaning, or is it now the brand accent? Either is fine; both cannot be true.
- **Q-P8 — sleep encoding.** Frame 12 row 4 is a moon+sparkle on a **black block** that grows with level (replacing the bed icon; DESIGN.md had deferred any sleep ramp and required it *"bluer/cooler so it never collides with medication purple"* — the moon is violet). Edit Check-In "Your Sleep" chips are **`Low · Flat · Good · Okay · Great`** (`I78:11482–11486`) — mood words, while `Levels.swift` `SleepLevel` is `restless · light · okay · good · deep` and the journal shows `8h Sleep` (`78:12210`). DESIGN.md's edit spec had hour presets *"2/4/6/8/10h presets plus a custom-hours text input"*. Question: is sleep a 5-level named scale, hours, or both — and which words?

### 4.3 Level vocabulary vs `Levels.swift` (Principle VII: not-in-set → `nil`)

Canonical (`Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift`): Mood `low flat okay good great` · Energy `sluggish tired steady alert charged` · Focus `foggy distracted present sharp lockedIn` (displayLabel "Locked In") · Sleep `restless light okay good deep`.
- Pen matches: Mood words; Energy `Tired/Steady/Alert/Charged`; Focus `Distracted/Present/Sharp/Locked In`.
- **Q-V1** — pen never shows `Sluggish` or `Foggy` (level 1 of Energy/Focus); the picker captions say only `Low … High`. Fine for pickers; confirm the level-1 labels appear where words are shown.
- **Q-V2** — `78:10944–10956` "Where you averaged / Energy Level" axis reads **`Steady · Alert · Tired · Good · Great`** (wrong order and two mood words); Focus axis reads `Low · Flat · Okay · Good · Great` (mood words). Copy defects to fix in the spec, not design intent.
- **Q-V3** — spelling in the pen: `Okey` (`78:12129`, legend `Okey (8)`), `Breackdoen` (`78:10642`), `Claendar` (`72:10016`), `Vyvans` (`78:11977`), `Elvense` (`I78:11500`), `How's Your Mode?` (`72:16402`), `How Does It Feels Today?` (`78:11736`), `Blocked While A Does Is Still Active` (`72:10096`), `AFTERNOO N` wrap in the rhythm header. The spec must state that copy is normalised to the code's `displayLabel`s and Title-Case-per-HIG, not copied from the pen.

### 4.4 Colour, contrast, typography, surfaces

- **Q-C1 — Inter vs native SF.** Frame 2 is an **Inter** ramp (12–36 pt × Regular/Medium/Semi Bold/Bold) and every screen text node is Inter (`screen-texts.md`). CLAUDE.md: *"typography (**native SF app-wide**; hierarchy via weight/size, not face)"*; spec 023 removed bundled faces. Precedent: spec 033 mapped *"the Figma Inter ramp … to existing `Typography` roles"* and design-database R01 says *"Inter is the working stand-in; SF Pro is the production target"*. Decision needed: map Inter→SF again (no font bundling), or reverse spec 023 and bundle Inter.
- **Q-C2 — amber as text.** `Charged` `#e38400` (`78:10767`, 12/600), `Mostly Steady` `#e38400` (`78:10744`). PRODUCT.md: *"meadow amber is decorative-only, never text"*; `#e38400` on white is well under 4.5:1. Keep amber for the bolt glyph only, or darken a text variant (the R09 "darker word colour" precedent)?
- **Q-C3 — green-500 as 12 pt text.** `#2a9134` carries `Good`, `Charged`, `Present`, `Active`, `Kicking In`, `Installed` at 12/600. Frame 5's own contrast card gives green-500 **4.04 (white)** — below the 4.5:1 body floor. green-600 `#26842f` is listed 4.75 AAA/AA; green-700 `#1e6725` 6.95. Which step carries small text?
- **Q-C4 — focus blue off-palette.** `Sharp` `#447097` (`78:11759`) / `Mostly Sharp` `#4278a8` (`78:10824`); the focus ring uses `#4278a8`/`#447097`. Neither is in Frame 5 (violet/green/neutral only). Is blue a fourth palette family to add, or a leftover?
- **Q-C5 — red off-palette.** `#842626` (Low) is not in Frame 5 either. Same question as Q-C4 (and Q-P1).
- **Q-C6 — `#8a8a8e` survives.** `78:11788` *"Written by on-device AI from your Voice, tap to Correct"* 12/400 `#8a8a8e`; rhythm `—` cells `#8a8a8e`. This is exactly the token whose light-mode AA failure (3.4:1 on white) was accepted 2026-07-12. Frame 5 offers grey-300 `#6a6d70` (5.21 AAA) which the pen uses elsewhere for secondary text. Retire `#8a8a8e`?
- **Q-C7 — `#6f7f75` and `#717680`/`#414651`.** Off-palette greys used for picker captions `Low/High` (`#6f7f75`), dates (`#6f7f75`), and the week strip (`#717680` weekday, `#414651` date — Untitled-UI greys). Consolidate onto Frame 5 neutrals?
- **Q-C8 — pure white / pure black.** Cards are `#ffffff`; the canvas is `#fbfffc` (off-palette; Frame 5 has no page-background swatch); the energy and sleep glyph level-blocks are **`#000000`**. PRODUCT.md anti-reference: *"Pure white / pure black surfaces (light = warm paper, dark = warm loam)."* Is that anti-reference retired with Paper & Pollen, or does the new doc keep it (then `#ffffff` cards and black blocks both need a decision)?
- **Q-C9 — black energy/sleep blocks.** Frame 12 rows 1 and 4: a black rectangle that grows from a sliver (level 1) to the full tile (level 5), bolt/moon drawn over it. It is a strong shape cue (good for "colour is never the only cue") but: what is it in dark mode (black on `#12140F`-like ground vanishes)? Is it a placeholder for a fill container? In `iPhone 17 - 19` the black block appears inline next to `Alert` at 12 pt — is that legible at that size and at AX5?
- **Q-C10 — dark mode is not designed.** All 8 screens are light; Frame 4's variant is named `Status=…, Mode=Light` (implying a Dark variant exists for navs only). Spec 033 precedent: *"Figma specs light only; dark is derived"*. Does the refresh derive dark (documented per-token), or is dark out of scope for 1.x?
- **Q-C11 — signal ramps.** The old five-step ramps (Mood `#DA7A2A · #EDA94A · #9FCB79 · #5FB36E · #2E8B57`, Energy Lemon, Focus Voltage blue) live in `Palette+Signals.swift` and `design-database` R09/R10. The pen bubble chart uses `#da7a2a · #eda94a · #9dcca2 · #55a75d · #2a9134` (levels 3–5 moved onto Frame 5 greens). Energy in the pen is a single amber bolt with black-block fill (no five-colour ramp); Focus is a blue ring that fills. Question: do ramps still exist as *colour* ramps, or is level now shape/fill only? This decides whether `MoodLevel+Palette.swift`, `Palette+Signals.swift`, `DayCardPaletteTests` survive.

### 4.5 Layout, chrome, accessibility

- **Q-L1 — floating tab bar + violet FAB on every root screen.** Frame 4 "Navs": pill bar with Calendar · Check In · Insights · Settings; Frame 15 "Add Button" FAB sits beside it on Calendar, Insights, Settings and Day Details. Question: what does `+` do (new check-in? log dose?), and how does that square with *"one primary action per screen"* when Check In is already a tab? On Day Details the FAB coexists with a back pill and a `•••` menu.
- **Q-L2 — tab bar on pushed screens.** `iPhone 17 - 1` (day details, pushed with a back pill) keeps the tab bar + FAB; `iPhone 17 - 18` (edit) hides both. Which rule?
- **Q-L3 — tab bar hides the Calendar week strip?** In `iPhone 17 - 7` the selected pill is **Calendar** although the screen is Insights (noted in the sibling screen spec). Confirm the Insights variant.
- **Q-L4 — touch targets.** Bill-shape chips (Frame 15) are **25 pt** tall; month-selector segments 30 pt; the `Low/High` picker tiles 56 pt (fine); `•••`/back pills 42.6 pt (< 44). PRODUCT.md floor is 44×44 pt. Are chips tappable (legend) or display-only?
- **Q-L5 — Dynamic Type.** 11 pt text in the rhythm grid (`78:11020…`), 12 pt captions everywhere, five fixed 56-pt tiles + 4×8 gaps = 312 pt in a 344 column, and chip rows that the PNG shows **clipping in a single row** (legend `Great (3)` cut off; Emotions/Side-effects rows overflow-hidden). Spec must define wrap/scroll behaviour and the AX5 layout, per the accessibility hard gate.
- **Q-L6 — Reduce Motion / crescent.** The pen check-in screens (`iPhone 17 - 4/5/6`) show `Speak Check-In` primary, `Log Medications` (`#634a96`), `Write Notes` (`#26842f`), a **72 pt timer** `0:07`, `Stop & Save` + **`Cancel`**, and *"Take Your Time, Speak Freely."*. DESIGN.md's listening state was *"single 'Stop & save' (no idle buttons)"* and had the breathing/rotating crescent. Question (Q-M1): does the crescent survive, and if not, what carries the "listening" motion — and what is its Reduce Motion fallback?
- **Q-L7 — date/time editing.** Edit Check-In shows read-only-looking fields `Jun 29` / `9:15 AM` with calendar/clock icons. DESIGN.md's edit sheet listed **When (date/time)** first — matches — but no picker is designed.
- **Q-L8 — "Today's Mood" hard-coded on a dated detail** (`78:11730` + `78:11731 "Monday, Jun 29 "`) and `•••` with no menu designed (edit/delete/export live where?). The old rule *"no back button (swipe-left); pencil → 'Edit check-in' button"* is reversed by the pen (back pill present). Log as a decision.

### 4.6 Paywall / monetization gap — the pen has no purchase surfaces

- The pen contains **no** paywall (A), trial-ended (B), fail-open (C), or Settings subscription (D) screen, and **no** Welcome/onboarding screen (paywall placement is *"after Welcome, before the ~500 MB model download"*).
- `html-mockups/055-paywall.html` (New Look tokens, 4 screens, dark + AX3/AX5 toggles; title *"Squirl · 055 Paywall — hard paywall + trial (RC-10)"*) is the only designed paywall. Its copy, for reference: A `"A minute a day, and Squirl does the rest"`, plans `Yearly €39,99 / year — That's €3,33 a month.` (badge `Best value · save 33%`) and `Monthly €4,99 / month — Cancel any time.`, CTA `Start 7 days free`, sub `Then €39,99 a year. Cancel any time in Settings.`, disclosure `Purchases are verified by our payments provider. Your journal never leaves this device.`, legal `Terms · Privacy Policy · Restore Purchases — Cancel in Settings ▸ Apple Account ▸ Subscriptions.`; B `Your trial has ended` / `Subscribe to pick up where you left off.` / `Your 34 check-ins are safe on this device. Nothing has been deleted.` / `You can export your journal without subscribing — your writing is yours.` / `Subscribe · €39,99 / year` / `Export my journal`; C `We couldn't check your subscription` / `You're offline, or the store isn't responding. We've unlocked the app so you're not stuck.` / `Continue to Squirl` / `Try again`; D Settings `Subscription: Squirl · Trial · 5 days left / Starts billing 6 Sep 2026 / Manage subscription / Restore purchases` and `Your data: Export journal / Privacy policy / Terms of use` + *"Privacy policy and terms open inside the app — they work with no connection."* The mockup's own note: *"Prices are placeholders."* (Test-Store prices on feat/055 are $9.99 / $79.99 / $99.99 with a Lifetime plan the mockup lacks.)
- On `feat/055` the root/Settings paywall is now **RevenueCatUI (remote, dashboard-designed)**; the custom SwiftUI screens that remain are the onboarding `PaywallStepView`, the fail-open card and `ExportJournalButton`/`LegalDocumentView`, plus the Settings subscription section (7 states, `SubscriptionSectionModel`).
- **Q-M2** — the pen Settings (`iPhone 17 - 16`) has sections `Check-In Claendar · Voice & Storage · Confirmations · Dose Guard · Medication Bar · Accessibility · Your Data` and **no** `Subscription` section, **no** `Restore purchases`, **no** `Export journal` row. Both are mandatory (3.1.1 restore-in-Settings; *"Export is never gated"*). Who designs them, in which language?
- **Q-M3** — pen `72:10165` *"Your recordings, check-ins, and signals stay on this device. Nothing is uploaded."* becomes **false once the receipt goes to RevenueCat** (PRODUCT.md principle 3: *"The *only* datum that leaves the device is the App Store purchase receipt"*; DESIGN.md requires the *"one honest disclosure line"*). Copy must be reconciled.
- **Q-M4** — a RevenueCatUI remote paywall cannot be restyled in SwiftUI; its look is set in the RevenueCat dashboard (RC-38, still a draft). Does the refresh's language get applied there too (owner task), or does the paywall stay visually separate?

### 4.7 Privacy

- Nothing in the pen invites sharing, accounts, or cloud; the AI attribution line (`"Written by on-device AI from your Voice, tap to Correct"`) satisfies principle 4 (auditable, correctable). Only Q-M3 above touches privacy copy.

---

## 5. Parked / in-flight work that overlaps, and sequencing

### 5.1 Inventory (all read-only observations)

| Item | Where | State | Overlap with the refresh |
|---|---|---|---|
| **Spec 053 — Insights shape views** | `feat/053-insights-shape-views`: **23 commits** ahead of `main` (last `760154c5`, 2026-08-20). Built T001–T053: `InsightGatedCard`, presence dots card, month shape card, usual-range card, variability bands card, emotion field card, all wired into `InsightsView` (`76dc7ded feat(insights): T033/T043/T053 wire L, J, G into scroll (FR-012 order)`). | Unmerged; final edits are **uncommitted in `stash@{0}`** (`59a9529a`, "WIP 053 insights shape views + 054 spec (auto-stashed before switching to main 2026-08-30 22:26)"): tracked changes to `InsightsViewModel+ShapeViews.swift`, `EmotionFieldCard/MonthShapeCard/PresenceDotsCard/UsualRangeCard/VariabilityBandsCard.swift`, `InsightsView.swift`, `InsightsShapeViewsTests.swift`, `specs/053…/contracts/viewmodel-api.md`, `.specify/feature.json`; plus deletions of `docs/FSD.md`, `add-google-cloud-ops-agent-repo.sh`, `test_space.patch` and **196 `.gems/` files** (already untracked on `main` at `93c342e9`, so `git stash apply` will hit path conflicts on those). | The pen Insights screen keeps *Mood breakdown*, *three signals by weekday*, **"Where you averaged"** (= 053 usual-range card), *Daily rhythm*, *Connections* — and shows **none** of presence dots, month shape lines, variability bands, emotion field. Owner decision: merge 053 then re-skin, or archive it (delete branch, drop stash) and re-scope Insights from the pen. Do not re-skin the same cards twice. |
| **Spec 054 — Settings topic hub** | Only in `stash@{0}`'s **untracked** half (`stash@{0}^3`): `specs/054-settings-topic-hub/{spec,plan,research,data-model,quickstart,tasks}.md` (1,236 lines total) + `.holding-053/` (3 Swift files: `DayNutritionFooter`, `HealthSettingsSection`, `NutritionEventRow`), `docs/engineering/DEVICE_DATA_EXTRACTION.md`, `scripts/export_evaluation_dataset.py`. `feat/054-settings-topic-hub` branch has **0 commits** ahead of `main`. | Spec only, no code. | The pen Settings is one flat scrolling page with 7 sections — a "topic hub" IA is not what the pen shows. Owner decision: 054 is superseded by the pen (archive its spec into `specs/` for history) or the pen Settings is a first-level page of a hub. |
| **Spec 055 — RevenueCat** | `feat/055-revenuecat`, 63 commits, last 2026-09-06; no PR; constitution 3.0.0; Swift skills vendored; 630 tests green (2026-09-03). | Implemented; owner device QA, ASC products, submission not recorded. | Adds screens/rows the refresh must style (onboarding paywall step, fail-open card, Settings subscription section, legal views, export button). Also carries the skills and constitution the refresh's implementation needs. |
| **Audit PRs** | #43 `docs/codebase-audit-2026-09` (report), #44 `fix/audit-safe-cleanup` ("Dead-code deletion, debug-surface gating (**RC-30**), PHI-log gating, overflow-trap fix"), #45 `fix/audit-high-medium` ("Debug build + 550 tests pass (6 new)"; fixes recording-cap race, orphaned audio on delete, save-before-move, **"Focus level-5 (`lockedIn`) restored in Insights + day timeline (stop lowercasing; show `displayLabel`)"**, sleep-hours guard, regenerate refreshes meds). All open since 2026-09-13, *"nothing merged — device QA is yours."* | Suggested merge order in `docs/audits/2026-09-13-remediation-status.md`: *"1. #44 … → merge. 2. #45 … → merge. 3. #43 … 4. Then land `chore/remove-dead-nlp` and decide the deferred items."* | #45 touches `InsightsView`/day timeline/`CheckInViewModel` — the same files the refresh re-skins. |
| **PR #46** `feat(056)` Gemma 4 E2B via LiteRT-LM (LLM epic) | open, 2026-09-13 | "additive/inert, device-gated" | Low UI overlap; owns spec number 056. |
| **PR #42** `feat(045)` SpeechAnalyzer migration | open, "REVIEW ONLY, do not merge" | — | none |
| **PR #41** `fix(settings): restore the 5-tap debug console` | open since 2026-08-31 | — | Settings view. |
| `feat/ui-refresh` | branch, 0 commits ahead | leftover name | Delete or ignore; the working branch is `feat/057-ui-refresh`. |
| Working tree | `D DESIGN.md`, `outsource_design/*.svg` untracked | uncommitted | The SVGs are the pen's screen exports; decide whether they are committed (as `docs/design/…`) or kept out of the repo. |

### 5.2 Sequencing the refresh must respect (derived from the rules above)

1. **055 lands first** (device QA → merge → tag if TestFlight). Reasons: it changes Settings/onboarding surfaces the refresh restyles; it carries the constitution 3.0.0 and the vendored Swift skills that CLAUDE.md requires before any SwiftUI is written; opening a refresh PR while 055 is unmerged is the exact *"feature branches stack unmerged"* risk V forbids.
2. **Audit #44 → #45 land next** (their own merge order). #45's `lockedIn` label fix is the source of truth for Focus level-5 copy.
3. **Decide 053** (merge-then-reskin vs archive) and **054** (superseded vs hub) **before** `/speckit-specify` for the refresh, so the refresh spec's Insights and Settings stories don't describe cards that are about to appear or disappear. Resolving `stash@{0}` (apply onto a fresh checkout of `feat/053…`, commit, or drop) is a prerequisite either way — and never with bare `git stash pop`.
4. **Re-cut `feat/057-ui-refresh` from the post-055 `main`** (it is currently identical to `main`, so re-cutting costs nothing).
5. Then the constitution/SPECKIT pipeline per feature: `/speckit-clarify` (the §4 questions are the clarify list) → `/speckit-specify` (one spec per shippable slice — e.g. tokens+chrome, Calendar, Day details+Edit, Check-in, Insights, Settings) → HTML mockups per screen (Principle I) → `/speckit-plan` with Constitution Check I–XI and a Complexity Tracking row for the second token set → `/speckit-tasks` → implement one task per session → per-slice PR → `/code-review` → owner device QA → merge.
6. **DESIGN.md replacement ships in the same commit as the deletion**, together with the CLAUDE.md §Design System rewrite and PRODUCT.md §Brand Personality update (79 references).

---

## 6. Existing test suite facts

- **Framework:** Swift Testing (`@Test`, `#expect`/`#require`), per constitution X and Technology Stack (*"Swift Testing (`@Test`/`#expect`) for unit + integration, test-first per Principle X; XCUITest for UI flows where warranted"*).
- **Size on this worktree (= `main`):** `grep -rE '^\s*@Test'` → **544** `@Test` attributes across **68** `*Tests.swift` files under `app-fourTests/` (grep count; includes any commented-out attributes). Documented run counts: **542 green** (docs/DEVLOG.md, 2026-08-14, spec 044 on `feat/043`), **550 pass (6 new)** on PR #45 (2026-09-13), **630 green** on `feat/055` (2026-09-03), 511 in `specs/043-mlx-journal-service/device-qa-checklist.md`.
- **Test target / plans / schemes:** target `app-fourTests` (project `app-four.xcodeproj`); shared test plans `app-four.xctestplan` (single target, **`defaultOptions: {}`** — i.e. no parallelization setting is actually stored in the file, despite `docs/BACKLOG.md` L163 *"Stopgap: parallelization off in the shared `.xctestplan`"*), `app-four-mlx-eval.xctestplan` and `app-four-mlx-eval-smoke.xctestplan` (env `MLX_EVAL=1`, `MLX_EVAL_FILTER=tuned`; device-only, inert otherwise). Schemes: `app-four`, `app-four-stable`.
- **Documented commands:**
  - Simulator (docs/TUNING.md L78): `xcodebuild test -project app-four.xcodeproj -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:app-fourTests/ExtractionValidatorTests …`
  - Device eval (docs/QA_REPORT_MLX_TUNING.md L94): `xcodebuild test -project app-four.xcodeproj -scheme app-four -testPlan app-four-mlx-eval -destination 'platform=iOS,id=00008101-000849EE0EB9003A' -only-testing:app-fourTests/MLXExtractionEvalTests`
  - Env workaround recorded in DEVLOG/plans: `env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 xcodebuild test …` (SwiftPM `safe.bareRepository=explicit` injection); pre-resolve with `-resolvePackageDependencies` + `-disableAutomaticPackageResolution`; fresh `-resultBundlePath` per run; read with `xcrun xcresulttool get test-results summary --path …`.
- **Known landmines (docs/BACKLOG.md L163, docs/DEVLOG.md L123/L266/L279, docs/TODO.md L27):** *"Test suite not parallel-safe … CLI `xcodebuild test` (default parallel clones) → 12 false failures … all pass serially (`-parallel-testing-enabled NO`)"*; *"the full suite crashes under `xcodebuild test` (a SwiftData `EXC_BREAKPOINT` in `DoseLogServiceTests` from the live full-app test host — nondeterministic, 0 assertion failures) but runs clean under the owner's ⌘U"*; DEBUG-only `-skipOnboarding` launch arg exists for headless simulator runs (but `simctl` does not forward it in some envs); `ios-debugger-agent`/XcodeBuildMCP historically *"not connected in this environment"* → CLI fallback.
- **View-adjacent suites the refresh will touch or break** (all on `main`): `Views/CalendarStripFadeTests`, `Views/DayCardExpandStateTests`, `Views/FoldedDayCardHeaderTests`, `Views/StickerSetupViewTests`, `Models/DayCardPaletteTests` (mood→tint mapping — dies if colour ramps go, §4.4 Q-C11), `Models/RecordingMoodDisplayTests`, `Models/RecordingDisplayTitleTests`, `SignalGlyphTests` (glyph shapes), `ViewModels/InsightsViewModelTests`, `ViewModels/MoodLibraryViewModelTests`, `ViewModels/CalendarMonthModelTests`, `ViewModels/DayTimelineBuilderTests`, `ViewModels/CheckInViewModelTests`, `ViewModels/ExtractionReviewViewModelTests`, `ViewModels/MedicationBarViewModelTests`, `ViewModels/SettingsViewModelTests`, `ViewModels/OnboardingViewModelTests`. On `feat/053`: `ViewModels/InsightsShapeViewsTests` (modified again in `stash@{0}`). On `feat/055`: the purchase/gate/copy/`SubscriptionSectionModel`/migration-fixture suites.
- **What the refresh owes the suite (Principle X):** views are exempt (build + on-simulator run + HTML mockup), but every new *logic* unit is RED→GREEN first — candidates visible in the pen: bubble diameter formula (`d ≈ 60 + 1.3·pct`, per the sibling Insights spec), Connections gating counts and copy, "Where you averaged" range derivation (already 053's `usualRange`), level→word/colour mapping (replacing `DayCardPaletteTests`), medication-bar status words (`Active`/`Kicking In`/worn-off), any `AppSettings` toggle added for Settings sections.

---

## Sources read (all read-only)

`.specify/memory/constitution.md` (main 2.2.0; `git show feat/055-revenuecat:` 3.0.0) · `docs/SPECKIT.md` · `CLAUDE.md` · `PRODUCT.md` · `git show HEAD:DESIGN.md` · `shipaton_plan/SEPTEMBER_PLAN.md`, `BACKLOG.md`, `DEVLOG.md` (main and `feat/055-revenuecat`) · `README.md` · `html-mockups/055-paywall.html` · `specs/` listing; `specs/032|033|036*/spec.md` headings · `docs/superpowers/` listing · `design-database/README.md`, `rules.csv` · `docs/audits/2026-09-13-remediation-status.md` (via `git show docs/codebase-audit-2026-09:`) · `docs/TUNING.md`, `docs/QA_REPORT_MLX_TUNING.md`, `docs/DEVLOG.md` (grep), `docs/BACKLOG.md` (grep), `docs/TODO.md` (grep) · `app-four.xctestplan`, `app-four-mlx-eval-smoke.xctestplan` · `Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift` · `.specify/feature.json` · git: `git log --oneline main..feat/055-revenuecat`, `main..feat/053-insights-shape-views`, `main..feat/054-settings-topic-hub`, `main..feat/ui-refresh`, `main..docs/codebase-audit-2026-09`, `git stash list`, `git stash show --stat stash@{0}`, `git show --stat stash@{0}^3`, `git branch -a`, `git tag`, `git status --short`, `gh pr list --state all` · pen exports: `scratchpad/pen/named/*.png` (statistics, mood journal, day details, Frame 12, Frame 4), `scratchpad/pen/ds-html-lite/Frame-{4,5,12}.html`, `scratchpad/figma/screen-texts.md`, sibling notes `scratchpad/out/screens/{insights,mood-journal,edit-checkin,day-details}.md`.
