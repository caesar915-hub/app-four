<!-- Created: 2026-07-18 20:01 (WEST) · Updated: 2026-07-18 20:01 (WEST) -->
# Data Model — Path B Design Artifacts (Phase 1)

The "entities" of a Figma feature: variables, components, and the screen×findings matrix. Values are the plan-of-record; the pilot may tune non-semantic details (exact grays) but role *structure* is fixed by the spec.

## 1 · `iOS Semantic` variable collection (new; Light + Dark on every var — research D4)

| Variable | Light | Dark | Role (one each — FR-006/SC-002) |
|---|---|---|---|
| `role/action` | `#34C759` | `#30D158` | primary action + on-state (merged per clarify Q1); toggles, primary buttons |
| `role/selectionTint` | `#3C3C43 @ 8%` over surface (neutral) | `#EBEBF5 @ 12%` | selected row/option background; pairs with a checkmark (Q3 iOS-standard) |
| `role/caption` | `#6C6C70` | `#AEAEB2` | group caption headers + footnotes — AA-compliant (FR-019; 5.23:1 on white) |
| `role/destructive` | `#D54037` | `#FF453A` | destructive text/actions (light aliases the retinted `ink/destructive`) |
| `role/status` | `#34C759` (dot only) | `#30D158` | status-ok indicators ("Installed") — same hue as action, never on interactive chrome |
| `surface/groupedBg` | `#EFF2EB` (keeps sage ground) | `#12140F` | screen ground behind groups |
| `surface/groupContainer` | `#FFFFFF` | `#1C1E19` | inset group container fill (shadowless) |
| `separator/hairline` | `#3C3C43 @ 29%` | `#545458 @ 65%` | row separators (iOS-standard translucent) |

Retained/untouched: mood/energy/focus ramps (data-only), `accent/medication` + `accent/medicationText` (medication identity), `ink/primary`. Retired from converted screens: brand greens in action/control/selection roles.

## 2 · Spacing & radius (reused — research D1)

| Tier | Variable (existing, Squirl Tokens) | Use |
|---|---|---|
| intra-row / in-group | `spacing/m = 12` | element gaps inside rows |
| group padding / margins | `spacing/l = 16` | screen gutters, row leading/trailing insets |
| between groups | `spacing/xxl = 24` | group-to-group rhythm |
| between sections | `spacing/section = 32` | major section breaks (R29 tiers) |
| container radius | `radius/control = 10` | inset-group containers (grouped-table standard) |
| retained card radius | `radius/card = 20` (Tiimo) | non-list retained cards only (FR-017) |

## 3 · Component library — "iOS Grouped" set (new local components)

| Component | Variants / props | Notes |
|---|---|---|
| `Group/Container` | — | shadowless, `surface/groupContainer`, r10, clips rows |
| `Group/CaptionHeader` | with/without trailing action | uppercase 13 `role/caption`, sits OUTSIDE container (FR-002) |
| `Group/Footnote` | — | 13 `role/caption`, outside container below |
| `Row/Base` | leading-icon? · label · value? · 44pt min height | hairline separator inset to text (FR-003), ≥44pt (FR-018/rank-7) |
| `Row/Toggle` | on/off | system switch, `role/action` on-state (FR-004) |
| `Row/Disclosure` | — | chevron trailing (FR-004) |
| `Row/Selection` | selected/unselected | checkmark + `role/selectionTint` (Q3) |
| `Row/Destructive` | — | `role/destructive` centered label |
| `Control/Segmented` | 2–4 segments | replaces detached pills (FR-004) |
| `Chrome/MedBar` | dose states | pinned chrome: thinner, tinted, NOT a card (FR-009; research D3) |
| `Chrome/StatusBar` | — | one shared instance, all 8 frames (FR-010) |
| `NavBar/LargeTitle` | — | a02/a08 (FR-005) |
| `NavBar/Sheet` | Cancel/title/Save | a03 modal (FR-005 corrected) |

## 4 · Screen × grammar × audit-findings matrix (FR-018 obligations)

| Screen | Grammar class | Perceptual-audit findings it MUST fix (rank) | Nav |
|---|---|---|---|
| **a02 pilot** | grouped-table | 1 hierarchy · 2 green · 3 card-grammar · 5 glyph-fill · 6 med-bar/status · 9 title-role · 10 padding-families · 13 state-clarity(n/a-check) · **16 purple audio player** · **17 hairline signal bars** · icon-set unification | LargeTitle |
| a03 | grouped-table | 1 · 2 · 3 · 5 · **7 touch-targets (chip grids)** · 9 · 13 (green-vs-purple selection) | Sheet |
| a08 | grouped-table | 1 · 2 · 3 · 6 · 9 · 13 (three-ways-one-choice) · **15 system-green switch** | LargeTitle |
| a01 | native composition (protection lifted) | 1 · 2 · 6 · 11 density · 12 chip-shape · **14 day-card duplicate/disc/green-on-green** | root |
| a04/a05 | native composition | 2 · **8 ring recomposition + duplicate indicator** · 11 | root/sheet |
| a06 | native composition | 2 · **18 unbalanced composition** | — |
| a07 | native composition (retained cards allowed) | 1 · 2 · **4 one-chart-vocabulary (D5: ≤2 families)** · 5 · 11 · 18 dashed-idiom | root |

States required (from findings): a01 expanded+collapsed day card (rank-14) · a07 locked/"not tracked" (rank-18, native empty-state pattern) · med-bar dose states on `Chrome/MedBar`.

## 5 · Verification data

Baseline numbers the re-audit is measured against: 8 high-severity findings across lenses (SC-008 → 0 on converted screens) · contrast baseline = AA for caption/secondary text (FR-019) · content inventories per screen captured from the backup page at conversion time (SC-005's 100% check).
