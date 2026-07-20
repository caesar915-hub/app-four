<!-- Created: 2026-07-18 20:52 (WEST) · Updated: 2026-07-20 09:25 (WEST) -->
# a02-b Contract Walk + Parity + Findings — Gate 1 evidence

Target: `a02-b / Recording Detail (Path B)` node `610:1393` on Screens v3 (`552:1163`), built 2026-07-18 (T012–T016). Evidence = `use_figma` measurements (structure dump, this session) + `a02b-final.png`. All checks against [contracts/grouped-table-grammar.md](../contracts/grouped-table-grammar.md) and [inventories/a02.md](../inventories/a02.md).

## T017 — Contract walk (§1–§7)

### §1 Group anatomy
- [x] Container fill = `surface/groupContainer` bound — 8/8 groups `fillBound: true`
- [x] Radius 10 via `radius/control` — 8/8 `radius: 10, radiusBound: true`
- [x] No shadow, no stroke — 8/8 `effects: 0`, no strokes
- [x] Screen gutter 16 both sides (`spacing/l` bound); groups span 358 on the 390 frame — measured
- [x] Between groups 24 (`spacing/xxl` bound stack gap); major-section tier 32 before TRANSCRIPT and Delete (24 + 8 `spacing/s` padding)
- [x] Caption header outside container, 16 leading inset, 8 below (baked into `Group/CaptionHeader`)
- [x] Footnote: none needed on a02 (contract MAY) — component exists for other screens

### §2 Row anatomy
- [x] Min height 44 — measured: Row/Base 45, signal rows 52, player 52, destructive 44
- [x] Horizontal insets 16/16 inside container (`spacing/l` bound)
- [x] Separator `separator/hairline` 0.5px, inset to text leading edge — 16 on plain rows (in `Row/Base`), 50 on glyph signal rows; none after last row (all groups verified)
- [x] Row kinds: value rows (label `ink/primary` / value `role/caption`) · destructive centered `role/destructive` — both per contract

### §3 Controls
- [x] n/a on a02 (no toggles/segmented/steppers); audio play control = neutral `ink/primary` polygon

### §4 Navigation
- [x] a02 = large-title nav (`NavBar/LargeTitle` instance, title "Recording", Bold 34); native back chevron `role/action`

### §5 Color roles
- [x] `role/action` = interactive tint only (back chevron); no brand greens on any control
- [x] Mood/energy/focus ramps on data marks only — post-T020 each signal uses ONE step for glyph+bar: `color/mood/base-5` (4.25:1) · `color/energy/base-2` (3.07:1) · `color/focus/base-3` (3.68:1)
- [x] Medication purple = med identity only (`Chrome/MedBar` tint + capsule + text); audio player neutral (rank-16 gone)
- [x] Caption contrast: `role/caption` #6C6C70 — 5.23:1 on white, ≥4.6:1 on #EFF2EB (computed T023)

### §6 Chrome
- [x] `Chrome/StatusBar` instance (44pt) — a02 original had NONE; FR-010 gap closed on the rebuild
- [x] `Chrome/MedBar` instance: 36pt (thinner than rows), `accent/medication` @12% tint (not `surface/groupContainer`), zero effects, pinned under status bar — cannot read as a content card

### §7 Typography roles
- [x] Caption 13 uppercase · row label 17 Regular · row value 17 `role/caption` · large title 34 Bold — all present, one role each
- [x] Signal value words = `Great/Charged/Sharp` 17 Regular `role/caption` (T020 fix 1 — initial 15-SB-ink treatment was flagged by 2 lenses and corrected to the §7 value role; word tokens preserved, casing documented)
- [~] Meta line `Mon · 09:15` = 15 `role/caption` under the large title — subtitle, not a contract role (duration deduped into AUDIO, T020 fix 5)

## T018 — Content parity (SC-005) — **100%**

