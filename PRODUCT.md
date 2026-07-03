<!-- Created: 2026-07-03 17:19 (WEST) · Updated: 2026-07-03 17:19 (WEST) -->
# Product

> Synthesized from the canonical Master PRD (`project-team/by-me/MASTER-PRD-manual-check.md`, v2.2) and [DESIGN.md](DESIGN.md). The Master PRD remains the source of truth for business/market context; this file is the strategic digest design tooling reads.

## Register

product

## Users

Adults (18+) with ADHD who want to track mood, energy, focus, sleep, and medications without typing forms or sacrificing privacy. The ADHD audience is a functional constraint, not flavor: low cognitive load, minimal friction, no overwhelm, fast and clear reward. Personas: medicated daily checker (Alex), streak-burned sporadic tracker (Jordan), privacy-absolutist paper journaler (Sam). Secondary: anyone wanting a voice-first, privacy-first daily check-in journal.

## Product Purpose

Squirl is an on-device, privacy-first iOS check-in journal. Voice-log (or type) a check-in in under a minute; the app transcribes and extracts structured signals (mood, energy, focus, sleep, medications, side effects, emotions) locally and surfaces personal patterns. No account, no server, no cloud by default. North star: **effortless** — in and out in under a minute, the app always slightly calmer than you. First three seconds read as *relief, then permission*.

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
3. **Privacy by architecture, not policy** — on-device transcription/extraction/storage; the design never invites data-sharing patterns.
4. **Deterministic over probabilistic · auditable over opaque · instant over eventual** — visible in UX as predictable, explainable behavior.
5. **Color is never the only cue** — every signal is also encoded by glyph shape + fill (colorblind- and grayscale-safe).

## Accessibility & Inclusion

WCAG 2.1/2.2 AA as a hard floor: contrast ≥ 4.5:1 body / ≥ 3:1 large+UI, touch targets ≥ 44×44 pt, VoiceOver labels on all controls, Dynamic Type AX1–AX5, Reduce Motion fallbacks (breathing/rotation collapse to static). Known token caveats: muted ink `#7A7361` fails AA for small text on paper (use ≥ large/bold or darken to ~`#6A6354`); meadow amber is decorative-only, never text.
