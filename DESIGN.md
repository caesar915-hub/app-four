# Design System — Squirl · "Paper & Pollen"

> Source of truth for all visual and UI decisions. Read this before writing or changing any SwiftUI.
> Visual companion (open in a browser): [docs/superpowers/plans/2026-06-15-paper-pollen-design-system.html](docs/superpowers/plans/2026-06-15-paper-pollen-design-system.html)
> Created 2026-06-15 via `/design-consultation`. Living document — revise with explicit approval and log changes in the Decisions Log.

## Product Context
- **What:** on-device, privacy-first iOS journal. The user voice-logs (or types) a daily check-in in under a minute; the app transcribes (WhisperKit) and extracts structured signals (mood, energy, focus, sleep, medications, side-effects, emotions) and surfaces personal patterns.
- **Who:** ADHD adults. The audience is a *functional* constraint, not flavor — low cognitive load, minimal friction, no overwhelm, fast/clear reward.
- **Platform:** SwiftUI, iOS 26 (Liquid Glass). Tokens live in `app-two/DesignSystem/` (`Palette`, `Typography`, `Spacing`, `Radius`, `Motion`, `Haptics`, `Icons`).
- **North star (the one thing to remember):** **effortless** — in and out in under a minute, the app always slightly calmer than you.

## Aesthetic Direction
- **Direction:** Organic / Natural — warm pressed paper, **not** dark glass, **not** blue/purple. A field journal that listens.
- **Decoration:** intentional, not expressive (subtle paper tone, hairline rules). Texture for warmth, never noise.
- **Mood:** calm, unhurried, non-judgmental. First 3 seconds should read as *relief, then permission.*
- **Reference (anti-pattern):** the mood-tracker category converges on blue/purple "calm" palettes and emoji faces. Squirl deliberately diverges (earth-warm paper, abstract glyphs).

## Typography
- **All roles: Apple SF** — SF Pro (display / body / UI) + SF Mono (data / time), defined in `Typography.swift` and `UIFontMetrics`-scaled so every role keeps Dynamic Type. Hierarchy comes from **weight** (SF semibold headings), not a serif voice.
- **Reversal (spec 023, 2026-06-26):** dropped the original **Fraunces + DM Sans + IBM Plex Mono** system — including the earlier rule *"do not use SF/system as display or body, the 'gave up on typography' signal"* — for native SF app-wide, an explicit owner decision. The bundled faces, `UIAppFonts`, and `SquirlFonts` registration were removed. (Settings was already SF-exempt; it now matches the rest of the app.)

## Color
Never pure white, never `#000`. Light = warm paper; dark = warm loam (not black).

### Foundation
| Token | Light | Dark |
|---|---|---|
| Background (paper / loam) | `#F6F1E7` | `#14130F` |
| Surface / card | `#FCF8EF` | `#1E1C16` |
| Surface-2 / inset | `#EFE8D8` | `#272419` |
| Ink (primary text) | `#221E16` | `#F3EEE0` |
| Muted ink | `#7A7361` | `#9A917C` |
| Hairline | `#E3DAC7` | `#322E22` |
| Meadow green (accent) | `#5F8A4C` | `#6E9A58` |
| Meadow amber (accent) | `#E0A33A` | `#E8B255` |
| Accent (bronze; links/focus) | `#B8842A` | `#D4A24A` |
| Medication (purple) | `#7E5CA8` | `#9277BE` |

The Meadow green→amber gradient is reserved for the recording crescent, primary buttons, and active states — not a flat brand fill everywhere.

### Signal ramps (5-level, ordinal 1→5)
These are **data encoding**, not brand color. Each dimension is a distinct hue family (categorical separation between signals), climbing by lightness+chroma within (sequential). Kept as shipped on `feat/insights-palette`:
- **Mood — "Meadow·Burnt":** `#DA7A2A · #EDA94A · #9FCB79 · #5FB36E · #2E8B57` (burnt-low → green-high; green = flourishing).
- **Energy — "Lemon":** `#A9A079 · #C2B25A · #D8C53E · #EAD22A · #F5D70E`.
- **Focus — "Voltage blue":** `#7E8B96 · #6E8DAE · #5683B8 · #3E73B0 · #2C5E9E`.
- **Sleep — deferred.** No ramp yet. If/when added, push it **bluer/cooler** so it never collides with medication purple.

