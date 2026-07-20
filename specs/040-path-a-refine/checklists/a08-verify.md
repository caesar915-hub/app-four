<!-- Created: 2026-07-20 19:40 (WEST) · Updated: 2026-07-20 19:40 (WEST) -->
# a08-a Verify — US1 evidence (T006)

Target: `a08-a / Settings (Path A refine)` `647:1408` (Screens v3, below a08). Renders: `a08a-v2.png` + Dose Guard closeups (scratchpad). All numbers measured via `use_figma` this session.

## Recipe walk (refine-recipe contract)
- [x] §1 Tiers: content gap **20**; 3 section spacers **12** (⇒32) before My Medication / Your data / export card; in-card gap 12
- [x] §2 Cards: **9** (was 13 — Preferences merge + Accessibility fold), all r20, **1 shadow each** (0/2/8@5%); destructive Clear-All isolated; merged rows = kicker(10+0.6 caption)+content
- [x] §4 Chrome: med bar **44pt r14 tint@0.10, 0 effects**, accepted anatomy; status bar present
- [x] §5 Controls: **6 toggles ON = `accent/selection`** (rank-15 gone); **13 chips h36/r18 ≥8 gaps** (≥44 effective), **0 sub-family chips remain**; selected generic chips = green fill + **ink Semi Bold label** (AA); med-identity chips (Concerta, 36 mg) keep purple fill + **green selection ring** (identity ≠ selection — rank-13); Dose Guard = one card, 3 radio rows (Time-window selected, teal ring+dot), details wrap
- [x] §7 AA spot set: kickers #6C6C70 on white 5.23 · ink labels on selection green ≥5 · medText on tint 5.13 (pilot math) · destructive red 4.55
- [x] §8 Parity: **63-string dump — every a08 inventory string present**, incl. FULL footnotes (inventory's 60-char truncations now superseded). Transforms documented: System/Check-in/Calendar/Accessibility card titles → kickers (strings verbatim); addition: "Preferences" card title (grammar, flagged)

## Findings check (data-model row a08)
| Rank | Status |
|---|---|
| 1 hierarchy | ✅ tiers + merge + kicker/title roles |
| 2 green roles | ✅ one interactive green (`accent/selection`) on every control; mood ramp absent from controls |
| 3 card grammar | ✅ 13→9 cards, single soft shadow, no card-per-fact runs |
| 6 med bar | ✅ 44pt tinted chrome |
| 9 title roles | ✅ card-title 17SB + kicker 10 caps, one each |
| 13 three-ways-one-choice | ✅ Dose Guard radio rows; selection ring ≠ identity fill |
| 15 toggle green | ✅ all 6 bound `accent/selection` |

## Deviations / notes for owner
- "Preferences" is a new card title (the only added string); the three old card titles live on as its kickers.
- Selected generic chips now use **ink** labels on green (was white — white fails AA 2.2:1; FR-013).
- Build defect caught + fixed mid-pass: first toggle rebind rendered black (paint fell back), rebound correctly; Dose Guard radios initially stacked (row was centered NONE-layout) → rows rebuilt horizontal.

**Status: PASS — awaiting owner side-by-side (T019).**