Every inventory string present on `a02-b` (text dump, 29 strings): med bar `09:15 · Concerta 36mg` + `ACTIVE` · meta line · GREAT/CHARGED/SHARP + Mood/Energy/Focus (kickers case-transformed) · MEDICATIONS + `Concerta 36mg`|`taken at 09:15` · SLEEP + `rested`|`slept 7h` · EMOTIONS + `excited`,`calm` (rows) · SIDE EFFECTS + `dry mouth`,`jittery` (rows) · TRANSCRIPT + full body verbatim · AUDIO + `2:34` + play + progress · `Delete recording`.
Documented grammar transforms (content-neutral): `·` joiners become label/value splits or rows; category titles → uppercase captions; kickers → title-case row labels. Additions (nav grammar, flagged): large title "Recording"; status bar (FR-010). Drops (consistent-icon-drop rule, US1-AS2): 4 category glyphs + trash glyph — zero information loss (all were decorative duplicates of the captions).

## T019 — Mapped findings check (FR-018, data-model §4 row a02)

| Rank | Finding | Status on a02-b |
|---|---|---|
| 1 | No emphasis/spacing hierarchy | ✅ 8/12/16/24/32 tiers, bound; caption vs content vs data weights |
| 2 | One green, many meanings | ✅ single `role/action` tint; brand greens absent from controls |
| 3 | Web/Material card grammar | ✅ shadowless inset groups, hairline rows, no card-per-fact |
| 5 | Glyph fill inconsistency | ✅ category icons dropped consistently; aperture ring weight 2.0 (T020) so the 3 signal glyphs carry comparable ink |
| 6 | Med bar reads as content | ✅ 36pt tinted chrome, unshadowed, pinned |
| 9 | Four interchangeable title roles | ✅ exactly one caption role + one large title |
| 10 | Padding families | ✅ only bound spacing tokens (8/12/16/24/32) |
| 13 | State clarity | n/a — no selection states on a02-b (checked) |
| 16 | Medication-purple audio player | ✅ neutral `ink/primary` play + progress |
| 17 | Hairline signal bars | ✅ 6pt fills on 86×6 visible tracks, ramp-bound, original ratios (69/73/60) |
| — | Icon-set unification | ✅ via consistent drop + equal-weight signal glyphs |

## T021–T023 — US2 color-role verification (SC-002, FR-006/007/019)