Rule: **color is never the only cue.** Every signal level is also encoded by glyph shape + fill (below), so it survives colorblindness and grayscale.

## Iconography & the Glyph Language
Each signal has its own **shape + hue + fill**, distinguishable by form alone (colorblind- and grayscale-safe). The canonical Paper & Pollen set (decided 2026-06-15; a "Bud" botanical redesign was explored 2026-06-16 and **reverted**):
- **Mood → sprout** ("bud → bloom"). Grows and opens with level. **Fixed** — an earlier user-selectable set (Seedling/Flower/Daisy/Clover) was dropped 2026-06-17.
- **Energy → lightning bolt.** Grows and fills with level.
- **Focus → aperture.** Scattered dashed ring (low) → tight concentric rings + sharp center (high).
- **Sleep → bed** (single icon, does not vary by level — ramp deferred). Cool indigo `#5566A6` (bluer than med purple so they never collide).
- **Medication → horizontal capsule** (single, two-tone, does not vary by level). Medication purple `#7E5CA8`. A chip/tag, not on the 1→5 ramp.

Complete register (every decision + all views): [2026-06-16-design-decisions-ALL.html](superpowers/plans/2026-06-16-design-decisions-ALL.html). **Build gap:** the app currently renders signals with **SF Symbols** (`sparkles` / `bolt.fill` / `target` / `bed` / `pills.fill`); porting these to SwiftUI `Shape`s is the open feature (Spec Kit).

Glyphs encode level by **shape + hue + fill simultaneously** (triple-redundant; verified grayscale/colorblind-safe via a single-ink silhouette test). No emoji faces anywhere — faces impose a self-judgment ("am I a frowny-face today?") that adds affective load; abstract growth glyphs are lower-stakes and faster to scan.

## Spacing
- **Base unit:** 8px. Comfortable-to-spacious density. Air reduces cognitive load.
- **Scale:** 4 · 8 · 12 · 16 · 24 · 32 · 48.
- **Radius:** small 12 · medium 14–16 · card 18 · pill/full 999. (Existing `Radius` tokens.)

## Layout & Components (iOS)
- **One primary action per screen.** Progressive disclosure; forgiving (easy undo/back, no penalty).
- **Four tabs:** Calendar · Check-in · Insights · Settings (`RootTabView`).
- **Cards** (`.card()`) on `Surface` with a hairline border and soft shadow; content in reading order, not a flat field dump.
- **Buttons:** primary = Meadow gradient pill; secondary = ghost (hairline) pill.
- **Signal picker** (input + edit): a row of tappable glyphs 1→5 with the current level ringed in accent and an inline label ("2 · scattered").
- **Chip groups** for emotions / side-effects / medications (tap to remove, "+ Add").

## Motion
- **Approach:** intentional; "effortless = inevitability." Everything decelerates gently; nothing snaps hard.
- **Crescent (`CrescentRing`):** breathes slowly when idle (~5s scale 1→1.035); revolves while listening (~7s/rev) with a voice-level glow; settles to a check when saved.
- **Settle transitions** (spring, gentle damping) for section/tab changes.
- **No confetti, no streak celebration, no "you're late" alarms.** Honor Reduce Motion (breathing collapses to a static glow).
- **Easing:** enter ease-out · exit ease-in · move ease-in-out. **Duration:** micro 50–100ms · short 150–250ms · medium 250–400ms.

## Product Posture (non-negotiable)
- **No streaks, no gamification.** A broken streak is a shame spiral for ADHD users and the #1 reason these apps get deleted. The reward is "I said it and it's captured."
- **Medication never nags.** No red, no "you're late." A worn-off dose just goes quiet.
- **Glyphs, not emoji faces** (see Iconography).
- **Privacy-first.** On-device; the store is excluded from iCloud backup. Nothing here invites surveillance imagery.

