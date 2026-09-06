<!-- Created: 2026-08-30 22:31 (WEST) · Updated: 2026-08-30 23:10 (WEST) -->
# RevenueCat Integration — Research, Plan, and Open Decisions

> Status: **research only, no code written.**
>
> ⚠️ **Superseded on two points (2026-08-30).** (1) **D1 is settled** — Squirl is entering RevenueCat Shipaton 2026, so RevenueCat is a hard requirement; the native-StoreKit-2 recommendation in §2 is void and kept only for the record. (2) §6 step 2 below was **wrong**: the App-Specific Shared Secret is StoreKit 1 only and must *not* be configured — StoreKit 2 requires an **In-App Purchase Key** instead. Corrected inline.
>
> The live plan is **[SHIPATON_PLAN.md](SHIPATON_PLAN.md)**.

---

## 0. Read this before anything else

Squirl 1.0 shipped to the App Store with:

- An App Privacy nutrition label of **"Data Not Collected"** (`docs/app-store/SUBMISSION.md:66`)
- A published privacy policy that states, verbatim (`docs/app-store/PRIVACY_POLICY.md`):
  - *"**No servers.** We operate no backend; the app has nothing to upload to."*
  - *"**No third-party data sharing.** There is no data to share."*
  - *"**No analytics or tracking.** No analytics SDKs, no advertising identifiers, no crash-reporting services."*
- `PrivacyInfo.xcprivacy` with an **empty** `NSPrivacyCollectedDataTypes` array.

RevenueCat is a third-party backend. Its whole value proposition is that receipts are validated **server-side** and purchase events land in **their dashboard**. Integrating it means:

1. The nutrition label changes from "Data Not Collected" to **"Data Collected → Purchases"** (purposes: Analytics + App Functionality).
2. `PrivacyInfo.xcprivacy` gains a collected-data-type entry.
3. Three sentences of the shipped privacy policy become **false** and must be rewritten before the build ships.

The policy already anticipates this. Line 70:

> *"If a future version of Squirl changes any of the above — for example, adding optional iCloud sync — this policy will be updated first, and the app will ask before anything leaves your device."*

So there is a **self-imposed contract**: policy updated *first*. That's a sequencing constraint on the whole project, not a footnote.

**This is not a blocker on doing it. It is a blocker on doing it silently.** See §2 for the alternative that preserves the label.

---

## 1. Where the codebase actually stands

| Fact | Value | Consequence for this work |
|---|---|---|
| Deployment target | **iOS 26.0** | StoreKit 2 is fully available with no legacy fallback. This materially weakens the case for RevenueCat. |
| Swift language mode | 5.0 (not Swift 6 strict) | RevenueCat SDK integrates without strict-concurrency friction. |
| Existing StoreKit code | **None** | Greenfield. No migration cost either way. |
| Targets | `app-four`, `app-fourTests` only | No widget/extension → **no App Group needed** for entitlement sharing. |
| SPM dependencies | WhisperKit, MLX, Yams, swift-collections | Adding one more SPM dep is routine. |
| DI pattern | `AppDependencies` (composition root) → `AppServices` (`@Observable @MainActor`) → `@Environment` | A purchase service must follow this exact shape. Views/ViewModels must never touch `Purchases.shared` directly. |
| Test suite | **Swift Testing**, 544 `@Test` cases across 67 files | See §7 — the StoreKit config file does **not** apply to `xcodebuild` CLI runs, so purchases must sit behind a protocol seam. |
| Monetization plan on record | **None** in `docs/BACKLOG.md` or any spec | Everything in §9 is genuinely undecided. |
| App Store status | 1.0 shipped: **free**, worldwide, iPhone-only | Existing users exist. Grandfathering is a real decision (D6). |

---

## 2. The decision that gates everything: RevenueCat vs. native StoreKit 2

This is the fork. Everything downstream changes depending on the answer.

