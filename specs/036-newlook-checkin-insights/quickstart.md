<!-- Created: 2026-07-16 19:20 (WEST) · Updated: 2026-07-16 19:20 (WEST) -->
# Quickstart / Device-QA — New Look Check-in + Insights (spec-036)

Owner builds + QAs on device (no simulator). Compare vs Figma a04 `447:821` · a05 `447:838` · a06 `447:855` · a07 `469:969`, light + dark. Branch `feat/036-newlook-checkin-insights` (contains 032→035 beneath it).

## Unit gate
- [ ] Full suite green; `averageLevelMatchesLabelOrdinal` demonstrably RED before `SignalAverage.level` existed (T002/T003).

## US1 — Check-in (a04–a06)
- [ ] Idle: green ring (selection → soft, breathing), caps date + 24pt bold title, hub = white pills + solid-green Speak pill with white mic; whisper hint unchanged; med bar identical to other tabs.
- [ ] Recording: white prompt card (green 4pt bar, 24pt question, hint, dots — rotation timing/copy unchanged), ring spins, timer, **green Stop & save pill**, white Cancel chip; cap-approach cue; VoiceOver announcements unchanged.
- [ ] Saved: green check disc pop (RM-gated), "Captured." 24pt, subtitle, full-width green Done; success haptic.
- [ ] Recovery (force a save failure if practical): ink "Try again" capsule + Discard — behavior unchanged.
- [ ] Log meds / Type note sheets open and work as before; auto-start via shortcut still lands in recording.

## US2 — Insights (a07)
- [ ] One continuous scroll — **no snap paging, no header dimming**; title + month chips scroll away naturally.
- [ ] Month chips: chip grammar (selected green/light label); switching months re-scopes every card.
- [ ] Breakdown card: bubbles + white legend capsules with dot + (count); "N check-ins" trailing.
- [ ] Signals card: 3 strips + "mostly X" + dashed empty slots + sleep chip — inside one card, no double insets.
- [ ] Averages card: gauges' fill/glyph ALWAYS agree with the "Okay+"-style label (FR-010).
- [ ] Rhythm card: 3×4 matrix, dashed empties.
- [ ] Connections: caps eyebrow block; unlocked card's mini-bar is **medication purple**; gated cards = flat white + dashed hairline + lock.
- [ ] Empty month: existing empty state, chips still shown.

## Cross-cutting
- [ ] Dark mode everywhere (derived tokens; ring/selection pills use dark variants — note `onSelection` flips labels to dark ink on green in dark mode, expected).
- [ ] Reduce Motion: ring static-ish (no spin/breathe), prompt transitions off, saved pop instant, chips un-animated.
- [ ] AX text sizes: prompt card wraps, hub pills grow, cards reflow; no truncation of questions/labels.
- [ ] VoiceOver: strips/gauges/cards announce as before; legend chips read "Level: count".

## Flags to eyeball (owner calls baked in — confirm they feel right)
- **Insights scroll feel changed completely** (pager → continuous, your ruling).
- **Meadow gradient is gone from check-in** (ring/speak/saved/Done now selection green; `Theme.meadow*` still lives elsewhere: status colors, `.primary` buttons on other screens).
- **Stop & save is green now** (was ink-capsule for ~a day post-T043); white-on-green in light mode is the accepted Figma-locked contrast family.
- **selectionSoft** (`#96C19F`) is a new token — ring-gradient scope only.