## Screen Specs
- **Check-in — three states.** Idle hub: crescent breathing + one big "Speak check-in", with "Log meds" / "Type note" as quiet secondaries. Listening: rotating Fraunces nudge, countdown bar + prompt dots, timer + record dot, single "Stop & save" (no idle buttons). Saved: a check that pops once + "Captured." with **Done** leading and "Check in again" secondary — **no transcribing UI, no daily card** (transcription/extraction run silently in the background; results land in Calendar/Insights). A `MedicationBarOverlay` rides above when a dose is on board.
- **Type-note (text check-in) — Layout A "signals first."** The glyph pickers are the input (mood/energy/focus 1→5), then a note field, then Save. Same glyph vocabulary as Insights/Edit.
- **Insights.** 5-section snapping scroll: breakdown (MoodBubbleChart) · signals (glyph ramps; Sleep shows "not tracked yet") · averages · rhythm · connections. Pinned selector; inactive headers dim.
- **Calendar.** **Unchanged** (collapsible week↔month over the mood/med timeline). Owner-preferred; do not redesign without explicit ask.
- **Recording detail.** Reads like a page top-to-bottom: title (Fraunces) + signal glyph summary → Summary card (with Regenerate) → Meds → Emotions → Transcript → **Audio player last** → "Edit check-in". **No back button** (navigate back by swipe-left); the old edit **pencil is removed** — the "Edit check-in" button is the single consistent edit affordance.
- **Edit sheet (`ExtractionReviewView`).** One scrolling modal reached by "Edit check-in", in order: **When** (date/time) · **Mood · Energy · Focus** (glyph pickers showing the named 1–5 level **+ a synonym line**, e.g. "Great · bright, thriving") · **Sleep** (named scale Restless→Deep, **no synonyms**, with 2/4/6/8/10h presets **plus a custom-hours text input**; bed icon, ramp deferred) · **Medications** · **Emotions · Side-effects** (chip groups). **Medications:** **Stimulants only** (Non-stimulants + Off-label removed for now); multi-select, **removable (×)**, **no count limit**; each selected med uses the **inline-expand (P1)** layout — dosage from the table, an **info-only default time**, and a **duration text box defaulted to the shortest** for that med. Each med is an **independent `MedicationEvent`** (same timestamp allowed). "Save corrections" writes `RecordingTag(source: .userCorrected)` → trains the personal lexicon. Low friction here is functional: if correcting is a chore, the NLP never learns.
- **Medication bar.** Capsule icon + single medication purple. The bar **fills from empty (just taken) to full (worn off)** over `MedicationEvent.durationHours`; onset (~first 20 min) shows a gentle pulse ("kicking in"). One consistent purple — only the fill changes, so onset and fading never share a color. Worn-off → quiet, overlay fades out. Inside the medication card/detail, the fuller **effect curve** (rise → peak → decline) may be shown where there's room.

## New Look (spec 033) — app-wide visual language

A cool, iOS-native alternative to Paper & Pollen, originally approved from the Figma a-screens
(file Squil-Design → "Screens (v2)": a03 Edit check-in, a02 Recording detail, a01 Calendar — a01
gated on spec-029) and piloted on Edit check-in + Recording detail (spec 032). **Spec 033
(2026-07-11) supersedes that two-screen pilot scope: New Look is now the app-wide visual
language** — every screen migrates to `NewLook.screen` / `NewLook.card` / `.newLookCard()` and the
New Look palette. `Theme` is retained only for the semantic accent/status colours that sit outside
the New Look palette: `Theme.accent`, `Theme.meadowGreen`, `Theme.meadowAmber`,
`Theme.meadowGradient`, `Theme.statusDone`, `Theme.statusInProgress`, `Theme.danger`. Tokens live
in `SquirlDesignSystem/NewLook.swift`, additive to that retained `Theme` subset; `Palette` and
`Typography` are untouched.