| | **RevenueCat** | **Native StoreKit 2** |
|---|---|---|
| Server dependency | Yes — theirs | **None** |
| App Privacy label | "Purchases" collected | **Stays "Data Not Collected"** |
| Privacy policy rewrite | Required | Not required (no data leaves device) |
| Cost | Free ≤ $2,500 MTR, then **1% of gross** (pre-Apple-commission) | **0%** |
| Time to first working paywall | ~1–2 days | ~3–5 days |
| Remote-configurable paywall | Yes (Paywalls v2, no app update) | No — requires app update |
| Paywall A/B testing | Built in | Build it yourself, or none |
| Subscription analytics (churn, LTV, cohorts) | Strong dashboard | **You get nothing** — ASC reports only |
| Cross-platform sync (Android/web) | Yes | No |
| Offline entitlement check | Cached; needs **one online launch first**; 3-day grace | `Transaction.currentEntitlements` — **works fully offline, always** |
| Edge cases (grace period, billing retry, refunds, upgrade/downgrade proration) | Handled | You handle them |
| Lock-in | Moderate | None |

### Assessment

**For this specific app, native StoreKit 2 is the stronger architectural fit — and it isn't close.**

Every structural advantage RevenueCat sells is neutralised here:

- **Cross-platform sync**: iPhone-only. Value = zero.
- **StoreKit 1 legacy handling**: iOS 26 minimum. Value = zero.
- **Server-side receipt validation**: `Transaction.currentEntitlements` is cryptographically verified by Apple on-device via JWS. For a single-platform app with no accounts, the server adds no security.
- **Cross-device restore**: already solved natively by the Apple ID. No account system needed either way.
- **Offline resilience**: Squirl is an offline-first, on-device app. StoreKit 2 is *better* here — RevenueCat's offline entitlements require at least one successful online launch before they work at all, and expire after a 3-day grace period.

What RevenueCat genuinely gives you that Apple does not: **remote-configurable paywalls, A/B testing, and a real subscription analytics dashboard.** Those are the actual product. They are also *precisely* the features that conflict with the privacy promise, because they require shipping purchase behaviour to a third party.

So the trade is honest and narrow:

> **Do you want paywall experimentation and churn analytics badly enough to give up "Data Not Collected" and rewrite a privacy policy whose absolutism is a core marketing asset for a privacy-first ADHD journal?**

For a first paid release with one price point, the answer is very likely no. The experimentation tooling is worth most when you have traffic to experiment on. You don't yet.

**A defensible middle path (recommended): ship v1 monetization on native StoreKit 2 behind a `PurchaseService` protocol.** If, six months in, you're revenue-constrained and paywall conversion is the bottleneck, swap the implementation. The protocol seam makes that a contained change, and you'll be making the privacy trade with actual data instead of a guess.

**If you choose RevenueCat anyway** — which is a legitimate call, especially if Android is on the roadmap — the rest of this document is the full implementation path. Nothing below assumes you took my recommendation.

---

## 3. Phase 0 — Commercial prerequisites (do this first; it has latency)

None of this is code, and some of it takes days to clear. Start it before writing anything.

1. **Agreements, Tax, and Banking** in App Store Connect → accept the **Paid Applications Agreement**. Without it, in-app purchase products cannot be created at all.
2. Complete **banking details** and **tax forms** (US W-8BEN/W-9 equivalent for your jurisdiction). This is the step most likely to stall.
3. Enrol in the **Small Business Program** if eligible (under $1M/year) → Apple's commission drops from **30% to 15%**. This is free money; do not skip it.
4. Confirm the legal entity on the account matches how you intend to invoice.

> **Note:** RevenueCat's 1% is charged on **Monthly Tracked Revenue — gross, before Apple's cut.** At 15% Apple commission, a nominal 1% is closer to **~1.18% of what actually reaches you**.

---

## 4. Phase 1 — Decide the product shape *before* touching code

Do not start integration until §9 D1–D5 are answered. Building the plumbing is easy; building it around a pricing model you then change is where the cost is.

Minimum you must fix:

- What is free forever vs. paid (D1)
- Subscription vs. one-time purchase vs. both (D2)
- Price points and billing periods (D3)
- Free trial / introductory offer (D4)
- What happens to existing 1.0 users (D6)

---

## 5. Phase 2 — Privacy compliance (before the build, per your own policy)

Sequence matters here — the policy says it updates *first*.

1. **Rewrite `docs/app-store/PRIVACY_POLICY.md`.** The three "no servers / no third-party / no analytics" claims must become accurate. Suggested framing that preserves the spirit:
   > *"Your journal content — voice, transcripts, moods, medications — never leaves your device. The only thing that does is your purchase receipt, which is sent to our payments provider RevenueCat solely to verify your subscription. It is not linked to your identity and contains none of your journal data."*

   That distinction — **journal data on-device, receipt data off-device** — is the honest and defensible position. It is a genuinely smaller claim than the current one, and you should not paper over that.
