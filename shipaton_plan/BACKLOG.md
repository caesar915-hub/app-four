<!-- Created: 2026-08-31 01:18 (WEST) · Updated: 2026-09-13 21:29 (WEST) -->
# Shipaton Sprint Backlog — September 2026

**The board for 2026-09-01 → 2026-09-30.** `docs/BACKLOG.md` is frozen for the sprint — read it for history, never edit it.

This holds **state** (where each ticket stands). The plan lives in [SEPTEMBER_PLAN.md](SEPTEMBER_PLAN.md); the *why* lives in [DEVLOG.md](DEVLOG.md). Ticket IDs match SEPTEMBER_PLAN and are stable once assigned — never renumber.

**Stages:** 💡 Idea → 📐 Planned → 🔨 In code → ✅ Shipped · 🧊 Deferred to October

---

## Changelog

Newest first. **Keep to 15 rows** — older rows drop off; the devlog holds the narrative. Never let this become a paragraph.

| When | What changed |
|---|---|
| 2026-09-13 21:29 | **Spec 056** Gemma 4 E2B/LiteRT-LM extraction → 🔨 In code (additive/inert, 584 tests green) on `feat/gemma4-litert-extraction`; switchover **device-gated** (A14 QA). Constitution 2.4.0 (pending ratification). LLM stream. |
| 2026-08-31 01:39 | Sprint tooling landed (`/morning`, `/evening`, constitution 2.2.0). **No ticket stages moved** — RC-08 + RC-10 still 🔨 In code, uncommitted |
| 2026-08-31 01:18 | Board created. RC-08 + RC-10 → 🔨 In code; RC-01 → ⏭️ Today (blocking, owner) |

---

## ⏭️ Today

| ID | Item | Owner | Why now |
|---|---|---|---|
| **RC-01** | Activate Paid Applications Agreement + banking + tax | Owner | **Blocks the entire epic.** Until it is Active, App Store Connect shows no Subscriptions section at all. Up to 24h to propagate. Owner is checking ASC → Business. |
| **RC-10** | Paywall mockup — owner approval | Owner | Gates RC-18. Mockup built ([055-paywall.html](../html-mockups/055-paywall.html), 4 screens); needs a look before any SwiftUI. |
| — | Decide product ID scheme + the two prices | Owner | RC-06 needs both Monday. **Product IDs are permanent.** |

## 🔨 In code

| ID | Item | Branch | Notes |
|---|---|---|---|
| **RC-08** | Privacy manifest + policy revision | `main` (uncommitted) | `PrivacyInfo.xcprivacy` declares `PurchaseHistory`, not linked, not tracking, AppFunctionality + Analytics. Lint-clean; verified present inside the built `.app`. Policy rewritten and **staged — do not deploy until the paid build ships**. |
| **RC-10** | Paywall mockup (4 screens) | `main` (uncommitted) | Hard paywall · trial-ended · fail-open · settings. Built on **New Look** tokens (spec 033), dark + Dynamic Type AX3/AX5 toggles. Awaiting owner approval. |

## 📐 Planned

Full ticket detail, estimates and acceptance criteria live in [SEPTEMBER_PLAN.md](SEPTEMBER_PLAN.md). This is the stage view only.

| ID | Item | Blocked by |
|---|---|---|
| RC-02 | Small Business Program enrolment (30% → 15%) | RC-01 |
| RC-03 | RevenueCat project + app + public SDK key | — |
| RC-04 | **In-App Purchase Key (`.p8`)** — mandatory for StoreKit 2 | RC-03 |
| RC-05 | Verify Restore Behavior = "Transfer to new App User ID" | RC-03 |
| RC-06 | ASC subscription group + monthly & annual products | RC-01 |
| RC-07 | Import products → `pro` entitlement + `default` offering | RC-04, RC-06 |
| RC-09 | Email `shipaton@revenuecat.com` re TestFlight vs public release | — |
| RC-11 | SPM dependency + In-App Purchase capability | RC-03 |
| RC-12 | Hardened `configure` + **prewarming guard** (#4623) | RC-11 |
| RC-13 | `PurchaseService` protocol + `EntitlementState` tri-state | — |
| RC-14 | `RevenueCatPurchaseService` + DI wiring | RC-12, RC-13 |
| RC-15 | **Grandfather flag** — must ship in the paid build | — |
| RC-16 | **App-level gate + fail-open path** — highest-risk ticket | RC-14, RC-15 |
| RC-17 | Paywall placement in onboarding + trial-ended state | RC-16 |
| RC-18 | Custom SwiftUI paywall (4 screens) | RC-10, RC-14 |
| RC-19 | Settings: Restore Purchases + Manage Subscription | RC-14 |
| RC-20 | Bundle EULA + privacy as native **offline** views | RC-08 |
| RC-21 | Unit tests via fakes; never configure the SDK in tests | RC-13 |
| RC-22 | Wire `PurchasesDiagnostics.checkSDKHealth()` (DEBUG) | RC-12 |
| RC-23 | Local StoreKit config testing | RC-18 |
| RC-24 | **Sandbox end-to-end** incl. offline-while-subscribed | RC-07, RC-18 |
| RC-25 | Accessibility pass on the paywall (AX5, VoiceOver, 44pt) | RC-18 |
| RC-26 | **Refresh ASC screenshots + description** (Guideline 2.3.1) | RC-18 |
| RC-27 | `/code-review` on the diff | RC-25 |
| RC-28 | **Owner device QA** — non-negotiable | RC-27 |
| RC-29 | Deploy policy · set label · archive · **submit with IAP attached** | RC-28 |
| BIP-01 | Daily #Shipaton post | — |
| BIP-02 | Collect post links + engagement | BIP-01 |
| BIP-03 | "How building in public helped" write-up | BIP-01 |
| UI-01 | *TBD — scope after Sep 4* | RC epic |
| LLM-01 | *TBD — scope after Sep 4* | RC epic |

## 💡 Ideas

| Item | Notes |
|---|---|
| JIRA/Linear CSV export | Column mapping defined in SEPTEMBER_PLAN §JIRA export. Needs a board and project key. Blocked on normalised epic tables (done) + owner supplying the key. |
| Peace Prize submission | ADHD mental-health angle is a genuine fit. Costs one write-up, no code. |

## ✅ Shipped

*Nothing yet — the sprint opens 2026-09-01.*

## 🧊 Deferred to October

| Item | Why deferred |
|---|---|
| Spec 053 — insights shape views | Parked in `stash@{0}`. 1.1 ships from `main`; 053 does not gate it (owner decision 2026-08-30). |
| Spec 054 — settings topic hub | Parked in `stash@{0}` alongside 053. |
| Multiple subscription tiers | Cut to fit the 5-day RevenueCat window. |
| Experiments / Targeting / A-B tests | Named nowhere in the Shipaton rules — no category rewards them. |
| Customer Center · win-back offers · promo codes | The 7-day trial already satisfies the judge-access requirement. |
