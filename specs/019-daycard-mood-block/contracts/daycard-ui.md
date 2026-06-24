# UI Contract — Day-card mood-block redesign

The "interface" this feature exposes is **visual + interaction**. The binding contract is the approved mockup `mockups/summary/index.html` ("#4 Divided · Cream disc") and its captured screenshots. Each clause below maps a state/anatomy to the spec FRs and is independently verifiable on-device.

## Folded card (FR-001..FR-005, FR-012, FR-019)

```
┌──────────────────────────────────────────────┐   ← whole card = mood block (level.color @ moodBlock)
│  (badge)   Good · Monday 8                ⌄   │   ← cream disc badge + mood word(deepFill) · weekday(primary) + chevron
│  ──────────────────────────────────────────  │   ← divider (Theme.separator), folded only
│  ⚡ Charged   ◎ Present   💊 Concerta          │   ← summary: energy · focus · medication NAME (no dose)
└──────────────────────────────────────────────┘
```

- C1: the entire card background is the day's representative-mood tint (one block, not a band per check-in). **FR-001, FR-012**
- C2: the mood glyph sits in a cream-disc badge (~42 pt) at the leading edge. **FR-002**
- C3: mood word (deepened mood colour) + weekday on one line, before the chevron. **FR-003**
- C4: a hairline divider separates the title line from the summary line. **FR-004**
- C5: the summary line shows energy, focus, and medication **name only** (from `DayCardSummary`), omitting any signal not logged. **FR-005**

## Unfolded card (FR-006..FR-011, FR-019)

```
┌──────────────────────────────────────────────┐
│  (badge)   Good · Monday 8                ⌃   │   ← mood-tint STRIP header (badge + word + weekday + up-chevron)
├──────────────────────────────────────────────┤   ← rows drop onto cream (Theme.cardBackground)
│ (ring+   Good  16:12                      ›   │   ← ring around mood glyph + % ; mood word + inline time ; details chevron
│  glyph+   ⚡ Charged   ◎ Present              │   ← energy + focus ramp glyphs (only logged)
│   58%)    [Taken Concerta 36mg] [chips…]      │   ← existing Taken pill + input chips
│ (ring)   Okay  12:40                      ›   │
│           ⚡ Steady                            │
└──────────────────────────────────────────────┘
```

- C6: tapping the header toggles fold/expand via the **existing** state machine; selection/auto-expand/collapse-others unchanged. **FR-006**
- C7: the mood-tint strip persists as the header; check-in rows render on the cream surface below. **FR-007**
- C8: each row's bead shows the medication-phase ring around the **mood glyph** with the dose **% beneath**. **FR-008**
- C9: each row shows the mood word with the **timestamp inline** right after it (not right-aligned). **FR-009**
- C10: energy + focus render as ramp glyphs (shape+hue+fill), only logged signals. **FR-010**
- C11: a **details chevron** sits on the trailing edge of the row. **FR-011**

## Accessibility & adaptivity contract (FR-013..FR-016, FR-019)

- A1: at the largest Dynamic Type, all text scales and wraps; the **mood word is never clipped/ellipsised**. **FR-013, SC-003**
- A2: fold/unfold honours **Reduce Motion** (instant when on; `Motion.smooth` reveal when off). **FR-014, SC-004**
- A3: every signal stays distinguishable by **shape+fill in greyscale**; mood readable by glyph shape + word. **FR-015, SC-005**
- A4: the header and each row remain ≥ **44 pt** tap targets; the row is one combined VoiceOver element. **FR-016**
- A5: correct in **light and dark**. **FR-019**

## Non-regression contract (FR-020, SC-007)

- N1: no change to data/schema, the `ExpandedDayCards` state machine, filter-above selection, auto-expand, or `DayCardSummary` derivation. 014's logic tests stay green.

## Token contract (FR-017, SC-006)

- T1: every radius, spacing, size, tint level, and type style in the changed views resolves through a `DesignSystem` token — verified by token audit (no magic-number literals).
