# Phase 0 Research — Day-card mood-block redesign

All "NEEDS CLARIFICATION" from the plan's Technical Context are resolved here. This feature is presentation-only on an existing screen, so research is grounding in the current code + the approved mockup, not external best-practice discovery.

## R1 — Where the mood tint lives (whole-card wash → header background)

- **Decision**: Move the mood tint from the `DayCard` whole-card background onto the **header** (`FoldedDayCardHeader`). The card's own background stays `Theme.cardBackground` (cream); the header draws the mood-tint block with the card's top corners rounded.
- **Rationale**: This produces the mockup's two states for free. Folded, only the header is visible → the whole card reads as a solid mood block. Expanded, the header is a tinted strip and the `TimelineRow`s sit on the cream card background below. The "background cross-fade" the mockup shows emerges from the existing expand reveal (rows appearing below the persistent tinted header) — no new explicit background animation needed.
- **Current code**: `DayCard.body` fills the whole shape with `Theme.cardBackground` then layers `MoodLevel.averageFill(of: moods).opacity(Opacity.moodWash=0.16)` ([DayCard.swift#L39-L46](../../app-four/Views/Components/DayCard.swift)). That whole-card wash is removed; the tint relocates to the header.
- **Alternatives rejected**: (a) animate the card's `background` colour folded↔expanded — more code, fights the existing expand animation, and risks a flash; (b) keep the whole-card wash and just darken it — fails the mockup (rows must be on cream, not tint).

## R2 — Which mood drives the tint (average → representative)

- **Decision**: Tint by the **representative summary mood** (`DayCardSummary(day:).mood`, the most-recent check-in's mood) — the same mood the badge glyph and the title word show. NOT the rounded average.
- **Rationale**: The mockup shows one coherent mood per card (block colour == badge glyph == word). Using the average would let the block colour disagree with the glyph/word. Spec FR-001 + Assumption locks this. It also drops a per-card `averageFill` computation.
- **Tradeoff (surfaced)**: a day whose latest check-in differs from its overall tone tints by the latest, not the day's balance. Accepted per spec; revisitable to "dominant"/"average" later without re-architecting (single accessor).
- **Current code**: `DayCard.moods` + `MoodLevel.averageFill` exist ([MoodLevel+Palette.swift](../../app-four/Models/MoodLevel+Palette.swift)). `averageFill`/`averageDeep` stay available (Insights gauges may use them — verify; only remove if unused) but the day card stops calling them.

## R3 — Mood colour ends (block, badge, word)

- **Decision**: Block tint and badge use **`MoodLevel.color`** (the saturated Meadow·Burnt **base**, e.g. good `#5FB36E`) over surface, mirroring the mockup's `--m4`-at-N% recipe; the **mood word** uses **`MoodLevel.deepFill`** (== `.color`, documented as "deeper, legible shade for header text").
  - Block background: `level.color.opacity(Opacity.moodBlock)` (~0.22) layered on `Theme.cardBackground`.
  - Cream-disc badge: `level.color.opacity(Opacity.moodBadge)` (~0.50) circle, `Metrics.headerMoodBadge` (~42) diameter, `SignalGlyph(.mood, level:)` centred.
  - Mood word: `level.deepFill`.
- **Rationale**: The app's mood palette has exactly these two ends (`color` base / `fill` light partner). The mockup tints by the BASE (`--m4`), so the app must too — the current header disc uses `fill` (light partner) at `moodCircle=0.55`, which is lighter than the mockup; switching to `color` matches. `deepFill` already exists for "header text" and reads on the light tint in light + dark.
- **Open contrast check (verify on-device, SC per quickstart)**: on the lightest moods (`okay`/`flat`) `deepFill` on a 22% same-hue block may be marginal at small sizes. If a contrast review fails, add a `deepInk` variant (`color` mixed toward `Theme.textPrimary`) as a token — kept out of v1 unless needed (Principle IV).
- **Alternatives rejected**: using `fill` (light partner) for the block — too pale vs. mockup; hardcoding green — fails FR-012 (must generalise across five moods).

## R4 — The expanded row (bead + head), replacing `MoodBanner`

- **Decision**:
  1. **`TimelineBead`** centre shows the **mood glyph** on a soft mood disc (mirroring the day badge at row scale) inside the existing purple medication-phase ring, with the **% badge** unchanged. The **time is removed from the bead**.
  2. **`TimelineRow`** gets a new **row head** replacing `MoodBanner`: the **mood word** (`level.deepFill`) with the **timestamp inline** immediately after it (`Typography.mono12`, `Theme.textSecondary`), then **energy + focus ramp glyphs** (`SignalGlyph`, only logged signals), and a **details/disclosure chevron** (`chevron.right`, `Theme.textSecondary`) pinned to the **trailing edge**. The existing `chips` (Taken pill + inputs) stay below.
  3. **`MoodBanner.swift` is deleted** (its only caller was `TimelineRow`).
- **Rationale**: This is the mockup's row anatomy 1:1 and removes the full-width colored band the QA called out. Time-in-bead → time-inline is the same move already made in the mockup (`ring()` lost its time; `rtime` went inline). The bead already draws the ring + % ([TimelineBead.swift](../../app-four/Views/Components/TimelineBead.swift)) — only its centre content and the moved time change.
- **Accessibility**: the row stays one combined VoiceOver element (existing `.accessibilityElement(children: .combine)`); the disclosure chevron is decorative (the whole row is already the button → detail). Mood word never truncates (`fixedSize`/no ellipsis); energy/focus + time wrap under it at large Dynamic Type.
- **Alternatives rejected**: keeping `MoodBanner` and only restyling it — leaves the band; right-aligning the time (current `rtime`) — the mockup explicitly moved it inline.

## R5 — Tokens to add (no magic numbers, FR-017)

- `Opacity.moodBlock` ≈ **0.22** (header block tint) and `Opacity.moodBadge` ≈ **0.50** (cream disc). Existing `moodWash`(0.16)/`moodCircle`(0.55) are retired from the day card; remove them only if no other caller remains (grep first — Principle III).
- `Metrics.headerMoodBadge` ≈ **42** (down from `headerMoodCircle=58`). Row mood-disc reuses the bead geometry (`timeBead=54`). Divider = `Theme.separator`, 1 pt. Corner radius = `Radius.card`. Spacing via existing `Spacing.*`.
- All values are **design intent, tunable on-device** within the mockup look (spec Assumption); they live as tokens, never inline.

## R6 — Motion + Reduce Motion (FR-014)

- **Decision**: Reuse 014's existing expand animation (the `isExpanded` toggle driven from the calendar list via `ExpandedDayCards`, animated with `Motion.smooth`). The reveal of cream rows under the persistent tinted header IS the fold/unfold motion; the chevron rotation already exists. No new animation is introduced.
- **Rationale**: `Motion.smooth`/`snappy` are SwiftUI system curves that **auto-honour Reduce Motion** for value-driven animation (per `Motion.swift` doc). So FR-014 ("animate bg + height; instant under Reduce Motion") is met by reusing the existing gated animation — nothing extra to gate.
- **Verify**: confirm the expand call site wraps the state change in `Motion.smooth` (not a raw `.spring`); if a raw animation is found, swap it to `Motion.smooth` (token, no magic).

## R7 — Test-first scope (Principle X)

- **Decision**: The redesign is ~95% SwiftUI view work (EXEMPT — build + sim + mockup). The one piece of *logic* introduced is the **mood→tint palette mapping** (level → block tint / badge tint / word colour). Add a pure, testable accessor set on `MoodLevel` (or a small `DayCardPalette`) and write **`DayCardPaletteTests`** RED→GREEN: for each of the 5 levels, the accessor returns the expected token (base colour, the right opacities, deepFill word) and is non-nil; nil mood → the neutral fallback. Keep it a value mapping, not a service (Principle IV/VIII).
- **Also**: run 014's existing logic tests (`ExpandedDayCards`, the date filter, `DayCardSummary`) and confirm green (SC-007) — this feature must not touch their behaviour.

## Resolved unknowns

| Unknown | Resolution |
|---|---|
| Tint placement | Header background, not whole card (R1) |
| Tint mood source | Representative summary mood (R2) |
| Colour ends | base `color` for block/badge, `deepFill` for word (R3) |
| Row layout | bead glyph + inline time + ramp glyphs + trailing chevron; delete `MoodBanner` (R4) |
| New tokens | `Opacity.moodBlock/moodBadge`, `Metrics.headerMoodBadge` (R5) |
| Motion/Reduce Motion | reuse existing `Motion.smooth` expand (R6) |
| Test-first surface | mood→tint palette helper + keep 014 tests green (R7) |