2. **Regenerate `docs/privacy.html` and `docs/app-store/privacy.html`** from the markdown, and redeploy the public site. The backlog already flags a stale deployed `privacy.html` — fix that in the same pass.
3. **Update `app-four/PrivacyInfo.xcprivacy`**: add an `NSPrivacyCollectedDataTypes` entry:
   - Type: `NSPrivacyCollectedDataTypePurchaseHistory`
   - Linked to user: **`false`** (true only if you use custom App User IDs — see D7)
   - Used for tracking: **`false`**
   - Purposes: `NSPrivacyCollectedDataTypePurposeAppFunctionality` **and** `NSPrivacyCollectedDataTypePurposeAnalytics`
4. **Change the App Store Connect nutrition label** from "Data Not Collected" to Purchases → Purchase History, with the same two purposes, not linked to identity, not used for tracking.
5. **Decide the in-app disclosure.** Your policy promises the app *"will ask before anything leaves your device."* A receipt leaving on purchase is arguably covered by the purchase itself — but a one-line note on the paywall ("Purchases are verified by our payments provider. Your journal never leaves this device.") honours the promise cheaply and defuses the obvious 1-star review.

---

## 6. Phase 3 — RevenueCat dashboard setup

Order matters; each step depends on the previous.

1. Create a RevenueCat account → **Project** → add an **App**, platform Apple App Store, with your bundle ID.
2. ⚠️ **CORRECTED:** upload an **In-App Purchase Key**, *not* the App-Specific Shared Secret. The Shared Secret is StoreKit 1 only and is deprecated for SDK v5+/StoreKit 2. RevenueCat's docs: *"When using Purchases v5.x+ (i.e., StoreKit 2), transactions will **fail to be recorded without this key being set**."* Apple charges the customer while RevenueCat never validates — a paid-but-locked-out user. Generate at ASC → Users and Access → Integrations → In-App Purchase, upload the `.p8` + Issuer ID, and confirm the green "Valid credentials" state **before** any sandbox testing.
3. Optionally configure **App Store Server Notifications V2** — point ASC's production + sandbox notification URLs at RevenueCat. This gives near-real-time renewal/cancellation updates instead of polling.
4. **Create the products in App Store Connect first** (Phase 4a below), then import them into RevenueCat.
5. In RevenueCat, define:
   - **Entitlement** — one identifier, e.g. `pro`. This is the *only* thing your app code should ever check.
   - **Offering** — e.g. `default`, the set of products shown on the paywall.
   - **Packages** inside the offering — `$rc_monthly`, `$rc_annual`, `$rc_lifetime` as applicable, each attached to a product.
6. Grab the **public SDK key** (starts `appl_`). It is safe to ship in the binary. The *secret* key is not — never put it in the app.

### Phase 4a — App Store Connect products

1. ASC → your app → **Subscriptions** → create a **Subscription Group** (e.g. "Squirl Pro"). One group = users can hold one plan at a time and upgrade/downgrade freely within it. Put monthly and annual in the **same** group.
2. Add each subscription: Reference Name, **Product ID** (immutable forever — pick a scheme like `com.<you>.squirl.pro.monthly`), duration, price tier.
3. Set **subscription levels** within the group (level 1 = highest tier) — this drives upgrade vs. downgrade proration behaviour.
4. Add **localised display name and description** for every product, and a **review screenshot** of the paywall. Missing these blocks review.
5. Configure **introductory offers** (free trial) if D4 says yes.
6. Products sit in "Missing Metadata" / "Ready to Submit" until submitted **with a binary**. Your first paid build must include the IAP in the same submission.

---

## 7. Phase 4 — Xcode integration

**1. Add the package.** File → Add Package Dependencies:

```
https://github.com/RevenueCat/purchases-ios-spm.git
```

Dependency rule: **Up to Next Major Version**, from `5.0.0`. Current release at time of writing: **5.87.1** (2026-08-27). Use the `-spm` repo, not `purchases-ios` — it's the SPM-optimised mirror and resolves faster.

