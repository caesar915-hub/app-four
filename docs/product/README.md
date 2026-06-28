# Product — Squirl

This document is the lightweight product definition for Squirl, an on-device iOS journal for ADHD adults.

---

## Problem

ADHD adults often struggle to notice patterns between daily choices, medications, sleep, mood, and energy. Existing journals are either too unstructured (blank pages lead to abandonment) or too rigid (mood trackers, habit streaks, and medication reminders feel infantilizing or add pressure). Many people also distrust apps that upload sensitive health data to the cloud.

## Target Persona

**Primary:** ADHD adults who want a low-effort way to capture their day and notice patterns without feeling managed by an app.

- Values privacy and autonomy.
- Struggles with consistency; needs friction to be near zero.
- Dislikes gamification, streaks, and alarm-style reminders.
- Wants to understand what affects focus, energy, mood, and sleep.

## Value Proposition

Squirl lets you log a voice or text check-in in under a minute and turns it into structured, searchable, private insights — all on your device. No cloud. No streaks. No nagging.

## Product Principles

1. **Effortless** — in and out in under a minute.
2. **Calming** — every interaction should leave the user slightly calmer.
3. **Private** — data never leaves the device; processing is local.
4. **Non-judgmental** — no streaks, no scores, no guilt.
5. **Signal-rich** — extract meaningful structure from free-form input without rigid forms.
6. **Autonomy-preserving** — the app shows patterns; it does not prescribe behavior.

## Core Loop

1. Open the app.
2. Tap and talk (or type) a check-in.
3. Squirl transcribes and extracts signals in the background.
4. Review the day in Calendar or notice patterns in Insights.

## Key Features

- **Voice check-in** with rotating prompts and an 8-minute soft cap.
- **Text check-in** with signal-first composer.
- **On-device transcription** via Whisper Small.
- **NLP extraction** of mood, energy, focus, sleep, medications, emotions, side effects, appointments, highlights, and topics.
- **Calendar / Library** with day-grouped timeline and collapsible cards.
- **Insights dashboard** with mood bubbles, weekday strips, rhythm matrix, and connections.
- **Medication tracking** with effect-window visualization, no alarms.
- **Extraction review / edit** to correct signals and train a personal lexicon.
- **Encrypted journal export** and full data clearing.

## What We Deliberately Do Not Do

- Streaks or gamification.
- Medication alarms or refill reminders.
- Cloud sync or cloud processing.
- Emoji faces or SF Symbols for signals.
- Prescriptive medical advice.
- Social features or sharing.

## Success Metrics (Draft)

Because the app is privacy-first and ships no analytics SDK, metrics are kept minimal and device-local where possible:

- **Activation:** User completes three check-ins within the first seven days.
- **Retention (proxy):** Local count of unique days with a check-in in the last 14 days.
- **Quality:** Extraction review correction rate per recording.
- **Performance:** Median end-to-end time from capture to structured result.

> Instrumentation approach is still TBD. Any telemetry must be opt-in and local-first.

## Monetization (Draft)

No decision has been made. Options under consideration:

- **Free with subscription:** core journaling free; advanced insights / export / multiple models premium.
- **One-time paid app:** simple, privacy-aligned, no ongoing billing complexity.
- **Free with one-time IAP unlock:** tip-jar style or "pro" feature unlock.

StoreKit is not yet implemented; this decision gates App Store listing.

## Roadmap Snapshot

See `docs/BACKLOG.md` for the full milestone plan. High-level stages:

- **v0.8** — Stable capture, transcription, extraction, calendar, insights.
- **v0.8.1** — UI parity, medication bar, signal glyphs, accessibility pass.
- **v0.9** — Personal lexicon learning, export, settings polish, App Store prep.
- **v1.0** — Ship to App Store.

## Open Questions

1. Which monetization model best serves the persona?
2. What is the minimum viable analytics approach that respects privacy?
3. How do we migrate users once SwiftData schema migrations are required?

---

*Last updated: 2026-06-28*
