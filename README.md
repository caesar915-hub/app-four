<!-- Created: 2026-09-27 12:55 (WEST) · Updated: 2026-09-27 12:55 (WEST) -->
# Squirl — Voice Journal

A privacy-first iOS check-in journal for adults with ADHD. Speak (or type) a check-in in under a minute; Squirl transcribes it and extracts mood, energy, focus, sleep and medications — **entirely on the device**. No account, no server, no tracking.

Built for **RevenueCat Shipaton 2026**.

## The App Store build is not this code

| What | Where | Status |
|---|---|---|
| **1.0** (build 2) | tag [`v1.0`](https://github.com/caesar915-hub/app-four/tree/v1.0) | **On the App Store.** Free, no paywall. Signals extracted with Apple's NaturalLanguage framework. |
| **1.1** — work in progress | [`main`](https://github.com/caesar915-hub/app-four/tree/main) | **Not submitted.** Replaces the extractor with an on-device LLM (Qwen2.5-1.5B via MLX). |
| **RevenueCat paywall** | [`feat/055-revenuecat`](https://github.com/caesar915-hub/app-four/tree/feat/055-revenuecat) | **Implemented, not approved by App Review.** Not in any App Store build yet. |
| Gemma 4 extraction | [`feat/gemma4-litert-extraction`](https://github.com/caesar915-hub/app-four/tree/feat/gemma4-litert-extraction) | Experiment — built but switched off (not wired into the app). |

Installing Squirl from the App Store today gets you 1.0 — none of the LLM or RevenueCat work below.

## RevenueCat integration

On [`feat/055-revenuecat`](https://github.com/caesar915-hub/app-four/tree/feat/055-revenuecat), under `app-four/Services/Purchase/`:

- Hard paywall with a 7-day free trial — monthly, annual and lifetime — using RevenueCatUI paywalls and Customer Center.
- Access is checked against the `pro` entitlement, never a product ID.
- All purchase code sits behind a `PurchaseService` protocol; views never touch `Purchases.shared`, and tests never hit the live SDK.
- **Fails open:** if the entitlement can't be verified, the app unlocks. Nobody gets locked out of their own journal.
- **Export is never gated**, and existing 1.0 users are grandfathered via `AppTransaction`.

## Stack

SwiftUI · SwiftData · Swift Concurrency · [WhisperKit](https://github.com/argmaxinc/WhisperKit) (`whisper-small`) · [MLX](https://github.com/ml-explore/mlx-swift) · Swift Testing. iOS 26+.
The speech and language models are downloaded on first launch, not bundled.

## Build

Open `app-four.xcodeproj` in Xcode 26, choose the `app-four` scheme, set your own signing team, and run on an iPhone with iOS 26 or later.

## Repository map

- `app-four/` — the app · `app-fourTests/` — tests · `Packages/` — local Swift packages (design system, MLX libraries)
- `specs/` — per-feature specs (Spec Kit) · `docs/` — design, engineering and product docs · `shipaton_plan/` — the Shipaton sprint plan and log
- `html-mockups/`, `mockups/` — design exploration, not the shipping UI