Add both products if you want the prebuilt paywall UI:
- `RevenueCat` — core SDK (required)
- `RevenueCatUI` — Paywalls v2 (optional; see D8)

**2. Enable the capability.** Target → Signing & Capabilities → **+ Capability → In-App Purchase**. Purchases silently fail without it.

**3. Configure at launch.** In [SquirlApp.swift](app-four/App/SquirlApp.swift) `init()`, alongside the existing `AppDependencies` warm-up:

```swift
#if DEBUG
Purchases.logLevel = .debug
#endif
Purchases.configure(withAPIKey: "appl_XXXXXXXX")
```

Pass **no `appUserID`**. Omitting it is what keeps customers anonymous — RevenueCat generates a random cached ID and you disclose nothing linked to identity. This is the single most important privacy lever in the integration (see D7).

---

## 8. Phase 5 — Architecture (fit it to the existing pattern)

The codebase has a clear rule, stated in [AppServices.swift](app-four/Store/AppServices.swift): *"Injected via SwiftUI `@Environment(AppServices.self)` so that ViewModels never reference `AppDependencies` directly."* Honour it.

**1. Protocol seam** — `app-four/Services/Protocols.swift`:

```swift
protocol PurchaseService: Sendable {
    var isPro: Bool { get }
    func refresh() async
    func purchase(_ package: Package) async throws
    func restore() async throws
}
```

This seam is what makes the RevenueCat-vs-StoreKit-2 decision reversible, and it is what makes the 544-test suite able to run without a network or a store.

**2. Implementation** — `app-four/Services/RevenueCatPurchaseService.swift`, `@Observable @MainActor`, mirroring the shape of the existing services. Subscribe to `Purchases.shared.customerInfoStream` so entitlement changes propagate without polling.

**3. Wire into DI** — add to `AppDependencies` and to the `AppServices` bundle in [AppDependencies.swift](app-four/Store/AppDependencies.swift). Views read it via `@Environment(AppServices.self)`.

**4. Gate on the entitlement, never the product.** Check `entitlements["pro"]?.isActive`. Never branch on a product ID — that hard-codes your pricing into your feature logic and breaks the day you add a tier.

**5. Fail open, not closed.** This is the one that bites offline-first apps. If `customerInfo` can't be fetched, do **not** revoke access. A paying user on a plane must keep their features. Distinguish "definitely not subscribed" from "couldn't check" and treat the latter as subscribed-until-proven-otherwise, within reason.

---

## 9. Phase 6 — Paywall

Two routes (D8):

- **RevenueCatUI `PaywallView`** — remote-configurable, no app update to change copy or layout, `.presentPaywallIfNeeded(requiredEntitlementIdentifier: "pro")` is close to one-line. **But** it will not match Paper & Pollen without significant work, and `DESIGN.md` is the stated source of truth for all UI. Expect a fight between the template system and your design system.
- **Custom SwiftUI paywall** — full Paper & Pollen fidelity, uses `Purchases.shared.offerings()` for products and prices. More code, no remote config.

Given `DESIGN.md`'s authority in this project and the app's very specific visual identity, **a custom paywall is the more consistent choice** — which also further weakens the case for RevenueCat, since remote paywall config was one of its two real advantages.

**Non-negotiable App Review requirements** (Guideline 3.1.1 — these cause automatic rejection):

- A visible **"Restore Purchases"** control. Put it on the paywall *and* in Settings.
- **Exact price** and **billing period** displayed before purchase.
- **Trial length** stated explicitly if there is one.
- Links to **Terms of Use (EULA)** and **Privacy Policy**.
- Plain-language note on **how to cancel** (Settings → Apple ID → Subscriptions).
- Products must actually load in the reviewer's sandbox — a paywall that renders empty is the single most common rejection.

Also add a **"Manage Subscription"** row in Settings — `app-four/Views/Settings/` already has a clean section pattern to follow.

---

## 10. Phase 7 — Testing

Three environments, in order:

**1. Local StoreKit configuration file** (`.storekit`, Xcode) — fastest loop. Simulate purchases, renewals, cancellations, refunds, billing retry. Editor → Subscription Renewal Rate compresses a year into minutes.

