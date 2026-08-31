<!-- Created: 2026-07-03 17:19 (WEST) · Updated: 2026-08-31 00:05 (WEST) -->
# Product

> Synthesized from the canonical Master PRD (`project-team/by-me/MASTER-PRD-manual-check.md`, v2.2) and [DESIGN.md](DESIGN.md). The Master PRD remains the source of truth for business/market context; this file is the strategic digest design tooling reads.

## Register

product

## Users

Adults (18+) with ADHD who want to track mood, energy, focus, sleep, and medications without typing forms or sacrificing privacy. The ADHD audience is a functional constraint, not flavor: low cognitive load, minimal friction, no overwhelm, fast and clear reward. Personas: medicated daily checker (Alex), streak-burned sporadic tracker (Jordan), privacy-absolutist paper journaler (Sam). Secondary: anyone wanting a voice-first, privacy-first daily check-in journal.

## Product Purpose

Squirl is an on-device, privacy-first iOS check-in journal. Voice-log (or type) a check-in in under a minute; the app transcribes it with **WhisperKit** (`openai_whisper-small`) and extracts structured signals (mood, energy, focus, sleep, medications, side effects, emotions) with an **on-device LLM** — `mlx-community/Qwen2.5-1.5B-Instruct-4bit` running through MLX, in a two-pass pipeline (narrative summary, then strict-JSON signals) — then surfaces personal patterns. **No account, no login; journal content never leaves the device.** North star: **effortless** — in and out in under a minute, the app always slightly calmer than you. First three seconds read as *relief, then permission*.

## Monetization

Free for the first release; a paid tier lands via **RevenueCat** (built for RevenueCat Shipaton 2026). Rules that follow from the principles above, not from conversion tactics:

- **Hard paywall with a 7-day free trial** (owner decision, 2026-08-30). New users subscribe — or start the trial — before using the app. This *supersedes* the earlier "gate depth, never capture" rule, which is recorded here because the reversal is deliberate and the tension is real: a hard paywall asks an ADHD user to commit before their first check-in, which cuts against principle 1. The mitigations below are what keep it honest rather than extractive.
- **Existing 1.0 users never see the paywall.** They installed a free app; the `installedBeforePaidRelease` flag ships in the paid build and grandfathers them permanently.
- **Your journal is never held hostage.** Export works without an active subscription. The user's writing is theirs — a trial ending locks the *app*, never the data.
- **Fail open, always.** If entitlement cannot be verified, the app unlocks. Under a hard paywall a verification failure would otherwise deny someone access to their own on-device journal, which is the single worst outcome this product can produce.
- **No shame mechanics on the paywall.** No countdown timers, no fake scarcity, no guilt copy, no streak-loss threats. The anti-references list applies to the paywall exactly as it applies to the rest of the app.
- **Existing 1.0 users are grandfathered.** They installed a free app; features they already have are not taken away.
- **Anonymous purchases.** RevenueCat anonymous app user IDs only — no accounts, nothing linked to identity.
- **Fail open.** If entitlement cannot be verified (offline, server down), access is *granted*, not revoked. A paying user on a plane keeps their app.

## Brand Personality

Calm · warm · non-judgmental. Warm pressed paper ("Paper & Pollen"), a field journal that listens. Decoration is intentional, never expressive; texture for warmth, never noise.

## Anti-references

- The mood-tracker category's blue/purple "calm" palettes and emoji-face mood rating.
- Streaks, badges, gamification, confetti — shame mechanics that get these apps deleted.
- Red "you're late" medication alarms; a worn-off dose just goes quiet.
- Surveillance imagery of any kind; nothing that undermines the on-device privacy promise.
- Pure white / pure black surfaces (light = warm paper, dark = warm loam).

## Design Principles

1. **Effortless over complete** — one primary action per screen, sub-minute capture, progressive disclosure.
2. **Non-judgmental by construction** — no streaks, no nags, no faces; the reward is "I said it and it's captured."
3. **Privacy by architecture, not policy** — on-device transcription/extraction/storage; the design never invites data-sharing patterns. The *only* datum that leaves the device is the App Store purchase receipt, sent to RevenueCat to verify a subscription (see Monetization). Journal content is never in scope.
4. **Auditable over opaque · correctable over final · instant over eventual** — extraction is a *probabilistic* on-device LLM, so the honest promise is not determinism but legibility: every inferred signal is shown plainly, attributed, and one tap from correction. The app never hides what it guessed. *(Revised 2026-08-30: the original "deterministic over probabilistic" wording predates the LLM pipeline and no longer describes the product.)*
5. **Color is never the only cue** — every signal is also encoded by glyph shape + fill (colorblind- and grayscale-safe).

## Accessibility & Inclusion

WCAG 2.1/2.2 AA as a hard floor: contrast ≥ 4.5:1 body / ≥ 3:1 large+UI, touch targets ≥ 44×44 pt, VoiceOver labels on all controls, Dynamic Type AX1–AX5, Reduce Motion fallbacks (breathing/rotation collapse to static). Known token caveats: muted ink `#7A7361` fails AA for small text on paper (use ≥ large/bold or darken to ~`#6A6354`); meadow amber is decorative-only, never text.