- **Palette** (adaptive light/dark; dark derived per iOS convention, QA-validated):

  | Token | Light | Dark | Role |
  |---|---|---|---|
  | `NewLook.screen` | `#EFF2EB` | `#12140F` | screen ground (cool sage) |
  | `NewLook.card` | `#FFFFFF` | `#1C1E19` | card surface (borderless) |
  | `NewLook.inkPrimary` | `#1C1B1F` | `#F2F3EE` | primary text |
  | `NewLook.inkSecondary` | `#8A8A8E` | `#9BA09A` | secondary text / labels |
  | `NewLook.hairline` | `#DBDDDE` | `#33362F` | chip / field borders |
  | `NewLook.tintNeutral` | `#ECEAE6` | `#272A22` | grooves / tracks / segmented-control fills / unselected med chip (T044) |
  | `NewLook.selection` | `#54B492` | `#5FC49F` | selected chip fill (non-medication) |
  | `NewLook.onInk` | `#F2F3EE` | `#1C1B1F` | inverse label on an `inkPrimary` fill (stop button, T043) |
  | `NewLook.onSelection` | `#FFFFFF` | `#1C1B1F` | label on a selection/medication fill (white per Figma in light; dark ink in dark for AA) |
  | `NewLook.checkInGreen` | `#5FB36E` | `#6FC47E` | capture-flow accent — check-in · onboarding · recording-detail **edit** (the day-card "Good"-mood green; **scoped, not app-wide**, 2026-07-16) |
  | `NewLook.checkInGreenSoft` | `#96C19F` | `#86BC9D` | soft partner at the check-in ring gradient's bottom (was `selectionSoft`) |
  | (medication) | `#7E5CA8` | `#957BC1` | reuses `Palette.medication`; dark nudged from `#9277BE` for AA text on the dark card (2026-07-16) |
  | `Palette.medicationFillEnd` | `#AF99C3` | `#B3A1D6` | light end of the med-bar dose-track gradient |
  | `Palette.sleepIndigo` | `#5566A6` | `#8E9BD4` | sleep chip/text; dark variant lightened for AA on the dark card (2026-07-15) |

  > **Known contrast limitation (`NewLook.inkSecondary`, light mode):** `#8A8A8E` measures **3.0:1**
  > on `screen` and **3.4:1** on `card` — below WCAG AA's 4.5:1 floor for normal-size body text
  > (dark mode passes at ~7:1). This is the Figma "Tiimo Colors" value, kept **1:1 with Figma by
  > owner decision (2026-07-12)** rather than darkened. Secondary/caption/label text using this
  > token in light mode does not clear AA; accept as a documented limitation, not a bug. Revisit
  > only with explicit approval to deviate from Figma (a compliant value is ~`#6C6C70`).

  > **Known contrast limitation (`NewLook.selection`, light mode):** the Figma green `#54B492`
  > measures **2.52:1** on white — below AA for the white chip label (4.5:1), for green text on
  > the card (Save/Cancel pills, synonym line), and for the ramp-picker selection ring's 3:1
  > non-text floor; the dose-track gradient end `#AF99C3` is **2.14:1** against its groove.
  > All four are Figma 1:1 values kept **by owner decision (2026-07-16)** — same ruling as
  > `inkSecondary`. Dark mode is unaffected: the dark values are derived, and every derived-value
  > failure was fixed the same day (`onSelection` dark ink label, medication dark nudge).

