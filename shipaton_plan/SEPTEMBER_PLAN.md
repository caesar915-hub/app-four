<!-- Created: 2026-08-30 23:19 (WEST) · Updated: 2026-08-31 01:39 (WEST) -->
# September 2026 — Delivery Plan

Rolling plan for September. Structured as **epics → tickets** so it exports to JIRA (or Linear) without rewriting. Ticket IDs are stable once assigned — never renumber.

| Epic | Scope | Window | Status |
|---|---|---|---|
| **[RC](#epic-rc--revenuecat-monetization)** | RevenueCat monetization → Shipaton 2026 entry | Aug 31 – Sep 4 | 🔨 Active |
| **[BIP](#epic-bip--build-in-public)** | #BuildInPublic posting track | Aug 31 – Sep 30 | 🔨 Active |
| **[UI](#epic-ui--ui-refresh-placeholder)** | UI refresh | TBD | 📋 Not scoped |
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

## Epic UI — UI Refresh *(placeholder)*

📋 **Not scoped.** To be filled after RC ships. Seeds: 053 insights shape views (parked in `stash@{0}`), 054 settings topic hub.

| ID | Summary | Type | Est | Owner | Depends | Acceptance |
|---|---|---|---|---|---|---|
| UI-01 | *TBD — scope after Sep 4* | — | — | — | RC epic | Must submit by ~Sep 15 to be live in week 3 |

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
