<!-- Created: 2026-07-16 18:54 (WEST) · Updated: 2026-07-16 18:54 (WEST) -->
# Squirl Privacy Policy

**Draft for hosting at `https://squirl.pt/privacy` — review before publishing. Owner action: host this page, then paste its URL into App Store Connect ▸ App Privacy.**

_Effective date: [SET ON PUBLISH]_

## The short version

Squirl doesn't collect your data. Everything you record — your voice, transcripts, moods, medication logs — stays on your device. We have no servers, no accounts, and no analytics.

## What Squirl stores, and where

Squirl is a voice-first check-in journal. When you record a check-in, the app:

- Saves the **audio recording**, its **transcript**, and any **signals** extracted from it (mood, energy, focus, sleep, medications, side effects, emotions) in the app's private storage on your device.
- Transcribes your voice **on your device**, using an open-source speech model (WhisperKit). Your audio is never sent anywhere for processing.

This data never leaves your device unless *you* export it. It is excluded from iCloud Backup by design.

## What Squirl does not do

- **No account.** There is nothing to sign up for.
- **No servers.** We operate no backend; the app has nothing to upload to.
- **No analytics or tracking.** No analytics SDKs, no advertising identifiers, no crash-reporting services.
- **No third-party data sharing.** There is no data to share.

## Network access

Squirl connects to the internet for exactly one purpose: a **one-time download of the speech-recognition model** (from Hugging Face's content delivery network) after you install the app. This is a download only — no personal data, identifiers, or telemetry are transmitted. You can restrict it to Wi-Fi in Settings.

## Export

You can export your journal from Settings at any time. Exports are encrypted (AES-256-GCM) with a recovery key that is shown to you once and never stored. Where you send an export — and whether you keep the key — is entirely up to you.

## Diagnostics

Squirl keeps a small, local log of technical session data (device thermal state, memory, screen names — never transcript text or audio) to help diagnose problems. It stays on your device. If you contact support, you choose whether to attach it.

## Health data

Your check-ins may describe your mood and medications. Squirl treats all of it as sensitive: stored only on your device, in app-private storage, excluded from backup, and never transmitted. Squirl is a journal, not a medical device, and doesn't provide medical advice.

## Children

Squirl is intended for adults (18+).

## Changes

If a future version of Squirl changes any of the above — for example, adding optional iCloud sync — this policy will be updated first, and the app will ask before anything leaves your device.

## Contact

Questions: **support@squirl.pt**