Variable census of `a02-b` (fills+strokes walk): **every color binding maps to exactly one role** — `role/action` ×2 (back chevron) · `role/caption` ×15 · `role/destructive` ×1 · `surface/groupContainer` ×8 · `surface/groupedBg` ×1 · `separator/hairline` ×8 · med identity `accent/medication` ×2 + `accent/medicationText` ×2 (chrome only) · ramps data-only (`mood/base-5` = bar + sprout glyph; `energy/base-2` bar + bolt glyph and `focus/base-3` bar + aperture rings after the T020 one-step-per-signal unification) · `ink/primary` ×25, `ink/tertiary` ×2 (status clone).
- [x] **Zero brand greens** (#5F8A4C/#54B492/#5FB36E) — raw scan + variable-name scan both empty
- [x] Raw paints reduced to documented neutrals: 4× track `#3C3C43@12%`, status-bar clone glyph blacks. **Fixed during scan**: bolt glyph was raw `#FFE803` → bound `color/energy/base-5` (matches sprout/aperture data-mark bindings)
- [x] Selection: no selection states on a02 — `role/selectionTint` unused here (n/a check)
- [x] AA (computed, WCAG relative luminance): caption on groupedBg **4.62** · caption on white **5.23** · ink on white 17.13 · medText on med-bar tint (#E1E0E3 resolved) **5.13** · destructive on white **4.55**. **Fixed during scan**: `ACTIVE` was medText@80% = 3.49 ✗ → solid medText = **5.13 ✓** (component + verified instance inherits)

## T024–T025 — US3 hierarchy & chrome verification (SC-003, FR-009/010)

- [x] Spacing tiers measured: within-row paddings 8/12/16 (bound) < between-group **24** (`spacing/xxl` bound stack gap) < major-section **32** (24+8 before TRANSCRIPT and Delete) — three distinct, token-bound tiers
- [x] `Chrome/StatusBar` present (44pt instance; a02 originally lacked it — FR-010 closed)
- [x] `Chrome/MedBar`: 36pt < 44pt rows, tinted `accent/medication@12%` (resolves #E1E0E3-lavender, not white), zero effects, pinned under status bar, full-bleed — reads as chrome, not a content card

## T020 — 4-lens agent re-audit (4 parallel Fable subagents, 2026-07-18/19)

Raw: fresh-eyes 9 (2H/4M/3L) · HIG 4 (1M/3L, all §1–§6 anatomy re-measured PASS) · checklist 4 (1H/2M/1L, delete-red/grays/ACTIVE/separators verified compliant) · consistency 3 (1H/2M, all other suspects measured clean) → **13 unique findings** after cross-lens dedup.

**Fixed on canvas (9)**
1. Signal value words → `Great/Charged/Sharp`, 17 Regular `role/caption` (was bold ink caps — flagged by 2 lenses as Material overline)
2. Energy mark color unified glyph+bar on **`color/energy/base-2` (3.07:1)** — kills both the two-yellows high and the 1.03:1 invisible-fill medium
3. Focus mark → glyph+bar on **`color/focus/base-3` (3.68:1)** (was 2.65:1)
4. Aperture ring weight → 2.0 (ink-mass gap vs sprout/bolt narrowed; ring *shape* unchanged per rank-5 ruling)
5. Meta line → `Mon · 09:15` (duration deduped — lives in AUDIO row)
6. EMOTIONS / SIDE EFFECTS → joined single rows `excited · calm`, `dry mouth · jittery` (kills the bare-token data-dump high; restores original middots verbatim)
7. Audio `2:34` → 17pt (trailing-metadata size now uniform)
8. Back affordance → chevron at 8pt leading (`spacing/s`) + `Back` 17 label, cluster driven by the Back boolean (NavBar/LargeTitle component)
9. Status bar person-bust artifact hidden (nested-instance vectors — `visible:false`, `remove()` disallowed)

**Documented as intended (4)** — owner sees these at the gate
- Back tint = `role/action` #34C759 at ~1.96:1 on the ground: **inherent to the owner's system-green tint ruling (clarify Q1)**; Apple ships the same green as a tint. The added Back label mitigates affordance; recolor would need a new ruling.
- Med strip as second-status-bar / duplicate 09:15: FR-009 pinned chrome by design; the 09:15s are dose-time vs check-in-time (sample data coincide).
- Lowercase vocab values (`rested`, `excited · calm`…): app fixed-vocabulary voice, parity-preserved (HIG low, defensible).
- `Delete recording` sentence case: app copy voice (HIG prefers title case; parity kept).

**Deferred to the SwiftUI spec (2)** — implementation notes, not canvas facts
- ≥44pt hit zones for chevron/play + play-vs-scrub gesture separation.
- Med-bar tap target if the bar is interactive (36pt is passive-banner compliant only).

Residual sample-data notes: "Mon" has no date (original's data); audio shows progress with play icon and no elapsed counter (static mock state).

**SC-008 (scope-of-one)**: all high-severity findings fixed except the back-tint contrast, which is not a defect of a02-b but a consequence of the standing `role/action` ruling — flagged for explicit owner judgment at the gate. Post-fix render: `a02b-postaudit.png` (scratchpad).

## T026 — Owner gate verdict: **FAIL → PATH B KILLED** (2026-07-20)

Owner judgment: a02-b reads as unacceptable identity loss ("completely disgusting") — the spec's named core tradeoff (generic system-settings look vs Squirl character) fired exactly as the pilot was designed to test. Every technical check above passed; the *language itself* was rejected. `a02-b` deleted per quickstart §Rollback; tokens + library parked; successor = Path A refine pilot (`a02-a`, `638:1465`).

## Notes / deviations for the owner
- Large title "Recording" and the status bar are **additive** (nav grammar / FR-010) — not in the original.
- Signal words at 15 SB and the meta line are deliberate non-row-role text (see §7 marks).
- Toggle off-track (library) and bar tracks use raw iOS neutral grays (#787880@16%, #3C3C43@12%) — neutrals, not semantic roles.
- Tiimo `radius/card` (20) is the retained-card token for non-list screens; Squirl `radius/card`=16 is legacy and unused here (T002 note).
