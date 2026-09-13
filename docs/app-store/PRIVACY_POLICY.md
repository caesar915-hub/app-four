<!-- Created: 2026-07-16 18:54 (WEST) · Updated: 2026-08-30 22:55 (WEST) -->
# Squirl Privacy Policy

**Canonical source for the page published at `https://squirl.pt/privacy`. The deployed copy is `privacy.html` in this folder, mirrored to `WEBSITE-me/public/privacy/index.html`. Edit both together — they must not drift. Paste the URL into App Store Connect ▸ App Privacy.**

> ⚠️ **UNPUBLISHED REVISION — do not deploy yet.** This revision describes the RevenueCat purchase flow, which is not in any shipped build. Publish it **with, or immediately before, the first App Store build that contains RevenueCat** — the app's own promise is that the policy changes first — and set the effective date to that release date. Until then the live site keeps the 2026-07-21 text. Deploying this early would disclose collection that isn't happening yet.

_Effective date: 2026-07-21 (current live version) · pending revision effective on the first paid release_

## The short version

Everything you record — your voice, transcripts, moods, medication logs — stays on your device. There are no accounts, no analytics, and no profiling, and your journal is never uploaded anywhere.

Two things do leave your device, and neither one is your journal:

1. **If you buy a subscription**, your App Store purchase receipt is checked by our payments provider, RevenueCat, so the app knows you've paid. It is not linked to your name or identity. See "Purchases and subscriptions" below.
2. **If you join the waitlist** at squirl.pt, we store the email address you give us. See "The Squirl website" below.

## What Squirl stores, and where

Squirl is a voice-first check-in journal. When you record a check-in, the app:

- Saves the **audio recording**, its **transcript**, and any **signals** extracted from it (mood, energy, focus, sleep, medications, side effects, emotions) in the app's private storage on your device.
- Transcribes your voice **on your device**, using an open-source speech model (WhisperKit).
- Reads that transcript with a **small open-source language model that also runs entirely on your device** (via Apple's MLX framework) to pull out the signals and write a short summary.

Neither your audio nor your transcript is sent anywhere for processing — both the speech model and the language model run locally on your iPhone, offline. This data never leaves your device unless *you* export it.

## What Squirl does not do

- **No account.** There is nothing to sign up for, and nothing to log in to.
- **Your journal never leaves your device.** Recordings, transcripts, moods, emotions and medication logs are not uploaded, not backed up to us, and not shared with anyone. We have no way to read them.
- **No analytics or tracking.** No analytics SDKs, no advertising identifiers, no crash-reporting services, no profiling, no cross-app or cross-site tracking.
- **No selling or renting data.** Not to advertisers, not to data brokers, not to anyone.
- **No ads.**

## Network access

Squirl connects to the internet for two purposes, and no others:

1. **A one-time download of its AI models** — the speech-recognition model and the small language model that reads your transcripts — from Hugging Face's content delivery network after you install the app. This is a download only: no personal data, identifiers, or telemetry are sent. You can restrict it to Wi-Fi in Settings.
2. **Checking your subscription**, if you have bought one. See below.

If you never buy a subscription, purpose 2 never happens.

## Purchases and subscriptions

Squirl's paid features are sold through the Apple App Store. Apple handles the payment — we never see your card details, billing address, or Apple ID.

To know whether your subscription is active, the app uses **RevenueCat**, a subscription-management provider acting as our data processor. When you buy, restore, or renew a subscription, RevenueCat receives:

- Your **App Store purchase receipt** (which products you bought and when).
- A **random, anonymous identifier** the app generates on your device to keep track of your purchase. It is not your name, email, Apple ID, or device serial number, and it is not linked to anything else about you.
- Basic **transaction context**: country, currency, language, platform and app version.

RevenueCat **never receives any journal content** — no audio, no transcripts, no moods, no emotions, no medication data. Those never leave your device at all.

**We use anonymous identifiers only.** We do not create accounts, so we have no way to connect a purchase to a person. That's a deliberate choice: it means we cannot build a profile of you even in principle.

**Nothing here is used for tracking or advertising.** Purchase data is used only to unlock what you paid for, to prevent fraud, and to see aggregate sales totals.

RevenueCat processes this on our behalf under its own privacy terms: <https://www.revenuecat.com/privacy>. Apple's handling of the payment itself is governed by Apple's privacy policy.

**Managing or cancelling** a subscription is done in iOS Settings ▸ your Apple ID ▸ Subscriptions — we cannot do it for you, and we cannot see your payment details.

## The Squirl website

Everything above describes the Squirl app. The website at squirl.pt works differently, because it has a waitlist form.

**What we store when you join the waitlist:** the email address you enter, the date and time you submitted it, and your browser's user-agent string (the standard identifier your browser sends with every request).

**Why:** to email you once, when Squirl launches. That is the only purpose. We don't send newsletters, we don't profile you, and we never sell or rent the list.

**Lawful basis:** your consent, given when you submit the form. You can withdraw it at any time by emailing us, and we'll delete your entry.

**How long we keep it:** 180 days from signup, after which it is deleted automatically.

**Where it lives:** in Google Firestore, on Google Cloud infrastructure in the United States, where Google acts as our data processor. If you are in the EU or UK, this means your email is transferred outside your home region; Google Cloud's standard data-protection terms cover that transfer.

**Your rights:** you can ask us for a copy of what we hold, have it corrected, or have it deleted — just email us at the address below and we'll action it. You also have the right to complain to your local data-protection supervisory authority.

The website has no advertising, no tracking pixels, and no third-party analytics.

## Export

You can export your journal from Settings at any time. Exports are encrypted (AES-256-GCM) with a recovery key that is shown to you once and never stored. Where you send an export — and whether you keep the key — is entirely up to you.

## Diagnostics

Squirl keeps a small, local log of technical session data (device thermal state, memory, screen names — never transcript text or audio) to help diagnose problems. It stays on your device. If you contact support, you choose whether to attach it.

## Health data

Your check-ins may describe your mood and medications. Squirl treats all of it as sensitive: stored only on your device and never transmitted. Squirl is a journal, not a medical device, and doesn't provide medical advice.

## Children

Squirl is intended for adults (18+).

## Changes

If a future version of Squirl changes any of the above — for example, adding optional iCloud sync — this policy will be updated first, and the app will ask before anything leaves your device.

## Contact

Squirl is an independent app. For any privacy question, or to exercise the rights described above, email **caesar915@icloud.com** and we'll respond.
