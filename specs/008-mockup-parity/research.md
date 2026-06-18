# Phase 0 — Research

## Decision 1 — Token mapping (mockup px → existing DesignSystem token)

The owner's rule is "map to existing tokens, no literals in views." This table is the single authority for every value during implementation. Tiny deltas are accepted.

### Corner radius → `Radius`
| Mockup | Element | Token |
|---|---|---|
| 18 | big card | `Radius.card` (16) |
| 14 | detail dcard, med bar | `Radius.card` |
| 13 | notebox, selected-med card | `Radius.card` |
| 11 | date box | `Radius.control` (10) |
| 9 | sleep segment, hour pill, glyph ring | `Radius.control` |
| 8 | duration box | `Radius.control` |
| 999 | chips, dose pills, Taken, grid chips | `Capsule()` |

### Type → `Typography` (+ weight modifier where the mockup is bold)
| Mockup | Element | Token |
|---|---|---|
| Fraunces 30 | section h2 | `Typography.display` |
| Fraunces 22 | greeting, Insights title | `Typography.title` |
| Fraunces 21 | detail title | `Typography.title` |
| Fraunces 16 | sheet/navbar title | `Typography.title` |
| Fraunces 25/26 | nudge, "Captured." | `Typography.display` / `Typography.title` |
| DM Sans 16 | body | `Typography.body` |
| DM Sans 15 | primary buttons | supplied by `.buttonStyle(.primary)` |
| DM Sans 13.5/13 ·600 | med name, sig-name | `Typography.subheadline.weight(.semibold)` |
| DM Sans 12/11 | field labels, meta, helper | `Typography.caption` / `Typography.label` |
| Mono 11/11.5/12 | readouts, sub-line, numbers | `Typography.mono12` |
| uppercase tracked label | eyebrows, field labels | `.cardEyebrow()` (bakes uppercase + tracking) |

### Color → `Theme` / `Palette`
`--bg`→`Theme.background` · `--surface`→`Theme.cardBackground` · `--surface2`→`Theme.surface2` · `--ink`→`Theme.textPrimary` · `--muted`→`Theme.textSecondary` · `--hair`→`Theme.separator` · `--accent`→`Theme.accent` · `--green`→`Theme.meadowGreen` · `--amber`→`Theme.meadowAmber` · gradient→`Theme.meadowGradient` · `--med`→`Palette.medication` · energy/focus ramps→`Palette.energyRamp`/`focusRamp` · sleep→`Palette.sleepIndigo`.

### Spacing/padding → `Spacing`
Map each gap/pad to the nearest of 4/8/12/16/20/24/32/40 (`xs…hero`). Mockup 13/14 gaps → `Spacing.m`(12) or `Spacing.l`(16); 6/7 → `Spacing.xs`(4)/`Spacing.s`(8). Line/stroke weights (1 hairline, 1.5 selection ring) are line weights, not scale tokens — they stay as-is, consistent with existing usage.

**Rationale**: keeps the token set unchanged (owner decision) while removing all literals from views. **Alternatives rejected**: adding new radius/type tokens (owner chose not to grow the token set); inline literals (the thing being fixed).

## Decision 2 — One shared `GlyphRampPicker`
A single component renders the bare 1→5 glyph ramp with an accent ring on the selected glyph, used by both Type-note (§06) and the Edit sheet (§07 Mood/Energy/Focus). **Rationale**: the two screens must be identical; DRY. **Alternatives rejected**: duplicating the ramp in each view (drift risk).

## Decision 3 — `Grid` for the inline-expand label column
The Edit-sheet med inline-expand aligns Dose/Time/Dur labels with a SwiftUI `Grid` (auto-sized label column) instead of a fixed-width column. **Rationale**: avoids a magic width literal and stays token-clean. **Alternatives rejected**: `.frame(width: 50)` (a literal the owner forbids).

## Decision 4 — Per-med duration via optional DTO field + name-keyed setters
`MedEvent` gains an optional `durationHours`; `Recording.setMedicationEvents` uses `med.durationHours ?? durationHours ?? catalog ?? 10`. VM setters (`setMedDose`/`setMedDuration`/`toggleMedTaken`) look up the row **by name** (unique among selected) not by value equality. **Rationale**: backs the shown duration box without changing existing behavior; name-keying avoids the stale-value-capture bug that drops focus on edit. **Alternatives rejected**: per-med duration on the SwiftData model (over-reach; `MedicationEvent` already has the column); value-equality lookups (break on first edit).

## Decision 5 — Screenshot verification
Verify each screen by a temporary root-swap harness (set the app root to the target screen with preview data) → build → install/launch on iPhone 17 sim → screenshot light + dark → diff against the mockup → revert the harness. **Rationale**: no idb/tap tooling available; this is the proven method from the baseline work. **Alternatives rejected**: manual tap-through (no tap tooling); previews only (don't catch device-render differences).

All `NEEDS CLARIFICATION`: none.
