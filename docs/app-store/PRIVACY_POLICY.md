<!-- Created: 2026-07-16 18:54 (WEST) · Updated: 2026-07-21 13:16 (WEST) -->
# Squirl Privacy Policy

**Canonical source for the page published at `https://squirl.pt/privacy`. The deployed copy is `privacy.html` in this folder, mirrored to `WEBSITE-me/public/privacy/index.html`. Edit both together — they must not drift. Paste the URL into App Store Connect ▸ App Privacy.**

_Effective date: 2026-07-21_

## The short version

The Squirl app doesn't collect your data. Everything you record — your voice, transcripts, moods, medication logs — stays on your device. There are no accounts and no analytics, and the app has no backend to send anything to.

The one exception is our website: if you join the waitlist at squirl.pt, we store the email address you give us. That's covered in "The Squirl website" below.

## What Squirl stores, and where

Squirl is a voice-first check-in journal. When you record a check-in, the app:

- Saves the **audio recording**, its **transcript**, and any **signals** extracted from it (mood, energy, focus, sleep, medications, side effects, emotions) in the app's private storage on your device.
- Transcribes your voice **on your device**, using an open-source speech model (WhisperKit). Your audio is never sent anywhere for processing.

This data never leaves your device unless *you* export it.

## What Squirl does not do

- **No account.** There is nothing to sign up for.
- **No servers.** We operate no backend; the app has nothing to upload to.
- **No analytics or tracking.** No analytics SDKs, no advertising identifiers, no crash-reporting services.
- **No third-party data sharing.** There is no data to share.

## Network access

Squirl connects to the internet for exactly one purpose: a **one-time download of the speech-recognition model** (from Hugging Face's content delivery network) after you install the app. This is a download only — no personal data, identifiers, or telemetry are transmitted. You can restrict it to Wi-Fi in Settings.

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
