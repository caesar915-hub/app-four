<!-- Created: 2026-08-30 23:04 (WEST) · Updated: 2026-08-31 00:05 (WEST) -->
# Shipaton 2026 — RevenueCat on Squirl · Draft Plan v1

> ⚠️ **Superseded on scope (2026-08-30): the owner chose a HARD PAYWALL + 7-day trial**, not the feature gate described in §4. The live plan is [SEPTEMBER_PLAN.md](../../shipaton_plan/SEPTEMBER_PLAN.md). Everything outside §4 (setup, hardening, testing, risks) still stands.
>
> **Draft v1.1 for review.** Research-backed, not yet a Spec Kit spec. Decisions in §8 are unanswered.
> v1.1 folds in the failure-mode research: the prewarming bug (§6.6), the corrected offline-grace behaviour (§6.3), and a re-ranked risk table (§7).

---

## 1. Verdict: eligible, and the clock is the enemy

**Squirl qualifies.** Submission Period opened **Jul 31 2026**; Squirl's first public release was **Aug 4 2026** — inside the window. The rule tests *public release*, not submission date, and Squirl was not public on any store before Jul 31. Adding RevenueCat as v1.1 is fine: the "no updates" clause excludes apps already public *before* the window.

> "The first public version of the Project must be released during the Submission Period… it must not have been publicly released on any eligible store **before** the Submission Period. Updates to previously released apps are not eligible." — [Official Rules](https://revenuecat-shipaton-2026.devpost.com/rules)

**One cheap insurance action:** email `shipaton@revenuecat.com` confirming that the TestFlight channel (`v0.8.0`, 18 Jun) does not count as a public store release. It shouldn't — the rules name only App Store / Play / Galaxy — but confirm it in writing now, not in October.

### The real deadline is not Sep 30

| Milestone | Date | Days from Aug 30 |
|---|---|---|
| Devpost submission closes | Sep 30, 11:45pm PDT | 31 |
| **Live on the App Store by** | ~Sep 23 | 24 |
| **Submitted to App Review by** | ~**Sep 16** | **17** |
| Judging | Oct 1 – Oct 13 | — |
| Winners | Oct 21 | — |

App Review is the bottleneck, and this submission carries **two elevated-risk changes at once**: a first-ever in-app purchase, and a privacy nutrition label flipping from "Data Not Collected." Budget for **two rejection cycles**.

---

## 2. Hard requirements to qualify

All verified from the Official Rules:

- ✅ Fully published to the App Store by the deadline (TestFlight does not count).
- ✅ **RevenueCat SDK powering at least one real in-app purchase.**
- ✅ **A free trial OR a promo code for judges** that unlocks all premium features.
- ✅ Accessible from the United States; free for judges to evaluate.
- ✅ Devpost artifacts: description · demo video **under 2 minutes** on YouTube/Vimeo · store URL · 1024×1024 icon · ≥1 screenshot at **1179×2556, no device frame**.

**Not required by any rule:** Paywalls v2, Experiments, Targeting, Customer Center, Web Billing, Virtual Currency. No category names them. Don't build them for points that don't exist.

---

## 3. Which prizes to actually target

| Track | Prize | Fit | Verdict |
|---|---|---|---|
| **RevenueCat Design Award** | $15k / 10k / 5k | Judges "craft… aesthetics, animations, gesture interactions," explicitly *separate from business viability*. Paper & Pollen, the design-database, and the Figma catalog are years of work already banked. | **Primary target.** |
| **#BuildInPublic** | $30k / 20k / 10k | Criteria state outright that **audience size does not matter** — judged on story, engagement, lessons learned. Highest prize-per-effort in the whole contest. | **Secondary — start posting today.** |
| **Peace Prize** | $15k / 10k / 5k | Social good. A non-judgmental ADHD medication/mood journal is a genuine, defensible fit. | **Tertiary — costs one write-up.** |
| HAMM (monetization) | $15k | Rewards conversion numbers we won't have in 3 weeks. | Skip. |
| Grand Prize | $100k | Shortlisted on **actual RevenueCat-reported revenue**. Not winnable from a standing start. | Skip. |

**#BuildInPublic starts now, not at the end.** The engagement window closes Sep 30; starting Aug 31 yields 30 days of posts. The 2025 winner's advice was daily posting, vulnerability over polish, visible improvement over time. Posts must be tagged **#Shipaton**.

---

## 4. Scope — the smallest thing that qualifies and still wins

**One entitlement: `pro`.** Never branch on a product ID.

~~**Gate depth, never capture.**~~ **Superseded — hard paywall.** Retained below for the record of what was weighed:

| Free forever | Paid (`pro`) |
|---|---|
| Recording a check-in | **Insights tab** (all cards) |
| Transcription + LLM extraction | **Journal export** |
| Editing/correcting extraction | *(candidate)* history beyond N months |
| Viewing your own entries | |
| Medication logging + dose bar | |

Gating capture would contradict the product's stated constitution and bleed exactly the users it exists for. Research is blunt about the cost: hard paywalls convert ~5× better than freemium (10.7% vs 2.1% median day-35 trial-to-paid). **We take that hit deliberately.**

**Products:** one Subscription Group, monthly + annual, **7-day free trial**. The trial satisfies the judge-access requirement *and* is the honest UX choice, so no promo code is needed.

**Grandfathering:** existing 1.0 users keep what they have. The `installedBeforePaidRelease` flag **must ship in the paid build** — it cannot be backfilled, and every day it isn't written is a day of new installs that can't be distinguished later.

---

## 5. Critical path

Parallel track from day one: **#BuildInPublic posts, daily.**

| Days | Work | Blocks |
|---|---|---|
| **Aug 31 – Sep 1** | Paid Apps Agreement, banking, tax in ASC. Small Business Program (30%→15%). RevenueCat project + app + **In-App Purchase Key**. Email Shipaton re: TestFlight. | Everything. Has latency — start first. |
| **Sep 1 – 2** | Privacy policy live-ready, `PrivacyInfo.xcprivacy` updated, nutrition label drafted in ASC. ASC products created (IDs are permanent). | App Review |
| **Sep 2 – 4** | Paywall HTML mockup → owner approval (`CLAUDE.md` mockup-before-SwiftUI rule). | Paywall code |
| **Sep 4 – 9** | Implementation: `PurchaseService` seam, `EntitlementStore`, gating, custom SwiftUI paywall, Settings rows. | Testing |
| **Sep 9 – 12** | Test Store → StoreKit config → **sandbox** → TestFlight. Full matrix incl. offline-while-subscribed. | Submission |
| **Sep 12 – 14** | Buffer · `/code-review` · **owner device QA** (non-negotiable per `CLAUDE.md`). | |
| **Sep 15 – 16** | **Submit to App Review** with the subscription attached to the same draft. | |
| Sep 16 – 23 | Review, fix, release. Two rejection cycles budgeted. | |
| Sep 23 – 30 | Demo video (<2 min), Devpost write-ups, screenshots, submit. | |

---

## 6. Implementation

### 6.1 Setup — the mandatory bit almost everyone misses

**The In-App Purchase Key (`.p8`) is required, not optional.** RevenueCat's own docs:

> "When using Purchases v5.x+ (i.e., StoreKit 2), transactions will **fail to be recorded without this key being set**. This can result in users not accessing the purchases they are entitled to."

Apple still charges the customer; RevenueCat silently fails to validate. **A paid-but-locked-out user is the worst failure mode we can ship.** Generate at ASC → Users and Access → Integrations → In-App Purchase; upload the `.p8` + Issuer ID; confirm the green "Valid credentials" state **before any sandbox testing**.

**Do NOT configure the App-Specific Shared Secret** — it is StoreKit 1 only and deprecated for our path. *(This corrects `REVENUECAT_INTEGRATION.md` §6.2, written before this was verified.)*

**Verify Restore Behavior = "Transfer to new App User ID"** in RevenueCat project settings. It is the default, but confirm it: RevenueCat's docs mark it *"Required to allow customers to restore transactions after uninstalling / reinstalling your app"* for anonymous-only projects. Any other value silently strands reinstalling users, and with no accounts we have no other recovery path.

**Watch the 50-alias cap.** Anonymous IDs plus repeated reinstall+restore generate aliases; past 50 you get `Alias limit reached (7255)` and restore stops working entirely. Check the Customer page for alias growth during QA.

### 6.2 SDK

```
https://github.com/RevenueCat/purchases-ios-spm.git   — Up to Next Major, from 5.87.1
```
Products: `RevenueCat` (+ `RevenueCatUI` only if we fall back to a template paywall). Enable **In-App Purchase** capability in Signing & Capabilities.

```swift
// App.init() ONLY — never .task (it can re-run; a second configure() SILENTLY swaps the singleton)
#if DEBUG
Purchases.logLevel = .debug              // must precede configure()
#endif
Purchases.configure(
    with: Configuration.Builder(withAPIKey: Secrets.revenueCatPublicKey)
        .with(automaticDeviceIdentifierCollectionEnabled: false)  // defaults to TRUE
        .with(showStoreMessagesAutomatically: false)              // defaults to TRUE
        .with(networkTimeout: 15)                                 // defaults to URLSession's 60s
        .build()
)
```

Each of those three overrides matters:
- `automaticDeviceIdentifierCollectionEnabled` **defaults to `true`.** Turning it off is the correct posture for an app whose nutrition label says "not linked to identity", and costs nothing (it only fires when an attribution-network ID is set, which we never do).
- `showStoreMessagesAutomatically` **defaults to `true`**, so StoreKit's price-consent / billing-issue sheets pop over onboarding at launch. Turn it off and call `showStoreMessages()` at a moment we choose.
- Default network timeout is **60 seconds**. A RevenueCat outage would stall the app for a full minute.

**Anonymous mode is the absence of configuration** — never call `.with(appUserID:)`, and **never call `logOut()`**: it mints a new anonymous ID and orphans the old one's purchases. There is no legitimate `logIn`/`logOut` in an app with no accounts.

**Build-config the API key.** A Test Store key shipped to production **crashes the app** — RevenueCat flags this in red. Debug → Test Store, Release → platform key, selected by build config, never by hand.

### 6.2b The prewarming bug — verified open, and it targets exactly our architecture

**[purchases-ios #4623](https://github.com/RevenueCat/purchases-ios/issues/4623) is OPEN and unfixed.** I confirmed the status directly.

iOS prewarms apps before first unlock. At that point files are `completeFileProtectionUntilFirstUserAuthentication`, so `UserDefaults` is unreadable — and RevenueCat, reading its cached anonymous ID during `configure()`, finds nothing, **mints a brand-new `$RCAnonymousID:` and drops the entitlement cache.** The reporter's words: *"end users reporting losing access (they lost entitlements and got a new anonymous ID) after a reboot until they restored purchases."*

For an app with no accounts, Restore is the *only* recovery. **This is the single worst failure mode available to us**, and it is not hypothetical.

**Mitigation — probe before configuring:**

```swift
private func protectedDataAvailable() -> Bool {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("rc-probe")
    do {
        try Data().write(to: url, options: .completeFileProtectionUntilFirstUserAuthentication)
        try? FileManager.default.removeItem(at: url)
        return true
    } catch { return false }
}
```

Configure only when that returns `true`; otherwise defer and retry on `UIApplication.protectedDataDidBecomeAvailableNotification`. Guard every call site with `Purchases.isConfigured` — **`Purchases.shared` is a `fatalError` when unconfigured**, so an unguarded access crashes the app.

**Reproduction** (the only reliable trigger): schedule a Live Activity, lock the device, reboot, wait ~60s still locked, then unlock and open.

### 6.3 Architecture — fits the existing chain

`AppDependencies` → `AppServices` (`@Observable @MainActor`) → `@Environment`. Views never touch `Purchases.shared`.

```swift
enum EntitlementState: Sendable { case subscribed, notSubscribed, unknown }

protocol PurchaseService: Sendable {
    var state: EntitlementState { get }
    func refresh() async
    func purchase(_ plan: PlanID) async throws
    func restore() async throws
}
```

**The protocol must speak our types, not RevenueCat's — this is forced, not stylistic.** `EntitlementInfo` is `@_hasMissingDesignatedInitializers`: it has **no public initializer at all**. You can build an empty `EntitlementInfos` container, but you **cannot construct a populated, active entitlement** through public API. So a protocol returning `CustomerInfo` is untestable for the only case that matters — the paying user. Returning our own `EntitlementState` makes the entitled path trivially fakeable.

Public offline fixtures *do* exist for the product side: `SubscriptionPeriod` → `TestStoreProduct` → `.toStoreProduct()` → `Package` → `Offering`. Use those for paywall previews and rendering tests.

- Single `@Observable EntitlementStore` as the one source of truth; drive it from `Purchases.shared.customerInfoStream`, not polling.
- Gate at **flow entry points** (before navigating to Insights), not inline `if isPro` scattered through view bodies — keeps "what's gated" auditable in one file.
- **Model entitlement as a tri-state, never a `Bool`:** `subscribed` / `notSubscribed` / `unknown`. `Purchases.shared.cachedCustomerInfo` returning `nil` means *no cache exists at all* — that is `unknown`, not "free". Never paywall on `unknown`; degrade to last-known-good.
- Error code **`OFFLINE_CONNECTION_ERROR` is distinct from `NETWORK_ERROR`** — branch on it rather than treating every failure alike.
- **Good news, verified against SDK source** (`CustomerInfo+ActiveDates.swift`): the widely-quoted "3-day offline grace period then you lose access" is **wrong**. Within 3 days of the last server refresh the SDK trusts the server's `requestDate`; *after* 3 days it falls back to the **device clock**, so an annual subscriber offline for a month stays active. A long-offline paying user is not locked out. (Caveat: device clock is user-manipulable — a piracy hole, not a lockout risk. Verify in airplane mode before designing around it; the docs and the source disagree.)
- **`purchase()` async does not throw on cancellation** — check `result.userCancelled` on the success path. The completion-handler API differs; old tutorials get this wrong.
- `restorePurchases()` must be **user-initiated** (it can trigger an OS sign-in prompt). Use `syncPurchases()` for programmatic re-sync.

### 6.4 Paywall — custom SwiftUI, not the template

The Design Award is the realistic win and Squirl's design is the differentiator; a dashboard template would undercut the pitch. Cost of going custom, accepted knowingly:

- No remote layout changes without a build.
- **Must call `Purchases.shared.trackCustomPaywallImpression()`** manually or funnel data is silently incomplete.
- Exit offers don't work with manually-embedded paywalls.
- Offerings/Targeting/Experiments still work — they're data-layer. Always read `offerings.current`, never a hardcoded offering ID.

**Required furniture** (Guideline 3.1.1 — omission is automatic rejection): exact price · billing period · trial length · **Restore Purchases** (paywall *and* Settings) · Terms/EULA · Privacy Policy · plain-language how-to-cancel.

**Banned outright** — these violate `DESIGN.md` Product Posture *and*, in one case, Apple policy:
- **Toggle paywalls** — Apple began rejecting these under **Guideline 3.1.2 in January 2026**. Do not build one.
- Countdown timers / fake urgency · loss-framed copy ("don't lose your progress") · purchase confetti · bouncy entrance animations · hiding the monthly plan to force annual.

**Terms and Privacy links must work OFFLINE.** This is a specific exposure for an offline-first app: a `WKWebView`/`SFSafariViewController` pointed at `squirl.pt` renders a blank error for an offline user *or a reviewer on flaky hotel wifi* — and there are repeated forum reports of 3.1.2 rejections even where the links existed. **Bundle the EULA and policy text locally as native views**; make the web link secondary.

**A second argument for the custom paywall:** [#6018](https://github.com/RevenueCat/purchases-ios/issues/6018) is open — RevenueCatUI's paywall leaks 58 MB → **1 GB+** after being opened twice, with CPU over 150% on iOS 26.1. There are open accessibility issues against it too. Use RevenueCat for entitlements; render the paywall ourselves.

**Placement:** the first check-in is free and unconditional. The paywall triggers at a genuine value moment — opening Insights — never interrupting capture. A dismissed paywall stays dismissed.

**Accessibility is a gate, not a polish pass:** single vertically-stacked plan list from day one (comparison grids break first at AX sizes), each plan a single VoiceOver element reading "Annual, €X/year, 7-day free trial", ≥44×44pt targets, "Most Popular" badge never colour-only.

### 6.5 Testing

Test Store (zero setup) → StoreKit config file → **Apple Sandbox** → TestFlight.

**Trap specific to this repo:** a `.storekit` config is a *scheme* setting and is **ignored by `xcodebuild`**, which runs all 544 `@Test` cases. No test may touch the live SDK.

Three things make that easy:
- **Never call `configure()` in tests.** `Purchases.shared` is a `fatalError` when unconfigured, so the SDK stays inert by construction — that's a feature, not a hazard.
- **Define our own narrow protocol** (`PurchaseService`, ~4 members). Do *not* try to mock `PurchasesType` — it's ~1,100 lines of requirements.
- **`CustomerInfo` has a public init documented "Useful for Unit testing purposes"**, and `TestStoreProduct` + `Offering`/`Package` public inits exist. Real fixtures, no network.
- **Swift Testing runs in parallel by default** — if any test ever does configure, its `UserDefaults` writes cross-contaminate. Mark those `.serialized` and isolate with `.with(userDefaults:)`.

Two further traps, both verified:
- **A second `configure()` does not crash our app — it silently swaps the singleton** (the `preconditionFailure` is gated behind RevenueCat's own internal `RCRunningTests` env var, which a consuming app never sets). Two parallel suites configuring with different keys would quietly race, logging only `purchase_instance_already_set` at info level. Harder to diagnose than a crash.
- **A `test_`-prefixed Test Store key in a *Release* build calls `fatalError` by design.** A CI matrix that runs any leg in Release configuration will crash there and nowhere else — which reads as flaky CI but is perfectly deterministic.

**`SKTestSession` must be serialized** — Apple's own docs: *"Run tests that reconfigure the environment serially, not concurrently."* There is one shared test environment across all sessions.

**Do not build CI purchase tests on the scheme's StoreKit config.** The scheme's `StoreKitConfigurationFileReference` sits under `LaunchAction` and is independently reported as not reaching the simulator's `storekitd` under headless `xcodebuild test` on Xcode 26.x — still unfixed through 26.6 release notes. If integration tests are wanted later, put them in a **separately tagged target** and exclude them from the default run with `xcodebuild test -skip-testing-tags` (available since Xcode 16.3).

**Free early-warning system:** `PurchasesDiagnostics.default.checkSDKHealth()` (DEBUG-only) returns typed failures — `.invalidBundleId`, `.invalidProducts`, `.offeringConfiguration` — and the SDK auto-logs a health report on launch in DEBUG. This turns "offerings are empty, why" from an afternoon into a log line. Note it is a *live* health check that hits the network, not a mocking tool. Wire it on day one.

Matrix: purchase · restore on second device · restore after reinstall · **offline launch while subscribed** · cancel → expiry · monthly→annual · refund · trial→paid. Note TestFlight now renews only **once per 24h** (Apple changed this Dec 2024) — do renewal-cycle testing in sandbox, not TestFlight.

---

## 7. Landmines, ranked

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| 1 | **Prewarming regenerates the anonymous ID → paying user loses access after a reboot** ([#4623](https://github.com/RevenueCat/purchases-ios/issues/4623), OPEN, unfixed) | Silent, intermittent, and unrecoverable without Restore. Worst bug available to us. | Probe file protection before `configure()`; defer to `protectedDataDidBecomeAvailable` (§6.2b) |
| 2 | **In-App Purchase Key not configured** | Customers charged, entitlement never granted | Verify green credentials before any sandbox test |
| 3 | **App Review rejection burns the deadline** | Misses Shipaton entirely | Submit by Sep 16; two cycles budgeted; every 3.1.1 element present |
| 4 | **Privacy label change draws 5.1.1 scrutiny** | Rejection + trust damage | Policy live *before* submission; label matches manifest exactly |
| 5 | **Test Store key reaches Release** | App **crashes on launch** in production | Build-config key selection, never manual |
| 6 | **Terms/Privacy unreachable offline** | 3.1.2 rejection; blank screen for reviewer on bad wifi | Bundle EULA + policy as native views; web link secondary |
| 7 | Grandfather flag not shipped in the paid build | Cannot be backfilled; 1-star reviews | Write it in the same PR as the gate |
| 8 | **Store screenshots/description still advertise now-paid features** | Guideline **2.3.1** rejection — the real risk of paywalling, not 3.1.2(a) | Refresh ASC screenshots + description in the same submission |
| 9 | Restore Behavior not "Transfer to new App User ID" | Reinstalling users permanently stranded | Verify in project settings before launch |
| 10 | Test suite goes network-dependent | 544 tests flaky | Never `configure()` in tests; own narrow protocol + public `CustomerInfo` init |
| 11 | Product IDs are permanent · new products take **24h** to propagate | Locked-in mistakes; empty paywall at demo time | Settle naming first; ship ≥24h before any demo |
| ~~12~~ | ~~Xcode 26 build failures~~ | **Downgraded** — [#5290](https://github.com/RevenueCat/purchases-ios/issues/5290)/[#5585](https://github.com/RevenueCat/purchases-ios/issues/5585) fixed in 5.39.1/5.40.0 and only ever reproduced via XCFramework, not SPM. We're on SPM at 5.87.1. **Do not upgrade to Xcode 27 mid-hackathon** — it has fresh open issues. |

---

## 8. Decisions needed before code

| # | Decision | Recommendation |
|---|---|---|
| ~~D1~~ | ~~Exact gated feature set?~~ | **Settled: hard paywall — the whole app behind a 7-day trial.** Export stays ungated. |
| **D2** | Price points (monthly / annual)? | Needs your call — drives ASC setup. |
| **D3** | 7-day free trial confirmed? | Yes — satisfies judge access, honest UX. |
| **D4** | Grandfather scope: all current features, or Insights too? | All current features, permanently. |
| **D5** | Custom paywall vs `PaywallView`? | Custom — it's the Design Award pitch. |
| **D6** | Target Peace Prize + #BuildInPublic as well? | Yes to both; cost is write-ups, not code. |
| **D7** | Does the 053 insights work land first, or ship 1.1 on current `main`? | **Blocking.** Gating a tab that's mid-rewrite risks conflicts. |

---

## 9. Immediate next actions

1. Answer **D7** (053 first or not) — it decides the branch topology.
2. Start Paid Apps Agreement / banking / tax **today** — pure latency, blocks everything.
3. Generate the **In-App Purchase Key** and verify green in RevenueCat.
4. Email `shipaton@revenuecat.com` re: TestFlight-vs-public-release.
5. First #BuildInPublic post, tagged **#Shipaton**.
6. Convert this into a Spec Kit spec (`specs/055-monetization/`).

---

## Sources

[Shipaton Official Rules](https://revenuecat-shipaton-2026.devpost.com/rules) · [In-App Purchase Key](https://www.revenuecat.com/docs/service-credentials/itunesconnect-app-specific-shared-secret/in-app-purchase-key-configuration) · [iOS installation](https://www.revenuecat.com/docs/getting-started/installation/ios) · [Identifying Customers](https://www.revenuecat.com/docs/customers/identifying-customers) · [Displaying Paywalls](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls) · [Custom paywall impressions](https://www.revenuecat.com/docs/getting-started/tracking-custom-paywall-impressions) · [Launch checklist](https://www.revenuecat.com/docs/test-and-launch/launch-checklist) · [Submitting an iOS subscription app](https://www.revenuecat.com/docs/test-and-launch/submitting-ios-subscription-app) · [Apple: auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions) · [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) · [RIP the toggle paywall](https://www.revenuecat.com/blog/growth/rip-toggle-paywall) · [Shipaton 2025 winners](https://www.revenuecat.com/blog/company/shipaton-2025-winners)