> ⚠️ **Codebase-specific trap:** a StoreKit configuration file is a *scheme* setting and is **ignored by `xcodebuild` on the command line.** Your 544 `@Test` cases run through `xcodebuild`. Therefore **no test may touch the real SDK** — every purchase test goes through a fake conforming to `PurchaseService`. Get this wrong and you'll have a permanently red or permanently network-dependent suite.

**2. Sandbox** — a real Sandbox Apple ID (ASC → Users and Access → Sandbox Testers), signed in via Settings → Developer. This is the only place your *actual* ASC product configuration and RevenueCat's receipt validation get exercised together. Renewals are accelerated (1 month ≈ 5 minutes). **Do not skip this** — local StoreKit testing validates none of your server-side setup.

**3. TestFlight** — production-sandbox behaviour, real purchase sheet, no charge. Last stop before submission.

Test matrix that actually matters: fresh purchase · restore on a second device · restore after delete-and-reinstall · **offline launch while subscribed** (critical for this app) · cancellation → expiry · upgrade monthly→annual · refund revocation · trial → paid conversion.

---

## 11. Phase 8 — Ship

1. Submit the app binary **together with** the IAP products in one submission.
2. Review notes must explain how to reach the paywall, and note that the app is a fully on-device journal needing no account.
3. Manual device QA by the owner is required before merge — per `CLAUDE.md`, code review alone never merges a PR.
4. Tag the TestFlight/release commit (`git tag v1.x.0`).
5. Update `docs/BACKLOG.md` as stages move, and `docs/DEVLOG.md` with the *why* of the pricing decision.

---

## 12. Decisions to make

| # | Decision | Why it can't be deferred |
|---|---|---|
| **D1** | **RevenueCat or native StoreKit 2?** | Gates everything. See §2. My recommendation: StoreKit 2 behind a `PurchaseService` protocol. |
| **D2** | **What is paid?** Insights? Export? Unlimited history? Medication tracking? | Determines every gate in the codebase. Note the ADHD audience and the "non-judgmental, no shame mechanics" principle — gating a *habit* feature behind a paywall risks exactly the resentment `PRODUCT.md` sets out to avoid. Gate *depth* (insights, export), not *capture*. |
| **D3** | **Subscription, one-time, or both?** | A privacy-first, offline, no-account app has an unusually strong case for a **one-time purchase** — no server needed at all, and it fits the "no ongoing relationship" ethos. Subscriptions earn more but demand ongoing justification. |
| **D4** | **Price points and free trial?** | Drives ASC product setup and the intro-offer configuration. |
| **D5** | **Free tier or hard paywall?** | A hard paywall on an ADHD journal will hurt retention badly. A generous free tier is likely correct. |
| **D6** | **What happens to existing 1.0 users?** | They installed a free app. Revoking features is a trust breach and a 1-star generator. Grandfathering (persist a "installed before vX" flag) is the safe call — decide it now, because you need the flag written *before* the paid build ships. |
| **D7** | **Anonymous IDs only?** (RevenueCat path) | Anonymous keeps the label "not linked to identity". The cost: no cross-device entitlement sync beyond Apple's own restore, and an anonymous ID is lost on uninstall. For a no-account app, anonymous is almost certainly right. |
| **D8** | **RevenueCatUI paywall or custom SwiftUI?** (RevenueCat path) | Template vs. Paper & Pollen fidelity. See §9. |
| **D9** | **Are Android or a web app on the roadmap?** | This is the strongest single argument *for* RevenueCat. If yes within 12 months, it changes my recommendation in D1. |

---

## 13. Open questions

Things this research cannot answer — they need you, Apple, or a vendor.