- **Cards** — `.newLookCard()`: white, **radius 20** (`Radius.newLookCard`), **no border** (contrast
  with `.card()`'s bordered radius-16), two-layer shadow — `0.05`-opacity black offset `(0, 2)`
  radius `8` + `0.03`-opacity black offset `(0, 1)` radius `2` (replaces the earlier single-layer
  approximation). 16px screen gutter.
- **Chips/pills** — `.newLookChip(selected:role:)`: unselected = white + hairline + ink; selected =
  solid `selection` (or `Palette.medication` for `.medication`, `checkInGreen` for `.checkIn` on the
  capture-flow surfaces) + `onSelection` label (white in light per Figma; dark ink in dark for AA); capsule.
- **Nav** — `NewLookNavBar`: leading pill · **centered title** (ZStack, width-independent) · trailing pill.
- **Typography** — native SF (unchanged rule); the Figma Inter ramp maps to existing `Typography`
  roles (headers → `.headline`, body → `.callout`, eyebrows → `.label`, 24pt nav title via
  `Typography.text(24,.bold,relativeTo:.title)`); Dynamic Type preserved.
- **Glyphs** — unchanged shapes (sprout/bolt/aperture/bed/capsule); only container/selection color
  context changes.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-16 | Capture-flow surfaces (check-in · onboarding · recording-detail **edit**) adopt one green — `NewLook.checkInGreen` `#5FB36E`, the day-card "Good"-mood green — replacing the mint `selection` + meadow-gradient mix | Owner wanted these three to match the day check-in card, which has no fixed green (mood ramp), so its "Good" green was chosen. **Scoped, not app-wide** (owner call): new token + `.checkIn` chip role + `CheckInPrimaryButtonStyle` (green-only gradient); Insights chips and other primary buttons keep `selection`/meadow. `selectionSoft` → `checkInGreenSoft`. Landed straight to `main` per owner. |
| 2026-07-16 | Contrast ruling on the spec-033 review's 8 WCAG findings: **fix derived dark-mode values, keep Figma-locked light values 1:1 and log them** | Figma specs light only; dark is derived, so fixing it isn't a deviation. Fixed: `onSelection` label token (dark ink on selection/medication fills in dark), medication dark `#9277BE`→`#957BC1`, Taken/Missed toggle re-grammar (`tintNeutral`+ink). Kept+logged: selection-green light family (chip label 2.52:1, green-on-white text, ramp ring, gradient/groove 2.14:1) — see palette note. |
| 2026-07-12 | Keep `NewLook.inkSecondary` at Figma value `#8A8A8E` despite light-mode WCAG AA failure (3.0:1 sage / 3.4:1 white, need 4.5:1) | Owner chose Figma fidelity over the contrast fix when the spec-033 accessibility audit surfaced it app-wide. Documented as a known limitation (see palette note above); dark mode unaffected (~7:1). A compliant alternative (~`#6C6C70`) is on record if revisited. |
| 2026-07-11 | Adopt "New Look" as the app-wide visual language (spec 033), superseding spec 032's two-screen pilot scope | Two-screen pilot (Edit check-in, Recording detail) validated the language; owner approved app-wide rollout. `Theme` retained only for accent/meadow/status/danger semantic colours — every other screen migrates to `NewLook.screen` / `NewLook.card` / `.newLookCard()`. |
| 2026-07-10 | Adopt "New Look" as a second visual language for Edit check-in + Recording detail (spec 032); dark tokens derived now; mixed P&P/New-Look shipped, no toggle | Owner adoption call after the Figma a-screens reached presentation grade; two lowest-risk screens prove the language before wider rollout. Calendar (a01) gated on spec-029. |
| 2026-06-15 | Adopt "Paper & Pollen" design system | `/design-consultation`. Warm-paper organic identity differentiates from the blue/purple category; "refine Meadow, don't replace." |
| 2026-06-15 | Keep shipped signal ramps; Energy stays Lemon | Owner override of the proposed Energy→Ember swap. Mood/Focus untouched. |
| 2026-06-15 | Signal glyphs = sprout / lightning / aperture | Distinct shapes make the four signals colorblind- and grayscale-safe; chosen over sun/eye/etc. |
| 2026-06-15 | Sleep = single bed icon, ramp deferred | One icon now (like meds' capsule); add a bluer 5-step ramp later to clear med purple. |
| 2026-06-15 | Medication = purple `#7E5CA8`, capsule, fill-up no-alarm bar | Purple is the only unused hue; the bar fills empty→full over the dose; never alarms. |
| 2026-06-15 | Check-in saved state shows no transcribing/card | Capture is the job of that moment; extraction is silent, results appear later. |
| 2026-06-15 | Type-note = Layout A (signals first) | Fewest taps for daily use; glyph pickers as input. |
| 2026-06-15 | No streaks / no gamification / no med alarms | Removes the dominant reason ADHD users delete these apps. |
| 2026-06-15 | Detail: no back button (swipe-left); pencil → "Edit check-in" button | From the owner screen-recording; the pencil was inconsistent with the interface. |
| 2026-06-15 | Edit pickers keep named 1–5 scale + synonyms (Mood/Energy/Focus); Sleep drops synonyms + adds custom-hours input | Owner kept the named scale as "correct"; synonyms help mood/energy/focus, add noise on sleep. |
| 2026-06-15 | Edit Medications: Stimulants only, multi-select, removable, P1 inline-expand, independent events, no limit | Non-stimulants/Off-label deferred (too complex now); inline-expand chosen over per-med sheet/table for the frictionless flow. |
| 2026-06-16 | Glyph redesign "Bud" botanical (pod/seedhead) — explored, then **REVERTED** | Owner returned to the canonical sprout/lightning/aperture set. Net glyph change for Mood/Energy/Focus: none. Full register: [design-decisions-ALL](superpowers/plans/2026-06-16-design-decisions-ALL.html). |
| 2026-06-17 | Sleep = bed, Medication = **horizontal** capsule, Mood icon **fixed** (selectable set removed) | Literal icons for the two non-self-state signals; one fixed Mood glyph. **Build target:** port all signal glyphs from SF Symbols → SwiftUI `Shape`s. |
| 2026-06-24 | Settings is **exempt** from the "no SF/system as display or body face" rule | Settings deliberately uses the native iOS grouped-`List` chrome (system-font section headers, rows, footers). It is HIG-aligned and more learnable than a custom-typeface settings screen; the Fraunces/DM Sans rule governs Squirl's own content surfaces, not OS-standard utility chrome. |
