<!-- Created: 2026-08-30 23:19 (WEST) · Updated: 2026-09-28 14:24 (WEST) -->
# September 2026 — Delivery Plan

Rolling plan for September. Structured as **epics → tickets** so it exports to JIRA (or Linear) without rewriting. Ticket IDs are stable once assigned — never renumber.

| Epic | Scope | Window | Status |
|---|---|---|---|
| **[RC](#epic-rc--revenuecat-monetization)** | RevenueCat monetization → Shipaton 2026 entry | Aug 31 – Sep 4 | 🔨 Active |
| **[BIP](#epic-bip--build-in-public)** | #BuildInPublic posting track | Aug 31 – Sep 30 | 🔨 Active |
| **[UI](#epic-ui--ui-refresh-spec-057)** | UI refresh (spec 057, pen-derived) | Sep 28 – Dec 18 | 🔨 Active |
| **[LLM](#epic-llm--llm-pipeline-placeholder)** | LLM pipeline work | TBD | 📋 Not scoped |

**The three sprint documents, and what each is for** — nothing is written twice:

| Question | Document |
|---|---|
| What are we doing, and when? | **this file** |
| Where does ticket X stand right now? | [BACKLOG.md](BACKLOG.md) |
| Why did we do it that way? | [DEVLOG.md](DEVLOG.md) |

Reviewed twice daily via `/morning` and `/evening`. `docs/BACKLOG.md` and `docs/DEVLOG.md` are frozen until the October 1 exit ritual (§end).

---

## Today

> Rewritten by `/morning` and `/evening`. This is the only block those commands touch here.

**Monday 2026-08-31** · **4 days** to the RevenueCat submission gate (Fri Sep 4) · 23 to the last safe submission · 30 to Devpost close.

1. **Commit the working tree.** 16 files — a full session of research, RC-08 and RC-10 — exist nowhere but on disk. Branch `feat/055-revenuecat` for the manifest; docs to `main` as trivial non-code changes.
2. **RC-01 — resolve ASC → Business.** Still unverified. Blocks every other RevenueCat ticket; Apple's queue, not effort. If it isn't Active, start it today and the Fri Sep 4 gate moves to Mon Sep 8.
3. **Decide product IDs + the two prices.** RC-06 needs both; **IDs are permanent**.
4. **RC-10 — approve or reject the paywall mockup.** Gates RC-18 (6h, the largest ticket in the epic).
5. **BIP-01 — first #Shipaton post.** The engagement window is already 4 weeks old.

*Untouched from the previous list: items 2–5 above. Item 1 is new and outranks them all.*

---

## Release train

Three streams shipping in September means **three App Store releases**, each needing review. This is the binding constraint on the month.

| Week | Dates | Work | Gate |
|---|---|---|---|
| 1 | Aug 31 – Sep 4 | RevenueCat 1.1 | **Submit Fri Sep 4** |
| 2 | Sep 7 – 11 | 1.1 goes live · UI build | — |
| 3 | Sep 14 – 18 | UI 1.2 | Submit ~Sep 15 |
| 4 | Sep 21 – 25 | LLM 1.3 | **Last safe submission ~Sep 23** |
| 5 | Sep 28 – 30 | Demo video · Devpost write-ups | **Devpost closes Wed Sep 30, 11:45pm PDT** |

Anything that must be **live** by Sep 30 has to be submitted by ~Sep 23. #BuildInPublic runs daily throughout.

**Decisions locked (2026-08-30):** 1.1 ships from `main` — 053/054 do not gate it (WIP parked in `stash@{0}`). **Hard paywall + 7-day free trial** — the whole app, not a feature gate. Monthly + annual. Custom SwiftUI paywall. Existing 1.0 users grandfathered. **Export is never gated.**

> ⚠️ **Hard paywall changes the failure model.** With a feature gate, a broken paywall meant no upsell. Now it means a user cannot reach their own on-device journal. Empty offerings and purchases-ios [#4623](https://github.com/RevenueCat/purchases-ios/issues/4623) both produce exactly that, so **RC-16 (fail-open) is the highest-risk ticket in the epic**, not a nicety.

---

## Epic RC — RevenueCat Monetization

**Goal:** Squirl 1.1 submitted to App Review by **Friday 4 September**, with a live RevenueCat-powered subscription.

**Why Friday and not later:** the Shipaton backstop is ~Sep 16, so Friday buys ~12 days of slack for App Review rejections. It also scores the Grand Prize criterion *"Early and Effective Release"*, and frees the rest of September for the UI and LLM epics.

**"Ready" means:** submitted to App Review, not live. Review adds 1–3 days outside our control; expect live ~Sep 7–9.

### 🚨 Do this tonight — it is the only true blocker

**RC-01 is the whole schedule.** Everything else is work we control; this one is Apple's queue.

> Squirl 1.0 shipped **free**, so the **Paid Applications Agreement is almost certainly unsigned** — there is no trace of it in `docs/app-store/`. Until it is active *and* banking + tax are complete, **the Subscriptions section does not even appear in App Store Connect.** Propagation can take up to 24h after submitting the forms, and tax forms can bounce.
>
> **Check it now:** ASC → Business (Agreements, Tax, and Banking). If it is not "Active", do it tonight. If it is already active, Friday is comfortable.

### Day plan

| Day | Date | Theme | Tickets |
|---|---|---|---|
| 0 | Sun 30 Aug | Unblock | RC-01 |
| 1 | Mon 31 Aug | Accounts, keys, products, privacy | RC-02 … RC-09 |
| 2 | Tue 1 Sep | Mockup + service layer | RC-10 … RC-14 |
| 3 | Wed 2 Sep | Gating + paywall | RC-15 … RC-20 |
| 4 | Thu 3 Sep | Testing | RC-21 … RC-25 |
| 5 | Fri 4 Sep | QA + submit | RC-26 … RC-29 |

### Tickets

Estimates are focused hours. **Owner** = you (account/paperwork/QA); **Claude** = implementation.

| ID | Summary | Type | Est | Owner | Depends | Acceptance criteria |
|---|---|---|---|---|---|---|
| **RC-01** | Activate Paid Applications Agreement + banking + tax | Task | 1h | Owner | — | ASC → Business shows **Active**; Subscriptions section visible in the app |
| **RC-02** | Enrol in Small Business Program | Task | 15m | Owner | RC-01 | Commission 30% → **15%** confirmed |
| **RC-03** | Create RevenueCat project + iOS app; capture public SDK key | Task | 20m | Owner | — | Key starts `appl_`; stored where the app can read it per build config |
| **RC-04** | Generate + upload **In-App Purchase Key** (`.p8`) | Task | 30m | Owner | RC-03 | RevenueCat shows **green "Valid credentials"**. *Without this, customers are charged and never get access* |
| **RC-05** | Verify Restore Behavior = "Transfer to new App User ID" | Task | 5m | Owner | RC-03 | Setting confirmed; required for anonymous-only projects |
| **RC-06** | Create ASC subscription group + monthly & annual products | Task | 1h | Owner | RC-01 | Product IDs final (**permanent**); 7-day intro offer; localised name + description; review screenshot uploaded; state = Ready to Submit |
| **RC-07** | Import products → RevenueCat; create `pro` entitlement + `default` offering | Task | 30m | Owner | RC-04, RC-06 | `offerings.current` returns 2 packages |
| **RC-08** | Privacy: policy revision live-ready, `PrivacyInfo.xcprivacy`, ASC label draft | Task | 1h | Claude | — | Manifest declares PurchaseHistory (not linked, not tracking, AppFunctionality + Analytics); label matches manifest exactly; policy staged but **not deployed until submission** |
| **RC-09** | Email `shipaton@revenuecat.com` re TestFlight vs public release | Task | 10m | Owner | — | Written confirmation that `v0.8.0` TestFlight doesn't count as prior public release |
| **RC-10** | Paywall HTML mockup → owner approval | Design | 2h | Claude | — | Paper & Pollen; all 3.1.1 furniture present; approved before any SwiftUI |
| **RC-11** | Add SPM dependency + In-App Purchase capability | Task | 20m | Claude | RC-03 | `purchases-ios-spm` @ 5.87.1, Up to Next Major; builds clean |
| **RC-12** | Hardened `Purchases.configure` + **prewarming guard** | Story | 2h | Claude | RC-11 | Configure in `App.init` only; `automaticDeviceIdentifierCollectionEnabled: false`, `showStoreMessagesAutomatically: false`, `networkTimeout: 15`; file-protection probe defers configure and retries on `protectedDataDidBecomeAvailable`; every call site guarded by `isConfigured` |
| **RC-13** | `PurchaseService` protocol + `EntitlementState` tri-state | Story | 1h | Claude | — | Protocol returns **our own** types, never `CustomerInfo` (`EntitlementInfo` has no public init → untestable otherwise) |
| **RC-14** | `RevenueCatPurchaseService` + wire into `AppDependencies`/`AppServices` | Story | 3h | Claude | RC-12, RC-13 | Driven by `customerInfoStream`; `@Observable @MainActor`; injected via `@Environment`; no view touches `Purchases.shared` |
| **RC-15** | **Grandfather flag** `installedBeforePaidRelease` | Story | 1h | Claude | — | Written on first launch of 1.1 for existing installs. **Cannot be backfilled — must ship in this build** |
| **RC-16** | **App-level gate + fail-open path** | Story | 3h | Claude | RC-14, RC-15 | Single gate at root, not scattered `if isPro`. `unknown` **unlocks** (mockup screen C) and never paywalls. Grandfathered users bypass entirely. **Highest-risk ticket in the epic — a wrong answer denies someone their own journal** |
| **RC-17** | Paywall placement in onboarding + trial-ended state | Story | 2h | Claude | RC-16 | Paywall after Welcome, **before** the ~500 MB model download. Trial-ended screen offers **export without subscribing** |
| **RC-18** | Custom SwiftUI paywall (4 screens: paywall · trial-ended · fail-open · settings) | Story | 6h | Claude | RC-10, RC-14 | Reads `offerings.current`; price/period/trial shown; no toggle paywall; calls `trackCustomPaywallImpression()`; survives Dynamic Type AX5 |
| **RC-19** | Settings: Restore Purchases + Manage Subscription rows | Story | 1h | Claude | RC-14 | Restore present on paywall **and** Settings; distinct restoring/restored/nothing-found states |
| **RC-20** | Bundle EULA + privacy text as **native offline** views | Story | 1h | Claude | RC-08 | Readable with no network; web link secondary. Guards a 3.1.2 rejection when a reviewer is on bad wifi |
| **RC-21** | Unit tests via fakes; never configure SDK in tests | Story | 3h | Claude | RC-13 | Suite stays green offline via `xcodebuild`; no test imports RevenueCat |
| **RC-22** | Wire `PurchasesDiagnostics.checkSDKHealth()` (DEBUG) | Task | 30m | Claude | RC-12 | Health report logged on launch in DEBUG |
| **RC-23** | Local StoreKit config testing | Task | 1h | Claude | RC-18 | Purchase + restore work in simulator from Xcode |
| **RC-24** | **Sandbox end-to-end** | Task | 3h | Owner | RC-07, RC-18 | Purchase · restore · reinstall-then-restore · **offline launch while subscribed** · cancel → expiry · monthly→annual |
| **RC-25** | Accessibility pass on paywall | Task | 1h | Claude | RC-18 | AX5 no truncation; VoiceOver reads each plan as one element; ≥44×44pt; no colour-only cues |
| **RC-26** | Refresh ASC screenshots + description | Task | 1h | Owner | RC-18 | No screenshot or copy advertises a now-paid feature (**Guideline 2.3.1** — the real paywalling risk) |
| **RC-27** | `/code-review` on the diff | Task | 1h | Claude | RC-25 | Findings addressed or consciously waived |
| **RC-28** | **Owner device QA** | Task | 2h | Owner | RC-27 | Non-negotiable per `CLAUDE.md` — never merge on code review alone |
| **RC-29** | Deploy privacy policy · set nutrition label · archive · **submit with IAP attached** | Task | 2h | Owner | RC-28 | Subscription + subscription group + build in **one** submission (first IAP must ride with a binary) |

### Explicitly cut to fit 5 days

Not doing, and why: multiple tiers · Experiments/Targeting/A-B tests (**named nowhere in the Shipaton rules**) · Customer Center · win-back offers · promo codes (the 7-day trial already satisfies judge access) · RevenueCatUI paywall (leaks 58 MB → 1 GB+, [#6018](https://github.com/RevenueCat/purchases-ios/issues/6018)).

### Risks specific to the compressed timeline

| Risk | Mitigation |
|---|---|
| **RC-01 not active** → no Subscriptions section at all | Check tonight. If it slips past Tuesday, Friday moves to Monday 8 Sep and we still clear Sep 16 |
| Product IDs are permanent | Settle naming in RC-06 before creating anything |
| New products take **up to 24h** to propagate | RC-06 lands Monday, so they are live well before Thursday's sandbox testing |
| Sandbox testing (RC-24) finds a blocker on Thursday | Friday is buffer; slipping to Monday still clears the backstop by a week |
| Prewarming bug ships unmitigated | RC-12 is not optional — under a hard paywall it doesn't just lose a feature, it **locks a paying user out of their whole journal** after a reboot |
| **2.3.1 — store listing still advertises a free app** | RC-26 becomes load-bearing, not housekeeping: every screenshot and line of description must match a paid app before submission |

---

## Epic BIP — #BuildInPublic

$30k track, and the criteria state outright that **audience size does not matter** — judged on story, engagement and lessons learned. Cost is minutes per day.

| ID | Summary | Type | Est | Owner | Depends | Acceptance |
|---|---|---|---|---|---|---|
| **BIP-01** | Daily post, tagged **#Shipaton** | Task | 15m/day | Owner | — | Public post; link captured for the Devpost write-up |
| **BIP-02** | Collect post links + engagement | Task | 15m/wk | Claude | BIP-01 | Running list in [BACKLOG.md](BACKLOG.md) |
| **BIP-03** | Write the "how building in public helped" narrative | Story | 2h | Claude | BIP-01 | Required submission artifact, drafted by Sep 25 |

Angles worth posting that are already true: shipping a paywall that refuses dark patterns; the prewarming bug that strands anonymous paying users; correcting my own eligibility misread; an on-device LLM in a privacy-first journal.

---

## Epic UI — UI Refresh (spec 057)

🔨 **Active since 2026-09-28.** Source of truth: the Pencil file `untitled.pen` → `DESIGN.md` (rewritten 2026-09-28); plan of record: [UI_REFRESH_PLAN.md](UI_REFRESH_PLAN.md) — the owner accepted every recommendation (D1–D26) on 2026-09-28 and asked for implementation ASAP. Branch `feat/057-ui-refresh`. **Two waves:** 1.2 ≈ Fri Nov 13 (foundations + chrome + check-in trio + Calendar), 1.3 ≈ Fri Dec 18 (Day Details + Edit + Insights + Settings); both after 055 / 1.1. The Shipaton release train no longer applies to this epic.

Execution deviations from the plan, logged in DEVLOG 2026-09-28: #44/#45 are not absorbed into the branch (merge denied by the permission policy — owner merges them; the refresh re-implements their hunks); 055 is merged into the branch only before the Settings step; per-screen HTML mockups are replaced by SwiftUI previews + simulator screenshots (owner unavailable to review); Spec Kit 057 is hand-written, 058–062 folded into it.

| ID | Summary | Type | Est | Owner | Depends | Acceptance |
|---|---|---|---|---|---|---|
| UI-01 | DESIGN.md v2 (pen-derived) + CLAUDE.md/PRODUCT.md reconciled + pen exports committed | Design | 6 | Claude | D1–D5, D8, D9, D14 | docs PR to `main` before #44; all 79 references + `test -e` paths resolve; posture/paywall sections carried; decisions log seeded |
| UI-02 | Decisions D1–D26 answered and logged | Task | 2 | Owner | — | no ★ item open |
| UI-03 | Plan → Epic UI table, BACKLOG 🧊 rows, DEVLOG | Task | 1.5 | Claude | UI-02 | docs PR to `main`; IDs stable; WORKLOG regenerated |
| UI-04 | Pre-flight: docs on main → #44 → #45 → #41 resolved → 055 merge + 1.1 (RC ETA) → 053/054 archived → ritual → worktrees removed, 057 re-cut | Task | 5 | Owner + Claude | UI-03; RC epic | `main..feat/057` empty; 053 stash entry gone, 15 others intact; Release build green; skills + constitution 3.1.0 present |
| UI-05 | Spec Kit 057 foundations | Task | 4 | Claude | UI-04 (6) | Constitution Check I–XI vs branch version (3.1.0); tasks map to UI-06…19; 055 view files enumerated |
| UI-05b | Design-system HTML mockup (Constitution I for Phase B atoms) | Design | 4 | Claude + Owner | UI-02, UI-01 | every §3.2 atom in all states, light/dark, 1×/AX5, 402/375; owner approval logged |
| UI-06 | Colour tokens + dark pairs + aliases + AA tests (PR B1 = full-app visual change) | Task | 8 | Claude | UI-05, UI-05b | `TokenContrastTests` green; full-app device QA light/dark with before/after pack; `Palette.medication` = violet-500 |
| UI-07 | Typography roles + alias map (old names kept until UI-49) | Task | 3 | Claude | UI-06 | zero call-site edits; 0-site roles gone; no silent re-weight; AX5 preview clean |
| UI-08 | Layout tokens + card modifiers + heading atoms (0-consumer deletions only) | Task | 5 | Claude | UI-07 | five card variants preview light/dark; consumed symbols aliased, not deleted |
| UI-09 | Button styles (Frame 3) replace three old styles + `PaywallButtonStyle` | Task | 5 | Claude | UI-08 | all call sites migrated; pressed/disabled states |
| UI-10 | BillChip + ChipRow (display 6/6; interactive ≥ 44 pt pitch, D-K6) | Task | 3 | Claude | UI-08 | four variants; wrap at AX5; no overlapping hit areas |
| UI-11 | NavPill, ToggleRow, RadioRow, SegmentedPicker, InfoRow | Task | 6 | Claude | UI-08 | a11y traits verified |
| UI-12 | Mood/energy/focus glyph redraw + identity icons | Task | 8 | Claude | UI-06, D3 | grayscale-distinct levels; `SignalGlyphTests` green |
| UI-13 | Sleep moon + `SleepLevel` ramp/label (`sleepIndigo` aliased) | Task | 3 | Claude | UI-12 | tests first; bed icon deleted; alias compiles |
| UI-14 | Medication glyphs + ProgressTrack + SignalMiniBar | Task | 3 | Claude | UI-12 | previews 0–100 % |
| UI-15 | `CheckInRing` + Welcome migration (`CrescentRing` kept until UI-21) | Task | 5 | Claude | UI-06, D5 | 375 pt fits; one remaining `CrescentRing` consumer recorded |
| UI-16 | `LevelTilePicker` | Task | 3 | Claude | UI-13 | narrow-device rule; "Mood: Good, 4 of 5, selected" |
| UI-17 | SF Symbol icon map (PR B2) | Task | 1 | Claude | UI-06 | `Icons.swift` table + preview strip; no literal `systemImage:` in views |
| UI-18 | FloatingTabBar + AddButton + root wiring (`ChromeVisibilityKey`; FAB hidden on hub) | Story | 12 | Claude | UI-11, UI-17, D4, D5 | VoiceOver "tab, 1 of 4" verified or fallback; deep link → B; chrome hides on Edit/B/C; no FAB on Check In |
| UI-19 | Design gallery (`SandboxApp/Sources/DesignGallery.swift`) + snapshot pack attached to PRs | Task | 3 | Claude | UI-18 | SandboxApp builds; pack attached to B4 PR |
| UI-20 | Spec Kit 058 check-in trio | Task | 3 | Claude | UI-19 | spec/plan/tasks committed; every step has ≥ 1 task |
| UI-21 | Check-in A idle hub (+ `CrescentRing`/`crescentDiameter` deleted) | Story | 15 | Claude | UI-20 | mockup approved; 32 VM tests green; FR-017/018 retired on record; no FAB on hub |
| UI-22 | Check-in B listening (motion per D-R2) | Story | 19 | Claude | UI-21, UI-34 | prompt copy tests green; timer stable |
| UI-23 | Check-in C saved | Story | 10 | Claude | UI-22 | SE-height AX5 OK; announcement matches copy |
| UI-24 | Spec Kit 059 Calendar (incl. expanded previous-day card, Q25b) | Task | 3 | Claude | UI-23 | spec/plan/tasks committed |
| UI-25 | Calendar / Mood Journal (private `Chip`/`DoseTrack` deleted first) | Story | 30 | Claude | UI-24, UI-35, UI-36, UI-37 | month-scoped previous days; `displayLabel`s spoken |
| UI-26 | Spec Kit 060 Day Details + Edit | Task | 4 | Claude | UI-25 | spec/plan/tasks committed |
| UI-27 | Day Details (#45 regenerate hunk deleted here) | Story | 35 | Claude | UI-26, UI-38, UI-54 | six card states; no AI byline on fallback transcript; tests re-baselined post-#45 |
| UI-28 | Edit Check-In (private `ChipGroup` deleted first) | Story | 27 | Claude | UI-27, UI-39 | 12 VM tests green; provenance intact; tile contract string |
| UI-29 | Spec Kit 061 Insights | Task | 3 | Claude | UI-28, D12, UI-40 | spec/plan/tasks committed |
| UI-30 | Insights (private `ConnectionCard`/`GatedCard`/`MiniBar` deleted first) | Story | 29.5 | Claude | UI-29, UI-40, UI-41 | tests re-baselined post-#45; `RhythmTile` view, `RhythmCell` model untouched |
| UI-31 | Spec Kit 062 Settings + wave-2 secondary surfaces | Task | 3 | Claude | UI-30, UI-04 (#41) | spec/plan/tasks committed; every `ModelDownloadRow` state mocked |
| UI-32 | Settings (`ModelDownloadRow` restyled, state machine untouched; `SettingsChip` deleted first) | Story | 39.5 | Claude | UI-31, UI-42 | eight must-keep rows present; model-row tests untouched |
| UI-33a | Secondary surfaces, wave 1 (Log Dose, composer, onboarding restyle) | Story | 8 | Claude | UI-20/24, UI-09–16 | onboarding chain runs; 44 pt close buttons; `GlyphRampPicker` gone |
| UI-33b | Secondary surfaces, wave 2 (recovery key, 055 paywall surfaces, Acknowledgements restyle) | Story | 8 | Claude | UI-31 | paywall surfaces AX5 clean; export works unsubscribed |
| UI-34 | `CheckInViewModel.flowProgress` (test-first) | Task | 1 (in UI-22) | Claude | UI-20 | RED → GREEN before UI-22 |
| UI-35 | `DoseStatus` hoist + status semantics (D10) | Task | 2 (in UI-25) | Claude | UI-24 | threshold + boundary tests green |
| UI-36 | `DayCardSummary` dose + `sleepLevel` | Task | 1.5 (in UI-25) | Claude | UI-13 | two `@Test`s green |
| UI-37 | `displayLabel` in `TimelineRow` + AX | Task | 0 (PR #45) | — | UI-04 | merged with #45 |
| UI-38 | `RecordingDetailViewModel.relativeTitle/subtitle` | Task | 0.5 (in UI-27) | Claude | UI-26 | `relativeTitleByDay` green |
| UI-39 | `ExtractionReviewViewModel.isDirty`, `medicationRows`, `cancelIfUnsaved()` (D21) | Task | 5.5 (in UI-28) | Claude | UI-26 | 3 new + 3 rewritten tests green |
| UI-40 | Sleep × Mood gate on `decodedSleepLevel` — own PR `fix/insights-sleep-mood-gate`, 1.1.x-shippable | Task | 1.5 | Claude | UI-04 | RED with canonical values → GREEN; copy unchanged; mergeable before Phase B |
| UI-41 | Bubble diameter · rhythm tint · range-bar span fns · caption case | Task | 3 (in UI-30) | Claude | UI-29 | three test files green |
| UI-42 | `medicationBarShowTakenTime` / `ShowEndTime` keys + `titleLine` | Task | 3 (in UI-32) | Claude | UI-31 | `titleLineVariants` green |
| UI-43 | Summary correction persistence (deferred, outside waves 1–2) | Story | 6 | Claude | owner | — |
| UI-44 | Dead-code sweep (refresh-orphaned code only; `Constants.swift` never) | Task | 3 | Claude | UI-32 | grep proofs; `WhisperKitTranscriptionService:134` still reads `medicalPromptEnabled` |
| UI-45 | Dark-mode pass (wave-2 screens) | Task | 6 | Claude + Owner | UI-33b | screenshot pack |
| UI-46 | Dynamic Type / AX pass (wave-2 screens) | Task | 6 | Claude | UI-45 | 3 × 3 matrix clean |
| UI-47 | VoiceOver + Reduce Motion pass (wave-2 screens) | Task | 4 | Claude + Owner | UI-46 | per-screen scripts |
| UI-48 | Copy normalisation sweep (pen-screen strings only) | Task | 3 | Claude | UI-32 | old strings gone |
| UI-49 | Token + typography alias deletion; Complexity row closed | Task | 6 | Claude | UI-48 | no `NewLook`/`Theme`/old `Typography` symbols |
| UI-50 | PR gate (recurring, ~25 PRs; risk #11 workaround) | Task | 37.5 | Owner + Claude | — | build · serial tests · review · device QA |
| UI-51 | Release 1.2 (wave 1) | Task | 9 | Owner + Claude | UI-25, UI-33a, UI-53 | 2.3.3 screenshots refreshed; `v1.2.0`; `docs/BACKLOG.md` rows shipped |
| UI-52 | Release 1.3 (wave 2) | Task | 9 | Owner + Claude | UI-49 | `v1.3.0` by Dec 18 |
| UI-53 | Wave-1 dark / AX / VoiceOver mini-pass (A/B/C + Calendar + Log Dose/composer) | Task | 6 | Claude + Owner | UI-25, UI-33a | light/dark pack + VoiceOver scripts for the four screens |
| UI-54 | Single `formattedDuration` — own PR `fix/duration-format` | Task | 0.5 | Claude | UI-04 | `durationFormatIsSingle` green; mergeable before Phase B |

---

## Epic LLM — LLM Pipeline *(placeholder)*

📋 **Not scoped.** Current: `mlx-community/Qwen2.5-1.5B-Instruct-4bit` via MLX, two-pass (summary → strict-JSON signals).

| ID | Summary | Type | Est | Owner | Depends | Acceptance |
|---|---|---|---|---|---|---|
| LLM-01 | *TBD — scope after Sep 4* | — | — | — | RC epic | **Last safe submission ~Sep 23** to be live by Sep 30 |

---

## JIRA export

The ticket tables above are already in import shape. Column mapping for JIRA's CSV importer:

| This file | JIRA field |
|---|---|
| ID | Issue key *(or Summary prefix if the project uses its own keys)* |
| Summary | Summary |
| Type | Issue Type (Story / Task / Design) |
| Est | Original Estimate |
| Owner | Assignee |
| Depends | Linked issue → *blocks / is blocked by* |
| Acceptance criteria | Description |
| Epic (RC/BIP/UI/LLM) | Epic Link / Parent |

Epics map to: **RC** → "RevenueCat Monetization", **BIP** → "Build in Public", **UI** → "UI Refresh", **LLM** → "LLM Pipeline".

*Not yet generated — ask for `september-plan.csv` when the board exists and the project key is known.*

---

## October 1 — exit ritual

Written here so it isn't improvised. Run it on **2026-10-01**:

1. Merge `✅ Shipped` rows from [BACKLOG.md](BACKLOG.md) into `docs/BACKLOG.md`; move `🧊 Deferred to October` rows into its Next-up / Ideas sections.
2. Append one summary `Direction` entry to `docs/DEVLOG.md` linking this sprint log.
3. Remove the freeze banners from both `docs/` files; delete the "September 2026 — Shipaton sprint" section from `CLAUDE.md`; revert the constitution amendment (2.2.0 → 2.3.0 with rationale).
4. Keep `shipaton_plan/` as a frozen archive — do not delete it.

Until then: **`docs/BACKLOG.md` and `docs/DEVLOG.md` are read-only.**

---

## Next actions

1. **Tonight** — check ASC → Business. Is the Paid Applications Agreement Active? Everything hangs on the answer.
2. **Tonight** — decide the product ID scheme and the two prices (RC-06 needs them Monday, and IDs are permanent).
3. **Monday AM** — RC-02 → RC-09 in order; RC-04's green credential state is the gate before any testing.
4. **Monday** — first #BuildInPublic post.
5. Say the word and I start RC-08 and RC-10 now — neither depends on any account state.