1. **Is the privacy positioning negotiable?** "Data Not Collected" is a marketing asset for a privacy-first ADHD app. Is it worth more than paywall analytics? Only you can price that.
2. **What's the revenue expectation?** Below ~$2,500 MTR, RevenueCat is free and the 1% argument is moot — the argument is purely about privacy and dependency. Above it, the fee becomes real.
3. **Is there existing user demand for a paid tier**, or is this monetization-by-default? No user research on pricing exists in the repo.
4. **Does the on-device MLX/Whisper model download cost** (bandwidth, ~500MB from Hugging Face's CDN) factor into pricing? It's a real per-user cost you currently absorb.
5. **Legal entity / VAT status** for receiving App Store payouts in your jurisdiction — unresolved in the repo.
6. **Is there an EULA?** Apple's standard EULA is the default, but if you link a custom one it must exist before submission. Only a privacy policy is on record.
7. **RevenueCat SDK + Xcode 26**: there are open reports (issue #5290) of deprecation-warning build failures on Xcode 26 with `SWIFT_TREAT_WARNINGS_AS_ERRORS`. Verify against your exact toolchain before committing to the dependency.

---

## 14. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Privacy-policy contradiction ships to production | **High** — App Store rejection under 5.1.1, plus a genuine trust breach | Phase 2 completes *before* the build is submitted. Non-negotiable. |
| "Data Not Collected" → "Data Collected" is publicly visible on the store listing | **Medium** — privacy-focused users will notice and comment | Get ahead of it in the release notes; explain the receipt/journal distinction plainly. |
| Paywall blocks App Review (empty products, missing Restore) | **Medium** — one rejection cycle ≈ 1 week | Full sandbox pass before submission; Restore button in two places. |
| Existing free users lose features | **High** — 1-star reviews, ADHD audience is retention-fragile | Grandfather. Decide D6 before the flag is needed. |
| Test suite becomes network-dependent | **Medium** — 544 tests going flaky | Protocol seam + fakes; no test touches the live SDK. |
| Entitlement check fails offline, locking out paying users | **High** — worst-case bug for an offline-first app | Fail open. Explicitly test the offline-while-subscribed path. |
| Product IDs are immutable | **Low but permanent** | Settle the naming scheme before creating the first product. |

---

## 15. Recommended sequence

If you take the recommendation in §2 (StoreKit 2), skip §6 and the RevenueCat parts of §7 — everything else stands unchanged.

1. Answer **D1, D2, D3, D5, D6, D9** — these are product decisions and block all code.
2. Start **Phase 0** in parallel (agreements/banking have latency).
3. Write a **Spec Kit spec** (`specs/0XX-monetization/`) — this is a feature; `CLAUDE.md` makes Spec Kit the mandatory build workflow, gated by the constitution.
4. **Phase 2** — privacy policy, manifest, label. Before code.
5. HTML mockup of the paywall → `DESIGN.md` review → only then SwiftUI.
6. Implement behind the protocol seam; branch `feat/0XX-monetization`.
7. Test: StoreKit config → sandbox → TestFlight.
8. `/code-review` + owner device QA → merge → tag.

---

## Sources

- [RevenueCat — iOS installation](https://www.revenuecat.com/docs/getting-started/installation/ios)
- [RevenueCat — Customers / App User IDs](https://www.revenuecat.com/docs/customers/user-ids)
- [RevenueCat — Caching & offline behaviour](https://www.revenuecat.com/docs/test-and-launch/debugging/caching)
- [RevenueCat — Offline Entitlements](https://www.revenuecat.com/blog/engineering/introducing-offline-entitlements)
- [RevenueCat — Apple App Privacy](https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy)
- [RevenueCat — Privacy-focused subscriptions](https://www.revenuecat.com/blog/engineering/privacy-focused-subscriptions-in-your-swift-app/)
- [RevenueCat — Paywalls v2](https://www.revenuecat.com/docs/tools/paywalls-v2)
- [RevenueCat — iOS subscription testing guide](https://www.revenuecat.com/blog/engineering/the-ultimate-guide-to-subscription-testing-on-ios)
- [RevenueCat — Small Business Program / 15% fee](https://www.revenuecat.com/blog/engineering/small-business-program)
- [purchases-ios releases](https://github.com/RevenueCat/purchases-ios/releases) · [Xcode 26 issue #5290](https://github.com/RevenueCat/purchases-ios/issues/5290)
- [Apple — Auto-renewable subscription groups](https://developer.apple.com/documentation/appstoreconnectapi/creating-auto-renewable-subscription-groups)
- [Apple — Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions)
- [Guideline 3.1.1 — Restore Purchases requirement](https://vp0.com/blogs/restore-purchases-button-missing-rejection-fix)
- [StoreKit 2 vs RevenueCat for indie devs (2026)](https://theswiftk.it.com/blog/storekit-2-vs-revenuecat-ios-subscriptions)
- [RevenueCat pricing 2026](https://costbench.com/software/subscription-billing/revenuecat/)
